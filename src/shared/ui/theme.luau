--!strict
-- Gem skin tokens.
--
-- Built on `tokens.luau`, which supplies the two scales every skin must speak —
-- `type` (six named roles) and `space` (six steps on a 4px rhythm). This file
-- adds only what is specific to the gem look: stroke weights, glass opacity,
-- surface dimensions, and the map from semantic variant to gem palette.
--
-- ---------------------------------------------------------------------------
-- Every number here is in REFERENCE PIXELS (1280×720), not screen pixels.
-- ---------------------------------------------------------------------------
-- A `ui.Surface` multiplies them by the viewport scale at render, so `space.lg`
-- is 20 here and 30 on a 1080p monitor. Author against the reference; never
-- reach for the real screen size unless the *layout itself* has to change.
--
-- Tunable live: the UI Labs Theme story mutates this table and every primitive
-- picks up the new values on the next render, because tokens are read at render
-- time and never captured at module scope. Copy values you like back into this
-- file to keep them.

local tokens = require(script.Parent.tokens)

local theme = {}

theme.tokens = tokens

------------------------------------------------------------------------------
-- Shared scales (required by the contract — same keys in every skin)
------------------------------------------------------------------------------
-- Cloned rather than aliased so the Theme story can retune gem without silently
-- retuning flat and every installed skin along with it.
theme.type = table.clone(tokens.type)
theme.space = table.clone(tokens.space)
theme.motion = table.clone(tokens.motion)

-- Which type role each primitive uses when the call site names none. Change one
-- of these to re-pitch a whole class of control at once.
theme.roles = {
	default = "body",
	button = "heading",
	badge = "title",
	input = "body",
	windowTitle = "title",
}

------------------------------------------------------------------------------
-- Strokes
------------------------------------------------------------------------------
-- Gem outline used by Button, Panel, TextField and GemBackground.
theme.strokeThickness = 4
-- Thinner outline for text. Applied only when a label opts in — body copy reads
-- badly with an outline eating its counters, which is half of why small text
-- looked muddy before.
theme.thinStrokeThickness = 2

------------------------------------------------------------------------------
-- Surface
------------------------------------------------------------------------------
theme.glassTransparency = 0.8

------------------------------------------------------------------------------
-- Colours
------------------------------------------------------------------------------
-- Semantic text colours. Gem shipped without these, which is why feature code
-- reached for raw `Color3.fromRGB` literals — the same class of drift the type
-- and space scales fix. Named here so a call site asks for a ROLE.
theme.textColor = Color3.fromRGB(255, 255, 255)
theme.mutedText = Color3.fromRGB(188, 196, 210)
theme.shadowColor = Color3.fromRGB(0, 0, 0)

------------------------------------------------------------------------------
-- Component dimensions (reference pixels)
------------------------------------------------------------------------------
theme.buttonSize = UDim2.fromOffset(60, 60)
theme.windowSize = UDim2.fromOffset(760, 520)
theme.topBarHeight = 60
-- Horizontal overflow of the top bar past the panel edge (gem accent).
theme.topBarOverflow = 8
theme.textFieldSize = UDim2.fromOffset(300, 60)
theme.rowHeight = 56
theme.checkboxSize = 40

-- Noise tile. Sized in reference pixels like everything else, so the grain reads
-- the same on every display instead of getting finer as resolution climbs.
theme.tileSize = UDim2.fromOffset(115, 115)
theme.badgeTileSize = UDim2.fromOffset(80, 80)

------------------------------------------------------------------------------
-- Variant mapping
------------------------------------------------------------------------------
-- Semantic role → gem palette key. Call sites should name the ROLE ("danger"),
-- not the colour ("red"): that is what lets a skin reinterpret intent, and what
-- lets a skin add a variant the framework never shipped.
--
-- The seven legacy colour names still resolve to themselves, so existing call
-- sites keep rendering exactly as they did.
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
		return "blue"
	end
	return theme.variantForRole[key] or key
end

-- Inner shadow-layer vertical offset for Text's drop-shadow effect.
theme.textForegroundOffset = -2

------------------------------------------------------------------------------
-- Legacy token names
------------------------------------------------------------------------------
-- The pre-scale vocabulary (`textSizeXL`, `padding`, `hoverScale`, …), kept so
-- call sites written against it keep rendering while they migrate to roles.
--
-- Resolved through a metatable rather than copied, so they stay live: retuning
-- `theme.type.body` in the Theme story moves `theme.textSizeSmall` with it. A
-- plain copy would have frozen at load and silently desynced.
--
-- New code uses `theme.type.<role>` and `theme.space.<step>`. Nothing here is
-- part of the skin contract — a skin is not required to provide these.
local legacy: { [string]: (typeof(theme)) -> any } = {
	textSizeXL = function(t) return t.type.display end,
	textSizeLarge = function(t) return t.type.title end,
	textSizeRegular = function(t) return t.type.heading end,
	textSizeSmall = function(t) return t.type.body end,
	textSizeXS = function(t) return t.type.label end,
	textSize = function(t) return t.type.body end,
	buttonTextSize = function(t) return t.type[t.roles.button] end,
	badgeTextSize = function(t) return t.type[t.roles.badge] end,
	inputTextSize = function(t) return t.type[t.roles.input] end,

	padding = function(t) return t.space.lg end,
	tightPadding = function(t) return t.space.sm end,
	itemSpacing = function(t) return t.space.md end,
	contentSpacing = function(t) return t.space.lg end,

	idleScale = function(t) return t.motion.idleScale end,
	hoverScale = function(t) return t.motion.hoverScale end,
	pressScale = function(t) return t.motion.pressScale end,
	hoverDuration = function(t) return t.motion.hoverDuration end,
	pressDuration = function(t) return t.motion.pressDuration end,
}

return setmetatable(theme, {
	__index = function(self, key: string): any
		local resolve = legacy[key]
		if resolve then
			return resolve(self :: any)
		end
		return nil
	end,
})
