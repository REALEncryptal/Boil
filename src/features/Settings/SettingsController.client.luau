-- Client surface for Settings. Reads the current value from PlayerData, sends
-- writes through ByteNet (we don't apply locally — the replica diff is the
-- source of truth), and exposes a `linkTo` helper so other features can ask
-- the UI to highlight a specific setting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

-- Required for its side effect: see SettingsService.server.luau for the full
-- explanation. Submodule requires alone don't trigger Settings/init.luau, so
-- auto-discovery wouldn't run if init.client.luau ever stopped requiring the
-- feature root directly.
require(ReplicatedStorage.Features.Settings)

local Constants = require(ReplicatedStorage.Features.Settings.Constants)
local Registry = require(ReplicatedStorage.Features.Settings.Registry)
local Packets = require(ReplicatedStorage.Features.Settings.Packets)

-- Client-realm sibling controller; resolved via StarterPlayerScripts.Features.
local PlayerDataController = require(script.Parent.Parent.PlayerData.PlayerDataController)

local SettingsController = {}

-- Fires with the requested setting id whenever linkTo() is called. The Settings
-- UI subscribes and briefly highlights the matching row.
SettingsController.LinkRequested = Signal.new()

-- Returns the current value for a setting. Falls back to the registered
-- default if the player hasn't toggled it yet (or if the replica hasn't
-- arrived). Returns nil only for ids that aren't registered.
function SettingsController.get(id: string): any
	local data = PlayerDataController.GetData()
	local values = if data then data[Constants.PROFILE_KEY] else nil
	if values ~= nil then
		local v = values[id]
		if v ~= nil then
			return v
		end
	end
	local def = Registry.getSetting(id)
	return if def then def.default else nil
end

function SettingsController.setToggle(id: string, value: boolean)
	local def = Registry.getSetting(id)
	if def == nil then
		warn(`[Settings] setToggle for unregistered id "{id}"`)
		return
	end
	if def.kind ~= "toggle" then
		warn(`[Settings] setToggle for non-toggle setting "{id}"`)
		return
	end
	if typeof(value) ~= "boolean" then
		return
	end
	Packets.SetToggle.send({ id = id, value = value })
end

-- Ask the Settings UI to navigate the user's attention to a specific setting.
-- The caller is still responsible for opening the Settings frame itself (e.g.
-- via UIShell.useFrame().open(Settings.FRAME_ID) from a React component, or
-- by mounting the frame any other way) — this just fires the highlight signal.
function SettingsController.linkTo(id: string)
	if typeof(id) ~= "string" then
		return
	end
	SettingsController.LinkRequested:Fire(id)
end

function SettingsController.Start()
	-- Nothing to wire up on start; every entry point is on-demand.
end

return SettingsController
