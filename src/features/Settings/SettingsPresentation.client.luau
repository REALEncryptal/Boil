-- Screen presentation for Settings: attaches the Settings window content to the
-- nav entry declared in Nav.luau. Discovered + required by init.client.luau
-- before the root mounts; registration is the only side effect.
--
-- Two halves in two realms: Nav.luau (shared) declares that a "Settings" screen
-- exists, this file (client) supplies the React element. `setScreen` warns if the
-- two ever disagree, which is the bug the old registry couldn't catch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Settings = require(ReplicatedStorage.Features.Settings)
local Constants = require(ReplicatedStorage.Features.Settings.Constants)
local HUD = ReplicatedStorage.Features:FindFirstChild("HUD")

-- Client-realm sibling (StarterPlayerScripts.Features.Settings.SettingsView).
local SettingsView = require(script.Parent.SettingsView)

-- HUD is an optional feature: without it Settings simply has no window, and the
-- world-part presentation still works. So this checks rather than assumes.
if Constants.Presentations.screen and HUD then
	require(HUD).setScreen(Settings.FRAME_ID, React.createElement(SettingsView))
end

return {}
