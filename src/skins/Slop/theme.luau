--!strict
-- Slop skin tokens, extracted from the Studio template
-- (StarterGui.WhiteSkinTemplate._scaffold).
--
-- The look, in one line: translucent black glass surfaces, a heavy dark outline,
-- a soft white inner glow, square corners, FredokaOne, and per-variant gradient
-- fills on the "gem" surfaces (Button, IconButton, GemBackground, ProgressBar
-- fill, Checkbox fill, Window close button).
--
-- Two surface families run through the whole skin:
--
--   glass — translucent black + black outline + inner glow. Panel, Badge,
--           TextField, Checkbox box, ProgressBar track, ScrollList, Window body.
--   gem   — opaque variant gradient + outline tinted by the same gradient +
--           a tighter inner glow. Button, IconButton, GemBackground, fills.
--
-- Tokens live under the skin, but since contract v2 two of them are REQUIRED and
-- their keys are fixed: `type` (six roles) and `space` (six steps). Call sites
-- name those — `role = "body"`, `gap = "md"` — so a screen written against gem
-- renders correctly here without knowing either skin's numbers.
--
-- Sizes are REFERENCE pixels (1280x720); `ui.Surface` scales them to the viewport.
-- The template's absolute pixel sizes below are read as reference pixels, which is
-- why they need no conversion.

local theme = {}

------------------------------------------------------------------------------
-- Type
------------------------------------------------------------------------------
theme.fontFamily = "rbxasset://fonts/families/FredokaOne.json"

function theme.font(weight: Enum.FontWeight?): Font
	return Font.new(theme.fontFamily, weight or Enum.FontWeight.Regular)
end

