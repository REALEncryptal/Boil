--!strict
-- Enforces the framework/feature boundary: framework code must never name a
-- specific feature. The dependency arrow points one way — features depend on the
-- framework's public surface (Shared.Boil); the framework stays agnostic to every
-- feature so it ships empty and updates without touching feature code.
--
-- Run: `lune run tools/check-framework-boundary`  (exits non-zero on any leak)
--
-- What's allowed: touching the `Features` container generically — iterating it,
-- `LoadDescendants(Features, …)`, `Features:GetChildren()`. That's the discovery
-- mechanism, and it names nobody.
-- What's a violation: reaching a *named* child of it —
-- `Features:WaitForChild("UIShell")`, `require(ReplicatedStorage.Features.Notes)`,
-- `Features.Settings`, `Features["Pets"]`. If the framework needs that, the seam
-- is backwards: the feature should register INTO the framework, not the reverse.
--
-- Scope: the runtime framework realms (Shared / client / server entries). The
-- build tools under tools/ are generic Lune scripts that operate on the features
-- directory by design, so they're out of scope here. See docs/game/framework-boundary.md.

local fs = require("@lune/fs")
local process = require("@lune/process")

local FRAMEWORK_DIRS = { "src/shared", "src/client", "src/server" }

-- Each rule captures the feature name a framework file is reaching for. Every
-- container variable in the entries ends in "Features" (Features / ServerFeatures
-- / ClientFeatures), so matching the bare token covers all three.
local RULES: { { pattern: string, why: string } } = {
	{ pattern = 'Features:WaitForChild%(%s*["\']([%w_]+)["\']', why = "WaitForChild a named feature" },
	{ pattern = 'Features:FindFirstChild%(%s*["\']([%w_]+)["\']', why = "FindFirstChild a named feature" },
	{ pattern = 'Features%[%s*["\']([%w_]+)["\']%s*%]', why = "index a named feature" },
	{ pattern = "Features%.([%a_][%w_]*)", why = "dot-access a named feature" },
}

-- `Features.<X>` accesses that are Instance members, not feature children.
local INSTANCE_MEMBERS: { [string]: boolean } = {
	Name = true,
	Parent = true,
	ClassName = true,
	Archivable = true,
}

local violations = 0
local scanned = 0

local function scanFile(path: string)
	scanned += 1
	local source = fs.readFile(path)
	for lineNo, line in ipairs(string.split(source, "\n")) do
		local trimmed = string.gsub(line, "^%s*", "")
		-- Skip comment-only lines so prose mentioning a feature can't trip it.
		if string.sub(trimmed, 1, 2) == "--" then
			continue
		end
		for _, rule in RULES do
			local name = string.match(line, rule.pattern)
			if not name then
				continue
			end
			if INSTANCE_MEMBERS[name] then
				continue
			end
			violations += 1
			print(`[check-framework-boundary] {path}:{lineNo}`)
			print(`    framework names feature "{name}" ({rule.why})`)
			print(`    > {trimmed}`)
		end
	end
end

local function walk(dir: string)
	if not fs.isDir(dir) then
		return
	end
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.match(name, "%.luau$") then
			scanFile(path)
		end
	end
end

for _, dir in FRAMEWORK_DIRS do
	walk(dir)
end

if violations > 0 then
	print(`\n[check-framework-boundary] FAILED — {violations} feature reference(s) in framework code.`)
	print("Framework code must not name a feature. Invert the seam: have the feature register into the")
	print("framework (UIRegistry / a registration API) instead of the framework reaching for the feature.")
	process.exit(1)
end

print(`[check-framework-boundary] ok — {scanned} framework file(s), no feature references.`)
