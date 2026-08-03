--!strict
-- Verifies every skin implements the full component contract.
--
-- Run: `lune run tools/check-skins`   (exits non-zero on an incomplete skin)
--
-- A skin is a table of component implementations keyed by name (see
-- src/shared/ui/contract.luau § Components). At runtime a missing key now falls
-- back to gem's implementation rather than erroring (`skins.resolve`), so an
-- installed skin that predates a contract addition degrades instead of breaking
-- the game. This lint is the build-time half of that deal: it tells you which
-- keys a skin still owes *before* you publish it, so "degraded" stays a safety
-- net and not the normal state.
--
-- Scope:
--   * built-in skins  — src/shared/ui/skins/<name>.luau or <name>/init.luau
--   * installed skins — src/skins/<Name>/init.luau (where `boil add` puts them)
--
-- Installed skins are additionally checked for a boil.toml declaring a `contract`
-- range that covers the current contract.VERSION. See docs/registry.md.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local CONTRACT = "src/shared/ui/contract.luau"
local BUILTIN_DIR = "src/shared/ui/skins"
local INSTALLED_DIR = "src/skins"

type Skin = {
	label: string,
	path: string,
	source: string,
	dir: string?, -- folder-form skins only
	installed: boolean,
}

local problems = 0

local function fail(label: string, message: string)
	problems += 1
	print(`[check-skins] {label}`)
	print(`    {message}`)
end

-- The keys every skin owes, read out of the contract's `Components` type.
local function contractKeys(): ({ string }, number)
	local src = fs.readFile(CONTRACT)
	local block = string.match(src, "export type Components = {(.-)\n}")
	assert(block, `[check-skins] could not find "export type Components" in {CONTRACT}`)

	local keys: { string } = {}
	for key in string.gmatch(block, "\n%s*([%w_]+)%s*:") do
		table.insert(keys, key)
	end

	local version = tonumber(string.match(src, "VERSION%s*=%s*(%d+)"))
	assert(version, `[check-skins] could not find VERSION in {CONTRACT}`)
	return keys, version
end

-- The keys a skin actually implements, read out of its `components = { … }` table.
local function implementedKeys(source: string): { [string]: boolean }
	local block = string.match(source, "components%s*=%s*{(.-)\n%s*}")
	if not block then
		return {}
	end
	local keys: { [string]: boolean } = {}
	for key in string.gmatch(block, "([%w_]+)%s*=") do
		keys[key] = true
	end
	return keys
end

local function collect(): { Skin }
	local skins: { Skin } = {}

	if fs.isDir(BUILTIN_DIR) then
		for _, entry in fs.readDir(BUILTIN_DIR) do
			local path = `{BUILTIN_DIR}/{entry}`
			if fs.isFile(path) and string.match(entry, "%.luau$") and entry ~= "init.luau" then
				local name = (string.gsub(entry, "%.luau$", ""))
				table.insert(skins, { label = name, path = path, source = fs.readFile(path), installed = false })
				continue
			end
			if fs.isDir(path) and fs.isFile(`{path}/init.luau`) then
				local init = `{path}/init.luau`
				table.insert(
					skins,
					{ label = entry, path = init, source = fs.readFile(init), dir = path, installed = false }
				)
			end
		end
	end

	if not fs.isDir(INSTALLED_DIR) then
		return skins
	end

	for _, entry in fs.readDir(INSTALLED_DIR) do
		local dir = `{INSTALLED_DIR}/{entry}`
		if not fs.isDir(dir) then
			continue
		end
		local init = `{dir}/init.luau`
		if not fs.isFile(init) then
			fail(entry, `installed skin has no init.luau ({dir}/) — it must return a contract.Skin`)
			continue
		end
		table.insert(skins, { label = entry, path = init, source = fs.readFile(init), dir = dir, installed = true })
	end

	return skins
end

-- Installed skins carry a manifest; `contract = "^N"` must cover the current
-- contract version. Only the major is compared — a minor contract bump is
-- backwards-compatible by construction (new keys fall back to gem).
local function checkManifest(skin: Skin, contractVersion: number)
	local path = `{skin.dir}/boil.toml`
	if not fs.isFile(path) then
		fail(skin.label, `installed skin has no boil.toml — run \`boil publish {skin.dir}\` to scaffold one`)
		return
	end

	local ok, manifest = pcall(serde.decode, "toml" :: any, fs.readFile(path))
	if not ok then
		fail(skin.label, `boil.toml is not valid TOML: {manifest}`)
		return
	end

	local declared = (manifest :: any).package and (manifest :: any).package.contract
	if not declared then
		fail(skin.label, `boil.toml is missing \`contract\` under [package] (current contract.VERSION is {contractVersion})`)
		return
	end

	local major = tonumber(string.match(declared, "(%d+)"))
	if major ~= contractVersion then
		fail(
			skin.label,
			`declares contract "{declared}" but this checkout is contract.VERSION {contractVersion} — the skin needs updating`
		)
	end
end

local keys, contractVersion = contractKeys()
local skins = collect()

for _, skin in skins do
	local implemented = implementedKeys(skin.source)

	local missing: { string } = {}
	for _, key in keys do
		if not implemented[key] then
			table.insert(missing, key)
		end
	end

	if #missing > 0 then
		fail(
			skin.label,
			`{skin.path} does not implement {#missing}/{#keys} contract key(s): {table.concat(missing, ", ")}`
		)
	end

	if not string.match(skin.source, 'name%s*=%s*["\']') then
		fail(skin.label, `{skin.path} has no \`name\` field — the registry keys skins by it`)
	end

	if skin.installed then
		checkManifest(skin, contractVersion)
	end
end

if problems > 0 then
	print(`\n[check-skins] FAILED — {problems} problem(s) across {#skins} skin(s).`)
	print("Every skin must implement every key in contract.Components (see docs/game/skin-contract.md).")
	process.exit(1)
end

print(`[check-skins] ok — {#skins} skin(s), all {#keys} contract key(s) implemented (contract v{contractVersion}).`)
