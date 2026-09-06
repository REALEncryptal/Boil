-- PlayerData — the shared feature that owns player profile persistence.
--
-- The profile schema is empty here by design. Each consuming feature drops a
-- sibling `PlayerData.luau` returning `function(PlayerData) … end` and calls
-- `PlayerData.registerTemplate(key, default)` to claim a top-level key on the
-- profile. PlayerDataService merges every registered slice and hands the result
-- to ProfileStore.New, so a feature like Pets adds its own data shape without
-- ever touching this folder.
--
-- Discovery is `Boil.Registry` — the same mechanism Settings and the HUD's Nav
-- use. It used to be a hand-written loop here, duplicated almost line for line in
-- Settings; every shared feature that wanted contributions was writing a fourth
-- copy. See docs/game/PlayerData.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Boil = require(ReplicatedStorage.Shared.Boil)

local PlayerData = {}

PlayerData.Constants = require(script.Constants)

local templateSlices: { [string]: any } = {}

-- Recursively clone a value so each profile gets its own tables. Registered
-- defaults may be mutable (a feature could register a nested table) — without
-- this, every profile would share one table object and a mutation on one player's
-- data would leak into the template and every other profile. Non-table values are
-- returned as-is.
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
		warn(`[PlayerData] template key "{key}" registered twice; second registration ignored`)
		return
	end
	templateSlices[key] = default
end

------------------------------------------------------------------------------
-- Discovery
------------------------------------------------------------------------------
-- `registerTemplate` is attached to the seam before anything reads it, so a
-- contributor's `function(PlayerData)` receives it. Discovery stays LAZY and
-- fires on the first `getTemplate()` — which is exactly when the server needs it,
-- just before ProfileStore.New.
local seam = Boil.Registry.define("PlayerData", script)
seam.registerTemplate = PlayerData.registerTemplate

-- Returns a fresh deep copy of the merged template. Callers (ProfileStore.New,
-- and anything that introspects defaults) get a private structure they can hand
-- out per-profile without aliasing the registered slices, so registered defaults
-- are safe to be mutable.
function PlayerData.getTemplate(): { [string]: any }
	seam.discover()

	local merged = {}
	for key, value in templateSlices do
		merged[key] = deepCopy(value)
	end
	return merged
end

return PlayerData
