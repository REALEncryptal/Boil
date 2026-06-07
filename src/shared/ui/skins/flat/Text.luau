--!strict
-- Flat Text: a plain label, no drop-shadow/stroke. Honors contract.TextProps;
-- shadow/strokeThickness/foregroundOffset are accepted but ignored.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local contract = require(ReplicatedStorage.Shared.ui.contract)
local theme = require(script.Parent.theme)

local function font(weight: Enum.FontWeight?): Font
	return Font.new("rbxasset://fonts/families/SourceSansPro.json", weight or Enum.FontWeight.SemiBold)
end

return function(props: contract.TextProps)
	return React.createElement("TextLabel", {
		Text = props.text,
		TextColor3 = props.color or theme.textColor,
		TextSize = props.textSize or theme.textSize,
		FontFace = font(props.weight),
		BackgroundTransparency = 1,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		AutomaticSize = props.automaticSize,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		TextXAlignment = props.xAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.yAlignment or Enum.TextYAlignment.Center,
	})
end
