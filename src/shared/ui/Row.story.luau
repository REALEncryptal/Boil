--!nonstrict
-- UI Labs story for the Row layout primitive (a horizontal Stack).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

return {
	summary = "Horizontal, structure-only layout. Children are skinned Buttons; Row only arranges them.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		gap = UILabs.Slider(12, 0, 60, 1),
		padding = UILabs.Slider(0, 0, 60, 1),
		fillVertical = false,
	},

	story = function(props)
		local c = props.controls
		return React.createElement(ui.Row, {
			gap = c.gap,
			padding = c.padding,
			fillVertical = c.fillVertical,
			size = UDim2.fromOffset(520, 120),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
		}, {
			A = React.createElement(ui.Button, { variant = "red", text = "A", size = UDim2.fromOffset(96, 64), layoutOrder = 1 }),
			B = React.createElement(ui.Button, { variant = "blue", text = "B", size = UDim2.fromOffset(96, 64), layoutOrder = 2 }),
			C = React.createElement(ui.Button, { variant = "green", text = "C", size = UDim2.fromOffset(96, 64), layoutOrder = 3 }),
		})
	end,
}
