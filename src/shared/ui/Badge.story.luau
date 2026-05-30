--!nonstrict
-- UI Labs story for the gem Badge primitive (icon + text pill).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

local REBIRTH_ICON = "rbxassetid://137349421699691"

return {
	summary = "Gem-style icon + text card. Toggle the icon to compare layouts.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		variant = UILabs.Choose({
			"blue", "red", "green", "purple", "yellow", "white", "rainbow",
		}),
		text = "Rebirth",
		textSize = UILabs.Slider(60, 8, 200, 1),
		showIcon = true,
		width = UILabs.Slider(300, 60, 800, 10),
		height = UILabs.Slider(60, 20, 200, 1),
	},

	story = function(props)
		local c = props.controls
		return React.createElement(ui.Badge, {
			variant = c.variant,
			text = c.text,
			textSize = c.textSize,
			icon = if c.showIcon then REBIRTH_ICON else nil,
			size = UDim2.fromOffset(c.width, c.height),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
		})
	end,
}
