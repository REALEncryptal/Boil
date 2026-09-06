--!strict
-- Slop ProgressBar: a glass track holding a gradient-filled bar and a centered
-- outlined label.
--
-- The bar's width is tweened to the latest `progress` rather than snapping; the
-- initial size is captured once on mount so React doesn't fight the tween on
-- prop updates. `showBleeds` drives gem's edge-halo frames, which this skin
-- doesn't draw — accepted and ignored.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Boil = require(ReplicatedStorage.Shared.Boil)
local parts = require(script.Parent.parts)
local theme = require(script.Parent.theme)

local DEFAULT_TWEEN_DURATION = 0.3
-- Label height as a fraction of the track, leaving room for the glyph outline.
local LABEL_HEIGHT = 0.8

return function(props: Boil.ProgressBarProps)
	-- Caps are enforced in absolute pixels, so they need the viewport scale to
	-- mean reference pixels. See parts.capFor.
	local scale = Boil.ui.useScale()
	local variant = theme.variant(props.variant)
	local progress = math.clamp(props.progress, 0, 1)
	local strokeThickness = props.strokeThickness or theme.strokeThickness
	local showText = props.showText ~= false

	-- Captured once so the JSX Size prop stays stable across renders; the tween
	-- hook owns the property after mount.
	local initialProgress = React.useRef(progress)
	local barRef = Boil.ui.useTweenedUDim2(UDim2.new(progress, 0, 1, 0), {
		property = "Size",
		duration = props.tweenDuration or DEFAULT_TWEEN_DURATION,
	})

	-- The bar is inset off the inner-drawn outline, but the *label* is not: a
	-- UIPadding on the track would apply to both, and on a bar this thin it
	-- leaves the label a sliver to scale into. So the inset lives on a wrapper
	-- around the bar only, and the label keeps the full track height.
	local inset = theme.tightPadding + strokeThickness

	local children: { [string]: any } = {
		InnerGlow = parts.innerGlow(),
		Outline = parts.outline(strokeThickness),

		FillArea = React.createElement("Frame", {
			Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			Fill = React.createElement("Frame", {
				Size = UDim2.new(initialProgress.current, 0, 1, 0),
				BackgroundColor3 = theme.progressFillBase,
				BorderSizePixel = 0,
				ref = barRef,
			}, {
				UIGradient = parts.fill(variant),
				InnerGlow = parts.innerGlow(theme.fillInnerGlowThickness),
			}),
		}),
	}

	if showText then
		local label = if props.text ~= nil then props.text else string.format("%d%%", math.round(progress * 100))
		children.Label = React.createElement("TextLabel", {
			Size = UDim2.fromScale(1, LABEL_HEIGHT),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = label,
			TextColor3 = theme.textColor,
			TextScaled = true,
			TextWrapped = true,
			FontFace = theme.font(),
			ZIndex = 3,
		}, {
			TextStroke = parts.textStroke(),
			SizeCap = parts.textSizeCap(parts.capFor(props.textSize or props.role, "label", scale)),
		})
	end

	return React.createElement("Frame", {
		Size = props.size or theme.progressBarSize,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = theme.glass,
		BackgroundTransparency = props.transparency or theme.glassTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, children)
end
