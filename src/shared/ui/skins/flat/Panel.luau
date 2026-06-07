--!strict
-- Flat Panel: a plain gray surface with a thin border. The gem-mode props
-- (variant/hasShine/tileSize) are accepted but the flat skin just tints the
-- border by the variant when one is given.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local contract = require(ReplicatedStorage.Shared.ui.contract)
local theme = require(script.Parent.theme)

return function(props: contract.PanelProps)
	local borderColor = if props.variant then theme.accent(props.variant) else theme.border

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
		Content = if props.children
			then React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, props.children)
			else nil,
	})
end
