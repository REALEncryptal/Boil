--!strict
-- General text primitive using the gem display font.
--
-- Always renders a Miter UIStroke (thickness defaults to `theme.thinStrokeThickness`).
-- The stroke is independent of the shadow effect — pass `strokeThickness = 0`
-- to omit it.
--
-- `shadow = true` opts into the two-layer drop-shadow effect used by the gem
-- primitives (outer TextLabel paints `shadowColor`, inner `FgTextLabel` paints
-- `color` offset upward by `foregroundOffset` pixels, both with the same stroke).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Assets = require(script.Parent.assets)
local theme = require(script.Parent.theme)

type Props = {
	text: string,
	textSize: number?,
	weight: Enum.FontWeight?,
	color: Color3?,
	xAlignment: Enum.TextXAlignment?,
	yAlignment: Enum.TextYAlignment?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	automaticSize: Enum.AutomaticSize?,
	-- Shadow (drop-shadow) feature.
	shadow: boolean?,
	shadowColor: Color3?,
	strokeThickness: number?,
	foregroundOffset: number?,
}

local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(0, 0, 0)

return function(props: Props)
	local textSize = props.textSize or theme.textSize
	local font = Font.new(
		Assets.DISPLAY_FONT_ID,
		props.weight or Enum.FontWeight.Bold,
		Enum.FontStyle.Normal
	)
	local xAlign = props.xAlignment or Enum.TextXAlignment.Center
	local yAlign = props.yAlignment or Enum.TextYAlignment.Center
	local color = props.color or WHITE
	local strokeThickness = props.strokeThickness or theme.thinStrokeThickness

	if not props.shadow then
		local children: { [string]: any } = {}
		if strokeThickness > 0 then
			children.UIStroke = React.createElement("UIStroke", {
				Thickness = strokeThickness,
				LineJoinMode = Enum.LineJoinMode.Miter,
			})
		end
		return React.createElement("TextLabel", {
			Size = props.size or UDim2.fromScale(1, 1),
			Position = props.position,
			AnchorPoint = props.anchorPoint,
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = props.text,
			TextColor3 = color,
			TextSize = textSize,
			FontFace = font,
			TextXAlignment = xAlign,
			TextYAlignment = yAlign,
			LayoutOrder = props.layoutOrder,
			ZIndex = props.zIndex,
			AutomaticSize = props.automaticSize,
		}, children)
	end

	local shadowColor = props.shadowColor or BLACK

	return React.createElement("TextLabel", {
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = props.text,
		TextColor3 = shadowColor,
		TextSize = textSize,
		FontFace = font,
		TextXAlignment = xAlign,
		TextYAlignment = yAlign,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		AutomaticSize = props.automaticSize,
	}, {
		UIStroke = React.createElement("UIStroke", {
			Thickness = strokeThickness,
			LineJoinMode = Enum.LineJoinMode.Miter,
		}),

		FgTextLabel = React.createElement("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(0, props.foregroundOffset or theme.textForegroundOffset),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = props.text,
			TextColor3 = color,
			TextSize = textSize,
			FontFace = font,
			TextXAlignment = xAlign,
			TextYAlignment = yAlign,
		}, {
			UIStroke = React.createElement("UIStroke", {
				Thickness = strokeThickness,
				LineJoinMode = Enum.LineJoinMode.Miter,
			}),
		}),
	})
end
