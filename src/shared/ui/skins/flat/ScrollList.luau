--!strict
-- Flat ScrollList: a transparent ScrollingFrame + UIListLayout. Layout-only, so
-- it behaves like the gem ScrollList; only the scrollbar/background defaults are
-- plainer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local contract = require(ReplicatedStorage.Shared.ui.contract)
local theme = require(script.Parent.theme)

return function(props: contract.ScrollListProps)
	local direction = props.direction or "vertical"
	local horizontal = direction == "horizontal"

	local children: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
			Padding = UDim.new(0, props.gap or theme.itemSpacing),
			HorizontalAlignment = props.horizontalAlignment or Enum.HorizontalAlignment.Center,
			VerticalAlignment = props.verticalAlignment or Enum.VerticalAlignment.Top,
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

	return React.createElement("ScrollingFrame", {
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = props.background or theme.surface,
		BackgroundTransparency = props.backgroundTransparency or 1,
		BorderSizePixel = 0,
		ClipsDescendants = if props.clipsDescendants ~= nil then props.clipsDescendants else true,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		ScrollBarThickness = props.scrollBarThickness or 6,
		ScrollBarImageColor3 = props.scrollBarColor or theme.border,
		ScrollBarImageTransparency = props.scrollBarTransparency or 0.4,
	}, children)
end
