--!strict
-- Flat Badge: a gray pill with an accent border, optional leading icon + text.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local contract = require(ReplicatedStorage.Shared.ui.contract)
local theme = require(script.Parent.theme)

return function(props: contract.BadgeProps)
	local accent = theme.accent(props.variant)

	local inner: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, theme.itemSpacing),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, theme.padding),
			PaddingRight = UDim.new(0, theme.padding),
			PaddingTop = UDim.new(0, theme.tightPadding),
			PaddingBottom = UDim.new(0, theme.tightPadding),
		}),
	}

	if props.icon then
		inner.Icon = React.createElement("ImageLabel", {
			Size = UDim2.fromOffset(theme.textSize, theme.textSize),
			BackgroundTransparency = 1,
			Image = props.icon,
			ImageColor3 = theme.textColor,
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = 1,
		})
	end

	inner.Text = React.createElement("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		Text = props.text or "",
		TextColor3 = theme.textColor,
		TextSize = props.textSize or theme.textSize,
		FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
		LayoutOrder = 2,
	})

	return React.createElement("Frame", {
		Size = props.size or UDim2.fromOffset(0, theme.topBarHeight),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = theme.surfaceAlt,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, {
		UICorner = React.createElement("UICorner", { CornerRadius = theme.cornerRadius }),
		UIStroke = React.createElement("UIStroke", { Thickness = theme.strokeThickness, Color = accent }),
		Inner = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
		}, inner),
	})
end
