--!strict
-- The package index: a git repo of manifests, one TOML file per package.
--
--   boil-index/packages/<scope>/<name>.toml
--
-- Cloned to ~/.boil/index/<hash> and read from there, so `explore`, `search` and
-- `list` all work offline — refreshing is an explicit action, never a hidden
-- network call on every command. A registry URL that resolves to a local
-- directory is used in place (handy for developing against an index before it's
-- published anywhere).

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local project = require("./project")
local source = require("./source")
local util = require("./util")

local registry = {}

registry.DEFAULT_URL = "https://github.com/REALEncryptal/boil-index"

export type Release = {
	version: string,
	source: string?,
	tag: string?,
	subdir: string?,
	boil: string?,
	contract: string?,
	published: string?,
}

export type Listing = {
	name: string,
	kind: string,
	description: string,
	versions: { Release },
}

function registry.url(): string
	local registries = project.read().registries
	return registries.default or registry.DEFAULT_URL
end

function registry.cacheDir(url: string): string
	local home = process.env.HOME or process.env.USERPROFILE or "."
	return `{home}/.boil/index/{string.sub(serde.hash("sha256", url), 1, 12)}`
end

-- Where the index actually lives on disk right now, or nil if it's never been
-- fetched. A local-directory registry resolves to itself.
function registry.localPath(url: string?): string?
	local target = url or registry.url()
	if fs.isDir(target) then
		return target
	end
	local cached = registry.cacheDir(target)
	return if fs.isDir(cached) then cached else nil
end

function registry.refresh(url: string?): (boolean, string)
	local target = url or registry.url()
	if fs.isDir(target) then
		return true, `using local index at {target}`
	end

	local dir = registry.cacheDir(target)
	if fs.isDir(`{dir}/.git`) then
		local ok, output = source.git({ "-C", dir, "pull", "--ff-only", "--quiet" })
		if not ok then
			return false, `could not update the index at {dir}:\n{util.trim(output)}`
		end
		return true, `updated {target}`
	end

	util.ensureDir(dir)
	util.removeDir(dir)
	local ok, output = source.git({ "clone", "--depth", "1", "--quiet", target, dir })
	if not ok then
		return false, `could not clone the index {target}:\n{util.trim(output)}`
	end
	return true, `cloned {target}`
end

local function parseListing(text: string): Listing?
	local ok, decoded = pcall(serde.decode, "toml" :: any, text)
	if not ok then
		return nil
	end
	local raw = decoded :: any
	if typeof(raw.name) ~= "string" then
		return nil
	end
	return {
		name = raw.name,
		kind = raw.kind or "feature",
		description = raw.description or "",
		versions = if typeof(raw.version) == "table" then raw.version else {},
	}
end

function registry.load(url: string?): { Listing }
	local dir = registry.localPath(url)
	if not dir then
		return {}
	end

	local packagesDir = `{dir}/packages`
	if not fs.isDir(packagesDir) then
		return {}
	end

	local listings: { Listing } = {}
	for _, rel in util.listFiles(packagesDir) do
		if not string.match(rel, "%.toml$") then
			continue
		end
		local listing = parseListing(fs.readFile(`{packagesDir}/{rel}`))
		if listing then
			table.insert(listings, listing)
		end
	end

	table.sort(listings, function(a, b)
		return a.name < b.name
	end)
	return listings
end

function registry.find(name: string, url: string?): Listing?
	for _, listing in registry.load(url) do
		if listing.name == name then
			return listing
		end
	end
	return nil
end

function registry.search(term: string, url: string?): { Listing }
	local needle = string.lower(term)
	local hits: { Listing } = {}
	for _, listing in registry.load(url) do
		local haystack = string.lower(`{listing.name} {listing.description}`)
		if string.find(haystack, needle, 1, true) then
			table.insert(hits, listing)
		end
	end
	return hits
end

-- The index file path a listing is published to.
function registry.listingPath(indexDir: string, name: string): string
	local scope, package = string.match(name, "^([^/]+)/(.+)$")
	return `{indexDir}/packages/{scope}/{package}.toml`
end

local function tomlString(value: string): string
	return `"{string.gsub(string.gsub(value, "\\", "\\\\"), '"', '\\"')}"`
end

-- Emitted by hand rather than through serde: a listing mixes top-level scalars
-- (name, kind, description) with an array of tables ([[version]]), and TOML
-- requires the scalars first. Lua table iteration order is arbitrary, so a
-- serde round-trip would produce invalid TOML at random.
function registry.serializeListing(listing: Listing): string
	local lines = {
		`name = {tomlString(listing.name)}`,
		`kind = {tomlString(listing.kind)}`,
		`description = {tomlString(listing.description)}`,
	}

	local ordered: { { key: string, value: string? } }
	for _, release in listing.versions do
		ordered = {
			{ key = "version", value = release.version },
			{ key = "source", value = release.source },
			{ key = "tag", value = release.tag },
			{ key = "subdir", value = release.subdir },
			{ key = "boil", value = release.boil },
			{ key = "contract", value = release.contract },
			{ key = "published", value = release.published },
		}
		table.insert(lines, "")
		table.insert(lines, "[[version]]")
		for _, field in ordered do
			if field.value then
				table.insert(lines, `{field.key} = {tomlString(field.value)}`)
			end
		end
	end

	return table.concat(lines, "\n") .. "\n"
end

function registry.writeListing(indexDir: string, listing: Listing)
	local path = registry.listingPath(indexDir, listing.name)
	local parent = string.match(path, "^(.*)/[^/]+$")
	if parent then
		util.ensureDir(parent)
	end
	fs.writeFile(path, registry.serializeListing(listing))
end

return registry
