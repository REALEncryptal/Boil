--!strict
-- A counter that LAGS its true value: a gain doesn't land on the number, it
-- lands on it one flying icon at a time -- and each landing ROLLS the digits up
-- rather than snapping them.
--
-- Extracted from Cash, which was the first counter to want this. It is generic
-- because nothing here knows what is being counted: the caller feeds it a value
-- and calls `credit()` as each icon arrives. Cash and WalkSpeed both drive it.
--
-- Three values, not one, and the split is what makes the edge cases tractable:
--
--   value     the truth, straight off the profile replica.
--   credited  how much of it the icons have paid down so far. Steps up once per
--             arrival.
--   shown     what's rendered. Chases `credited` a fraction per frame.
--
-- The whole thing rests on one rule: **owed is always recomputed from the live
-- value, never accumulated**. A ledger of "credits still to pay" would be a
-- second source of truth, and every edge case below is a way for that ledger to
-- disagree with the profile. Deriving `value - credited` on each arrival means
-- the display converges on whatever the value is *now*, regardless of what it
-- was when the icons launched.
--
-- The edge cases that shape it:
--
--   Back-to-back gains -- the second burst adds its icons to `remaining` rather
--     than replacing it, and owed is re-derived, so the two bursts pay down one
--     combined gap instead of racing each other.
--
--   Gain then loss immediately -- a loss must land INSTANTLY; a player who just
--     paid for something and still sees the old number assumes it failed. So the
--     display snaps DOWN whenever it sits above the value: both `credited` and
--     `shown`, with no roll. Counting up is a flourish for something arriving;
--     counting down is just a slow answer to "did that go through".
--     If the loss leaves the value still above the display (earned 1000, spent
--     300, display only rolled up to 400) there is nothing to snap -- the icons
--     keep landing and converge on the new, lower target.
--
--   Icons that never arrive -- PickupFX uninstalled, the overlay unmounted, a
--     burst destroyed mid-flight. Without a backstop the counter would sit wrong
--     forever, which is worse than not lagging at all. If nothing credits for
--     `catchupTimeout`, it settles to the truth.
--
--   The value arriving at all -- a join is not a gain. The first real value
--     seeds all three outright, so nobody watches their savings roll up from
--     zero every time they load in.
--
-- The roll re-renders the label every frame while it's moving, which is the one
-- thing PickupFX's Overlay goes out of its way to avoid. It's the right call
-- here and not there: rolling digits ARE a text change, so there is nothing to
-- write through a ref, and it's one small label for a fraction of a second
-- rather than a dozen icons for as long as they fly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)

-- Nothing has credited for this long: the icons are never coming, so show the
-- truth. A counter stuck on a wrong number is worse than one that never lagged.
local DEFAULT_CATCHUP_TIMEOUT = 2.5
-- Roughly how long the number takes to roll from one icon's credit to the next.
-- Short: it has to finish before the next icon lands, or the rolls queue up.
local DEFAULT_COUNT_UP_SECONDS = 0.18

export type Options = {
	catchupTimeout: number?,
	countUpSeconds: number?,
}

export type Handle = {
	-- What to render. Trails `value`, rolling up as icons land.
	displayed: number,
	-- Tell it how many arrivals are coming. Additive, so overlapping bursts sum.
	expect: (count: number) -> (),
	-- One icon landed: pay down a share of what's owed.
	credit: () -> (),
	-- Give up on the lag and show the truth now. For the paths with no icons
	-- coming at all, so they don't wait out the timeout.
	settle: () -> (),
	-- Snap to an explicit intermediate value. CounterFX uses this to apply a
	-- silent portion before animating the remainder of a merged gain.
	settleTo: (target: number) -> (),
}

