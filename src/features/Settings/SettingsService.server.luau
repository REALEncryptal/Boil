-- Server entry point for Settings. Listens to ByteNet packets, validates
-- each request against the shared Registry, and routes accepted writes
-- through PlayerDataService so the change reaches both the player's Replica
-- (instant UI update) and ProfileStore (next autosave).
--
-- Validation here is intentionally minimal — id length, registry membership,
-- kind agreement. Per-setting business rules (e.g. "only changeable while
-- not in combat") belong in the feature that owns the setting, not here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Required for its side effect: loading Features.Settings runs init.luau's
-- auto-discovery loop, which walks the Features tree and registers each
-- sibling `Settings.luau`'s categories + settings into the per-realm Registry.
-- Submodule requires (Constants, Registry, Packets) do NOT trigger this — they
-- just index children of the Settings ModuleScript. Without this line the
-- server's Registry stays empty and every incoming SetToggle is rejected.
require(ReplicatedStorage.Features.Settings)

local Constants = require(ReplicatedStorage.Features.Settings.Constants)
local Registry = require(ReplicatedStorage.Features.Settings.Registry)
local Packets = require(ReplicatedStorage.Features.Settings.Packets)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataService)

local SettingsService = {}

-- Run after PlayerData (priority 1) so SetValue / GetReplica are ready,
-- but ahead of gameplay services that might want to read settings at Start.
SettingsService.Priority = 5

function SettingsService.Start()
	Packets.SetToggle.listen(function(payload: { id: string, value: boolean }, player: Player)
		local id = payload.id

		if #id == 0 or #id > Constants.MAX_SETTING_ID_LENGTH then
			return
		end

		local def = Registry.getSetting(id)
		if def == nil then
			warn(`[Settings] {player.Name} tried to set unregistered setting "{id}"`)
			return
		end
		if def.kind ~= "toggle" then
			warn(`[Settings] {player.Name} sent SetToggle for non-toggle setting "{id}"`)
			return
		end

		-- ByteNet already enforced `value: bool`, but defend in depth.
		if typeof(payload.value) ~= "boolean" then
			return
		end

		-- Blessed mutation path: replica diff + profile autosave stay in sync.
		PlayerDataService.SetValue(player, { Constants.PROFILE_KEY, id }, payload.value)
	end)
end

return SettingsService
