--!strict
-- Stack — a transparent, structure-only linear layout. Wraps a UIListLayout (+
-- optional UIPadding) with no visuals of its own: no background, no stroke. It
-- arranges children along one axis; skin and content live in the children.
--
-- Spacing is named, not numbered:
--
--   React.createElement(ui.Stack, { gap = "md", padding = "lg" }, children)
--
-- `gap` and `padding` take a step from the active skin's `theme.space` — that's
-- what keeps adjacent components on one rhythm instead of each call site picking
-- 12 or 14 or 16 and landing a few pixels off its neighbour. A raw number still
-- works as an escape hatch for a value the scale genuinely can't express.
--
-- Stack is vertical by default; `Row` is the horizontal wrapper. This is the
-- default surface for arranging a screen in code (seam #2); escalate to a
-- Studio-extract skeleton only when arrangement is painful here (see
-- docs/game/layout-surfaces.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local SkinProvider = require(script.Parent.SkinProvider)
local tokens = require(script.Parent.tokens)

export type Direction = "vertical" | "horizontal"

export type StackProps = {
	direction: Direction?, -- default "vertical" (Row forces "horizontal")
	-- Space between children. A `theme.space` step name, or reference pixels.
	gap: (string | number)?,
	-- Inset on all four sides. Same units.
	padding: (string | number)?,
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
	local skin = SkinProvider.useSkin()
	local space = skin.theme.space
	local horizontal = props.direction == "horizontal"

	-- Defaults to one step rather than zero: a stack of items almost always
	-- wants breathing room, and making the common case free is what stops call
	-- sites from inventing their own number.
	local gap = tokens.resolveSpace(space, props.gap, space.md)
	local padding = if props.padding ~= nil then tokens.resolveSpace(space, props.padding, 0) else nil

	local children: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
			Padding = UDim.new(0, gap),
			HorizontalAlignment = props.horizontalAlignment or Enum.HorizontalAlignment.Center,
			VerticalAlignment = props.verticalAlignment
				or (if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top),
			HorizontalFlex = if props.fillHorizontal then Enum.UIFlexAlignment.Fill else Enum.UIFlexAlignment.None,
			VerticalFlex = if props.fillVertical then Enum.UIFlexAlignment.Fill else Enum.UIFlexAlignment.None,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	if padding then
		children.Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, padding),
			PaddingBottom = UDim.new(0, padding),
			PaddingLeft = UDim.new(0, padding),
			PaddingRight = UDim.new(0, padding),
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
