--!strict
-- Slop Text: a scale-to-fit FredokaOne label with a dark outline on the glyphs.
--
-- The outline *is* this skin's version of gem's drop-shadow, so it's drawn by
-- default; pass `shadow = false` for a bare label. `strokeColor` (or the older
-- `shadowColor`) recolors the outline and `strokeThickness` resizes it.
-- `gradient` paints the glyphs. `foregroundOffset` is gem-specific (it offsets a
-- second shadow layer) and is ignored here.
--
-- Every label here is already TextScaled, capped at the role's ceiling. `scaled`
-- asks for the BOX to set the size outright — a BillboardGui sized in studs,
-- where a pixel ceiling would pin the glyphs at one size on screen no matter
-- how close the tag is — so under it the cap comes off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Boil = require(ReplicatedStorage.Shared.Boil)
local parts = require(script.Parent.parts)
local theme = require(script.Parent.theme)

return function(props: Boil.TextProps)
	-- Caps are enforced in absolute pixels, so they need the viewport scale to
	-- mean reference pixels. See parts.capFor.
	local scale = Boil.ui.useScale()
	local showStroke = props.shadow ~= false

	-- `textSize` still wins when given; otherwise the role sets the ceiling.
	local children: { [string]: any } = {
		SizeCap = if props.scaled
			then nil
			else parts.textSizeCap(parts.capFor(props.textSize or props.role, theme.roles.default, scale)),
	}

	if showStroke then
		children.TextStroke = React.createElement("UIStroke", {
			-- `strokeColor` is the contract's name for this; `shadowColor` stays
			-- honoured because this skin has always spelled it that way.
			Color = props.strokeColor or props.shadowColor or Color3.fromRGB(0, 0, 0),
			Thickness = props.strokeThickness or theme.textStrokeThickness,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			ZIndex = 2,
		})
	end

	if props.gradient then
		children.TextGradient = React.createElement("UIGradient", {
			Color = props.gradient,
			Rotation = props.gradientRotation or 0,
		})
	end

	return React.createElement("TextLabel", {
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		Text = props.text,
		TextColor3 = props.color or theme.textColor,
		TextScaled = true,
		-- `wrap` defaults on here: TextScaled without wrapping shrinks a long
		-- label to nothing rather than breaking the line.
		TextWrapped = if props.wrap == nil then true else props.wrap,
		TextTruncate = if props.truncate then Enum.TextTruncate.AtEnd else nil,
		RichText = props.richText,
		LineHeight = props.lineHeight,
		FontFace = theme.font(props.weight),
		TextXAlignment = props.xAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.yAlignment or Enum.TextYAlignment.Center,
		AutomaticSize = props.automaticSize,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, children)
end
