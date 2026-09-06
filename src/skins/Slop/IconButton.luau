--!strict
-- Slop IconButton: the same gem surface as Button, forced square by an
-- aspect-ratio constraint, with a centered icon instead of a label.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Boil = require(ReplicatedStorage.Shared.Boil)
local parts = require(script.Parent.parts)
local theme = require(script.Parent.theme)

-- Template's icon inset: the glyph covers 70% of the button.
local DEFAULT_ICON_SCALE = 0.7

return function(props: Boil.IconButtonProps)
	local variant = theme.variant(props.variant)
	local hover = Boil.ui.useHoverScale()
	local iconScale = props.iconScale or DEFAULT_ICON_SCALE

	local children: { [string]: any } = {
		UIScale = React.createElement("UIScale", { Scale = 1, ref = hover.scaleRef }),
		UIAspectRatioConstraint = React.createElement("UIAspectRatioConstraint", { AspectRatio = 1 }),
		-- Stays square inside a list that stretches its items (see Checkbox).
		UIFlexItem = React.createElement("UIFlexItem", {
			ItemLineAlignment = Enum.ItemLineAlignment.Center,
		}),
		UIGradient = parts.fill(variant),
		InnerGlow = parts.innerGlow(theme.gemInnerGlowThickness),
		Outline = parts.gemOutline(variant),

		Icon = if props.icon
			then React.createElement("ImageLabel", {
				Size = UDim2.fromScale(iconScale, iconScale),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = props.icon,
				ImageColor3 = props.iconColor or theme.mutedTextColor,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 3,
			}, {
				UIAspectRatioConstraint = React.createElement("UIAspectRatioConstraint", { AspectRatio = 1 }),
			})
			else nil,

		Trigger = React.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 10,
			[React.Event.MouseEnter] = hover.onEnter,
			[React.Event.MouseLeave] = hover.onLeave,
			[React.Event.MouseButton1Down] = hover.onPress,
			[React.Event.MouseButton1Up] = hover.onRelease,
			[React.Event.Activated] = props.onClick,
		}),
	}

	-- Caller content rides inside the frame, so the hover scale carries it.
	if props.children then
		for key, child in props.children do
			children[key] = child
		end
	end

	return React.createElement("Frame", {
		Size = props.size or theme.iconButtonSize,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = theme.fillBase,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex or 2,
	}, children)
end
