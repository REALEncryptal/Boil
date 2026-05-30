--!strict
-- Defaults and randomization ranges for the pickup-icon animation.
-- Tuned for "Moderate" variance: lively bursts without chaos. Adjust here
-- rather than threading numbers through every spawn() call.

local Constants = {}

Constants.DEFAULT_SIZE = Vector2.new(48, 48)

-- Per-icon random delay before the pop-in starts (seconds). Spreads a burst
-- so icons don't move as a clump.
Constants.STAGGER_MIN = 0
Constants.STAGGER_MAX = 0.18

-- Pop-in (scale 0 -> overshoot -> 1) duration. Fixed; the variance is in
-- travel + stagger, not pop-in.
Constants.POP_DURATION = 0.14
Constants.POP_OVERSHOOT_SCALE = 1.15

-- Travel duration randomized within this range. Each icon gets a different
-- value so they don't arrive in lockstep.
Constants.TRAVEL_MIN = 0.55
Constants.TRAVEL_MAX = 0.85

-- Perpendicular offset (px) applied to the bezier control point. Signed
-- randomly so curves arc both ways across the direct line. Tuned high so
-- the arcs read clearly even on short travels.
Constants.CURVE_OFFSET_MIN = 150
Constants.CURVE_OFFSET_MAX = 350

-- Fade-out scale tween after arrival.
Constants.FADE_DURATION = 0.08

-- Overlay's root ZIndex — must draw above HUD/Window content.
Constants.OVERLAY_ZINDEX = 1000
Constants.ICON_ZINDEX = 1

return Constants
