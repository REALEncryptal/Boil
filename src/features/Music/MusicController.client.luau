-- Drives background music playback from the persisted music.enabled setting.
--
-- The controller doesn't subscribe to the Settings feature directly — it
-- reacts to PlayerDataController.DataChanged, then asks SettingsController.get
-- for the current value (which already does the "saved value or registered
-- default" fallback). Any change that flips music.enabled in the replica
-- runs applyState; idempotent calls to playMusic/stopMusic make redundant
-- fires harmless.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local audio = require(ReplicatedStorage.Shared.audio)
local Constants = require(ReplicatedStorage.Features.Music.Constants)

-- Client-realm siblings (StarterPlayerScripts.Features tree).
local PlayerDataController = require(script.Parent.Parent.PlayerData.PlayerDataController)
local SettingsController = require(script.Parent.Parent.Settings.SettingsController)

local MusicController = {}

-- After PlayerData (1). Before Settings has nothing to do at Start so its
-- ordering doesn't matter; ours just has to come after PlayerData so the
-- DataChanged signal is wired by the time the replica arrives.
MusicController.Priority = 10

local function applyState()
	local enabled = SettingsController.get(Constants.SETTING_ID)
	if enabled then
		audio.playMusic(Constants.DEFAULT_TRACK, Constants.VOLUME)
	else
		audio.stopMusic()
	end
end

function MusicController.Start()
	-- React to every replica change. SettingsController.get reads PlayerData
	-- under the hood, so flipping music.enabled inside PlayerData.Settings
	-- flows through here on the next replica diff.
	PlayerDataController.DataChanged:Connect(applyState)

	-- If PlayerData already arrived before we got here (lucky load order),
	-- apply immediately. Otherwise wait for the first DataChanged — avoids
	-- a brief burst of default-on music if the player has it saved off.
	if PlayerDataController.GetData() ~= nil then
		applyState()
	end
end

return MusicController
