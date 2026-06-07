--!nonstrict
-- UI Labs story for the Slot positioning primitive. A Slot draws nothing; here
-- it positions + pads a skinned Panel so you can see the region it defines.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

return {
	summary = "Transparent named positioning container. Tune size / padding; the visible Panel fills the slot.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		width = UILabs.Slider(300, 80, 600, 1),
		height = UILabs.Slider(200, 80, 600, 1),
		padding = UILabs.Slider(16, 0, 80, 1),
	},

	story = function(props)
		local c = props.controls
		return React.createElement(ui.Slot, {
			name = "DemoSlot",
			size = UDim2.fromOffset(c.width, c.height),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			padding = c.padding,
		}, {
			Panel = React.createElement(ui.Panel, {
				variant = "blue",
				size = UDim2.fromScale(1, 1),
			}),
		})
	end,
}
