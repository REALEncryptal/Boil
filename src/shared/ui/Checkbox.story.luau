--!nonstrict
-- UI Labs story for the Checkbox primitive.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

return {
	summary = "Toggleable dark-glass checkbox. Click to flip; check uses the picked variant palette.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		variant = UILabs.Choose({
			"white", "red", "blue", "green", "purple", "yellow", "rainbow",
		}),
		startChecked = false,
		size = UILabs.Slider(40, 16, 200, 1),
		padding = UILabs.Slider(5, 0, 20, 1),
		strokeThickness = UILabs.Slider(4, 0, 12, 1),
	},

	story = function(props)
		local c = props.controls
		local checked, setChecked = React.useState(c.startChecked)

		return React.createElement(ui.Checkbox, {
			variant = c.variant,
			checked = checked,
			onToggle = setChecked,
			size = UDim2.fromOffset(c.size, c.size),
			padding = c.padding,
			strokeThickness = c.strokeThickness,
		})
	end,
}
