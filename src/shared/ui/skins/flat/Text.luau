--!strict
-- Flat Text: a plain label, no drop-shadow/stroke. Honors contract.TextProps;
-- shadow/strokeThickness/foregroundOffset are accepted but ignored.
--
-- Size comes from the type ROLE, resolved against flat's own scale — the same
-- `role = "body"` call site renders at 20 here and 22 under gem, which is the
-- point of putting the scale in the contract.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local contract = require(ReplicatedStorage.Shared.ui.contract)
local tokens = require(ReplicatedStorage.Shared.ui.tokens)
local theme = require(script.Parent.theme)

local function font(weight: Enum.FontWeight?): Font
	return Font.new("rbxasset://fonts/families/SourceSansPro.json", weight or Enum.FontWeight.SemiBold)
end

return function(props: contract.TextProps)
	return React.createElement("TextLabel", {
		Text = props.text,
		TextColor3 = props.color or theme.textColor,
		TextSize = props.textSize
			or tokens.resolveType(theme.type, props.role or theme.roles.default, theme.type.body),
		FontFace = font(props.weight),
		TextWrapped = props.wrap,
		TextTruncate = if props.truncate then Enum.TextTruncate.AtEnd else nil,
		RichText = props.richText,
		LineHeight = props.lineHeight,
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
