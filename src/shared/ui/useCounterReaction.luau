--!strict
-- A counter label's reaction: it punches bigger, flashes toward a colour, and
-- vibrates — all three fired together as each flying icon lands on it.
--
-- Extracted from Cash, which was the first counter to want this. Nothing here
-- knows what is being counted; `ui.Counter` wires it to a label, and any feature
-- with a counter drives it the same way.
--
-- Split into three moving parts on purpose:
--
--   * scale and rotation are written straight to refs on a Heartbeat, so the
--     vibration runs at frame rate without re-rendering React 60 times a
--     second. Same reason PickupFX's Overlay does it.
--   * the flash rides on the gradient, which reaches the label as a PROP, so it
--     has to go through state. It's quantized to `flashSteps` so the whole
--     reaction costs ~8 re-renders of one small subtree instead of ~22.
--   * the shake sits on a frame wrapping the NUMBER only. The icon beside it
--     holds still — shaking the whole counter reads as the HUD glitching,
--     where shaking just the number reads as the number reacting. It also
--     keeps the PickupFX destination (the outer frame) still, so icons don't
--     chase a wobbling target and visibly wander on approach.
--
-- Re-triggering restarts the reaction from the top rather than queueing, so a
-- burst of icons reads as one sustained buzz that keeps getting re-kicked.
--
-- Each trigger also rolls its own duration, punch, angle, speed, shake phase and
-- shake DIRECTION. That last pair matters most: a sine started from zero every
-- time makes every reaction identical frame for frame, so two gains close
-- together look like the label barely moved on the second one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)

-- Every trigger rolls its own variance within ±this fraction of the tuned
-- values. Without it, back-to-back gains play the exact same reaction frame for
-- frame and the second one reads as the label sitting still.
local DEFAULTS = {
	jitter = 0.28,
	duration = 0.36,
	-- Scale is applied INSTANTLY, then eases back to 1 across `duration`.
	punchScale = 1.22,
	-- Peak vibration angle in degrees, decaying to 0 over the reaction. Small on
	-- purpose: the speed is what sells a vibration, and past ~4° it stops
	-- reading as a buzz and starts reading as the label falling over.
	shakeAngle = 3,
	-- Radians/sec of the shake oscillation. High on purpose — the brief is
	-- "vibrating", not "swaying".
	shakeSpeed = 58,
	-- How far the glyph gradient lerps toward the flash colour at peak.
	flashStrength = 0.85,
	-- The flash is the one part driven by React state rather than a ref, since
	-- the gradient reaches the label as a prop. Quantizing it to this many steps
	-- caps the reaction at ~8 re-renders instead of one per frame; the eye can't
	-- resolve finer than this over a third of a second anyway.
	flashSteps = 8,
}

export type Options = {
	jitter: number?,
	duration: number?,
	punchScale: number?,
	shakeAngle: number?,
	shakeSpeed: number?,
	flashStrength: number?,
	flashSteps: number?,
}

export type Handle = {
	-- Attach to the outer frame: the stable point icons fly to.
	anchorRef: { current: Frame? },
	-- Attach to the frame wrapping the number: this is what rotates and scales.
	shakeRef: { current: Frame? },
	-- Attach to a UIScale inside the shaker.
	scaleRef: { current: UIScale? },
	-- 0 when idle, up to `flashStrength` at the peak.
	flash: number,
	-- Call to (re)start the reaction.
	trigger: () -> (),
}

-- Decays from 1 to 0 over the reaction, easing out so the punch and the shake
-- both settle rather than stopping dead.
local function decay(t: number): number
	local u = 1 - t
	return u * u
end
-- One trigger's rolled variance. Held for the length of that reaction so the
-- numbers stay put mid-animation instead of re-rolling every frame.
type Roll = {
	duration: number,
	punch: number,
	angle: number,
	speed: number,
	phase: number,
}

return function(options: Options?): Handle
	local anchorRef = React.useRef(nil :: Frame?)
	local shakeRef = React.useRef(nil :: Frame?)
	local scaleRef = React.useRef(nil :: UIScale?)
	local startedAt = React.useRef(nil :: number?)
	local variance = React.useRef(nil :: Roll?)
	local flash, setFlash = React.useState(0)

	-- Tuning read through a ref: a caller passing an inline table gets a fresh
	-- reference every render, and the Heartbeat effect must not re-subscribe on
	-- each one.
	local tuning = React.useRef(DEFAULTS)
	tuning.current = if options == nil
		then DEFAULTS
		else {
			jitter = options.jitter or DEFAULTS.jitter,
			duration = options.duration or DEFAULTS.duration,
			punchScale = options.punchScale or DEFAULTS.punchScale,
			shakeAngle = options.shakeAngle or DEFAULTS.shakeAngle,
			shakeSpeed = options.shakeSpeed or DEFAULTS.shakeSpeed,
			flashStrength = options.flashStrength or DEFAULTS.flashStrength,
			flashSteps = options.flashSteps or DEFAULTS.flashSteps,
		}

	local trigger = React.useCallback(function()
		local tuned = tuning.current

		local function jittered(base: number): number
			return base * (1 + (math.random() * 2 - 1) * tuned.jitter)
		end

		variance.current = {
			duration = jittered(tuned.duration),
			-- Jitter the punch's DEPTH, not the final scale, so the variance is
			-- proportional to the effect rather than to 1.
			punch = 1 + jittered(tuned.punchScale - 1),
			-- Signed, so the first flick goes left as often as right.
			angle = jittered(tuned.shakeAngle) * (if math.random() < 0.5 then -1 else 1),
			speed = jittered(tuned.shakeSpeed),
			phase = math.random() * math.pi * 2,
		}
		startedAt.current = os.clock()
	end, {})

	React.useEffect(function()
		local function settle()
			local shaker = shakeRef.current
			local scale = scaleRef.current
			if shaker then
				shaker.Rotation = 0
			end
			if scale then
				scale.Scale = 1
			end
			setFlash(0)
		end

		local conn = RunService.Heartbeat:Connect(function()
			local start = startedAt.current
			local roll = variance.current
			if start == nil or roll == nil then
				return
			end

			local elapsed = os.clock() - start
			if elapsed >= roll.duration then
				startedAt.current = nil
				variance.current = nil
				settle()
				return
			end

			local falloff = decay(elapsed / roll.duration)

			local scale = scaleRef.current
			if scale then
				-- Instant to the punch scale on the first frame, then eased back.
				scale.Scale = 1 + (roll.punch - 1) * falloff
			end

			local shaker = shakeRef.current
			if shaker then
				shaker.Rotation = math.sin(roll.phase + elapsed * roll.speed) * roll.angle * falloff
			end

			-- Quantized: only push a render when the bucket actually changes.
			local steps = tuning.current.flashSteps
			local target = math.round(falloff * tuning.current.flashStrength * steps) / steps
			setFlash(function(current: number): number
				return if current == target then current else target
			end)
		end)

		return function()
			conn:Disconnect()
		end
	end, {})

	return {
		anchorRef = anchorRef,
		shakeRef = shakeRef,
		scaleRef = scaleRef,
		flash = flash,
		trigger = trigger,
	}
end
