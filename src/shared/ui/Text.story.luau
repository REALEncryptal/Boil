--!nonstrict
-- UI Labs story for the Text primitive. Toggle the shadow control to compare
-- the plain label against the gem drop-shadow variant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

return {
	summary = "Text primitive — toggle `shadow` for the drop-shadow gem treatment.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		text = "Hello",
		textSize = UILabs.Slider(50, 8, 200, 1),
		shadow = false,
		weight = UILabs.Choose({
			"Bold", "Heavy", "SemiBold", "Medium", "Regular",
		}),
		xAlignment = UILabs.Choose({ "Center", "Left", "Right" }),
	},

	story = function(props)
		local c = props.controls
		return React.createElement(ui.Text, {
			text = c.text,
			textSize = c.textSize,
			shadow = c.shadow,
			weight = Enum.FontWeight[c.weight],
			xAlignment = Enum.TextXAlignment[c.xAlignment],
			size = UDim2.fromOffset(600, 80),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
		})
	end,
}
