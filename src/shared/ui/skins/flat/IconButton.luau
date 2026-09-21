--!strict
-- Flat IconButton: gray box, accent border, centered icon, invisible trigger.
-- `surface = "glass"` sinks the box to the recessed grey this skin uses for a
-- surface that should read as *behind* the content rather than on top of it,
-- with the neutral border rather than the variant accent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local contract = require(ReplicatedStorage.Shared.ui.contract)
local useHoverScale = require(ReplicatedStorage.Shared.ui.useHoverScale)
local theme = require(script.Parent.theme)

return function(props: contract.IconButtonProps)
	local glass = props.surface == "glass"
	local accent = if glass then theme.border else theme.accent(props.variant)
	local background = if glass then theme.surfaceDeep else theme.surface
	-- Caller content rides inside the frame, so the hover scale carries it.
	local content = if props.children
		then React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, props.children)
		else nil
	local hover = useHoverScale()
	local scale = props.iconScale or 0.6

	return React.createElement("Frame", {
		Size = props.size or theme.buttonSize,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = background,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex or 2,
	}, {
		UIScale = React.createElement("UIScale", { Scale = 1, ref = hover.scaleRef }),
		UICorner = React.createElement("UICorner", { CornerRadius = theme.cornerRadius }),
		UIStroke = React.createElement("UIStroke", { Thickness = theme.strokeThickness, Color = accent }),

		Icon = if props.icon
			then React.createElement("ImageLabel", {
				Size = UDim2.fromScale(scale, scale),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = props.icon,
				ImageColor3 = props.iconColor or theme.textColor,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 2,
			})
			else nil,

		Content = content,

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
