--!strict
-- Rendering shared by the scriptable commands and the explorer.
--
-- Both surfaces show the same rows and the same detail view, from the same code:
-- the explorer is a discovery aid over the commands, never a second
-- implementation that can drift from them.

local manifest = require("./manifest")
local project = require("./project")
local registry = require("./registry")
local semver = require("./semver")
local term = require("./term")
local util = require("./util")

local format = {}

export type Compat = {
	ok: boolean,
	reason: string?,
}

-- Is this release installable into *this* checkout? Checked up front so the
-- explorer can mark a package incompatible in the list, rather than letting the
-- user find out by installing something that breaks at runtime.
function format.compat(release: registry.Release): Compat
	local boil = project.read().boil
	if release.boil and not semver.satisfies(boil, release.boil) then
		return { ok = false, reason = `needs Boil {release.boil}, this checkout is {boil}` }
	end

	if not release.contract then
		return { ok = true }
	end

	local contract = project.contractVersion()
	if not semver.satisfies(`{contract}.0.0`, release.contract) then
		return { ok = false, reason = `needs skin contract {release.contract}, this checkout is v{contract}` }
	end
	return { ok = true }
end

function format.latest(listing: registry.Listing): registry.Release?
	local best: registry.Release? = nil
	for _, release in listing.versions do
		local parsed = semver.parse(release.version)
		if not parsed then
			continue
		end
		if not best or semver.compare(parsed, semver.parse(best.version) :: semver.Version) > 0 then
			best = release
		end
	end
	return best
end

function format.findRelease(listing: registry.Listing, range: string?): registry.Release?
	if not range then
		return format.latest(listing)
	end
	local versions: { string } = {}
	for _, release in listing.versions do
		table.insert(versions, release.version)
	end
	local picked = semver.maxSatisfying(versions, range)
	if not picked then
		return nil
	end
	for _, release in listing.versions do
		if release.version == picked then
			return release
		end
	end
	return nil
end

function format.pad(text: string, width: number): string
	if #text >= width then
		return text
	end
	return text .. string.rep(" ", width - #text)
end

-- One list row: "encryptal/shop      1.2.0  Currency shop with rotating stock"
function format.row(listing: registry.Listing, installed: { [string]: string }, nameWidth: number): string
	local release = format.latest(listing)
	local version = if release then release.version else "—"
	local marker = " "
	local suffix = ""

	if installed[listing.name] then
		marker = term.green("●")
		if release and installed[listing.name] ~= release.version then
			suffix = term.yellow(` (installed {installed[listing.name]})`)
		end
	elseif release and not format.compat(release).ok then
		marker = term.red("×")
	end

	local kind = format.pad(listing.kind, 8)
	return `{marker} {format.pad(listing.name, nameWidth)}  {term.dim(kind)}{format.pad(version, 9)}{listing.description}{suffix}`
end

function format.rows(listings: { registry.Listing }, installed: { [string]: string }): { string }
	local nameWidth = 12
	for _, listing in listings do
		nameWidth = math.max(nameWidth, #listing.name)
	end
	local out: { string } = {}
	for _, listing in listings do
		table.insert(out, format.row(listing, installed, nameWidth))
	end
	return out
end

-- The detail view: everything you need to decide whether to install.
function format.detail(listing: registry.Listing, release: registry.Release?, installedVersion: string?): { string }
	local lines: { string } = {}
	local function add(text: string?)
		table.insert(lines, text or "")
	end

	add(term.bold(listing.name))
	for _, line in util.wrap(listing.description, 72, "") do
		add(term.dim(line))
	end
	add()

	if not release then
		add(term.yellow("No published versions."))
		return lines
	end

	local compat = format.compat(release)
	add(`  {format.pad("version", 12)}{release.version}{if installedVersion then term.dim(` (installed: {installedVersion})`) else ""}`)
	add(`  {format.pad("kind", 12)}{listing.kind} → {project.INSTALL_DIRS[listing.kind] or "?"}/`)
	if release.source then
		add(`  {format.pad("source", 12)}{release.source}{if release.tag then term.dim(` @ {release.tag}`) else ""}`)
	end
	if release.published then
		add(`  {format.pad("published", 12)}{release.published}`)
	end
	add(
		`  {format.pad("compatible", 12)}{if compat.ok then term.green("yes") else term.red("no") .. term.dim(` — {compat.reason}`)}`
	)

	local other: { string } = {}
	for _, candidate in listing.versions do
		if candidate.version ~= release.version then
			table.insert(other, candidate.version)
		end
	end
	if #other > 0 then
		add(`  {format.pad("other", 12)}{term.dim(table.concat(other, ", "))}`)
	end

	return lines
end

-- The parts of a manifest that only exist once the package is fetched: its
-- dependencies, Wally requirements, and the Studio assets you have to build by
-- hand. Printed after an install, and by `doctor`.
function format.requirements(package: manifest.Package): { string }
	local lines: { string } = {}

	if next(package.dependencies) then
		table.insert(lines, term.bold("Depends on"))
		for name, range in package.dependencies do
			table.insert(lines, `  {name} {term.dim(range)}`)
		end
	end

	local wally: { string } = {}
	for name, spec in package.wally do
		table.insert(wally, `  {name} = "{spec}"`)
	end
	for name, spec in package.wallyServer do
		table.insert(wally, `  {name} = "{spec}" {term.dim("(server)")}`)
	end
	if #wally > 0 then
		table.insert(lines, term.bold("Wally packages"))
		for _, line in wally do
			table.insert(lines, line)
		end
	end

	local studio = package.studio
	if not studio.tags and not studio.notes then
		return lines
	end

	table.insert(lines, term.bold("Studio setup — you have to create these by hand"))
	for _, tag in studio.tags or {} do
		table.insert(lines, `  CollectionService tag: {term.cyan(tag)}`)
	end
	if studio.notes then
		for _, line in util.wrap(studio.notes, 70, "  ") do
			table.insert(lines, line)
		end
	end

	return lines
end

return format
