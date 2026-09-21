--!strict
-- Icon — a bare image.
--
-- Transparent and structure-only like Stack/Row/Grid/Slot, and deliberately NOT
-- skin-resolved: an icon is *content*, not a surface, so there is nothing for a
-- skin to draw. Badge and IconButton wrap an image in a skinned surface; this is
-- the case where you want the image and nothing else — a HUD counter's glyph, a
-- label's leading mark.
--
--   React.createElement(ui.Icon, {
--       image = ui.assets.Icons.bandOfCash,
--       size = UDim2.fromOffset(48, 48),
--   })
--
-- `ScaleType.Fit` is the default so a non-square source letterboxes inside its
-- box instead of stretching. Sizes are REFERENCE pixels like everything else.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

export type IconProps = {
	image: string,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	-- Tints the image. Unset leaves the artwork's own colours.
	color: Color3?,
	transparency: number?,
	scaleType: Enum.ScaleType?,
	-- Locks the box to width/height when set. Unset lets `size` stand alone,
	-- which is what you want inside an auto-sizing layout.
	aspectRatio: number?,
	automaticSize: Enum.AutomaticSize?,
	layoutOrder: number?,
	zIndex: number?,
}

return function(props: IconProps)
	local children: { [string]: any } = {}

	if props.aspectRatio ~= nil then
		children.Aspect = React.createElement("UIAspectRatioConstraint", {
			AspectRatio = props.aspectRatio,
		})
	end

	return React.createElement("ImageLabel", {
		Image = props.image,
		ImageColor3 = props.color,
		ImageTransparency = props.transparency,
		ScaleType = props.scaleType or Enum.ScaleType.Fit,
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		AutomaticSize = props.automaticSize,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, children)
end
