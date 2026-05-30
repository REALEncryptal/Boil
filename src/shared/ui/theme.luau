--!strict
-- Centralized design tokens for the shared UI primitives. Every visual
-- default in `src/shared/ui/` reads from this module — changing a value
-- here flows out to every consumer (props still override per call site).
--
-- All tokens here are base values. Relationships between tokens (e.g.
-- Window's top content padding being `padding + strokeThickness` to clear
-- the stroke) live at the consumer's render site so they recompute every
-- frame — which means a live theme mutation in the UI Labs Theme story
-- propagates through immediately.
--
-- Add new tokens here rather than inlining magic numbers in components.
-- If you need a value that's *almost* one of these but slightly different,
-- consider whether the existing token should change or whether the
-- difference is component-specific (in which case keep it inline).

local theme = {}

------------------------------------------------------------------------------
-- Strokes
------------------------------------------------------------------------------
-- Gem-style outline used by Button, Panel, TextField, and GemBackground's
-- outer / glow / shine strokes.
theme.strokeThickness = 4
-- Thinner outline used by non-gem text (Sidebar label, Text body when
-- `strokeThickness` is unset) and the inner Text shadow layer.
theme.thinStrokeThickness = 2

------------------------------------------------------------------------------
-- Surface
------------------------------------------------------------------------------
-- Translucent dark glass background transparency (Panel, TextField).
theme.glassTransparency = 0.8

------------------------------------------------------------------------------
-- Padding & spacing (all in pixels)
------------------------------------------------------------------------------
-- Default inner padding used by TextField, Badge (horizontal), and Window
-- content edges.
theme.padding = 10
-- Tight padding used by Badge top/bottom (less vertical breathing room
-- because the icon already provides visual height).
theme.tightPadding = 5
-- Spacing between row items inside a single component (e.g. Badge: gap
-- between icon and text).
theme.itemSpacing = 10
-- Spacing between stacked content rows inside a Window's scroll body.
theme.contentSpacing = 15

------------------------------------------------------------------------------
-- Text
------------------------------------------------------------------------------
-- Standardized size ladder. Prefer these tier tokens at feature call sites
-- over hard-coded numbers — a single edit here re-scales every UI that uses
-- the ladder. Use cases noted in each comment.
theme.textSizeXL = 60      -- Window / badge titles (e.g. "Index" header).
theme.textSizeLarge = 44   -- Section headers, prominent stats.
theme.textSizeRegular = 32 -- Body labels (card rarity / name, captions).
theme.textSizeSmall = 24   -- Sidebar pills, secondary copy.
theme.textSizeXS = 20      -- Tiny metadata (progress-bar counters, footnotes).

-- Component defaults. Mapped to the ladder so existing primitives stay in
-- step: Badge title is XL, Button label is XL, TextField input is Large.
-- The generic Text default also lands on XL. Override per call site when
-- a specific instance needs to deviate from its default tier.
theme.textSize = theme.textSizeXL
theme.buttonTextSize = theme.textSizeXL
theme.badgeTextSize = theme.textSizeXL
theme.inputTextSize = theme.textSizeLarge
-- Inner shadow-layer vertical offset for Text's drop-shadow effect.
theme.textForegroundOffset = -2

------------------------------------------------------------------------------
-- Button
------------------------------------------------------------------------------
theme.buttonSize = UDim2.fromOffset(60, 60)

------------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------------
theme.windowSize = UDim2.fromOffset(797, 595)
theme.topBarHeight = 60
-- Horizontal overflow of the top bar past the panel edge (gem-style accent).
theme.topBarOverflow = 8
-- Window's content top padding is derived as `theme.padding +
-- theme.strokeThickness` at the Window render site so the relationship is
-- live (stroke change → top padding follows). Bottom/left/right just use
-- the base `theme.padding`.

------------------------------------------------------------------------------
-- TextField
------------------------------------------------------------------------------
theme.textFieldSize = UDim2.fromOffset(300, 60)

------------------------------------------------------------------------------
-- GemBackground (noise texture tile)
------------------------------------------------------------------------------
theme.tileSize = UDim2.fromOffset(115, 115)
-- Badge ships a smaller tile so the noise reads at the badge's lower height.
theme.badgeTileSize = UDim2.fromOffset(80, 80)

------------------------------------------------------------------------------
-- Hover / press scale animation (useHoverScale defaults)
------------------------------------------------------------------------------
theme.idleScale = 1
theme.hoverScale = 1.06
theme.pressScale = 0.92
theme.hoverDuration = 0.15
theme.pressDuration = 0.08

return theme
