--!nonstrict
-- UI Labs story for the gem Button primitive.
-- Discovered automatically by the UI Labs Studio plugin via the `.story` name suffix.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

return {
	summary = "Gem-style button. Exercise size, label size, and optional surface/text stroke emphasis.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		variant = UILabs.Choose({
			"red", "blue", "green", "purple", "yellow", "white", "rainbow",
		}),
		text = "Click",
		textSize = UILabs.Slider(50, 8, 200, 1),
		strokeThickness = UILabs.Slider(4, 0, 20, 1),
		textStrokeThickness = UILabs.Slider(3, 0, 20, 1),
		width = UILabs.Slider(60, 20, 400, 1),
		height = UILabs.Slider(60, 20, 400, 1),
		disabled = false,
	},

	story = function(props)
		local c = props.controls
		return React.createElement(ui.Button, {
			variant = c.variant,
			text = c.text,
			textSize = c.textSize,
			strokeThickness = c.strokeThickness,
			textStrokeThickness = c.textStrokeThickness,
			size = UDim2.fromOffset(c.width, c.height),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			disabled = c.disabled,
			onClick = function()
				print(`[UI Labs] Button "{c.text}" ({c.variant}) clicked`)
			end,
		})
	end,
}
