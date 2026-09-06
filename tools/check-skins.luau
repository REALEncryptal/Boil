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
--
-- Since contract v2 a skin also owes TOKENS, not just components: the six `type`
-- roles and the six `space` steps, plus `resolveVariant`. Call sites name those
-- ("role = body", "gap = md") rather than typing numbers, so a skin missing one
-- renders a nil size — which is exactly the class of breakage the shape-only
-- contract used to allow. The keys are read out of the contract so this lint and
-- the runtime never disagree about the list.

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

-- The token keys every skin owes, read out of the contract's REQUIRED_* lists.
local function contractTokenKeys(): ({ string }, { string })
	local src = fs.readFile(CONTRACT)

	local function list(name: string): { string }
		-- Concatenated rather than interpolated: the pattern contains braces, and
		-- a backtick string would read those as interpolation holes.
		local block = string.match(src, "local " .. name .. "%s*=%s*{(.-)}")
		assert(block, `[check-skins] could not find {name} in {CONTRACT}`)
		local out: { string } = {}
		for key in string.gmatch(block, '"([%w_]+)"') do
			table.insert(out, key)
		end
		return out
	end

	return list("REQUIRED_TYPE_KEYS"), list("REQUIRED_SPACE_KEYS")
end

-- A skin's theme module: `<skin dir>/theme.luau` for a folder skin, and the
-- shared `theme.luau` for the single-file gem skin (which re-exports it).
local function themeSource(skin: Skin): (string?, string?)
	local candidates = {}
	if skin.dir then
		table.insert(candidates, `{skin.dir}/theme.luau`)
	end
	-- `theme = require(ui.theme)` — a single-file skin pointing at the shared one.
	if string.match(skin.source, "theme%s*=%s*require%b()") then
		table.insert(candidates, "src/shared/ui/theme.luau")
	end
	for _, path in candidates do
		if fs.isFile(path) then
			return fs.readFile(path), path
		end
	end
	return nil, nil
end

-- `theme.type = {` / `theme.space = {` bodies, so a missing role is named rather
-- than reported as "no scale".
local function scaleKeys(source: string, field: string): { [string]: boolean }
	local found: { [string]: boolean } = {}
	-- %b{} matches the balanced table body, so the pattern needs no newline
	-- literal and doesn't care how the table is formatted.
	local block = string.match(source, "theme%." .. field .. "%s*=%s*(%b{})")
	if not block then
		-- `theme.<field> = table.clone(tokens.<field>)` inherits the canonical
		-- set wholesale, so read the keys out of tokens.luau instead.
		if not string.match(source, "theme%." .. field .. "%s*=%s*table%.clone") then
			return found
		end
		local canonical = fs.readFile("src/shared/ui/tokens.luau")
		block = string.match(canonical, "tokens%." .. field .. "%s*=%s*(%b{})")
		if not block then
			return found
		end
	end
	for key in string.gmatch(block, "([%w_]+)%s*=") do
		found[key] = true
	end
	return found
end

local function checkTokens(skin: Skin, typeKeys: { string }, spaceKeys: { string })
	local source, path = themeSource(skin)
	if not source then
		fail(skin.label, "could not locate a theme.luau — a skin must expose a token table")
		return
	end

	for field, required in { type = typeKeys, space = spaceKeys } do
		local found = scaleKeys(source, field)
		local missing: { string } = {}
		for _, key in required do
			if not found[key] then
				table.insert(missing, key)
			end
		end
		if #missing > 0 then
			fail(
				skin.label,
				`{path} is missing theme.{field}: ` .. table.concat(missing, ", ") .. " (contract v2 requires all of them)"
			)
		end
	end

	if not string.match(source, "function theme%.resolveVariant") then
		fail(skin.label, `{path} has no theme.resolveVariant(key) — semantic variants can't be mapped without it`)
	end
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
local typeKeys, spaceKeys = contractTokenKeys()
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

	checkTokens(skin, typeKeys, spaceKeys)

	if skin.installed then
		checkManifest(skin, contractVersion)
	end
end

if problems > 0 then
	print(`\n[check-skins] FAILED — {problems} problem(s) across {#skins} skin(s).`)
	print("Every skin must implement every key in contract.Components (see docs/game/skin-contract.md).")
	process.exit(1)
end

print(
	`[check-skins] ok — {#skins} skin(s), all {#keys} component key(s) and `
		.. `{#typeKeys + #spaceKeys} token(s) present (contract v{contractVersion}).`
)
