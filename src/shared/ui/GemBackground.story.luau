--!nonstrict
-- UI Labs story for GemBackground — the tiled-noise + gradient fill + glow stroke
-- stack that gives every gem surface its look. Usually composed by Button, Badge
-- and Panel rather than used directly; this story exists so the layers can be
-- tuned in isolation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

local VARIANTS = { "primary", "danger", "success", "warning", "special", "secondary" }

return {
	summary = "The gem fill/glow/shine stack on its own. `variant` names a semantic role; the skin maps it to a palette.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		variant = UILabs.Choose(VARIANTS),
		hasShine = true,
		fillRotation = UILabs.Slider(90, 0, 360, 5),
		glowRotation = UILabs.Slider(90, 0, 360, 5),
		tile = UILabs.Slider(115, 20, 400, 5),
		size = UILabs.Slider(320, 80, 700, 10),
	},

	story = function(props)
		local c = props.controls
		local key = ui.theme.resolveVariant(c.variant)
		local palette = ui.assets.Variants[key] or ui.assets.Variants.blue

		return React.createElement("Frame", {
			Size = UDim2.fromOffset(c.size, c.size),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			Gem = React.createElement(ui.GemBackground, {
				fillGradient = palette.fill,
				glowGradient = palette.glow,
				fillRotation = c.fillRotation,
				glowRotation = c.glowRotation,
				tileSize = UDim2.fromOffset(c.tile, c.tile),
				hasShine = c.hasShine,
			}),
			Label = React.createElement(ui.Text, {
				text = `{c.variant} → {key}`,
				role = "heading",
				shadow = true,
				zIndex = 3,
			}),
		})
	end,
}
