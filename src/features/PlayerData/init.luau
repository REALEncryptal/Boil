-- PlayerData — the shared feature that owns player profile persistence.
--
-- The profile schema is empty here by design. Each consuming feature drops a
-- sibling `PlayerData.luau` file (auto-discovered below) that returns
-- `function(PlayerData) ... end` and calls `PlayerData.registerTemplate(key, default)`
-- to claim a top-level key on the profile. PlayerDataService merges every
-- registered slice and hands the result to ProfileStore.New, which means a
-- feature like Pets can add its own data shape without ever touching this folder.
--
-- See docs/game/PlayerData.md for the integration guide.

local PlayerData = {}

PlayerData.Constants = require(script.Constants)

local templateSlices: { [string]: any } = {}

-- Recursively clone a value so each profile gets its own tables. Registered
-- defaults may be mutable (Settings registers `{}`, a feature could register a
-- nested table) — without this, every profile would share one table object and
-- a mutation on one player's data would leak into the template and every other
-- profile. Non-table values (strings, numbers, booleans) are returned as-is.
local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

function PlayerData.registerTemplate(key: string, default: any)
	if templateSlices[key] ~= nil then
		warn(
			`[PlayerData] template key "{key}" registered twice; `
				.. `second registration ignored`
		)
		return
	end
	templateSlices[key] = default
end

-- Returns a fresh deep copy of the merged template. Callers (ProfileStore.New,
-- and anything that introspects defaults) get a private structure they can hand
-- out per-profile without aliasing the registered slices. Registered defaults
-- are therefore safe to be mutable.
function PlayerData.getTemplate(): { [string]: any }
	local merged = {}
	for key, value in templateSlices do
		merged[key] = deepCopy(value)
	end
	return merged
end

------------------------------------------------------------------------------
-- Auto-discovery
------------------------------------------------------------------------------
-- Walk the Features tree and require any sibling feature's `PlayerData.luau`
-- module. That module is expected to return `function(PlayerData) ... end` —
-- when called, it receives this PlayerData table and uses registerTemplate to
-- claim slices of the profile.
--
-- Mirrors the Settings feature's discovery pattern. The convention avoids a
-- circular require (a feature's PlayerData.luau never requires Features.PlayerData
-- itself) and works on both realms — only the server reads getTemplate() today,
-- but the registry is realm-neutral so the same registrations are visible on
-- the client if a feature wants to introspect them.
do
	local Features = script.Parent
	for _, featureModule in Features:GetChildren() do
		if featureModule == script then
			continue
		end
		local mod = featureModule:FindFirstChild("PlayerData")
		if mod == nil or not mod:IsA("ModuleScript") then
			continue
		end

		local ok, result = pcall(require, mod)
		if not ok then
			warn(`[PlayerData] failed to require {mod:GetFullName()}: {result}`)
			continue
		end
		if typeof(result) ~= "function" then
			warn(
				`[PlayerData] {mod:GetFullName()} must return function(PlayerData); `
					.. `got {typeof(result)}`
			)
			continue
		end

		local okCall, err = pcall(result, PlayerData)
		if not okCall then
			warn(`[PlayerData] registration error in {mod:GetFullName()}: {err}`)
		end
	end
end

return PlayerData
