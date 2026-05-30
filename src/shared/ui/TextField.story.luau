--!nonstrict
-- UI Labs story for the TextField primitive.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

return {
	summary = "Translucent dark glass text input. Drag size/padding, type to update; FocusLost prints the value.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		width = UILabs.Slider(400, 100, 1200, 10),
		height = UILabs.Slider(60, 30, 200, 1),
		textSize = UILabs.Slider(40, 8, 120, 1),
		transparency = UILabs.Slider(0.8, 0, 1, 0.05),
		strokeThickness = UILabs.Slider(4, 0, 12, 1),
		padding = UILabs.Slider(10, 0, 40, 1),
		placeholderText = "Type something",
		clearTextOnFocus = false,
	},

	story = function(props)
		local c = props.controls
		local value, setValue = React.useState("")

		return React.createElement(ui.TextField, {
			size = UDim2.fromOffset(c.width, c.height),
			textSize = c.textSize,
			transparency = c.transparency,
			strokeThickness = c.strokeThickness,
			padding = c.padding,
			placeholderText = c.placeholderText,
			clearTextOnFocus = c.clearTextOnFocus,
			text = value,
			onTextChanged = setValue,
			onFocusLost = function(text, enterPressed)
				print(`[UI Labs] TextField FocusLost: "{text}" (enter={enterPressed})`)
			end,
		})
	end,
}
