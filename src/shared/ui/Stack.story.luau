--!nonstrict
-- UI Labs story for the Stack layout primitive. Tune gap / padding / alignment /
-- fill and watch the (skinned) children rearrange. Stack itself draws nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

return {
	summary = "Vertical, structure-only layout. Children are skinned Buttons; Stack only arranges them.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		gap = UILabs.Slider(12, 0, 60, 1),
		padding = UILabs.Slider(0, 0, 60, 1),
		alignment = UILabs.Choose({ "Center", "Left", "Right" }),
		fillHorizontal = false,
	},

	story = function(props)
		local c = props.controls
		local hAlign = Enum.HorizontalAlignment.Center
		if c.alignment == "Left" then
			hAlign = Enum.HorizontalAlignment.Left
		elseif c.alignment == "Right" then
			hAlign = Enum.HorizontalAlignment.Right
		end
		return React.createElement(ui.Stack, {
			gap = c.gap,
			padding = c.padding,
			horizontalAlignment = hAlign,
			fillHorizontal = c.fillHorizontal,
			size = UDim2.fromOffset(360, 360),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
		}, {
			A = React.createElement(ui.Button, { variant = "red", text = "One", size = UDim2.fromOffset(200, 56), layoutOrder = 1 }),
			B = React.createElement(ui.Button, { variant = "blue", text = "Two", size = UDim2.fromOffset(200, 56), layoutOrder = 2 }),
			C = React.createElement(ui.Button, { variant = "green", text = "Three", size = UDim2.fromOffset(200, 56), layoutOrder = 3 }),
		})
	end,
}
