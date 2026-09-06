--!strict
-- Slop Checkbox: a square glass box, forced 1:1, with an inset fill shown when
-- checked. The fill carries the variant gradient, so a green checkbox reads as
-- the same material as a green button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Boil = require(ReplicatedStorage.Shared.Boil)
local parts = require(script.Parent.parts)
local theme = require(script.Parent.theme)

-- Fill size as a fraction of the box, matching the template's proportion (a
-- 15px inset on its 66px box). Proportional rather than a fixed pixel inset
-- because a checkbox is small and its size varies: a flat inset that reads fine
-- at 66px leaves almost nothing but stroke at 56px.
local FILL_SCALE = 0.55

return function(props: Boil.CheckboxProps)
	local variant = theme.variant(props.variant)
	local strokeThickness = props.strokeThickness or theme.strokeThickness
	-- `padding` (contract) is a pixel inset; with none given, scale instead.
	local fillSize = if props.padding
		then UDim2.new(1, -props.padding * 2, 1, -props.padding * 2)
		else UDim2.fromScale(FILL_SCALE, FILL_SCALE)

	return React.createElement("Frame", {
		Size = props.size or theme.checkboxSize,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = theme.glass,
		BackgroundTransparency = props.transparency or theme.glassTransparency,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, {
		UIAspectRatioConstraint = React.createElement("UIAspectRatioConstraint", { AspectRatio = 1 }),
		-- Opts out of a parent list's cross-axis stretch (Window's body sets
		-- HorizontalFlex = Fill). Without it the aspect constraint turns the
		-- stretched width into a giant square. FlexMode is the wrong lever here
		-- — it governs the main axis; ItemLineAlignment governs the cross one.
		UIFlexItem = React.createElement("UIFlexItem", {
			ItemLineAlignment = Enum.ItemLineAlignment.Center,
		}),
		InnerGlow = parts.innerGlow(),
		Outline = parts.outline(strokeThickness),

		Fill = React.createElement("Frame", {
			Size = fillSize,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = theme.fillBase,
			BorderSizePixel = 0,
			Visible = props.checked,
			ZIndex = 3,
		}, {
			UIGradient = parts.fill(variant),
			Outline = parts.outline(),
		}),

		Trigger = React.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = 10,
			[React.Event.Activated] = function()
				if props.onToggle then
					props.onToggle(not props.checked)
				end
			end,
		}),
	})
end
