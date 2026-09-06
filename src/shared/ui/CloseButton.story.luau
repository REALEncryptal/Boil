--!nonstrict
-- UI Labs story for CloseButton — the project's fixed close control, recreated
-- from the Studio instance at StarterGui.ScreenGui.ImageLabel.
--
-- The `skin` control is here to demonstrate something specific: this button looks
-- the SAME in every skin. It is the one primitive that deliberately opts out of
-- the skin seam (see CloseButton.luau). Everything around it re-skins; this
-- doesn't.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

return {
	summary = "The project's close control. Fixed art — identical under every skin, unlike every other primitive. Hover to see it grow; press to see it shrink.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		size = UILabs.Slider(60, 24, 200, 2),
		device = UILabs.Choose({ "actual", "desktop", "tablet", "phone" }),
		skin = UILabs.Choose({ "default", "slop", "gem", "flat" }),
		inWindow = false,
	},

	story = function(props)
		local c = props.controls

		local content
		if c.inWindow then
			-- In place: the top-bar close, at whatever size that skin's bar gives it.
			content = React.createElement(ui.Window, {
				title = "Settings",
				icon = ui.assets.Icons.rocket,
				size = UDim2.fromOffset(560, 320),
				onClose = function() end,
			}, {
				Body = React.createElement(ui.Text, {
					text = "The close control sits in the top bar and keeps its own look.",
					role = "body",
					wrap = true,
					size = UDim2.new(1, 0, 0, 80),
				}),
			})
		else
			content = React.createElement(ui.Surface, {
				size = UDim2.fromOffset(c.size, c.size),
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
			}, {
				Button = React.createElement(ui.CloseButton, {
					size = UDim2.fromScale(1, 1),
					onClick = function() end,
				}),
			})
		end

		local skinned = React.createElement(
			ui.SkinProvider,
			{ skin = if c.skin == "default" then nil else c.skin },
			{ Content = content }
		)

		if c.device == "actual" then
			return skinned
		end
		return React.createElement(ui.ViewportProvider, { device = c.device }, { Skinned = skinned })
	end,
}
