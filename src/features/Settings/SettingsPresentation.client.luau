-- Screen presentation for Settings: registers the Settings window content into
-- the HUD's frame slot. Discovered + required by init.client.luau before the
-- root mounts; registration is the only side effect.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIRegistry = require(ReplicatedStorage.Shared.Boil).UIRegistry
local Settings = require(ReplicatedStorage.Features.Settings)
local Constants = require(ReplicatedStorage.Features.Settings.Constants)

-- Client-realm sibling (StarterPlayerScripts.Features.Settings.SettingsView).
local SettingsView = require(script.Parent.SettingsView)

if Constants.Presentations.screen then
	UIRegistry.registerScreen(Settings.FRAME_ID, React.createElement(SettingsView))
end

return {}
