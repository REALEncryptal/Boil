--!strict
-- The package manifest: `boil.toml` inside a package folder.
--
-- It lives *inside* the package because the splitter only copies `.luau` files —
-- a TOML file in `src/features/Shop/` never reaches Roblox. So a package is
-- exactly one self-describing directory, with nothing to keep in sync elsewhere.
--
-- See docs/registry.md for the schema.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local semver = require("./semver")

local manifest = {}

manifest.FILENAME = "boil.toml"

export type Studio = {
	tags: { string }?,
	notes: string?,
}

export type Package = {
	name: string,
	kind: string, -- "feature" | "skin"
	version: string,
	description: string?,
	license: string?,
	author: string?,
	repository: string?, -- git URL the package is published to
	folder: string?, -- override the derived install folder name
	boil: string?, -- compatible Shared.Boil surface range
	contract: string?, -- skins only: compatible contract.VERSION range
	dependencies: { [string]: string },
	wally: { [string]: string },
	wallyServer: { [string]: string },
	studio: Studio,
}

local function asStringMap(value: any): { [string]: string }
	local out: { [string]: string } = {}
	if typeof(value) ~= "table" then
		return out
	end
	for key, entry in value do
		if typeof(key) == "string" and typeof(entry) == "string" then
			out[key] = entry
		end
	end
	return out
end

function manifest.parse(text: string): (Package?, string?)
	local ok, decoded = pcall(serde.decode, "toml" :: any, text)
	if not ok then
		return nil, `not valid TOML: {decoded}`
	end

	local raw = decoded :: any
	local package = raw.package
	if typeof(package) ~= "table" then
		return nil, "missing a [package] section"
	end

	local studio = if typeof(raw.studio) == "table" then raw.studio else {}

	return {
		name = package.name or "",
		kind = package.kind or "feature",
		version = package.version or "",
		description = package.description,
		license = package.license,
		author = package.author,
		repository = package.repository,
		folder = package.folder,
		boil = package.boil,
		contract = package.contract,
		dependencies = asStringMap(raw.dependencies),
		wally = asStringMap(raw.wally),
		wallyServer = asStringMap(raw["wally-server"]),
		studio = {
			tags = studio.tags,
			notes = studio.notes,
		},
	},
		nil
end

function manifest.read(dir: string): (Package?, string?)
	local path = `{dir}/{manifest.FILENAME}`
	if not fs.isFile(path) then
		return nil, `no {manifest.FILENAME} in {dir}/`
	end
	return manifest.parse(fs.readFile(path))
end

-- Everything that must be true before a package can be published or installed.
function manifest.validate(package: Package): { string }
	local errors: { string } = {}

	if not string.match(package.name, "^[%w%-%_%.]+/[%w%-%_%.]+$") then
		table.insert(errors, `name "{package.name}" must be scoped, e.g. "encryptal/shop"`)
	end
	if package.kind ~= "feature" and package.kind ~= "skin" then
		table.insert(errors, `kind "{package.kind}" must be "feature" or "skin"`)
	end
	if not semver.parse(package.version) then
		table.insert(errors, `version "{package.version}" is not semver (e.g. "1.2.0")`)
	end
	if not package.description or package.description == "" then
		table.insert(errors, "description is required — it's the line the explorer lists")
	end
	if not package.boil then
		table.insert(errors, 'boil range is required, e.g. boil = "^0.3"')
	end
	if package.kind == "skin" and not package.contract then
		table.insert(errors, 'skins must declare a contract range, e.g. contract = "^1"')
	end

	return errors
end

function manifest.serialize(package: Package): string
	local body: { [string]: any } = {
		package = {
			name = package.name,
			kind = package.kind,
			version = package.version,
			description = package.description,
			license = package.license,
			author = package.author,
			repository = package.repository,
			folder = package.folder,
			boil = package.boil,
			contract = package.contract,
		},
	}
	if next(package.dependencies) then
		body.dependencies = package.dependencies
	end
	if next(package.wally) then
		body.wally = package.wally
	end
	if next(package.wallyServer) then
		body["wally-server"] = package.wallyServer
	end
	if package.studio.tags or package.studio.notes then
		body.studio = { tags = package.studio.tags, notes = package.studio.notes }
	end
	return serde.encode("toml", body, true)
end

function manifest.write(dir: string, package: Package)
	fs.writeFile(`{dir}/{manifest.FILENAME}`, manifest.serialize(package))
end

function manifest.empty(name: string, kind: string): Package
	return {
		name = name,
		kind = kind,
		version = "0.1.0",
		dependencies = {},
		wally = {},
		wallyServer = {},
		studio = {},
	}
end

return manifest
