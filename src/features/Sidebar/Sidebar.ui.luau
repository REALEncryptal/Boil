--!strict
-- Vertical column of icon entries with the label overlaid inside each icon.
-- Renders no chrome itself — the sidebar reads as a floating column over the
-- world. Wrap in a Panel if you want a backdrop.
--
-- Composes `ui.Stack` rather than hand-building a UIPadding + UIListLayout pair,
-- so its spacing comes off the same scale as everything else.
--
-- Pass `items` as an ordered list. Each item is rendered with SidebarItem
-- and inherits the column's `iconSize` / `labelRole` defaults.
--
-- Wire each item's `onClick` to whatever you want (UIShell.useFrame().open(...)
-- is the common case).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ui = require(ReplicatedStorage.Shared.Boil).ui
local Constants = require(script.Parent.Constants)
local SidebarItem = require(script.Parent.SidebarItem)

export type Item = {
	id: string,
	icon: string,
	label: string,
	-- Semantic variant for the entry's gem surface.
	variant: string?,
	-- Corner marker text ("!", "3", "NEW"). Unset → no marker.
	badge: string?,
	badgeVariant: string?,
	onClick: (() -> ())?,
}

type Props = {
	items: { Item },
	iconSize: number?,
	labelRole: string?,
	-- Space step names (or reference pixels).
	spacing: (string | number)?,
	padding: (string | number)?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	zIndex: number?,
}

return function(props: Props)
	local iconSize = props.iconSize or Constants.DEFAULT_ICON_SIZE

	local children: { [string]: any } = {}
	for index, item in ipairs(props.items) do
		children[item.id] = React.createElement(SidebarItem, {
			icon = item.icon,
			label = item.label,
			variant = item.variant,
			badge = item.badge,
			badgeVariant = item.badgeVariant,
			iconSize = iconSize,
			labelRole = props.labelRole or Constants.LABEL_ROLE,
			onClick = item.onClick,
			layoutOrder = index,
		})
	end

	return React.createElement(ui.Stack, {
		gap = props.spacing or Constants.ITEM_SPACING,
		padding = props.padding or Constants.PADDING_STEP,
		horizontalAlignment = Enum.HorizontalAlignment.Center,
		-- The column is exactly one item wide plus its padding. The item's label
		-- runs wider than the button and overflows this box on purpose — it is
		-- centered, so it spills evenly and reads as part of the button.
		size = props.size or UDim2.fromOffset(iconSize, 0),
		-- Height follows the item count unless the caller pinned a size.
		automaticSize = if props.size then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
		position = props.position,
		anchorPoint = props.anchorPoint,
		zIndex = props.zIndex,
	}, children)
end
