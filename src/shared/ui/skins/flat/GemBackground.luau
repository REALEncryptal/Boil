--!strict
-- Flat GemBackground: a plain stand-in so gem-composing code that reaches for
-- ui.GemBackground still renders something under the flat skin. It samples the
-- first color of the supplied fill gradient as a flat fill — no noise, gradient,
-- or shine.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local contract = require(ReplicatedStorage.Shared.ui.contract)
local theme = require(script.Parent.theme)

return function(props: contract.GemBackgroundProps)
	local keypoints = props.fillGradient.Keypoints
	local fill = if #keypoints > 0 then keypoints[1].Value else theme.surface

	return React.createElement("Frame", {
		Size = props.size or UDim2.fromScale(1, 1),
		BackgroundColor3 = fill,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex or 1,
	}, {
		UICorner = React.createElement("UICorner", { CornerRadius = theme.cornerRadius }),
		UIStroke = React.createElement("UIStroke", { Thickness = theme.strokeThickness, Color = theme.border }),
	})
end
