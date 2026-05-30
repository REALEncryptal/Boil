--!strict
-- Scrollable container with UIListLayout baked in. Vertical by default; flip
-- `direction = "horizontal"` for a horizontal strip. Caller passes children as
-- a named table and sets LayoutOrder on each to control stacking order.
--
-- Canvas size is automatic along the scroll axis (`AutomaticCanvasSize`) and
-- pinned at 0 on the other — the UIListLayout grows the canvas as children mount.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

export type Direction = "vertical" | "horizontal"

type Props = {
	direction: Direction?,
	-- Gap between items (UIListLayout Padding).
	gap: number?,
	-- Inner UIPadding on all sides.
	padding: number?,
	horizontalAlignment: Enum.HorizontalAlignment?,
	verticalAlignment: Enum.VerticalAlignment?,
	-- Stretch children to fill the available horizontal space (UIListLayout
	-- HorizontalFlex = Fill). For a vertical list this fills the cross axis so
	-- items span the scroll list's width; for a horizontal list it distributes
	-- main-axis space evenly across items.
	fillHorizontal: boolean?,
	-- Same as fillHorizontal but for the vertical axis (UIListLayout
	-- VerticalFlex = Fill). For a horizontal list this fills the cross axis so
	-- items span the scroll list's height; for a vertical list it distributes
	-- main-axis space evenly across items.
	fillVertical: boolean?,
	scrollBarThickness: number?,
	scrollBarColor: Color3?,
	scrollBarTransparency: number?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	background: Color3?,
	backgroundTransparency: number?,
	clipsDescendants: boolean?,
	children: { [string]: any }?,
}

local WHITE = Color3.fromRGB(255, 255, 255)

return function(props: Props)
	local direction = props.direction or "vertical"
	local isHorizontal = direction == "horizontal"

	local listChildren: { [string]: any } = {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = if isHorizontal
				then Enum.FillDirection.Horizontal
				else Enum.FillDirection.Vertical,
			Padding = UDim.new(0, props.gap or 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = props.horizontalAlignment or Enum.HorizontalAlignment.Center,
			VerticalAlignment = props.verticalAlignment or Enum.VerticalAlignment.Top,
			HorizontalFlex = if props.fillHorizontal
				then Enum.UIFlexAlignment.Fill
				else Enum.UIFlexAlignment.None,
			VerticalFlex = if props.fillVertical
				then Enum.UIFlexAlignment.Fill
				else Enum.UIFlexAlignment.None,
		}),
	}

	if props.padding then
		listChildren.UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, props.padding),
			PaddingBottom = UDim.new(0, props.padding),
			PaddingLeft = UDim.new(0, props.padding),
			PaddingRight = UDim.new(0, props.padding),
		})
	end

	if props.children then
		for k, v in pairs(props.children) do
			listChildren[k] = v
		end
	end

	return React.createElement("ScrollingFrame", {
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = props.background or WHITE,
		BackgroundTransparency = if props.backgroundTransparency == nil
			then 1
			else props.backgroundTransparency,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		ClipsDescendants = if props.clipsDescendants == nil then true else props.clipsDescendants,
		AutomaticCanvasSize = if isHorizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = if isHorizontal
			then Enum.ScrollingDirection.X
			else Enum.ScrollingDirection.Y,
		ScrollBarThickness = props.scrollBarThickness or 2,
		ScrollBarImageColor3 = props.scrollBarColor or WHITE,
		ScrollBarImageTransparency = if props.scrollBarTransparency == nil
			then 0.5
			else props.scrollBarTransparency,
	}, listChildren)
end
