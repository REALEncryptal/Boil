--!strict
-- The scriptable commands. Every explorer action maps onto one of these, so
-- anything you can do by browsing you can also do from a script or CI.

local fs = require("@lune/fs")

local format = require("./format")
local lock = require("./lock")
local manifest = require("./manifest")
local project = require("./project")
local registry = require("./registry")
local semver = require("./semver")
local source = require("./source")
local term = require("./term")
local util = require("./util")

local commands = {}

export type AddOptions = {
	force: boolean?,
	quiet: boolean?,
	skipSplit: boolean?,
	direct: boolean?, -- record in the project manifest (false for transitive deps)
}

function commands.installedVersions(): { [string]: string }
	local out: { [string]: string } = {}
	for _, entry in lock.read() do
		out[entry.name] = entry.version
	end
	return out
end

-- Files that differ between two copies of a package.
local function diffDirs(a: string, b: string): ({ string }, { string }, { string })
	local added, removed, changed = {}, {}, {}
	local inA: { [string]: boolean } = {}

	for _, rel in util.listFiles(a) do
		inA[rel] = true
	end
	for _, rel in util.listFiles(b) do
		if not inA[rel] then
			table.insert(added, rel)
			continue
		end
		if fs.readFile(`{a}/{rel}`) ~= fs.readFile(`{b}/{rel}`) then
			table.insert(changed, rel)
		end
		inA[rel] = nil
	end
	for rel in inA do
		table.insert(removed, rel)
	end

	table.sort(added)
	table.sort(removed)
	table.sort(changed)
	return added, removed, changed
end

-- A feature package must be a flat folder: the splitter iterates files and skips
-- nested directories entirely, so a nested .luau would vanish at build time
-- rather than fail loudly.
local function checkFlat(package: manifest.Package, dir: string): { string }
	if package.kind ~= "feature" then
		return {}
	end
	local nested: { string } = {}
	for _, rel in util.listFiles(dir) do
		if string.find(rel, "/", 1, true) and string.match(rel, "%.luau$") then
			table.insert(nested, rel)
		end
	end
	return nested
end

local function resolveIndexed(spec: source.Spec): (registry.Listing, registry.Release)
	local name = spec.name :: string
	local listing = registry.find(name)
	if not listing then
		local hint = if registry.localPath() then "" else " (the index has never been fetched — try `boil refresh`)"
		term.fail(`"{name}" is not in the index{hint}`)
	end

	local release = format.findRelease(listing :: registry.Listing, spec.version)
	if not release then
		local available: { string } = {}
		for _, candidate in (listing :: registry.Listing).versions do
			table.insert(available, candidate.version)
		end
		term.fail(`no version of "{name}" matches "{spec.version}" — published: {table.concat(available, ", ")}`)
	end

	return listing :: registry.Listing, release :: registry.Release
end

