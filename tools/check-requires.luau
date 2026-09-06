--!strict
-- Detects require cycles between modules in the shared UI kit.
--
-- Run: `lune run tools/check-requires`   (exits non-zero on a cycle)
--
-- Why this exists: a cycle here doesn't produce a readable error. It produces
-- "C stack overflow" from inside whatever required the module first — in
-- practice, from UI Labs' Promise internals, naming a file that has nothing to do
-- with the problem. Nothing else in the toolchain catches it: the splitter only
-- copies files, `check-syntax` parses each file alone, and `rojo build` embeds
-- source as strings.
--
-- The cycle that motivated it:
--
--   skins/init → gem → ScrollList → SkinProvider → skins/init
--
-- ScrollList is a gem *implementation*. It resolved the active skin to read a
-- spacing token, which closed the loop. The rule that follows:
--
--   A skin implementation must never require SkinProvider — it IS a skin.
--   Only the semantic wrappers in init.luau and the unskinned layout primitives
--   (Stack / Row / Grid / Slot, which no skin lists) may call useSkin.
--
-- That rule is checked directly below as well, because it produces a much better
-- message than "cycle found" does.

local fs = require("@lune/fs")
local process = require("@lune/process")

local UI = "src/shared/ui"
local GEM = "src/shared/ui/skins/gem.luau"

local problems = 0

local function fail(message: string, detail: string?)
	problems += 1
	print(`[check-requires] {message}`)
	if detail then
		print(`    {detail}`)
	end
end

-- Modules keyed by name, with the sibling modules each one requires.
type Module = { name: string, path: string, requires: { string } }

local function collect(): { [string]: Module }
	local modules: { [string]: Module } = {}
	if not fs.isDir(UI) then
		return modules
	end

	local function add(path: string, name: string)
		local source = fs.readFile(path)
		local requires: { string } = {}

		-- `require(script.Parent.X)` / `require(ui.X)` / `require(script.X)` —
		-- the three shapes the kit actually uses for sibling requires.
		for target in string.gmatch(source, "require%(script%.Parent%.([%w_]+)%)") do
			table.insert(requires, target)
		end
		for target in string.gmatch(source, "require%(ui%.([%w_]+)%)") do
			table.insert(requires, target)
		end
		for target in string.gmatch(source, "require%(script%.([%w_]+)%)") do
			table.insert(requires, target)
		end

		modules[name] = { name = name, path = path, requires = requires }
	end

	for _, entry in fs.readDir(UI) do
		local path = `{UI}/{entry}`
		if fs.isFile(path) and string.match(entry, "%.luau$") and not string.match(entry, "%.story%.luau$") then
			add(path, (string.gsub(entry, "%.luau$", "")))
		end
	end

	-- The skin registry and the gem table participate in the graph.
	if fs.isFile(`{UI}/skins/init.luau`) then
		add(`{UI}/skins/init.luau`, "skins")
	end
	if fs.isFile(GEM) then
		add(GEM, "gem")
	end

	return modules
end

local modules = collect()

------------------------------------------------------------------------------
-- The specific rule, checked first for the better message
------------------------------------------------------------------------------
-- Everything gem lists as a component implementation.
local gemComponents: { [string]: boolean } = {}
if fs.isFile(GEM) then
	local block = string.match(fs.readFile(GEM), "components%s*=%s*(%b{})")
	if block then
		for key in string.gmatch(block, "([%w_]+)%s*=") do
			gemComponents[key] = true
		end
	end
end

for name in gemComponents do
	local module = modules[name]
	if module == nil then
		continue
	end
	for _, target in module.requires do
		if target ~= "SkinProvider" then
			continue
		end
		fail(
			`{module.path} requires SkinProvider, but it is a gem skin implementation`,
			"A skin must not resolve the active skin — that closes the cycle "
				.. "skins → gem → this file → SkinProvider → skins. Read `theme` directly."
		)
	end
end

------------------------------------------------------------------------------
-- General cycle detection
------------------------------------------------------------------------------
local state: { [string]: string } = {} -- "open" while on the stack, "done" after
local stack: { string } = {}
local reported: { [string]: boolean } = {}

local function visit(name: string)
	local module = modules[name]
	if module == nil or state[name] == "done" then
		return
	end

	if state[name] == "open" then
		-- Trim the stack to the cycle itself so the message is the loop, not the
		-- whole path that reached it.
		local start = table.find(stack, name) or 1
		local loop: { string } = {}
		for index = start, #stack do
			table.insert(loop, stack[index])
		end
		table.insert(loop, name)

		local key = table.concat(loop, ">")
		if not reported[key] then
			reported[key] = true
			fail("require cycle", table.concat(loop, " → "))
		end
		return
	end

	state[name] = "open"
	table.insert(stack, name)
	for _, target in module.requires do
		visit(target)
	end
	table.remove(stack)
	state[name] = "done"
end

for name in modules do
	visit(name)
end

if problems > 0 then
	print(`\n[check-requires] FAILED — {problems} problem(s).`)
	print("A cycle surfaces at runtime as a C stack overflow, usually blaming an unrelated file.")
	process.exit(1)
end

local count = 0
for _ in modules do
	count += 1
end
print(`[check-requires] ok — {count} module(s), no require cycles.`)
