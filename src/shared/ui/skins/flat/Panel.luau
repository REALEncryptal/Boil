--!strict
-- Flat Panel: a plain gray surface with a thin border. The gem-mode props
-- (variant/hasShine/tileSize) are accepted but the flat skin just tints the
-- border by the variant when one is given.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local contract = require(ReplicatedStorage.Shared.ui.contract)
local tokens = require(ReplicatedStorage.Shared.ui.tokens)
local theme = require(script.Parent.theme)

return function(props: contract.PanelProps)
	local borderColor = if props.variant then theme.accent(props.variant) else theme.border

	-- The caller's inset, plus the border it sits against. Nil (no UIPadding at
	-- all) unless asked for, so a flat Panel stays a bare surface by default.
	local strokeThickness = props.strokeThickness or theme.strokeThickness
	local inset = if props.padding ~= nil
		then tokens.resolveSpace(theme.space, props.padding, 0) + strokeThickness
		else nil

	return React.createElement("Frame", {
		Size = props.size or theme.windowSize,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = theme.surface,
		BackgroundTransparency = props.transparency or 0,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, {
		UICorner = React.createElement("UICorner", { CornerRadius = theme.cornerRadius }),
		UIStroke = React.createElement("UIStroke", {
			Thickness = props.strokeThickness or theme.strokeThickness,
			Color = borderColor,
		}),
		UIPadding = if inset
			then React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, inset),
				PaddingBottom = UDim.new(0, inset),
				PaddingLeft = UDim.new(0, inset),
				PaddingRight = UDim.new(0, inset),
			})
			else nil,
		Content = if props.children
			then React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, props.children)
			else nil,
	})
end
