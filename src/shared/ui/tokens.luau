--!strict
-- tokens — the skin-independent design scales.
--
-- This is the layer the old theme.luau was missing. Before, every skin invented
-- its own vocabulary (gem had `textSizeXL…textSizeXS`, flat had `textSize` and
-- `titleTextSize` and nothing else), so a call site could never portably ask for
-- "a body-size label" — it could only type a number. That's why type and spacing
-- drifted apart across features.
--
-- Now there are two shared scales, and both are part of the contract:
--
--   * `type`  — six named roles. Call sites say `role = "body"`, never a number.
--   * `space` — six named steps on a 4px rhythm. Layout says `gap = "md"`.
--
-- A skin may re-tune the VALUES (a compact skin could shrink every step) but not
-- the KEYS — those are what call sites depend on. `contract.assertTheme` checks
-- that a skin supplies all of them.
--
-- ---------------------------------------------------------------------------
-- Everything here is in REFERENCE PIXELS, not screen pixels.
-- ---------------------------------------------------------------------------
-- Sizes are authored against `REFERENCE` (1280×720) and multiplied at render by
-- the viewport scale (see useScale.luau). A `body` label is 22 reference px; on a
-- 1080p monitor it renders at 33, on a phone at ~15. Author at the reference and
-- never think about it again — but only inside a `ui.Surface`, which is what
-- mounts the UIScale that does the multiplying.

local tokens = {}

------------------------------------------------------------------------------
-- Reference resolution
------------------------------------------------------------------------------
-- The screen every number below is authored against. Chosen at 720p because
-- Roblox UI reads large: scaling UP to desktop keeps text comfortably big, which
-- is the failure mode we're correcting.
tokens.REFERENCE = Vector2.new(1280, 720)

------------------------------------------------------------------------------
-- Type scale
------------------------------------------------------------------------------
-- Six roles on a ~1.27 ratio. Pick by JOB, not by size:
--
--   display — the one number or word a screen is about (a currency total, a
--             rebirth multiplier). At most one per surface.
--   title   — window titles, badge text, the top of a screen.
--   heading — section headers inside a surface.
--   body    — the default. Buttons, list rows, labels, running copy.
--   label   — secondary copy that sits beside body text without competing.
--   caption — metadata, counters, footnotes. The floor; never go smaller.
export type TypeRole = "display" | "title" | "heading" | "body" | "label" | "caption"

tokens.type = {
	display = 48,
	title = 36,
	heading = 28,
	body = 22,
	label = 18,
	caption = 14,
}

-- The role a primitive uses when the call site names none.
tokens.defaultTypeRole = "body" :: TypeRole

------------------------------------------------------------------------------
-- Space scale
------------------------------------------------------------------------------
-- Six steps on a 4px rhythm. Every gap, padding and inset in the kit comes from
-- here, which is what makes adjacent components line up instead of sitting two
-- pixels off each other.
--
--   xs  — hairline separation (icon to its own label)
--   sm  — inside a control (a badge's inner padding)
--   md  — between controls in a group (list rows, button rows)
--   lg  — a surface's inner edge padding
--   xl  — between sections of a surface
--   xxl — between whole surfaces on screen
export type SpaceRole = "xs" | "sm" | "md" | "lg" | "xl" | "xxl"

tokens.space = {
	xs = 4,
	sm = 8,
	md = 12,
	lg = 20,
	xl = 32,
	xxl = 48,
}

------------------------------------------------------------------------------
-- Semantic variants
------------------------------------------------------------------------------
-- What a control MEANS, not what colour it is. The old scheme spelled a confirm
-- button `"green"`, which meant a skin could never reinterpret intent and an
-- installed skin could never add a variant.
--
-- Skins map these to their own palette (gem → gradient, flat → accent colour).
-- The seven legacy colour names still resolve, so old call sites keep working;
-- see `theme.resolveVariant`.
export type VariantRole = "primary" | "secondary" | "danger" | "success" | "warning" | "neutral" | "special"

tokens.variantRoles = {
	primary = true,
	secondary = true,
	danger = true,
	success = true,
	warning = true,
	neutral = true,
	special = true,
}

------------------------------------------------------------------------------
-- Motion
------------------------------------------------------------------------------
-- Durations in seconds. Shared across skins so the kit feels like one thing
-- even when the surfaces look different.
tokens.motion = {
	hoverDuration = 0.15,
	pressDuration = 0.08,
	frameDuration = 0.22,
	idleScale = 1,
	hoverScale = 1.06,
	pressScale = 0.92,
}

------------------------------------------------------------------------------
-- Touch
------------------------------------------------------------------------------
-- Minimum interactive dimension in REAL SCREEN PIXELS — the one number here that
-- is not in reference space, and deliberately so.
--
-- A floor expressed in reference pixels isn't a floor: a Surface multiplies it by
-- the viewport scale, so 38 reference px became 27 real px on an iPhone SE, which
-- is smaller than the value was meant to guarantee and well under the ~44px both
-- Apple and Material call for. Primitives divide by the scale to get the
-- reference-space constraint that renders to this many real pixels.
--
-- Use `tokens.minTouchReference(scale)` rather than reading this directly.
tokens.minTouchTarget = 44

-- The reference-pixel minimum that renders to `minTouchTarget` real pixels at
-- the given viewport scale. Guard against a zero/absent scale so a component
-- rendered outside a ViewportProvider still gets a sane floor.
function tokens.minTouchReference(scale: number?): number
	local factor = if scale and scale > 0 then scale else 1
	return tokens.minTouchTarget / factor
end

-- Resolve a space value that may be given as a role name or a raw number.
-- Layout primitives take `gap = "md"` (preferred) or `gap = 12` (escape hatch).
function tokens.resolveSpace(scale: { [string]: number }, value: (string | number)?, fallback: number?): number
	if type(value) == "number" then
		return value
	end
	if type(value) == "string" then
		local step = scale[value]
		if step then
			return step
		end
		warn(`[tokens] unknown space role "{value}" — using 0`)
		return 0
	end
	return fallback or 0
end

-- Resolve a type size that may be given as a role name or a raw number.
function tokens.resolveType(scale: { [string]: number }, role: (string | number)?, fallback: number): number
	if type(role) == "number" then
		return role
	end
	if type(role) == "string" then
		local size = scale[role]
		if size then
			return size
		end
		warn(`[tokens] unknown type role "{role}" — using body`)
		return scale.body or fallback
	end
	return fallback
end

return tokens