function commands.add(args: { string }, options: AddOptions?): string?
	local opts = options or {}
	local specText = args[1]
	if not specText then
		term.fail("usage: boil add <package>[@version] | github:owner/repo[@tag] | path:<dir>")
	end

	local spec = source.parseSpec(specText)
	local fetchSpec = spec
	local listing: registry.Listing? = nil
	local release: registry.Release? = nil

	if spec.name then
		listing, release = resolveIndexed(spec)
		local compat = format.compat(release :: registry.Release)
		if not compat.ok and not opts.force then
			term.fail(`{spec.name}@{(release :: registry.Release).version} is not compatible — {compat.reason}. Pass --force to install anyway.`)
		end
		local url = (release :: registry.Release).source or ""
		fetchSpec = {
			git = (string.gsub(url, "^git%+", "")),
			tag = (release :: registry.Release).tag,
			subdir = (release :: registry.Release).subdir,
		}
	end

	local dir, fetchError = source.fetch(fetchSpec)
	if not dir then
		term.fail(fetchError :: string)
	end

	local package, manifestError = manifest.read(dir :: string)
	if not package then
		term.fail(`{specText}: {manifestError}`)
	end

	local errors = manifest.validate(package :: manifest.Package)
	if #errors > 0 then
		term.print(term.red(`{specText} has an invalid boil.toml:`))
		for _, message in errors do
			term.info(`• {message}`)
		end
		term.fail("refusing to install an invalid package")
	end

	local pkg = package :: manifest.Package

	-- The fetched manifest is the authority, not the index entry: this is the only
	-- compat check that also covers `add github:…` and `add path:…`, which never
	-- touch the index.
	local compat = format.compat({ version = pkg.version, boil = pkg.boil, contract = pkg.contract })
	if not compat.ok and not opts.force then
		util.removeDir(dir :: string)
		term.fail(`{pkg.name} {pkg.version} is not compatible — {compat.reason}. Pass --force to install anyway.`)
	end

	local nested = checkFlat(pkg, dir :: string)
	if #nested > 0 then
		term.fail(
			`{pkg.name} has .luau files in subfolders ({table.concat(nested, ", ")}) — `
				.. "the splitter only reads the top level of a feature folder, so those would silently never build"
		)
	end

	local target = project.installPath(pkg)
	if fs.isDir(target) and not opts.force then
		term.fail(`{target}/ already exists — use \`boil update {pkg.name}\`, or --force to overwrite`)
	end

	util.removeDir(target)
	util.copyDir(dir :: string, target)
	util.removeDir(dir :: string)

	local wallyAdded = project.mergeWally(pkg)

	lock.upsert({
		name = pkg.name,
		version = pkg.version,
		kind = pkg.kind,
		source = source.describe(fetchSpec),
		tag = fetchSpec.tag,
		subdir = fetchSpec.subdir,
		path = target,
		fingerprint = project.fingerprint(target),
	})

	if opts.direct ~= false then
		local proj = project.read()
		proj.dependencies[pkg.name] = `^{pkg.version}`
		project.write(proj)
	end

	-- Transitive dependencies. Recorded in the lockfile but not in the project
	-- manifest — the project only declares what it asked for directly.
	local installed = commands.installedVersions()
	for name, range in pkg.dependencies do
		if installed[name] and semver.satisfies(installed[name], range) then
			continue
		end
		if not registry.find(name) then
			term.warn(`{pkg.name} depends on {name} {range}, which isn't in the index — install it yourself`)
			continue
		end
		commands.add({ `{name}@{range}` }, { quiet = true, skipSplit = true, direct = false, force = opts.force })
	end

	if not opts.skipSplit then
		project.runSplit()
	end

	if opts.quiet then
		term.ok(`{pkg.name} {pkg.version} → {target}/`)
		return target
	end

	term.print("")
	term.ok(`installed {term.bold(pkg.name)} {pkg.version} → {target}/`)
	if #wallyAdded > 0 then
		term.print("")
		term.print(term.bold("Added to wally.toml — run `wally install`"))
		for _, line in wallyAdded do
			term.info(line)
		end
	end

	local requirements = format.requirements(pkg)
	if #requirements > 0 then
		term.print("")
		for _, line in requirements do
			term.print(line)
		end
	end
	term.print("")

	return target
end

function commands.remove(args: { string })
	local name = args[1]
	if not name then
		term.fail("usage: boil remove <package>")
	end

	local entry = lock.find(name)
	if not entry then
		term.fail(`"{name}" is not installed (see \`boil list\`)`)
	end

	-- Anything that declares it as a dependency is about to break.
	for _, other in lock.read() do
		if other.name == name then
			continue
		end
		local otherPackage = manifest.read(other.path)
		if otherPackage and otherPackage.dependencies[name] then
			term.warn(`{other.name} depends on {name} — it will break`)
		end
	end

	util.removeDir((entry :: lock.Entry).path)
	lock.remove(name)

	local proj = project.read()
	proj.dependencies[name] = nil
	project.write(proj)

	project.runSplit()
	term.ok(`removed {name} ({(entry :: lock.Entry).path}/)`)
end

