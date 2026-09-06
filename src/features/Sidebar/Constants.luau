--!strict
-- Sidebar layout defaults. Override at the call site via props per item or
-- per Sidebar instance; bump these to change the game-wide defaults.
--
-- The look is ported from the Miami HUD's quick-action group (uidev): a gem
-- surface carrying the icon, with the label overlaid across its bottom edge and
-- an optional marker straddling the top-right corner. The previous sidebar was
-- bare art with a random hover tilt and no surface behind it.
--
-- Sizes are REFERENCE pixels (1280x720); the HUD mounts the sidebar inside a
-- `ui.Surface` that scales them to the viewport.
--
-- Anything the design system already names is read from `theme` at render time
-- rather than restated here. Only values genuinely specific to this widget stay
-- as literals — and only the ones the type/space scales can't express.

return {
	-- The item's square, in reference pixels. THE knob for the whole entry's size:
	-- the label box, the badge and its corner nudge are all fractions of this, so
	-- changing it scales the button as one piece rather than leaving the badge
	-- oversized and the label stranded.
	DEFAULT_ICON_SIZE = 96,

	-- Icon inset inside the surface. Runs bigger than the skin default so the art
	-- fills the gem rather than floating in the middle of it.
	ICON_SCALE = 0.86,

	-- The label sits INSIDE the button, not under it, so the skin's hover growth
	-- scales the icon and its label as one piece.
	--
	-- Its box runs wider than the button so a long word ("Inventory") scales up to
	-- the same glyph size as a short one instead of being squeezed by the box.
	LABEL_WIDTH_SCALE = 1.25,
	-- The label's box height, as a fraction of the button's square. Under a
	-- scale-to-fit skin this is what actually sets the glyph size — the type role
	-- below only caps it — so it's the knob to turn for bigger or smaller text.
	LABEL_HEIGHT_SCALE = 0.34,
	-- Type role for the label. Sets the ceiling under a scale-to-fit skin, so it
	-- has to sit above the height above or it clamps the text back down.
	LABEL_ROLE = "title",
	-- Lifts the label off the button's bottom edge. Small, so the label sits low
	-- on the surface the way the reference HUD has it.
	LABEL_LIFT = 4,

	-- Notification marker straddling the top-right corner, nudged back inside the
	-- surface on both axes so it overlaps the corner rather than floating off it.
	--
	-- Both are fractions of the item's square, not fixed pixels — a fixed 44px
	-- marker on a 96px button reads as a different design from the same marker on
	-- a 128px one.
	BADGE_SCALE = 0.34,
	BADGE_NUDGE_SCALE = 0.09,
	BADGE_ROLE = "label",
	-- Palette for the marker when an entry doesn't name one. Semantic, so the
	-- skin picks the paint.
	BADGE_VARIANT = "danger",

	-- Variant for an entry that doesn't name one.
	DEFAULT_VARIANT = "primary",

	-- Vertical gap between sibling items, as a space step.
	ITEM_SPACING = "lg",
	-- Outer padding on each side, as a space step.
	PADDING_STEP = "md",
}
