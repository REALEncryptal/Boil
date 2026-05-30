--!strict
-- Vertical column of icon entries with the label overlaid inside each icon.
-- Renders no chrome itself — the sidebar reads as a floating column over the
-- world. Wrap in a Panel if you want a backdrop.
--
-- Pass `items` as an ordered list. Each item is rendered with SidebarItem
-- and inherits the column's `iconSize` / `labelSize` defaults.
--
-- Wire each item's `onClick` to whatever you want (UIShell.useFrame().open(...)
-- is the common case).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Constants = require(script.Parent.Constants)
local SidebarItem = require(script.Parent.SidebarItem)

export type Item = {
	id: string,
	icon: string,
	label: string,
	onClick: (() -> ())?,
}

type Props = {
	items: { Item },
	iconSize: number?,
	labelSize: number?,
	spacing: number?,
	padding: number?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	zIndex: number?,
}

return function(props: Props)
	local iconSize = props.iconSize or Constants.DEFAULT_ICON_SIZE
	local labelSize = props.labelSize or Constants.DEFAULT_LABEL_SIZE
	local spacing = props.spacing or Constants.ITEM_SPACING
	local padding = props.padding or Constants.PADDING

	local children: { [string]: any } = {
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, padding),
			PaddingBottom = UDim.new(0, padding),
			PaddingLeft = UDim.new(0, padding),
			PaddingRight = UDim.new(0, padding),
		}),
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, spacing),
		}),
	}

	for index, item in ipairs(props.items) do
		children[item.id] = React.createElement(SidebarItem, {
			icon = item.icon,
			label = item.label,
			iconSize = iconSize,
			labelSize = labelSize,
			onClick = item.onClick,
			layoutOrder = index,
		})
	end

	return React.createElement("Frame", {
		Size = props.size or UDim2.fromOffset(iconSize + padding * 2, 0),
		AutomaticSize = if props.size then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		Position = props.position or UDim2.fromScale(0, 0.5),
		AnchorPoint = props.anchorPoint or Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
	}, children)
end
