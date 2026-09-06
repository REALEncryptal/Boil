--!strict
-- Slop Icon: the image in the same cool off-white the skin tints every other
-- icon with (Badge's leading glyph, IconButton's face, the Window icon).
--
-- No outline: this skin's dark edge is a UIStroke, which traces a frame's border
-- rather than an image's alpha, so there's nothing here for it to draw around.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Boil = require(ReplicatedStorage.Shared.Boil)
local theme = require(script.Parent.theme)

return function(props: Boil.IconProps)
	return React.createElement("ImageLabel", {
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = props.image,
		ImageColor3 = props.color or theme.mutedTextColor,
		ImageTransparency = props.transparency,
		ScaleType = props.scaleType or Enum.ScaleType.Fit,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	})
end
