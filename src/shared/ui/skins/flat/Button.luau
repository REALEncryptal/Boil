--!strict
-- Flat Button: gray box, accent-colored border (from the variant), invisible
-- trigger on top. Reuses the shared useHoverScale hook for press feedback so
-- behavior matches the gem skin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local contract = require(ReplicatedStorage.Shared.ui.contract)
local tokens = require(ReplicatedStorage.Shared.ui.tokens)
local useHoverScale = require(ReplicatedStorage.Shared.ui.useHoverScale)
local theme = require(script.Parent.theme)

-- Same dim treatment as the gem skin: dark wash below the trigger.
local DISABLED_OVERLAY_TRANSPARENCY = 0.45

return function(props: contract.ButtonProps)
	local accent = theme.accent(props.variant)
	local disabled = props.disabled == true
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
		MinSize = React.createElement("UISizeConstraint", {
			MinSize = Vector2.new(tokens.minTouchTarget, tokens.minTouchTarget),
		}),
		UIScale = React.createElement("UIScale", { Scale = 1, ref = hover.scaleRef }),
		UICorner = React.createElement("UICorner", { CornerRadius = theme.cornerRadius }),
		UIStroke = React.createElement("UIStroke", { Thickness = theme.strokeThickness, Color = accent }),

		Label = React.createElement("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = props.text or "",
			TextColor3 = theme.textColor,
			TextSize = props.textSize
				or tokens.resolveType(theme.type, props.role or theme.roles.button, theme.type.body),
			TextTruncate = Enum.TextTruncate.AtEnd,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				props.textWeight or Enum.FontWeight.Bold
			),
			ZIndex = 2,
		}),

		Trigger = React.createElement(
			"TextButton",
			(function()
				local trigger: { [any]: any } = {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 10,
				}
				for key, value in hover.events(props.onClick, disabled) do
					trigger[key] = value
				end
				return trigger
			end)()
		),

		DisabledOverlay = if disabled
			then React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = DISABLED_OVERLAY_TRANSPARENCY,
				BorderSizePixel = 0,
				ZIndex = 9,
			}, {
				UICorner = React.createElement("UICorner", { CornerRadius = theme.cornerRadius }),
			})
			else nil,
	})
end