-- `value` is nil until the profile replica lands.
return function(value: number?, options: Options?): Handle
	local shown, setShown = React.useState(0)

	-- Read inside callbacks and the frame loop, which outlive the render they
	-- were created in.
	local valueRef = React.useRef(value)
	valueRef.current = value
	local credited = React.useRef(0)
	local shownRef = React.useRef(shown)
	shownRef.current = shown

	-- Tuning is read the same way. A caller passing an inline table gets a fresh
	-- reference every render, so the frame loop must never close over the table
	-- itself or it would re-subscribe on each one.
	local catchupTimeout = React.useRef(DEFAULT_CATCHUP_TIMEOUT)
	catchupTimeout.current = (options and options.catchupTimeout) or DEFAULT_CATCHUP_TIMEOUT
	local countUpSeconds = React.useRef(DEFAULT_COUNT_UP_SECONDS)
	countUpSeconds.current = (options and options.countUpSeconds) or DEFAULT_COUNT_UP_SECONDS

	local seeded = React.useRef(false)
	local remaining = React.useRef(0)
	-- When the last credit landed. nil once the display has caught up.
	local waitingSince = React.useRef(nil :: number?)

	local function snapTo(target: number)
		credited.current = target
		remaining.current = 0
		waitingSince.current = nil
		shownRef.current = target
		setShown(target)
	end

	local settle = React.useCallback(function()
		local target = valueRef.current
		if target ~= nil then
			snapTo(target)
		end
	end, {})
	local settleTo = React.useCallback(function(target: number)
		snapTo(target)
	end, {})

	local expect = React.useCallback(function(count: number)
		remaining.current += math.max(1, count)
		waitingSince.current = os.clock()
	end, {})

	local credit = React.useCallback(function()
		local target = valueRef.current
		if target == nil then
			return
		end

		waitingSince.current = os.clock()

		local current = credited.current
		if current >= target then
			-- Nothing owed: a loss already snapped past this arrival.
			remaining.current = 0
			return
		end

		local steps = math.max(1, remaining.current)
		remaining.current = math.max(0, steps - 1)

		if remaining.current == 0 then
			-- Last expected icon: land exactly, never a rounding short.
			credited.current = target
			return
		end

		-- Integer values, and a floor of 1 so a gap smaller than the icon count
		-- still moves on every landing instead of stalling.
		local step = math.max(1, math.floor((target - current) / steps))
		credited.current = math.min(target, current + step)
	end, {})

	-- Seed on the first real value; snap down on a loss.
	React.useEffect(function()
		if value == nil then
			return
		end

		if not seeded.current then
			seeded.current = true
			snapTo(value)
			return
		end

		if credited.current > value or shownRef.current > value then
			snapTo(value)
			return
		end
		-- External pickups may never call expect (or never arrive). Start the
		-- backstop on the gain itself as well as on explicitly declared bursts.
		if credited.current < value and waitingSince.current == nil then
			waitingSince.current = os.clock()
		end
	end, { value })

	-- The roll, plus the backstop. Both no-op once the display has caught up.
	React.useEffect(function()
		local conn = RunService.Heartbeat:Connect(function(delta: number)
			local target = valueRef.current
			if target == nil then
				return
			end

			-- Nothing has credited for too long: the icons are never coming.
			local since = waitingSince.current
			if
				since ~= nil
				and credited.current < target
				and os.clock() - since >= catchupTimeout.current
			then
				credited.current = target
				remaining.current = 0
				waitingSince.current = nil
			end

			local goal = credited.current
			local current = shownRef.current
			if current == goal then
				if goal == target then
					waitingSince.current = nil
				end
				return
			end

			-- A fraction of the remaining gap per frame, so the roll decelerates
			-- into its target instead of stopping dead. The floor of 1 is what
			-- guarantees it terminates rather than creeping the last few units.
			local gap = goal - current
			local fraction = math.min(1, delta / countUpSeconds.current)
			local step = math.max(1, math.floor(math.abs(gap) * fraction))
			local nextShown = if gap > 0
				then math.min(goal, current + step)
				else math.max(goal, current - step)

			shownRef.current = nextShown
			setShown(nextShown)
		end)

		return function()
			conn:Disconnect()
		end
	end, {})

	return {
		displayed = shown,
		expect = expect,
		credit = credit,
		settle = settle,
		settleTo = settleTo,
	}
end