------------------------------------------------------------------------------
-- Strokes
------------------------------------------------------------------------------
-- The heavy outline every surface carries.
theme.strokeThickness = 6
-- Outline drawn on text glyphs sitting on glass (Text, Badge label, …).
theme.textStrokeThickness = 4
-- Slightly heavier outline for text on a gem surface, where it also carries the
-- variant gradient. The template used 5 on the Button label and 6 on the close
-- button's; normalized to one token.
theme.gemTextStrokeThickness = 5
-- Soft white inner glow, in three sizes: glass surfaces, gem surfaces, and the
-- smaller fills (ProgressBar's bar) that can't carry the full 15px.
theme.innerGlowThickness = 15
theme.gemInnerGlowThickness = 12
theme.fillInnerGlowThickness = 9
theme.innerGlowTransparency = 0.89
-- Outline color on gem surfaces. The gradient child tints it, so this reads as
-- a darkened edge of the variant rather than pure black.
--
-- The template used 50,50,50 on Button/IconButton and 70,70,70 on
-- GemBackground/CloseButton; normalized to one token here.
theme.outlineColor = Color3.fromRGB(50, 50, 50)

------------------------------------------------------------------------------
-- Surfaces
------------------------------------------------------------------------------
theme.glass = Color3.fromRGB(0, 0, 0)
theme.glassTransparency = 0.5
-- TextField sits on a lighter gray than the other glass surfaces so the input
-- reads as recessed rather than as another panel.
theme.inputSurface = Color3.fromRGB(61, 61, 61)
-- Base color under a gradient fill. White keeps the gradient's own colors true.
theme.fillBase = Color3.fromRGB(255, 255, 255)
-- ProgressBar's bar sits on a faintly cool white instead of pure white.
theme.progressFillBase = Color3.fromRGB(235, 235, 255)

------------------------------------------------------------------------------
-- Text
------------------------------------------------------------------------------
theme.textColor = Color3.fromRGB(255, 255, 255)
-- Slightly cool off-white for icons and secondary labels (Badge, Window icon).
theme.mutedTextColor = Color3.fromRGB(227, 227, 255)
theme.placeholderColor = Color3.fromRGB(177, 177, 190)

-- Every label in this skin is TextScaled: text fills the box its component gives
-- it, and the box is sized from the size tokens below. Chunky text is the look,
-- and the template's own TextSize values were inert (TextScaled ignores TextSize).
--
-- So this skin reads the type scale as a **ceiling**, not a size. `role = "body"`
-- caps the scale-up at `theme.type.body`; the label still shrinks to fit a small
-- box. That keeps the chunky look while making roles mean the same thing they do
-- in every other skin — a caption never out-shouts a title. Mounted as a
-- UITextSizeConstraint; see parts.textSizeCap.
--
-- The caps sit a little above gem's ladder because a scaled label wants headroom.
theme.type = {
	display = 56,
	title = 42,
	heading = 32,
	body = 25,
	label = 20,
	caption = 16,
}

-- Hover/press feel. Shared across skins so the kit behaves like one thing even
-- where the surfaces differ; required by the contract.
theme.motion = {
	idleScale = 1,
	hoverScale = 1.05,
	pressScale = 0.94,
	hoverDuration = 0.15,
	pressDuration = 0.08,
}

-- Which role each primitive caps at when the call site names none.
theme.roles = {
	default = "body",
	button = "heading",
	badge = "body",
	input = "body",
	windowTitle = "title",
}

------------------------------------------------------------------------------
-- Padding & spacing (reference pixels)
------------------------------------------------------------------------------
-- The six required steps. `lg` is this skin's own 15px surface padding, so the
-- scale is built around the template's rhythm rather than imposed on it.
theme.space = {
	xs = 4,
	sm = 6,
	md = 10,
	lg = 15,
	xl = 24,
	xxl = 36,
}

theme.padding = 15
theme.inputPadding = 12
theme.tightPadding = 6
-- Gap between a Badge's icon and its label.
theme.itemSpacing = 6
-- ScrollList's own inset and inter-item gap.
theme.listPadding = 10
theme.listGap = 8
-- Vertical gap between rows in a Window body.
theme.contentSpacing = 12

------------------------------------------------------------------------------
-- Sizes (from the template's absolute pixel sizes)
------------------------------------------------------------------------------
theme.buttonSize = UDim2.fromOffset(335, 88)
theme.iconButtonSize = UDim2.fromOffset(88, 88)
theme.badgeSize = UDim2.fromOffset(228, 60)
theme.panelSize = UDim2.fromOffset(609, 219)
theme.textFieldSize = UDim2.fromOffset(548, 82)
theme.checkboxSize = UDim2.fromOffset(66, 66)
theme.progressBarSize = UDim2.fromOffset(609, 49)
theme.scrollListSize = UDim2.fromOffset(609, 274)
theme.gemBackgroundSize = UDim2.fromOffset(609, 164)
theme.windowSize = UDim2.fromOffset(974, 575)
theme.topBarHeight = 82

------------------------------------------------------------------------------
-- Variants
------------------------------------------------------------------------------
-- Straight from the template's `Palette` row — each swatch is the gradient that
-- paints every gem surface for that variant. Rainbow runs near-horizontal (the
-- template's 10°) because its stops only read across the long axis.

export type Variant = {
	color: ColorSequence,
	rotation: number,
}

local function gradient(rotation: number, stops: { { number } }): Variant
	local keypoints = {}
	for i, stop in ipairs(stops) do
		keypoints[i] = ColorSequenceKeypoint.new(stop[1], Color3.fromRGB(stop[2], stop[3], stop[4]))
	end
	return { color = ColorSequence.new(keypoints), rotation = rotation }
end

theme.variants = {
	red = gradient(90, { { 0, 255, 106, 128 }, { 1, 213, 55, 58 } }),
	-- Not in the template's palette row: a hotter, purer red for markers that
	-- have to read as louder than a `red` surface behind them.
	brightRed = gradient(90, { { 0, 255, 92, 92 }, { 1, 255, 12, 12 } }),
	blue = gradient(90, { { 0, 8, 234, 255 }, { 1, 36, 146, 214 } }),
	green = gradient(90, { { 0, 117, 255, 58 }, { 1, 58, 213, 31 } }),
	purple = gradient(90, { { 0, 255, 83, 226 }, { 1, 170, 43, 195 } }),
	yellow = gradient(90, { { 0, 251, 255, 24 }, { 1, 229, 198, 41 } }),
	white = gradient(90, { { 0, 255, 255, 255 }, { 1, 210, 220, 232 } }),
	rainbow = gradient(10, {
		{ 0, 255, 66, 66 },
		{ 0.125, 255, 158, 60 },
		{ 0.25, 245, 255, 51 },
		{ 0.375, 71, 255, 61 },
		{ 0.5, 48, 255, 255 },
		{ 0.625, 55, 48, 255 },
		{ 0.75, 170, 52, 255 },
		{ 0.875, 255, 69, 255 },
		{ 1, 255, 66, 66 },
	}),
}

-- The template styled every exemplar green, so that's this skin's default.
-- Unknown variant keys fall back to it (per the contract).
theme.defaultVariant = "green"

-- Semantic role -> palette key. Contract v2 call sites name what a control MEANS
-- ("danger"), not what colour it is, so the skin decides the paint. The seven
-- legacy colour names still resolve to themselves for older call sites.
theme.variantForRole = {
	primary = "blue",
	secondary = "white",
	danger = "red",
	success = "green",
	warning = "yellow",
	neutral = "white",
	special = "rainbow",
}

function theme.resolveVariant(key: string?): string
	if key == nil then
		return theme.defaultVariant
	end
	return theme.variantForRole[key] or key
end

function theme.variant(key: string?): Variant
	local resolved = theme.resolveVariant(key)
	return theme.variants[resolved] or theme.variants[theme.defaultVariant]
end

-- Semantic colour alias the shared kit reads (gem and flat both expose it).
theme.mutedText = theme.mutedTextColor

return theme
