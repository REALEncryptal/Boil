--!strict
-- Scale policy — the tunable half of seam #5 (how big the UI is on the player's
-- device). Pure math plus a handful of knobs; no React, no instances.
--
-- Every skin token is a fixed pixel offset (`theme.buttonSize`, `theme.padding`,
-- `theme.textSizeXL`), which means every screen in this project is authored at one
-- resolution: `referenceViewport`. `compute` turns an actual viewport into the
-- factor a `Canvas` applies so that authored design pixel maps onto the device.
--
-- The formula, in order:
--   1. `raw = min(viewport.X / reference.X, viewport.Y / reference.Y)` — the
--      largest uniform factor that still fits the design canvas on both axes.
--   2. `raw ^ responsiveness` — softening. 1 = fully proportional (the design,
--      letterboxed — WYSIWYG); 0 = never scale at all; between = shrink less than
--      the viewport did, trading fidelity for legibility on small screens.
--   3. `× touchBoost` on touch-only devices, because a finger needs a bigger
--      target than a cursor does.
--   4. clamp to [`minScale`, `maxScale`], so a 4K monitor doesn't get a comically
--      large HUD and a tiny phone doesn't get an unreadable one.
--
-- Tokens are mutated live by the Canvas story (same trick as the Theme story), so
-- tune by eye there and copy the values you settle on back into this file.
--
-- Deliberately NOT a skin token: how large the UI is on a device is a property of
-- the device, not of the look. Every skin scales by the same policy. See
-- docs/game/device-scale.md.

local scale = {}

-- The resolution every screen in this project is authored at. Change this only if
-- you re-author the token ladder in `theme.luau` to match.
scale.referenceViewport = Vector2.new(1920, 1080)

-- How hard the UI follows the viewport. 1 = fully proportional, 0 = fixed size.
scale.responsiveness = 1

-- Clamp on the final factor.
scale.minScale = 0.5
scale.maxScale = 1.25

-- Extra size for touch-only devices (phones/tablets with no keyboard). Applied
-- before the clamp.
scale.touchBoost = 1.1

-- A viewport axis below this many pixels is the engine reporting a not-yet-ready
-- surface (CurrentCamera briefly reads 1×1 on join, and a Frame's AbsoluteSize is
-- 0×0 for the frame before it lays out). Treat those as "no measurement yet".
local MIN_MEANINGFUL_AXIS = 2

-- True when `size` is a real measurement rather than a boot-time placeholder.
function scale.isMeasured(size: Vector2): boolean
	return size.X >= MIN_MEANINGFUL_AXIS and size.Y >= MIN_MEANINGFUL_AXIS
end

-- UserInputService is client-only — `GetService` on it throws on the server — so
-- it's resolved lazily on first use rather than at require time. `ui` is required
-- from server code through `Boil.ui`, and this module must not blow that up.
local userInputService: UserInputService? = nil

-- Touch-ONLY, deliberately: a laptop with a touchscreen reports TouchEnabled but
-- is driven by a cursor, and shouldn't get the finger-sized bump.
function scale.isTouchDevice(): boolean
	if userInputService == nil then
		local ok, service = pcall(game.GetService, game, "UserInputService")
		if not ok then
			return false
		end
		userInputService = service :: UserInputService
	end
	local uis = userInputService :: UserInputService
	return uis.TouchEnabled and not uis.KeyboardEnabled
end

-- The factor a Canvas of `viewport` pixels applies to authored design pixels.
-- Returns 1 for an unmeasured viewport so an unlaid-out frame renders at design
-- size for the one frame before it measures, rather than collapsing.
function scale.compute(viewport: Vector2, isTouch: boolean?): number
	local reference = scale.referenceViewport
	if not scale.isMeasured(viewport) or not scale.isMeasured(reference) then
		return 1
	end

	local raw = math.min(viewport.X / reference.X, viewport.Y / reference.Y)
	local factor = raw ^ math.clamp(scale.responsiveness, 0, 1)
	if isTouch then
		factor *= scale.touchBoost
	end

	return math.clamp(factor, scale.minScale, scale.maxScale)
end

return scale
