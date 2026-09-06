--!strict
-- Slop GemBackground: the decorative gem surface on its own — gradient fill,
-- gradient-tinted outline, inner glow.
--
-- Unlike gem's version there's no tiled noise texture and no diagonal shine, so
-- `glowGradient`, `glowTransparency`, `tileSize` and `hasShine` have nothing to
-- drive and are ignored. `fillGradient` and `fillRotation` are honored, which is
-- what feature code composing its own surfaces actually reaches for.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Boil = require(ReplicatedStorage.Shared.Boil)
local parts = require(script.Parent.parts)
local theme = require(script.Parent.theme)

return function(props: Boil.GemBackgroundProps)
	local variant: theme.Variant = {
		color = props.fillGradient,
		rotation = props.fillRotation or 90,
	}

	return React.createElement("Frame", {
		Size = props.size or UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.fillBase,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex or 1,
	}, {
		UIGradient = parts.fill(variant),
		InnerGlow = parts.innerGlow(theme.gemInnerGlowThickness),
		Outline = parts.gemOutline(variant),
	})
end