function commands.list()
	local entries = lock.read()
	if #entries == 0 then
		term.print("No packages installed. Try `boil explore`.")
		return
	end

	local nameWidth = 12
	for _, entry in entries do
		nameWidth = math.max(nameWidth, #entry.name)
	end

	term.heading(`Installed ({#entries})`)
	for _, entry in entries do
		local status = ""
		if not fs.isDir(entry.path) then
			status = term.red("  missing — run `boil install`")
		elseif project.fingerprint(entry.path) ~= entry.fingerprint then
			status = term.yellow("  modified locally")
		end
		term.print(
			`  {format.pad(entry.name, nameWidth)}  {format.pad(entry.version, 9)}{term.dim(entry.path .. "/")}{status}`
		)
	end
	term.print("")
end

function commands.outdated()
	local entries = lock.read()
	local stale = 0

	for _, entry in entries do
		local listing = registry.find(entry.name)
		if not listing then
			continue
		end
		local latest = format.latest(listing :: registry.Listing)
		if not latest or latest.version == entry.version then
			continue
		end
		local current = semver.parse(entry.version)
		local newest = semver.parse(latest.version)
		if not current or not newest or semver.compare(newest, current) <= 0 then
			continue
		end
		if stale == 0 then
			term.heading("Outdated")
		end
		stale += 1
		local compat = format.compat(latest)
		local note = if compat.ok then "" else term.dim(`  (incompatible: {compat.reason})`)
		term.print(`  {entry.name}  {entry.version} → {term.green(latest.version)}{note}`)
	end

	if stale == 0 then
		term.print("Everything is up to date.")
		return
	end
	term.print("")
	term.print(term.dim("Update with `boil update <package>`."))
	term.print("")
end

local function updateOne(entry: lock.Entry, force: boolean): boolean
	local listing = registry.find(entry.name)
	if not listing then
		term.warn(`{entry.name} is not in the index — skipped`)
		return false
	end

	local latest = format.latest(listing :: registry.Listing)
	if not latest then
		term.warn(`{entry.name} has no published versions — skipped`)
		return false
	end
	if latest.version == entry.version then
		return false
	end

	local compat = format.compat(latest)
	if not compat.ok and not force then
		term.warn(`{entry.name} {latest.version} is incompatible — {compat.reason} (skipped)`)
		return false
	end

	local modified = fs.isDir(entry.path) and project.fingerprint(entry.path) ~= entry.fingerprint
	if modified then
		local fetched = source.fetch({
			git = (string.gsub(latest.source or "", "^git%+", "")),
			tag = latest.tag,
			subdir = latest.subdir,
		})
		if fetched then
			local added, removed, changed = diffDirs(entry.path, fetched)
			util.removeDir(fetched)
			term.warn(`{entry.name} has local edits. Upstream {entry.version} → {latest.version} changes:`)
			for _, rel in added do
				term.info(term.green(`+ {rel}`))
			end
			for _, rel in removed do
				term.info(term.red(`- {rel}`))
			end
			for _, rel in changed do
				term.info(term.yellow(`~ {rel}`))
			end
		end
		if not force and not term.confirm(`Overwrite your local changes to {entry.name}?`) then
			term.info("skipped")
			return false
		end
	end

	commands.add({ `{entry.name}@{latest.version}` }, { force = true, quiet = true, skipSplit = true, direct = false })
	return true
end

function commands.update(args: { string }, force: boolean)
	local entries = lock.read()
	local targets: { lock.Entry } = {}

	if args[1] then
		local entry = lock.find(args[1])
		if not entry then
			term.fail(`"{args[1]}" is not installed`)
		end
		targets = { entry :: lock.Entry }
	else
		targets = entries
	end

	local updated = 0
	for _, entry in targets do
		if updateOne(entry, force) then
			updated += 1
		end
	end

	project.runSplit()
	if updated == 0 then
		term.print("Nothing to update.")
		return
	end
	term.ok(`updated {updated} package(s)`)
end

-- Restore every locked package that isn't on disk (a fresh clone of the game).
function commands.install()
	local restored = 0
	for _, entry in lock.read() do
		if fs.isDir(entry.path) then
			continue
		end
		local url = (string.gsub(entry.source, "^git%+", ""))
		local dir, err = source.fetch({ git = url, tag = entry.tag, subdir = entry.subdir })
		if not dir then
			term.warn(`{entry.name}: {err}`)
			continue
		end
		util.copyDir(dir :: string, entry.path)
		util.removeDir(dir :: string)
		restored += 1
		term.ok(`restored {entry.name} {entry.version} → {entry.path}/`)
	end

	if restored == 0 then
		term.print("Everything in the lockfile is already on disk.")
		return
	end
	project.runSplit()
end

function commands.search(args: { string })
	local termText = args[1]
	if not termText then
		term.fail("usage: boil search <term>")
	end

	local hits = registry.search(termText)
	if #hits == 0 then
		term.print(`No packages match "{termText}".`)
		return
	end

	term.heading(`{#hits} result(s) for "{termText}"`)
	for _, line in format.rows(hits, commands.installedVersions()) do
		term.print(line)
	end
	term.print("")
end

function commands.info(args: { string })
	local name = args[1]
	if not name then
		term.fail("usage: boil info <package>")
	end

	local listing = registry.find(name)
	if not listing then
		term.fail(`"{name}" is not in the index`)
	end

	term.print("")
	local installed = commands.installedVersions()[name]
	for _, line in format.detail(listing :: registry.Listing, format.latest(listing :: registry.Listing), installed) do
		term.print(line)
	end
	term.print("")
end

function commands.refresh()
	local ok, message = registry.refresh()
	if not ok then
		term.fail(message)
	end
	local count = #registry.load()
	term.ok(`{message} — {count} package(s)`)
end

-- Everything that's wrong with the current install set, in one pass.
function commands.doctor()
	local problems = 0
	local function problem(text: string)
		problems += 1
		term.print(`  {term.yellow("!")} {text}`)
	end

	term.heading("doctor")

	local entries = lock.read()
	local installed = commands.installedVersions()

	for _, entry in entries do
		if not fs.isDir(entry.path) then
			problem(`{entry.name}: {entry.path}/ is missing — run \`boil install\``)
			continue
		end

		local package = manifest.read(entry.path)
		if not package then
			problem(`{entry.name}: no boil.toml in {entry.path}/`)
			continue
		end

		local pkg = package :: manifest.Package
		for name, range in pkg.dependencies do
			if not installed[name] then
				problem(`{entry.name} depends on {name} {range}, which is not installed`)
				continue
			end
			if not semver.satisfies(installed[name], range) then
				problem(`{entry.name} needs {name} {range}, but {installed[name]} is installed`)
			end
		end

		local wallyText = if fs.isFile("wally.toml") then fs.readFile("wally.toml") else ""
		for name in pkg.wally do
			if not string.find(wallyText, `\n%s*{name}%s*=`) then
				problem(`{entry.name} needs the Wally package {name}, which is not in wally.toml`)
			end
		end

		if pkg.studio.tags or pkg.studio.notes then
			term.print(`  {term.cyan("i")} {entry.name} expects Studio assets — \`boil info {entry.name}\` to review`)
		end
	end

	-- Folders that look like packages but aren't tracked.
	for kind, root in project.INSTALL_DIRS do
		if not fs.isDir(root) then
			continue
		end
		for _, folder in fs.readDir(root) do
			local dir = `{root}/{folder}`
			if not fs.isDir(dir) or not fs.isFile(`{dir}/{manifest.FILENAME}`) then
				continue
			end
			local package = manifest.read(dir)
			if package and not lock.find((package :: manifest.Package).name) then
				problem(`{dir}/ has a boil.toml ({(package :: manifest.Package).name}) but no lockfile entry — publish it or \`boil add path:{dir}\``)
			end
			local _ = kind
		end
	end

	if problems == 0 then
		term.ok(`{#entries} package(s), nothing wrong`)
		return
	end
	term.print("")
	term.print(term.yellow(`{problems} problem(s).`))
end

return commands
