--!strict
-- Flat ProgressBar: gray track + accent fill sized to progress + optional label.
-- No tween (debug skin); the fill snaps to the current value.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local contract = require(ReplicatedStorage.Shared.ui.contract)
local theme = require(script.Parent.theme)

return function(props: contract.ProgressBarProps)
	local progress = math.clamp(props.progress, 0, 1)
	local accent = theme.accent(props.variant or "yellow")
	local showText = props.showText ~= false
	local label = props.text or `{math.floor(progress * 100)}%`

	return React.createElement("Frame", {
		Size = props.size or UDim2.fromOffset(300, 40),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = theme.surfaceDeep,
		BackgroundTransparency = props.transparency or 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, {
		UICorner = React.createElement("UICorner", { CornerRadius = theme.cornerRadius }),
		UIStroke = React.createElement("UIStroke", {
			Thickness = props.strokeThickness or theme.strokeThickness,
			Color = theme.border,
		}),
		Fill = React.createElement("Frame", {
			Size = UDim2.fromScale(progress, 1),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			UICorner = React.createElement("UICorner", { CornerRadius = theme.cornerRadius }),
		}),
		Label = if showText
			then React.createElement("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = label,
				TextColor3 = theme.textColor,
				TextSize = props.textSize or theme.textSize,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
				ZIndex = 3,
			})
			else nil,
	})
end
