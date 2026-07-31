--!strict
-- Filesystem and string helpers shared by the boil CLI.

local fs = require("@lune/fs")
local process = require("@lune/process")

local util = {}

local SKIP_DIRS: { [string]: boolean } = { [".git"] = true, [".github"] = true }

function util.ensureDir(path: string)
	if fs.isDir(path) then
		return
	end
	local parent = string.match(path, "^(.*)/[^/]+$")
	if parent and parent ~= "" and not fs.isDir(parent) then
		util.ensureDir(parent)
	end
	fs.writeDir(path)
end

-- Every file under `dir`, as paths relative to `dir`, sorted. `.git` is skipped
-- so a freshly-cloned package fingerprints the same as an installed one.
function util.listFiles(dir: string): { string }
	local out: { string } = {}
	local function recurse(current: string, prefix: string)
		if not fs.isDir(current) then
			return
		end
		for _, entry in fs.readDir(current) do
			local path = `{current}/{entry}`
			local rel = if prefix == "" then entry else `{prefix}/{entry}`
			if fs.isFile(path) then
				table.insert(out, rel)
			elseif fs.isDir(path) and not SKIP_DIRS[entry] then
				recurse(path, rel)
			end
		end
	end
	recurse(dir, "")
	table.sort(out)
	return out
end

function util.copyDir(src: string, dest: string)
	util.ensureDir(dest)
	for _, rel in util.listFiles(src) do
		local target = `{dest}/{rel}`
		local parent = string.match(target, "^(.*)/[^/]+$")
		if parent then
			util.ensureDir(parent)
		end
		fs.writeFile(target, fs.readFile(`{src}/{rel}`))
	end
end

function util.removeDir(path: string)
	if fs.isDir(path) then
		fs.removeDir(path)
	end
end

-- "encryptal/player-data" -> "PlayerData". The folder name becomes the Roblox
-- instance name and the registration key, so it has to be PascalCase.
function util.pascal(name: string): string
	local last = string.match(name, "([^/]+)$") or name
	local out = ""
	for word in string.gmatch(last, "[%w]+") do
		out ..= string.upper(string.sub(word, 1, 1)) .. string.sub(word, 2)
	end
	return out
end

function util.trim(s: string): string
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function util.startsWith(s: string, prefix: string): boolean
	return string.sub(s, 1, #prefix) == prefix
end

local tempCounter = 0

function util.tempDir(label: string): string
	local base = process.env.TMPDIR or process.env.TEMP or "/tmp"
	base = (string.gsub(base, "/$", ""))
	tempCounter += 1
	local path = `{base}/boil-{label}-{os.time()}-{tempCounter}`
	util.removeDir(path)
	util.ensureDir(path)
	return path
end

-- Word-wrap for the explorer's detail view.
function util.wrap(text: string, width: number, indent: string): { string }
	local lines: { string } = {}
	for _, paragraph in string.split(util.trim(text), "\n") do
		local line = ""
		for word in string.gmatch(paragraph, "%S+") do
			if line == "" then
				line = word
			elseif #line + #word + 1 <= width then
				line ..= " " .. word
			else
				table.insert(lines, indent .. line)
				line = word
			end
		end
		table.insert(lines, indent .. line)
	end
	return lines
end

return util
