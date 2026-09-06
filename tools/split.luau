--!strict
-- Splits src/features/<Feature>/*.luau into build/{shared,server,client}/<Feature>/
-- *.server.luau -> build/server/<Feature>/<name>.luau  (suffix stripped)
-- *.client.luau -> build/client/<Feature>/<name>.luau
-- *.ui.luau     -> build/shared/<Feature>/<name>.luau  (suffix stripped)
-- everything else (init.luau, plain *.luau) -> build/shared/<Feature>/<same-name>
--
-- It also COMPILES each feature's boil.toml into build/shared/<Feature>/Manifest.luau.
-- The manifest is the single source of truth for what a feature needs, but a TOML
-- file never reaches Roblox (only .luau is copied), so the runtime had no way to
-- read it — dependencies existed for the CLI and were invisible to the game.
-- Emitting a Luau mirror is what lets `FeatureLoader` sort features by their
-- dependency graph and warn about a missing one at boot, instead of every feature
-- guessing a `Priority` integer.
--
-- Stories (`*.story.luau`) are copied like any other file, because UI Labs reads
-- them from the DataModel at edit time. Pass `--no-stories` for a production
-- build to leave them out — they are a third of the feature code and nothing
-- shipped ever requires them.
--
-- Run: `lune run tools/split` (one-shot) or `lune run tools/split --watch`
-- (on Lune < 0.9 the flag needs a `--` separator: `lune run tools/split -- --watch`)
--
-- The build is incremental: only changed files are written, stale files are
-- deleted in place, and the three realm dirs are never removed. The previous
-- "rm -rf build && recreate" pattern would cause Rojo's file watcher to miss
-- newly-added feature folders, requiring a `rojo serve` restart on every new
-- feature.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local SRC = "src/features"
local BUILD = "build"
local REALMS = { "shared", "server", "client" }

-- Set by --no-stories. Declared here so build() can see it.
local skipStories = false

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

-- Read every feature's boil.toml once, so dependencies (which name PACKAGES,
-- e.g. "encryptal/ui-shell") can be resolved to the FOLDERS they installed into
-- ("UIShell") — which is what the runtime actually looks up.
type Manifest = {
	folder: string,
	package: string,
	version: string,
	requires: { string },
	soft: { string },
	missing: { string },
}

local function readManifests(): { [string]: Manifest }
	local byFolder: { [string]: any } = {}
	local folderForPackage: { [string]: string } = {}

	if not fs.isDir(SRC) then
		return {}
	end

	for _, feature in fs.readDir(SRC) do
		local path = `{SRC}/{feature}/boil.toml`
		if not fs.isDir(`{SRC}/{feature}`) or not fs.isFile(path) then
			continue
		end
		local ok, decoded = pcall(serde.decode, "toml" :: any, fs.readFile(path))
		if not ok then
			print(`[split] WARNING {path} is not valid TOML; skipping its manifest ({decoded})`)
			continue
		end
		local pkg = (decoded :: any).package or {}
		local record = {
			folder = pkg.folder or feature,
			package = pkg.name or "",
			version = pkg.version or "0.0.0",
			dependencies = (decoded :: any).dependencies or {},
			soft = (decoded :: any)["soft-dependencies"] or {},
		}
		byFolder[feature] = record
		if record.package ~= "" then
			folderForPackage[record.package] = record.folder
		end
	end

	local out: { [string]: Manifest } = {}
	for feature, record in byFolder do
		local requires: { string } = {}
		local soft: { string } = {}
		local missing: { string } = {}

		for name in record.dependencies do
			local folder = folderForPackage[name]
			if folder then
				table.insert(requires, folder)
			else
				-- Declared but not installed in this checkout. Recorded rather
				-- than dropped so the game can say so at boot.
				table.insert(missing, name)
			end
		end
		for name in record.soft do
			local folder = folderForPackage[name]
			if folder then
				table.insert(soft, folder)
			end
		end

		table.sort(requires)
		table.sort(soft)
		table.sort(missing)
		out[feature] = {
			folder = record.folder,
			package = record.package,
			version = record.version,
			requires = requires,
			soft = soft,
			missing = missing,
		}
	end
	return out
end

local function luaList(values: { string }): string
	if #values == 0 then
		return "{}"
	end
	local quoted: { string } = {}
	for _, value in values do
		table.insert(quoted, `"{value}"`)
	end
	return "{ " .. table.concat(quoted, ", ") .. " }"
end

local NEWLINE = string.char(10)

local function manifestSource(manifest: Manifest): string
	local lines = {
		"--!strict",
		"-- GENERATED by tools/split from this feature's boil.toml. Do not edit;",
		"-- change the manifest and re-run the splitter.",
		"--",
		"-- `requires` and `soft` are FOLDER names, resolved from the package names",
		"-- in boil.toml, because folders are what the runtime looks up under",
		"-- Features. `missing` lists declared dependencies not installed here.",
		"",
		"return {",
		`	name = "{manifest.package}",`,
		`	folder = "{manifest.folder}",`,
		`	version = "{manifest.version}",`,
		`	requires = {luaList(manifest.requires)},`,
		`	soft = {luaList(manifest.soft)},`,
		`	missing = {luaList(manifest.missing)},`,
		"}",
		"",
	}
	return table.concat(lines, NEWLINE)
end

local function build()
	-- 1. Compute the target file set: { [outPath] = sourceContent }.
	local target: { [string]: string } = {}
	local featureCount = 0
	local manifests = readManifests()
	local manifestCount = 0
	if fs.isDir(SRC) then
		for _, feature in fs.readDir(SRC) do
			local featureDir = `{SRC}/{feature}`
			if fs.isDir(featureDir) then
				featureCount += 1
				for _, entry in fs.readDir(featureDir) do
					local srcPath = `{featureDir}/{entry}`
					if fs.isFile(srcPath) and string.match(entry, "%.luau$") then
						if skipStories and string.match(entry, "%.story%.luau$") then
							continue
						end
						local realm, outName = classify(entry)
						local outPath = `{BUILD}/{realm}/{feature}/{outName}`
						target[outPath] = fs.readFile(srcPath)
					end
				end

				-- Compile the manifest alongside the feature's own modules, in
				-- the shared realm so both server and client can read it.
				local manifest = manifests[feature]
				if manifest then
					manifestCount += 1
					target[`{BUILD}/shared/{feature}/Manifest.luau`] = manifestSource(manifest)
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
		print(`[split] built {featureCount} feature(s) ({manifestCount} manifest(s)) into {BUILD}/`)
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

-- Scan the whole arg list rather than checking args[1]. Lune 0.9 stopped
-- sinking flags passed to `lune run`, so `-- --watch` now arrives as two
-- arguments ("--", "--watch") instead of one. Looking for the flag anywhere
-- keeps both invocations working.
local watching = false
for _, arg in process.args do
	if arg == "--watch" then
		watching = true
	elseif arg == "--no-stories" then
		skipStories = true
	end
end

if watching then
	watch()
else
	build()
end
