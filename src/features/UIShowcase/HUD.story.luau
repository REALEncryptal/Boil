--!nonstrict
-- UI Labs story for the game HUD. Wraps the HUD in UIShell.FrameProvider so
-- useFrame() resolves inside the story preview (production mounts the
-- provider once at the client root in src/client/init.client.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Features = ReplicatedStorage:WaitForChild("Features")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UIShell = require(Features:WaitForChild("UIShell"))

local HUD = require(Features:WaitForChild("UIShowcase"):WaitForChild("HUD"))

return {
	summary = "Game HUD: Sidebar icon+label entries toggle Window frames. Sidebar slides off-screen while any frame is open; click X (or the same Sidebar entry again) to close. Add more entries by appending to SIDEBAR_ENTRIES in HUD.ui.luau.",
	react = React,
	reactRoblox = ReactRoblox,

	story = function()
		return React.createElement(UIShell.FrameProvider, {}, {
			HUD = React.createElement(HUD),
		})
	end,
}
