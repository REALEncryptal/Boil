--!strict
-- Slop Panel: a translucent black glass surface with the heavy dark outline and
-- a soft inner glow.
--
-- Gem mode (contract): passing a `variant` swaps the glass body for an opaque
-- variant gradient and tints the outline to match — the same surface Button and
-- GemBackground paint. `hasShine` / `tileSize` describe gem's noise-and-shine
-- stack, which this skin has no equivalent for; they're accepted and ignored.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Boil = require(ReplicatedStorage.Shared.Boil)
local parts = require(script.Parent.parts)
local theme = require(script.Parent.theme)

return function(props: Boil.PanelProps)
	local gem = props.variant ~= nil
	local variant = theme.variant(props.variant)
	local strokeThickness = props.strokeThickness or theme.strokeThickness

	local children: { [string]: any } = {
		InnerGlow = parts.innerGlow(if gem then theme.gemInnerGlowThickness else theme.innerGlowThickness),
		Outline = if gem then parts.gemOutline(variant, strokeThickness) else parts.outline(strokeThickness),

		-- The outline draws *inside* the frame, so bare padding would leave
		-- content crowding it. Summed at render time so a live theme edit
		-- carries through (see CLAUDE.md § stroke thickness).
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, theme.padding + strokeThickness),
			PaddingBottom = UDim.new(0, theme.padding + strokeThickness),
			PaddingLeft = UDim.new(0, theme.padding + strokeThickness),
			PaddingRight = UDim.new(0, theme.padding + strokeThickness),
		}),
	}

	if gem then
		children.UIGradient = parts.fill(variant)
	end

	if props.children then
		for key, child in props.children do
			children[key] = child
		end
	end

	return React.createElement("Frame", {
		Size = props.size or theme.panelSize,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = if gem then theme.fillBase else theme.glass,
		BackgroundTransparency = props.transparency or (if gem then 0 else theme.glassTransparency),
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, children)
end
