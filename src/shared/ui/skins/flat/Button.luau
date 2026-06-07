--!strict
-- Flat Button: gray box, accent-colored border (from the variant), invisible
-- trigger on top. Reuses the shared useHoverScale hook for press feedback so
-- behavior matches the gem skin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local contract = require(ReplicatedStorage.Shared.ui.contract)
local useHoverScale = require(ReplicatedStorage.Shared.ui.useHoverScale)
local theme = require(script.Parent.theme)

return function(props: contract.ButtonProps)
	local accent = theme.accent(props.variant)
	local hover = useHoverScale()

	return React.createElement("Frame", {
		Size = props.size or theme.buttonSize,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = theme.surface,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex or 2,
	}, {
		UIScale = React.createElement("UIScale", { Scale = 1, ref = hover.scaleRef }),
		UICorner = React.createElement("UICorner", { CornerRadius = theme.cornerRadius }),
		UIStroke = React.createElement("UIStroke", { Thickness = theme.strokeThickness, Color = accent }),

		Label = React.createElement("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = props.text or "",
			TextColor3 = theme.textColor,
			TextSize = props.textSize or theme.textSize,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				props.textWeight or Enum.FontWeight.Bold
			),
			ZIndex = 2,
		}),

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
	})
end
