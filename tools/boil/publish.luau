--!strict
-- `boil publish` — take a folder you built inside a real game and put it in the
-- index.
--
-- The gate matters more than the upload. A package that quietly assumes another
-- feature exists, or requires a Wally package the consuming game doesn't have,
-- installs cleanly and then breaks at runtime in someone else's project. Those
-- checks are the reason this command exists rather than "just push the folder".

local fs = require("@lune/fs")
local process = require("@lune/process")

local manifest = require("./manifest")
local project = require("./project")
local registry = require("./registry")
local source = require("./source")
local term = require("./term")
local util = require("./util")

local publish = {}

export type Options = {
	yes: boolean?,
	dryRun: boolean?,
}

local LINTS = { "tools/split", "tools/check-views", "tools/check-framework-boundary", "tools/check-skins" }

local function runLints(): { string }
	local failures: { string } = {}
	for _, lint in LINTS do
		local result = process.spawn("lune", { "run", lint })
		if not result.ok then
			table.insert(failures, `{lint}:\n{util.trim(if result.stderr ~= "" then result.stderr else result.stdout)}`)
		end
	end
	return failures
end

-- Wally packages the code requires but the manifest doesn't declare.
local function undeclaredWally(package: manifest.Package, dir: string): { string }
	local missing: { [string]: boolean } = {}
	for _, rel in util.listFiles(dir) do
		if not string.match(rel, "%.luau$") then
			continue
		end
		for line in string.gmatch(fs.readFile(`{dir}/{rel}`), "[^\n]+") do
			if util.startsWith(util.trim(line), "--") then
				continue
			end
			local server = string.match(line, "ServerPackages%.([%w_]+)")
			if server then
				if not package.wallyServer[server] then
					missing[server] = true
				end
				continue
			end
			local shared = string.match(line, "Packages%.([%w_]+)")
			if shared and not package.wally[shared] then
				missing[shared] = true
			end
		end
	end

	local out: { string } = {}
	for name in missing do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

-- Cross-feature registration files imply a dependency.
--
-- The convention is that a feature extends another by dropping a sibling file
-- named after it (Notes/PlayerData.luau registers a profile slice into the
-- PlayerData feature). Detected generically — a root file whose name matches an
-- installed feature folder — so this tool never names a feature.
local function undeclaredFeatureDeps(package: manifest.Package, dir: string): { string }
	local selfFolder = package.folder or util.pascal(package.name)
	local declared: { [string]: boolean } = {}
	for name in package.dependencies do
		declared[util.pascal(name)] = true
	end

	local missing: { string } = {}
	for _, rel in util.listFiles(dir) do
		local base = string.match(rel, "^([%w_]+)%.luau$")
		if not base or base == selfFolder or declared[base] then
			continue
		end
		if fs.isDir(`{project.INSTALL_DIRS.feature}/{base}`) then
			table.insert(missing, base)
		end
	end
	return missing
end

function publish.check(package: manifest.Package, dir: string): { string }
	local problems: { string } = {}

	for _, message in manifest.validate(package) do
		table.insert(problems, message)
	end

	if package.kind == "feature" then
		for _, rel in util.listFiles(dir) do
			if string.find(rel, "/", 1, true) and string.match(rel, "%.luau$") then
				table.insert(problems, `{rel} is in a subfolder — the splitter only reads a feature folder's top level`)
			end
		end
	end

	for _, name in undeclaredWally(package, dir) do
		table.insert(problems, `requires Packages.{name} but doesn't declare it under [wally]`)
	end

	for _, name in undeclaredFeatureDeps(package, dir) do
		table.insert(
			problems,
			`has {name}.luau (a registration file for the {name} feature) but no [dependencies] entry for it`
		)
	end

	return problems
end

-- Fill in a manifest for a folder that doesn't have one yet.
local function scaffold(dir: string): manifest.Package
	local folder = string.match(dir, "([^/]+)/?$") or dir
	local kind = if util.startsWith(dir, project.INSTALL_DIRS.skin) then "skin" else "feature"

	term.print(`No {manifest.FILENAME} in {dir}/ — let's write one.`)
	local scope = term.text("Scope (your GitHub username or org)", "encryptal") or "encryptal"
	local name = term.text("Package name", string.lower(folder)) or string.lower(folder)
	local description = term.text("One-line description") or ""
	local version = term.text("Version", "0.1.0") or "0.1.0"
	local repository = term.text("Package git URL", `https://github.com/{scope}/boil-{string.lower(folder)}`)

	local package = manifest.empty(`{scope}/{name}`, kind)
	package.description = description
	package.version = version
	package.repository = repository
	package.boil = `^{project.read().boil}`
	if kind == "skin" then
		package.contract = `^{project.contractVersion()}`
	end

	manifest.write(dir, package)
	term.ok(`wrote {dir}/{manifest.FILENAME} — edit it and re-run publish`)
	return package
end

