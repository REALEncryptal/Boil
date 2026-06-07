--!strict
-- Stack — a transparent, structure-only linear layout. Wraps a UIListLayout (+
-- optional UIPadding) with no visuals: no background, no stroke. It arranges its
-- children along one axis; everything else (skin, content) lives in the children.
--
-- Stack is vertical by default; `Row` is the horizontal convenience wrapper. Tune
-- gap / padding / alignment / flex live in the Stack story. This is the default
-- surface for arranging a screen in code (seam #2); escalate to a Studio-extract
-- skeleton only when arrangement is painful here (see docs/game/layout-surfaces.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

export type Direction = "vertical" | "horizontal"

export type StackProps = {
	direction: Direction?, -- default "vertical" (Row forces "horizontal")
	gap: number?,
	padding: number?,
	horizontalAlignment: Enum.HorizontalAlignment?,
	verticalAlignment: Enum.VerticalAlignment?,
	-- UIFlexAlignment.Fill on the named axis (stretch children to fill).
	fillHorizontal: boolean?,
	fillVertical: boolean?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	automaticSize: Enum.AutomaticSize?,
	layoutOrder: number?,
	zIndex: number?,
	children: { [string]: any }?,
}

return function(props: StackProps)
	local horizontal = props.direction == "horizontal"

	local children: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
			Padding = UDim.new(0, props.gap or 0),
			HorizontalAlignment = props.horizontalAlignment or Enum.HorizontalAlignment.Center,
			VerticalAlignment = props.verticalAlignment
				or (if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top),
			HorizontalFlex = if props.fillHorizontal then Enum.UIFlexAlignment.Fill else Enum.UIFlexAlignment.None,
			VerticalFlex = if props.fillVertical then Enum.UIFlexAlignment.Fill else Enum.UIFlexAlignment.None,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	if props.padding then
		children.Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, props.padding),
			PaddingBottom = UDim.new(0, props.padding),
			PaddingLeft = UDim.new(0, props.padding),
			PaddingRight = UDim.new(0, props.padding),
		})
	end
	if props.children then
		for key, child in props.children do
			children[key] = child
		end
	end

	return React.createElement("Frame", {
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		AutomaticSize = props.automaticSize,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, children)
end
