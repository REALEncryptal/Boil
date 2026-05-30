--!nonstrict
-- UI Labs story for the ProgressBar primitive. Drag the progress slider to
-- watch the bar tween; pick a variant to swap fill+glow palette.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

return {
	summary = "Gem-styled progress bar. Variant-driven fill+glow, animated tween, atmospheric edge bleed.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		variant = UILabs.Choose({
			"yellow", "red", "blue", "green", "purple", "white", "rainbow",
		}),
		progress = UILabs.Slider(0.5, 0, 1, 0.01),
		width = UILabs.Slider(500, 100, 1200, 10),
		height = UILabs.Slider(60, 30, 200, 1),
		textSize = UILabs.Slider(50, 8, 120, 1),
		tweenDuration = UILabs.Slider(0.3, 0, 2, 0.05),
		showText = true,
		showBleeds = true,
		strokeThickness = UILabs.Slider(4, 0, 12, 1),
	},

	story = function(props)
		local c = props.controls
		return React.createElement(ui.ProgressBar, {
			variant = c.variant,
			progress = c.progress,
			size = UDim2.fromOffset(c.width, c.height),
			textSize = c.textSize,
			tweenDuration = c.tweenDuration,
			showText = c.showText,
			showBleeds = c.showBleeds,
			strokeThickness = c.strokeThickness,
		})
	end,
}
