--!strict
-- Splits src/features/<Feature>/*.luau into build/{shared,server,client}/<Feature>/
-- *.server.luau -> build/server/<Feature>/<name>.luau  (suffix stripped)
-- *.client.luau -> build/client/<Feature>/<name>.luau
-- *.ui.luau     -> build/shared/<Feature>/<name>.luau  (suffix stripped)
-- everything else (init.luau, plain *.luau) -> build/shared/<Feature>/<same-name>
-- Run: `lune run tools/split` (one-shot) or `lune run tools/split -- --watch`
--
-- The build is incremental: only changed files are written, stale files are
-- deleted in place, and the three realm dirs are never removed. The previous
-- "rm -rf build && recreate" pattern would cause Rojo's file watcher to miss
-- newly-added feature folders, requiring a `rojo serve` restart on every new
-- feature.

local fs = require("@lune/fs")
local process = require("@lune/process")
local task = require("@lune/task")

local SRC = "src/features"
local BUILD = "build"
local REALMS = { "shared", "server", "client" }

local function ensureDir(path: string)
	if fs.isDir(path) then
		return
	end
	local parent = string.match(path, "^(.*)/[^/]+$")
	if parent and parent ~= "" and not fs.isDir(parent) then
		ensureDir(parent)
	end
	fs.writeDir(path)
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

-- Returns { [path] = true } for every file under root.
local function listAllFiles(root: string): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if not fs.isDir(root) then
		return set
	end
	local function recurse(dir: string)
		for _, entry in fs.readDir(dir) do
			local p = `{dir}/{entry}`
			if fs.isFile(p) then
				set[p] = true
			elseif fs.isDir(p) then
				recurse(p)
			end
		end
	end
	recurse(root)
	return set
end

-- Returns directories under root in post-order (deepest first), so an empty-dir
-- sweep can clean leaves before their parents.
local function listAllDirs(root: string): { string }
	local out: { string } = {}
	if not fs.isDir(root) then
		return out
	end
	local function recurse(dir: string)
		for _, entry in fs.readDir(dir) do
			local p = `{dir}/{entry}`
			if fs.isDir(p) then
				recurse(p)
				table.insert(out, p)
			end
		end
	end
	recurse(root)
	return out
end

local function build()
	-- 1. Compute the target file set: { [outPath] = sourceContent }.
	local target: { [string]: string } = {}
	local featureCount = 0
	if fs.isDir(SRC) then
		for _, feature in fs.readDir(SRC) do
			local featureDir = `{SRC}/{feature}`
			if fs.isDir(featureDir) then
				featureCount += 1
				for _, entry in fs.readDir(featureDir) do
					local srcPath = `{featureDir}/{entry}`
					if fs.isFile(srcPath) and string.match(entry, "%.luau$") then
						local realm, outName = classify(entry)
						local outPath = `{BUILD}/{realm}/{feature}/{outName}`
						target[outPath] = fs.readFile(srcPath)
					end
				end
			end
		end
	end

	-- 2. Ensure realm dirs exist; Rojo's $path entries point at these.
	ensureDir(BUILD)
	for _, realm in REALMS do
		ensureDir(`{BUILD}/{realm}`)
	end

	-- 3. Delete files that should no longer exist.
	for path in listAllFiles(BUILD) do
		if not target[path] then
			fs.removeFile(path)
		end
	end

	-- 4. Write target files; skip unchanged content so mtimes don't churn.
	for path, content in target do
		local parent = string.match(path, "^(.*)/[^/]+$")
		if parent then
			ensureDir(parent)
		end
		local current
		if fs.isFile(path) then
			current = fs.readFile(path)
		end
		if current ~= content then
			fs.writeFile(path, content)
		end
	end

	-- 5. Sweep empty feature dirs (post-order). Never remove the realm dirs.
	local protected: { [string]: boolean } = { [BUILD] = true }
	for _, realm in REALMS do
		protected[`{BUILD}/{realm}`] = true
	end
	for _, dir in listAllDirs(BUILD) do
		if not protected[dir] and #fs.readDir(dir) == 0 then
			fs.removeDir(dir)
		end
	end

	if not fs.isDir(SRC) then
		print(`[split] {SRC} does not exist; built 0 feature(s) into {BUILD}/`)
	else
		print(`[split] built {featureCount} feature(s) into {BUILD}/`)
	end
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
