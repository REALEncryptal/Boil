-- World presentation for Settings (seam #4: an in-world surface instead of a
-- screen GUI). Binds every part tagged `SettingsToggleStation`: a ProximityPrompt
-- on the part flips the setting named by the part's `SettingId` attribute.
--
-- It calls the SAME core intent the GUI calls — SettingsController.setToggle —
-- so the world part and the Settings window stay in sync through the one
-- replicated state source. The two presentations are peers; neither knows about
-- the other.
--
-- Studio assets you must create (Rojo only syncs code):
--   * A Part (anchored, anywhere reachable) tagged `SettingsToggleStation`
--     (CollectionService tag — add it via the Tag Editor or the attribute UI).
--   * A String attribute `SettingId` on that part = an existing setting id,
--     e.g. "music.enabled" (the Music feature's toggle).
--   A ProximityPrompt is created automatically if the part doesn't have one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Constants = require(ReplicatedStorage.Features.Settings.Constants)

-- Client-realm sibling controller (StarterPlayerScripts.Features.Settings.…).
local SettingsController = require(script.Parent.SettingsController)

if not Constants.Presentations.world then
	return {}
end

local TAG = Constants.WORLD_TAG
local ATTR = Constants.WORLD_SETTING_ATTRIBUTE

local function onTriggered(part: BasePart, player: Player)
	if player ~= Players.LocalPlayer then
		return
	end
	local id = part:GetAttribute(ATTR)
	if typeof(id) ~= "string" then
		warn(`[Settings] {part:GetFullName()} is tagged {TAG} but has no string {ATTR} attribute`)
		return
	end
	-- Same intent the GUI fires; the server validates and the replica diff
	-- updates both the world part's source of truth and the Settings window.
	local current = SettingsController.get(id)
	SettingsController.setToggle(id, not current)
end

local function bind(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local prompt = part:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt == nil then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Toggle"
		prompt.ObjectText = "Setting"
		prompt.Parent = part
	end
	prompt.Triggered:Connect(function(player)
		onTriggered(part, player)
	end)
end

for _, part in CollectionService:GetTagged(TAG) do
	bind(part)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(bind)

return {}
