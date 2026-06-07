--!strict
-- Flat Checkbox: gray box with an accent fill shown when checked.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local contract = require(ReplicatedStorage.Shared.ui.contract)
local theme = require(script.Parent.theme)

return function(props: contract.CheckboxProps)
	local accent = theme.accent(props.variant)

	return React.createElement("Frame", {
		Size = props.size or UDim2.fromOffset(theme.topBarHeight, theme.topBarHeight),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = theme.surfaceDeep,
		BackgroundTransparency = props.transparency or 0,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, {
		UICorner = React.createElement("UICorner", { CornerRadius = theme.cornerRadius }),
		UIStroke = React.createElement("UIStroke", {
			Thickness = props.strokeThickness or theme.strokeThickness,
			Color = theme.border,
		}),
		Check = React.createElement("Frame", {
			Size = UDim2.fromScale(0.55, 0.55),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Visible = props.checked,
			ZIndex = 2,
		}, {
			UICorner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 3) }),
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
