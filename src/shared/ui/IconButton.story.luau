--!nonstrict
-- UI Labs story for the gem IconButton primitive.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

return {
	summary = "Icon button. Flip surface between the gem fill and translucent glass, pick a variant, paste an asset id; click prints.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		variant = UILabs.Choose({
			"red", "blue", "green", "purple", "yellow", "brown", "white", "rainbow",
		}),
		surface = UILabs.Choose({ "gem", "glass" }),
		icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		iconScale = UILabs.Slider(0.6, 0.1, 1, 0.05),
		width = UILabs.Slider(80, 20, 400, 1),
		height = UILabs.Slider(80, 20, 400, 1),
	},

	story = function(props)
		local c = props.controls
		return React.createElement(ui.IconButton, {
			variant = c.variant,
			surface = c.surface,
			icon = c.icon,
			iconScale = c.iconScale,
			size = UDim2.fromOffset(c.width, c.height),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			onClick = function()
				print(`[UI Labs] IconButton ({c.surface}/{c.variant}) clicked`)
			end,
		})
	end,
}