-- Replace the package repo's contents with `dir`, then commit and tag.
local function pushPackage(package: manifest.Package, dir: string, tag: string): boolean
	local repo = package.repository :: string
	local work = util.tempDir("publish")
	util.removeDir(work)

	local ok, output = source.git({ "clone", "--quiet", repo, work })
	if not ok then
		term.warn(`could not clone {repo}:\n{util.trim(output)}`)
		term.info("Create the repository first, then re-run publish.")
		return false
	end

	for _, rel in util.listFiles(work) do
		fs.removeFile(`{work}/{rel}`)
	end
	util.copyDir(dir, work)

	source.git({ "add", "-A" }, work)
	local committed = source.git({ "commit", "-m", `{package.name} {package.version}` }, work)
	if not committed then
		term.info("no content changes to commit")
	end

	local tagged, tagOutput = source.git({ "tag", tag }, work)
	if not tagged then
		term.warn(`could not create tag {tag}: {util.trim(tagOutput)}`)
		util.removeDir(work)
		return false
	end

	local pushed, pushOutput = source.git({ "push", "origin", "HEAD", "--tags" }, work)
	util.removeDir(work)
	if not pushed then
		term.warn(`push failed:\n{util.trim(pushOutput)}`)
		return false
	end
	return true
end

local function pushIndex(package: manifest.Package, tag: string): boolean
	local url = registry.url()
	if fs.isDir(url) then
		local listing = registry.find(package.name, url)
			or { name = package.name, kind = package.kind, description = package.description or "", versions = {} }
		publish.mergeRelease(listing, package, tag)
		registry.writeListing(url, listing)
		term.ok(`updated the local index at {url}`)
		return true
	end

	local work = util.tempDir("index")
	util.removeDir(work)
	local ok, output = source.git({ "clone", "--quiet", url, work })
	if not ok then
		term.warn(`could not clone the index {url}:\n{util.trim(output)}`)
		return false
	end

	local listing = registry.find(package.name, work)
		or { name = package.name, kind = package.kind, description = package.description or "", versions = {} }
	publish.mergeRelease(listing, package, tag)
	registry.writeListing(work, listing)

	source.git({ "add", "-A" }, work)
	source.git({ "commit", "-m", `{package.name} {package.version}` }, work)
	local pushed, pushOutput = source.git({ "push", "origin", "HEAD" }, work)
	util.removeDir(work)

	if not pushed then
		term.warn(`could not push to the index:\n{util.trim(pushOutput)}`)
		term.info("You may not have write access — open a pull request against the index instead.")
		return false
	end
	return true
end

function publish.mergeRelease(listing: registry.Listing, package: manifest.Package, tag: string)
	listing.description = package.description or listing.description
	listing.kind = package.kind

	local release: registry.Release = {
		version = package.version,
		source = `git+{package.repository}`,
		tag = tag,
		boil = package.boil,
		contract = package.contract,
	}

	for index, existing in listing.versions do
		if existing.version == package.version then
			listing.versions[index] = release
			return
		end
	end
	table.insert(listing.versions, release)
end

function publish.run(args: { string }, options: Options?)
	local opts = options or {}
	local dir = args[1]
	if not dir then
		term.fail("usage: boil publish <path-to-package>")
	end
	dir = (string.gsub(dir, "/$", ""))
	if not fs.isDir(dir) then
		term.fail(`no such directory: {dir}`)
	end

	local package = manifest.read(dir)
	if not package then
		scaffold(dir)
		return
	end

	local pkg = package :: manifest.Package
	term.heading(`Publishing {pkg.name} {pkg.version}`)

	local problems = publish.check(pkg, dir)
	if #problems > 0 then
		term.print("")
		for _, message in problems do
			term.print(`  {term.red("×")} {message}`)
		end
		term.fail(`{#problems} problem(s) — fix these before publishing`)
	end
	term.ok("manifest, layout and declared dependencies check out")

	local lintFailures = runLints()
	if #lintFailures > 0 then
		term.print("")
		for _, failure in lintFailures do
			term.print(term.red(failure))
		end
		term.fail("lints failed")
	end
	term.ok(`lints pass ({table.concat(LINTS, ", ")})`)

	if not pkg.repository then
		term.fail('no `repository` in boil.toml — set it to the git URL this package publishes to')
	end

	local tag = `v{pkg.version}`
	if opts.dryRun then
		term.ok(`dry run: would push {dir}/ to {pkg.repository} at {tag} and register it in {registry.url()}`)
		return
	end

	term.print("")
	term.info(`push {dir}/ → {pkg.repository} @ {tag}`)
	term.info(`register {pkg.name} {pkg.version} in {registry.url()}`)
	if not opts.yes and not term.confirm("Publish?") then
		term.print("Cancelled.")
		return
	end

	if not pushPackage(pkg, dir, tag) then
		term.fail("publish aborted — nothing was written to the index")
	end
	term.ok(`pushed {pkg.repository} @ {tag}`)

	if not pushIndex(pkg, tag) then
		term.fail("the package was pushed, but the index was not updated")
	end
	term.ok(`published {pkg.name} {pkg.version}`)
end

return publish
