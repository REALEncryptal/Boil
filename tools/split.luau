--!strict
-- Splits src/features/<Feature>/*.luau into build/{shared,server,client}/<Feature>/
-- *.server.luau -> build/server/<Feature>/<name>.luau  (suffix stripped)
-- *.client.luau -> build/client/<Feature>/<name>.luau
-- *.ui.luau     -> build/shared/<Feature>/<name>.luau  (suffix stripped)
-- everything else (init.luau, plain *.luau) -> build/shared/<Feature>/<same-name>
-- Run: `lune run tools/split` (one-shot) or `lune run tools/split -- --watch`

local fs = require("@lune/fs")
local process = require("@lune/process")
local task = require("@lune/task")

local SRC = "src/features"
local BUILD = "build"

local function ensureDir(path: string)
	if not fs.isDir(path) then
		fs.writeDir(path)
	end
end

local function classify(filename: string): (string, string)
	if string.match(filename, "%.server%.luau$") then
		return "server", (string.gsub(filename, "%.server%.luau$", ".luau"))
	elseif string.match(filename, "%.client%.luau$") then
		return "client", (string.gsub(filename, "%.client%.luau$", ".luau"))
	elseif string.match(filename, "%.ui%.luau$") then
		return "shared", (string.gsub(filename, "%.ui%.luau$", ".luau"))
	else
		return "shared", filename
	end
end

local function copyFeature(featureName: string)
	local srcDir = `{SRC}/{featureName}`
	for _, entry in fs.readDir(srcDir) do
		local srcPath = `{srcDir}/{entry}`
		if fs.isFile(srcPath) and string.match(entry, "%.luau$") then
			local realm, outName = classify(entry)
			local outDir = `{BUILD}/{realm}/{featureName}`
			ensureDir(outDir)
			fs.writeFile(`{outDir}/{outName}`, fs.readFile(srcPath))
		end
	end
end

local function build()
	if fs.isDir(BUILD) then
		fs.removeDir(BUILD)
	end
	ensureDir(BUILD)
	ensureDir(`{BUILD}/shared`)
	ensureDir(`{BUILD}/server`)
	ensureDir(`{BUILD}/client`)

	if not fs.isDir(SRC) then
		print(`[split] {SRC} does not exist; wrote empty build/`)
		return
	end

	local count = 0
	for _, feature in fs.readDir(SRC) do
		local featurePath = `{SRC}/{feature}`
		if fs.isDir(featurePath) then
			copyFeature(feature)
			count += 1
		end
	end
	print(`[split] built {count} feature(s) into {BUILD}/`)
end

-- naive snapshot: map of path -> modifiedAt (unix seconds)
local function snapshot(): { [string]: number }
	local snap: { [string]: number } = {}
	if not fs.isDir(SRC) then
		return snap
	end
	for _, feature in fs.readDir(SRC) do
		local featurePath = `{SRC}/{feature}`
		if fs.isDir(featurePath) then
			for _, entry in fs.readDir(featurePath) do
				local path = `{featurePath}/{entry}`
				if fs.isFile(path) then
					local meta = fs.metadata(path)
					local modified = meta.modifiedAt
					snap[path] = if modified then modified.unixTimestamp else 0
				end
			end
		end
	end
	return snap
end

local function snapshotsDiffer(a: { [string]: number }, b: { [string]: number }): boolean
	for k, v in a do
		if b[k] ~= v then
			return true
		end
	end
	for k in b do
		if a[k] == nil then
			return true
		end
	end
	return false
end

local function watch()
	build()
	print(`[split] watching {SRC}/ ... (ctrl-c to stop)`)
	local last = snapshot()
	while true do
		task.wait(0.5)
		local now = snapshot()
		if snapshotsDiffer(last, now) then
			build()
			last = now
		end
	end
end

local args = process.args
if args[1] == "--watch" then
	watch()
else
	build()
end
