--!strict
-- Enforces the headless-core rule: presentation files (`*.ui.luau` and
-- `*View*.luau`) are dumb. They read state and call intent actions — they must
-- NOT contain networking, validation, or persistence. Those belong in the
-- feature's Controller (client) / Service (server).
--
-- Run: `lune run tools/check-views`  (exits non-zero on any violation)
--
-- The splitter doesn't typecheck Luau and Studio is the only runtime, so this is
-- the cheap pre-Studio signal that the core/view seam hasn't been crossed. See
-- docs/game/headless-core.md.

local fs = require("@lune/fs")
local process = require("@lune/process")

local SRC = "src/features"

-- Lua patterns that must not appear in a presentation file, each with a reason.
-- Keep these specific to the seam we're protecting (networking / persistence).
local FORBIDDEN: { { pattern: string, why: string } } = {
	{ pattern = "Packets", why = "networking — packets belong in the Controller/Service, not a view" },
	{ pattern = "ByteNet", why = "networking — define/route packets in the Controller/Service" },
	{ pattern = "%.send%(", why = "networking send — call a Controller intent instead" },
	{ pattern = "%.listen%(", why = "networking listen — handle packets in the Service" },
	{ pattern = "PlayerDataService", why = "persistence — write through the Controller, not the view" },
	{ pattern = "ProfileStore", why = "persistence — server-only; views never touch the datastore" },
}

-- A file is a "presentation" file if it's a *.ui.luau or has "View" in its name.
local function isPresentation(name: string): boolean
	if string.match(name, "%.ui%.luau$") then
		return true
	end
	if string.match(name, "View") and string.match(name, "%.luau$") then
		return true
	end
	return false
end

local violations = 0
local scanned = 0

local function scanFile(path: string, name: string)
	scanned += 1
	local source = fs.readFile(path)
	for lineNo, line in ipairs(string.split(source, "\n")) do
		-- Skip comment-only lines so doc/comments mentioning a term don't trip it.
		local trimmed = string.gsub(line, "^%s*", "")
		if string.sub(trimmed, 1, 2) == "--" then
			continue
		end
		for _, rule in FORBIDDEN do
			if string.find(line, rule.pattern) then
				violations += 1
				print(`[check-views] {path}:{lineNo}`)
				print(`    forbidden: {rule.pattern}  ({rule.why})`)
				print(`    > {trimmed}`)
			end
		end
	end
end

local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif isPresentation(name) then
			scanFile(path, name)
		end
	end
end

walk(SRC)

if violations > 0 then
	print(`\n[check-views] FAILED — {violations} violation(s) across presentation files.`)
	print("Move networking/validation/persistence into the feature's Controller/Service.")
	process.exit(1)
end

print(`[check-views] ok — {scanned} presentation file(s), no logic leaks.`)
