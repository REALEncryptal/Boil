--!strict
-- Compiles every .luau file in the project and reports the ones that don't parse.
--
-- Run: `lune run tools/check-syntax`   (exits non-zero on a syntax error)
--
-- This fills a real hole. `rojo build` embeds source as strings and never parses
-- it, so a syntax error survives a clean build and only surfaces when Roblox
-- requires the module at runtime — often in a code path nobody hits until a
-- player does. The splitter completing was the closest thing to a signal, and it
-- only proves files were *copied*.
--
-- Lune's `@lune/luau` runs the same compiler Roblox does, so this catches the
-- syntax half of that gap in about a second. It does NOT type-check: that needs
-- `luau-analyze` against a generated sourcemap, which is a separate tool and a
-- separate install.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local ROOTS = { "src", "tools" }

local failures = 0
local checked = 0

local function walk(dir: string, visit: (string) -> ())
	if not fs.isDir(dir) then
		return
	end
	for _, entry in fs.readDir(dir) do
		local path = `{dir}/{entry}`
		if fs.isDir(path) then
			walk(path, visit)
		elseif fs.isFile(path) and string.match(entry, "%.luau$") then
			visit(path)
		end
	end
end

for _, root in ROOTS do
	walk(root, function(path)
		checked += 1
		local ok, err = pcall(luau.compile, fs.readFile(path))
		if ok then
			return
		end
		failures += 1
		print(`[check-syntax] {path}`)
		-- The compiler prefixes its own path; strip it so the message reads as
		-- `line: problem` rather than repeating what we just printed.
		local message = tostring(err)
		print(`    {(string.gsub(message, "^%[string [^%]]*%]:?", ""))}`)
	end)
end

if failures > 0 then
	print(`\n[check-syntax] FAILED — {failures} of {checked} file(s) do not parse.`)
	process.exit(1)
end

print(`[check-syntax] ok — {checked} file(s) parse.`)
