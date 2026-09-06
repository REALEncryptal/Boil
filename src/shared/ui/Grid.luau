--!strict
-- Grid — a transparent, structure-only grid layout. Wraps a UIGridLayout with no
-- visuals. Children are mounted as DIRECT children of the grid frame: UIGridLayout
-- only sizes direct children, so don't wrap cells in another container, and use a
-- child UIScale (not a Size tween) if you need to animate a cell — the layout
-- reasserts Size every pass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local SkinProvider = require(script.Parent.SkinProvider)
local tokens = require(script.Parent.tokens)

export type GridProps = {
	cellSize: UDim2?,
	-- Gap between cells. A `theme.space` step name applies to both axes; pass a
	-- UDim2 only when the horizontal and vertical gaps genuinely differ.
	gap: (string | number)?,
	cellPadding: UDim2?,
	fillDirection: Enum.FillDirection?,
	fillDirectionMaxCells: number?,
	horizontalAlignment: Enum.HorizontalAlignment?,
	verticalAlignment: Enum.VerticalAlignment?,
	startCorner: Enum.StartCorner?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	automaticSize: Enum.AutomaticSize?,
	layoutOrder: number?,
	zIndex: number?,
	children: { [string]: any }?,
}

return function(props: GridProps)
	local skin = SkinProvider.useSkin()
	local space = skin.theme.space
	local gap = tokens.resolveSpace(space, props.gap, space.md)

	local children: { [string]: any } = {
		Layout = React.createElement("UIGridLayout", {
			CellSize = props.cellSize or UDim2.fromOffset(100, 100),
			CellPadding = props.cellPadding or UDim2.fromOffset(gap, gap),
			FillDirection = props.fillDirection or Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = props.fillDirectionMaxCells or 0,
			HorizontalAlignment = props.horizontalAlignment or Enum.HorizontalAlignment.Center,
			VerticalAlignment = props.verticalAlignment or Enum.VerticalAlignment.Top,
			StartCorner = props.startCorner or Enum.StartCorner.TopLeft,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
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
