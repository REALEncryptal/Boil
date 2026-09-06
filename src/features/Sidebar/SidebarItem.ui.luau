--!strict
-- One sidebar entry: a gem icon button with its label overlaid across the bottom
-- edge, and an optional marker on the top-right corner.
--
-- Ported from the Miami HUD's quick-action button (uidev). Two details carry the
-- look, and both are load-bearing:
--
--   * The label and the marker are mounted INSIDE the button (its children slot)
--     rather than beside it, so the skin's hover growth scales the whole entry as
--     one piece instead of sliding the label out from under a growing icon.
--   * The button is centered in its cell, which is what makes that growth spread
--     from the middle rather than down and to the right.
--
-- Composed entirely from `ui.*`, so it re-skins with the active SkinProvider —
-- the previous version was a raw ImageButton with a bespoke rotation rig and its
-- own hover handling, which no skin could touch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ui = require(ReplicatedStorage.Shared.Boil).ui
local Constants = require(script.Parent.Constants)

type Props = {
	icon: string,
	label: string,
	variant: string?,
	-- Corner marker text ("!", "3", "NEW"). Unset → no marker.
	badge: string?,
	badgeVariant: string?,
	iconSize: number?,
	labelRole: string?,
	onClick: (() -> ())?,
	layoutOrder: number?,
}

return function(props: Props)
	local size = props.iconSize or Constants.DEFAULT_ICON_SIZE

	local content: { [string]: any } = {
		Label = React.createElement(ui.Text, {
			text = props.label,
			role = props.labelRole or Constants.LABEL_ROLE,
			-- Wider than the button on purpose — see Constants.LABEL_WIDTH_SCALE.
			size = UDim2.new(
				Constants.LABEL_WIDTH_SCALE,
				0,
				0,
				size * Constants.LABEL_HEIGHT_SCALE
			),
			position = UDim2.new(0.5, 0, 1, -Constants.LABEL_LIFT),
			anchorPoint = Vector2.new(0.5, 1),
			truncate = true,
			shadow = true,
			zIndex = 5,
		}),
	}

	-- Everything below is a fraction of the item's square, so the entry scales as
	-- one piece. See Constants.DEFAULT_ICON_SIZE.
	local badgeSize = size * Constants.BADGE_SCALE
	local badgeNudge = size * Constants.BADGE_NUDGE_SCALE

	if props.badge then
		-- The glyph is a SIBLING of the marker's surface, not a child: Panel pads
		-- its children clear of its own outline, which on a box this small leaves
		-- an exclamation mark too squeezed to read.
		content.Badge = React.createElement(ui.Slot, {
			name = "Badge",
			size = UDim2.fromOffset(badgeSize, badgeSize),
			position = UDim2.new(1, -badgeNudge, 0, badgeNudge),
			anchorPoint = Vector2.new(0.5, 0.5),
			zIndex = 6,
		}, {
			Surface = React.createElement(ui.Panel, {
				variant = props.badgeVariant or Constants.BADGE_VARIANT,
				size = UDim2.fromScale(1, 1),
			}),
			Mark = React.createElement(ui.Text, {
				text = props.badge,
				role = Constants.BADGE_ROLE,
				size = UDim2.fromScale(1, 1),
				shadow = true,
				zIndex = 3,
			}),
		})
	end

	return React.createElement(ui.Slot, {
		name = "Item",
		size = UDim2.fromOffset(size, size),
		layoutOrder = props.layoutOrder,
	}, {
		Button = React.createElement(ui.IconButton, {
			variant = props.variant or Constants.DEFAULT_VARIANT,
			icon = props.icon,
			iconScale = Constants.ICON_SCALE,
			size = UDim2.fromScale(1, 1),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			onClick = props.onClick,
		}, content),
	})
end
