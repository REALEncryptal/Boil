--!strict
-- Sidebar layout defaults. Override at the call site via props per item or
-- per Sidebar instance; bump these to change the framework-wide defaults.
--
-- Shared visual tokens (e.g. the label stroke thickness) come from
-- `Shared.ui.theme` so they track the rest of the gem-styled UI.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local theme = require(ReplicatedStorage.Shared.Boil).ui.theme

return {
	-- SidebarItem square size (pixels). The whole item is one icon — the
	-- label rides on top of it, anchored to the bottom edge.
	DEFAULT_ICON_SIZE = 72,
	-- Label TextSize (pixels).
	DEFAULT_LABEL_SIZE = 26,
	-- Miter UIStroke thickness on the label. Matches the gem text outline
	-- minus the offset shadow layer — readable on top of any icon.
	LABEL_STROKE_THICKNESS = theme.thinStrokeThickness,
	-- Distance (pixels) from the bottom edge of the icon to the baseline of
	-- the label. Keeps the label inside the icon's visual bounds.
	LABEL_BOTTOM_INSET = 6,
	-- Rotation tilt picked at random on hover-enter (degrees). Magnitude
	-- comes from [MIN, MAX]; sign is 50/50. Set MAX = 0 to disable.
	HOVER_TILT_MIN_DEG = 4,
	HOVER_TILT_MAX_DEG = 12,
	-- Vertical gap between sibling SidebarItems in the column (pixels).
	ITEM_SPACING = 12,
	-- Default outer Sidebar padding on each side (pixels).
	PADDING = 12,
}
