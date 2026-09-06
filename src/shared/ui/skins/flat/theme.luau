--!strict
-- Flat skin tokens. Deliberately plain: solid grey surfaces, thin borders, no
-- gradients, noise or shine.
--
-- The two shared scales (`type`, `space`) come from `tokens.luau` — the same
-- source gem uses — because they are part of the contract. That is the fix for
-- the old split, where flat declared `textSize = 24` and `titleTextSize = 28`
-- and nothing else, so `theme.textSizeRegular` was simply nil here and any call
-- site reading it broke the moment you swapped skins.
--
-- Flat re-tunes the scales slightly rather than replacing them: a flat surface
-- has no gem artwork carrying visual weight, so its type sits a touch smaller
-- and its spacing a touch tighter without the layout falling apart.
--
-- All values are reference pixels (1280×720). See tokens.luau.

local tokens = require(script.Parent.Parent.Parent.tokens)

local theme = {}

theme.tokens = tokens

------------------------------------------------------------------------------
-- Shared scales (required by the contract — same keys as every other skin)
------------------------------------------------------------------------------
theme.type = {
	display = 42,
	title = 32,
	heading = 25,
	body = 20,
	label = 16,
	caption = 13,
}

theme.space = {
	xs = 4,
	sm = 8,
	md = 12,
	lg = 16,
	xl = 26,
	xxl = 40,
}

theme.motion = table.clone(tokens.motion)

theme.roles = {
	default = "body",
	button = "body",
	badge = "heading",
	input = "body",
	windowTitle = "heading",
}

------------------------------------------------------------------------------
-- Flat surfaces
------------------------------------------------------------------------------
theme.strokeThickness = 2
theme.thinStrokeThickness = 1
theme.cornerRadius = UDim.new(0, 4)
theme.glassTransparency = 0.15

theme.surface = Color3.fromRGB(58, 58, 64)
theme.surfaceAlt = Color3.fromRGB(78, 78, 86)
theme.surfaceDeep = Color3.fromRGB(44, 44, 49)
theme.border = Color3.fromRGB(150, 150, 158)
theme.textColor = Color3.fromRGB(236, 236, 240)
theme.mutedText = Color3.fromRGB(170, 170, 178)

------------------------------------------------------------------------------
-- Component dimensions (reference pixels)
------------------------------------------------------------------------------
theme.buttonSize = UDim2.fromOffset(60, 60)
theme.windowSize = UDim2.fromOffset(760, 520)
theme.topBarHeight = 56
theme.topBarOverflow = 0
theme.textFieldSize = UDim2.fromOffset(300, 56)
theme.rowHeight = 52
theme.checkboxSize = 38
theme.tileSize = UDim2.fromOffset(115, 115)
theme.badgeTileSize = UDim2.fromOffset(80, 80)
theme.textForegroundOffset = -2

------------------------------------------------------------------------------
-- Variant mapping
------------------------------------------------------------------------------
-- Both the semantic roles and the seven legacy colour names resolve to a flat
-- accent, so a call site can say `variant = "danger"` (preferred) or the older
-- `variant = "red"` and get the same swatch.
theme.variants = {
	red = Color3.fromRGB(206, 84, 84),
	blue = Color3.fromRGB(84, 134, 206),
	green = Color3.fromRGB(84, 184, 116),
	purple = Color3.fromRGB(154, 96, 206),
	yellow = Color3.fromRGB(212, 184, 76),
	white = Color3.fromRGB(210, 210, 216),
	rainbow = Color3.fromRGB(184, 124, 204),
}

theme.variantForRole = {
	primary = "blue",
	secondary = "white",
	danger = "red",
	success = "green",
	warning = "yellow",
	neutral = "white",
	special = "purple",
}

function theme.resolveVariant(key: string?): string
	if key == nil then
		return "white"
	end
	return theme.variantForRole[key] or key
end

function theme.accent(variant: string?): Color3
	return theme.variants[theme.resolveVariant(variant)] or theme.variants.white
end

------------------------------------------------------------------------------
-- Legacy token names
------------------------------------------------------------------------------
-- Same live-resolution trick as the gem theme: derived on read, so retuning a
-- scale moves them instead of leaving a stale copy behind.
local legacy: { [string]: (typeof(theme)) -> any } = {
	textSizeXL = function(t) return t.type.display end,
	textSizeLarge = function(t) return t.type.title end,
	textSizeRegular = function(t) return t.type.heading end,
	textSizeSmall = function(t) return t.type.body end,
	textSizeXS = function(t) return t.type.label end,
	textSize = function(t) return t.type.body end,
	titleTextSize = function(t) return t.type[t.roles.badge] end,
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
