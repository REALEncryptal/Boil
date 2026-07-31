--!strict
-- The consuming game's side of the registry: the root `boil.toml` (what this
-- project depends on), the paths packages install into, and the compatibility
-- numbers a package is checked against.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local manifest = require("./manifest")
local util = require("./util")

local project = {}

project.MANIFEST = "boil.toml"
project.CONTRACT = "src/shared/ui/contract.luau"

-- Where each package kind lands. Features go through the splitter; skins are
-- pure shared-realm code and sync straight to ReplicatedStorage.Skins.
project.INSTALL_DIRS = {
	feature = "src/features",
	skin = "src/skins",
} :: { [string]: string }

export type Project = {
	name: string,
	boil: string,
	registries: { [string]: string },
	dependencies: { [string]: string },
}

function project.read(): Project
	local defaults: Project = {
		name = "boil-game",
		boil = "0.1.0",
		registries = {},
		dependencies = {},
	}

	if not fs.isFile(project.MANIFEST) then
		return defaults
	end

	local ok, decoded = pcall(serde.decode, "toml" :: any, fs.readFile(project.MANIFEST))
	if not ok then
		return defaults
	end

	local raw = decoded :: any
	local meta = if typeof(raw.project) == "table" then raw.project else {}
	return {
		name = meta.name or defaults.name,
		boil = meta.boil or defaults.boil,
		registries = if typeof(raw.registries) == "table" then raw.registries else {},
		dependencies = if typeof(raw.dependencies) == "table" then raw.dependencies else {},
	}
end

function project.write(p: Project)
	local body: { [string]: any } = {
		project = { name = p.name, boil = p.boil },
	}
	if next(p.registries) then
		body.registries = p.registries
	end
	if next(p.dependencies) then
		body.dependencies = p.dependencies
	end
	fs.writeFile(project.MANIFEST, serde.encode("toml", body, true))
end

-- The skin API version this checkout provides, read from the contract itself so
-- it can never drift from the code.
function project.contractVersion(): number
	if not fs.isFile(project.CONTRACT) then
		return 0
	end
	return tonumber(string.match(fs.readFile(project.CONTRACT), "VERSION%s*=%s*(%d+)")) or 0
end

function project.installPath(package: manifest.Package): string
	local root = project.INSTALL_DIRS[package.kind]
	local folder = package.folder or util.pascal(package.name)
	return `{root}/{folder}`
end

-- A content hash of an installed folder. Recorded at install time so `update`
-- can tell "you never touched this, safe to overwrite" from "you edited it".
function project.fingerprint(dir: string): string
	local parts: { string } = {}
	for _, rel in util.listFiles(dir) do
		table.insert(parts, rel)
		table.insert(parts, fs.readFile(`{dir}/{rel}`))
	end
	return string.sub(serde.hash("sha256", table.concat(parts, "\0")), 1, 16)
end

-- Add a package's Wally requirements to wally.toml.
--
-- Textual insert rather than a decode/encode round-trip: wally.toml is hand-
-- maintained and a round-trip would reformat it and drop its comments. Returns
-- the entries actually added.
function project.mergeWally(package: manifest.Package): { string }
	local added: { string } = {}
	if not fs.isFile("wally.toml") then
		return added
	end

	local text = fs.readFile("wally.toml")

	local function insert(section: string, entries: { [string]: string })
		for name, spec in entries do
			if string.find(text, `\n%s*{name}%s*=`) then
				continue
			end
			local header = `[{section}]`
			if not string.find(text, header, 1, true) then
				text ..= `\n{header}\n`
			end
			text = string.gsub(text, `%[{section}%]\n`, `[{section}]\n{name} = "{spec}"\n`, 1)
			table.insert(added, `{name} = "{spec}"`)
		end
	end

	insert("dependencies", package.wally)
	insert("server-dependencies", package.wallyServer)

	if #added > 0 then
		fs.writeFile("wally.toml", text)
	end
	return added
end

function project.runSplit(): boolean
	local result = process.spawn("lune", { "run", "tools/split" })
	return result.ok
end

return project
