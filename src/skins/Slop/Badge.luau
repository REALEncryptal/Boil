--!strict
-- Slop Badge: a glass pill with an optional leading icon and a scale-to-fit
-- label, both in the cool off-white the template uses for secondary content.
--
-- The template's badge is glass with a plain black outline and no gradient
-- anywhere, so `variant` has nothing to paint here and is ignored. (An earlier
-- cut routed it to the outline to keep the prop visible; that just made every
-- badge in a red showcase red-bordered, which isn't the design.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Boil = require(ReplicatedStorage.Shared.Boil)
local parts = require(script.Parent.parts)
local theme = require(script.Parent.theme)

-- Template's icon inset inside the pill.
local ICON_SCALE = 0.8
-- Label height as a fraction of the pill, leaving room for the glyph outline.
local LABEL_HEIGHT = 0.645

return function(props: Boil.BadgeProps)
	-- Caps are enforced in absolute pixels, so they need the viewport scale to
	-- mean reference pixels. See parts.capFor.
	local scale = Boil.ui.useScale()
	local children: { [string]: any } = {
		InnerGlow = parts.innerGlow(),
		Outline = parts.outline(),

		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, theme.space.sm),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
		-- Clears the inner-drawn outline on the sides the content runs up to.
		UIPadding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, theme.tightPadding + theme.strokeThickness),
			PaddingRight = UDim.new(0, theme.tightPadding + theme.strokeThickness),
		}),
	}

	if props.icon then
		children.Icon = React.createElement("ImageLabel", {
			Size = UDim2.fromScale(ICON_SCALE, ICON_SCALE),
			BackgroundTransparency = 1,
			Image = props.icon,
			ImageColor3 = theme.mutedTextColor,
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = 1,
			ZIndex = 3,
		}, {
			UIAspectRatioConstraint = React.createElement("UIAspectRatioConstraint", { AspectRatio = 1 }),
		})
	end

	children.Label = React.createElement("TextLabel", {
		Size = UDim2.fromScale(0, LABEL_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = props.text or "",
		TextColor3 = theme.mutedTextColor,
		TextScaled = true,
		TextWrapped = true,
		FontFace = theme.font(),
		LayoutOrder = 2,
		ZIndex = 3,
	}, {
		TextStroke = parts.textStroke(),
		SizeCap = parts.textSizeCap(parts.capFor(props.textSize or props.role, theme.roles.badge, scale)),
	})

	return React.createElement("Frame", {
		Size = props.size or theme.badgeSize,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = theme.glass,
		BackgroundTransparency = theme.glassTransparency,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, children)
end
