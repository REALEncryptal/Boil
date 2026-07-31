--!strict
-- Skin registry — the lookup behind the skin seam.
--
-- Holds every skin available to this game, keyed by name. Three ways in:
--
--   1. Built-ins — `gem` and `flat`, shipped with the framework.
--   2. Discovery — every ModuleScript under `ReplicatedStorage.Skins`, which is
--      where `boil add <skin>` installs (src/skins/<Name>/ syncs there directly;
--      skins are pure shared-realm code, so the splitter isn't involved).
--   3. `register(skin)` — imperative, for a skin built at runtime.
--
-- Discovery is **lazy**: it runs on the first `get`/`names`/`all` call, not at
-- require time and not from the client entry script. That's deliberate — UI Labs
-- runs in Studio edit mode where the entry script never executes, so an installed
-- skin has to appear in the SkinProvider story the same way a built-in does.
--
-- The container is read generically (`FindFirstChild("Skins")`, iterate children),
-- so no framework code ever names a skin. See docs/registry.md.
--
-- Name access works two ways — `skins.get("gem")` or `skins.gem` (metatable).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local contract = require(script.Parent.contract)

local SKINS_CONTAINER = "Skins"

local registry: { [string]: contract.Skin } = {}
local discovered = false
local warned: { [string]: boolean } = {}

-- A skin is a name + a token table + component implementations. Anything under
-- ReplicatedStorage.Skins that doesn't look like one is skipped with a warning
-- rather than erroring — one malformed installed skin must not break the game.
local function isSkin(value: any): boolean
	return typeof(value) == "table" and typeof(value.name) == "string" and typeof(value.components) == "table"
end

local function register(skin: contract.Skin): contract.Skin
	if not isSkin(skin) then
		error("[skins] register expects { name, theme, components }", 2)
	end
	registry[skin.name] = skin
	return skin
end

local function discover()
	local container = ReplicatedStorage:FindFirstChild(SKINS_CONTAINER)
	if not container then
		return
	end
	for _, child in container:GetChildren() do
		if not child:IsA("ModuleScript") then
			continue
		end
		local ok, result = pcall(require, child)
		if not ok then
			warn(`[skins] "{child.Name}" failed to load: {result}`)
			continue
		end
		if not isSkin(result) then
			warn(`[skins] "{child.Name}" did not return a skin table; skipped`)
			continue
		end
		registry[(result :: contract.Skin).name] = result
	end
end

local function ensureDiscovered()
	if discovered then
		return
	end
	discovered = true
	discover()
end

local function get(name: string?): contract.Skin
	ensureDiscovered()
	local skin = registry[name or ""]
	if skin then
		return skin
	end
	if name and not warned[name] then
		warned[name] = true
		warn(`[skins] unknown skin "{name}" — falling back to gem`)
	end
	return registry.gem
end

local function names(): { string }
	ensureDiscovered()
	local out: { string } = {}
	for name in registry do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

local function all(): { [string]: contract.Skin }
	ensureDiscovered()
	return table.clone(registry)
end

-- Resolve one component implementation, falling back to gem's when the active
-- skin doesn't implement the key.
--
-- This is what keeps published skins forward-compatible: adding a primitive to
-- the contract used to be a hard runtime error for every skin that predated it
-- (`React.createElement(nil)`). Now an older skin renders that one primitive in
-- gem and everything else in its own look — degraded, not broken. `check-skins`
-- is the build-time signal that a skin is incomplete; this is the runtime net.
local function resolve(skin: contract.Skin, key: string): any
	local impl = (skin.components :: any)[key]
	if impl then
		return impl
	end
	local warnKey = `{skin.name}.{key}`
	if not warned[warnKey] then
		warned[warnKey] = true
		warn(`[skins] skin "{skin.name}" does not implement "{key}" — rendering gem's`)
	end
	return (registry.gem.components :: any)[key]
end

register(require(script.gem))
register(require(script.flat))

local skins = {
	get = get,
	names = names,
	all = all,
	register = register,
	resolve = resolve,
}

-- `skins.gem` / `skins.<installed>` alongside `skins.get(name)`. Falls through to
-- the registry only for keys that aren't part of the API above.
return setmetatable(skins, {
	__index = function(_, key: string): any
		ensureDiscovered()
		return registry[key]
	end,
})
