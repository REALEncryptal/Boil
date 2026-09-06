--!strict
-- Slop Button: an opaque gem surface — variant gradient fill, gradient-tinted
-- dark outline, soft inner glow — with a scale-to-fit label whose glyph outline
-- carries the same gradient. An invisible Trigger on top captures the press.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Boil = require(ReplicatedStorage.Shared.Boil)
local parts = require(script.Parent.parts)
local theme = require(script.Parent.theme)

-- Dark wash drawn over the gem (and its label) while disabled. Sits below the
-- Trigger so it only affects the look, never the tree.
local DISABLED_OVERLAY_TRANSPARENCY = 0.45

-- Optical centering. A TextScaled label is centered on its *line box*, which
-- reserves descender room below the baseline; FredokaOne's is deep enough that
-- glyphs with nothing below the baseline ("+", digits, caps) read as sitting low
-- in the button. Lifting the box by this fraction of the button height puts the
-- glyph on the geometric center instead of the line's.
local LABEL_OPTICAL_LIFT = 0.04

return function(props: Boil.ButtonProps)
	-- Caps are enforced in absolute pixels, so they need the viewport scale to
	-- mean reference pixels. See parts.capFor.
	local scale = Boil.ui.useScale()
	local variant = theme.variant(props.variant)
	local disabled = props.disabled == true
	local hover = Boil.ui.useHoverScale()

	return React.createElement("Frame", {
		Size = props.size or theme.buttonSize,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = theme.fillBase,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex or 2,
	}, {
		UIScale = React.createElement("UIScale", { Scale = 1, ref = hover.scaleRef }),
		UIGradient = parts.fill(variant),
		InnerGlow = parts.innerGlow(theme.gemInnerGlowThickness),
		Outline = parts.gemOutline(variant),

		Label = React.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 0.675, 0),
			Position = UDim2.fromScale(0.5, 0.5 - LABEL_OPTICAL_LIFT),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Text = props.text or "",
			TextColor3 = theme.textColor,
			TextScaled = true,
			TextWrapped = true,
			FontFace = theme.font(props.textWeight),
			ZIndex = 3,
		}, {
			TextStroke = parts.textStroke(theme.gemTextStrokeThickness, variant),
			SizeCap = parts.textSizeCap(parts.capFor(props.textSize or props.role, theme.roles.button, scale)),
		}),

		DisabledOverlay = if disabled
			then React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = DISABLED_OVERLAY_TRANSPARENCY,
				BorderSizePixel = 0,
				ZIndex = 9,
			})
			else nil,

		Trigger = React.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 10,
			[React.Event.MouseEnter] = if disabled then nil else hover.onEnter,
			[React.Event.MouseLeave] = if disabled then nil else hover.onLeave,
			[React.Event.MouseButton1Down] = if disabled then nil else hover.onPress,
			[React.Event.MouseButton1Up] = if disabled then nil else hover.onRelease,
			[React.Event.Activated] = if disabled then nil else props.onClick,
		}),
	})
end
