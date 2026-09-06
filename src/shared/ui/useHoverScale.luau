--!strict
-- Hover + (optional) press scale animation, built on useTweenedScale.
--
-- `triggerKind` picks the state machine:
--   "button" — full hover + press (default). Wire all four handlers to a
--              GuiButton's MouseEnter/Leave/Button1Down/Button1Up events.
--   "hover"  — hover only, no press tracking. Wire onEnter/onLeave to any
--              GuiObject's MouseEnter/MouseLeave (Frame, ImageLabel, etc.).
--
-- `isHovered` / `isPressed` are exposed so callers can drive other effects
-- (color shifts, glow toggles, etc.) off the same state machine. For purely
-- programmatic animations with no pointer trigger, use useTweenedScale directly.
--
-- Touch: on a touch device the hook does NOT bind hover at all, and `events`
-- omits MouseEnter/MouseLeave. Roblox fires those inconsistently for a finger
-- (enter on touch-down, leave sometimes never), which is what used to leave a
-- button stuck in its hovered state after a tap. Touch gets press feedback only,
-- plus an InputEnded guard so a finger dragged off the control still releases.
--
-- Wire a control by spreading `events` rather than naming the four handlers:
--
--   local hover = useHoverScale()
--   React.createElement("TextButton", merge({ … }, hover.events(onClick)))
--
-- Audio feedback: by default the hook plays a `hoverIn` SFX on enter, a
-- `hoverOut` SFX on leave, and a `click` SFX on press (`triggerKind = "button"`
-- only). Override `sounds` to swap individual cues, or pass `sounds = false`
-- to mute the whole hook (e.g. for non-clickable hover surfaces like a tooltip
-- target). Sounds are pulled from `shared/audio` and use the registered keys.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local audio = require(ReplicatedStorage.Shared.audio)
local theme = require(script.Parent.theme)
local useTweenedScale = require(script.Parent.useTweenedScale)
local useViewport = require(script.Parent.useViewport)

export type TriggerKind = "button" | "hover"

export type Sounds = {
	hoverIn: string?,
	hoverOut: string?,
	press: string?,
}

export type Options = {
	triggerKind: TriggerKind?,
	idleScale: number?,
	hoverScale: number?,
	pressScale: number?,
	hoverDuration: number?,
	pressDuration: number?,
	sounds: (Sounds | boolean)?,
}

-- Default audio cues. Each entry is an `audio.UI` key — change here and every
-- shared widget that uses the hook follows.
local DEFAULT_SOUNDS: Sounds = {
	hoverIn = "hoverIn",
	hoverOut = "hoverOut",
	press = "click",
}

export type Handle = {
	scaleRef: useTweenedScale.ScaleRef,
	isHovered: boolean,
	isPressed: boolean,
	onEnter: () -> (),
	onLeave: () -> (),
	onPress: () -> (),
	onRelease: () -> (),
	-- Ready-to-spread React event map for a GuiButton. Pass the click handler;
	-- pass `disabled = true` to get an empty map (no feedback, no click).
	events: (onClick: (() -> ())?, disabled: boolean?) -> { [any]: any },
}

local function useHoverScale(options: Options?): Handle
	local opts = options or {}
	local triggerKind = opts.triggerKind or "button"
	local idle = opts.idleScale or theme.idleScale
	local hoverScale = opts.hoverScale or theme.hoverScale
	local pressScale = opts.pressScale or theme.pressScale
	local hoverDuration = opts.hoverDuration or theme.hoverDuration
	local pressDuration = opts.pressDuration or theme.pressDuration
	local pressEnabled = triggerKind == "button"

	-- Resolve audio cues. `sounds = false` mutes everything; a partial table
	-- merges over the defaults (so `sounds = { press = "click2" }` only swaps
	-- the press cue and keeps the default hover cues).
	local hoverInSound: string? = DEFAULT_SOUNDS.hoverIn
	local hoverOutSound: string? = DEFAULT_SOUNDS.hoverOut
	local pressSound: string? = DEFAULT_SOUNDS.press
	if opts.sounds == false then
		hoverInSound = nil
		hoverOutSound = nil
		pressSound = nil
	elseif typeof(opts.sounds) == "table" then
		local s = opts.sounds :: Sounds
		if s.hoverIn ~= nil then hoverInSound = s.hoverIn end
		if s.hoverOut ~= nil then hoverOutSound = s.hoverOut end
		if s.press ~= nil then pressSound = s.press end
	end

	local isTouch = useViewport.useViewport().isTouch

	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)

	local target = if pressed then pressScale elseif hovered then hoverScale else idle
	local duration = if pressed then pressDuration else hoverDuration

	local scaleRef = useTweenedScale(target, { duration = duration })

	local noop = function() end

	local onEnter = function()
		setHovered(true)
		if hoverInSound then
			audio.playUI(hoverInSound)
		end
	end

	-- Clear pressed too: a drag-off shouldn't leave the element stuck small.
	local onLeave = function()
		setHovered(false)
		if pressEnabled then
			setPressed(false)
		end
		if hoverOutSound then
			audio.playUI(hoverOutSound)
		end
	end

	local onPress = if pressEnabled
		then function()
			setPressed(true)
			if pressSound then
				audio.playUI(pressSound)
			end
		end
		else noop

	local onRelease = if pressEnabled then function() setPressed(false) end else noop

	local function events(onClick: (() -> ())?, disabled: boolean?): { [any]: any }
		if disabled then
			return {}
		end
		local map: { [any]: any } = {
			[React.Event.Activated] = onClick,
			[React.Event.MouseButton1Down] = onPress,
			[React.Event.MouseButton1Up] = onRelease,
		}
		if isTouch then
			-- A finger lifted off the edge of the control never fires
			-- MouseButton1Up, so release on the raw input end as well.
			map[React.Event.InputEnded] = function(_, input: InputObject)
				if input.UserInputType == Enum.UserInputType.Touch then
					onRelease()
				end
			end
			return map
		end
		map[React.Event.MouseEnter] = onEnter
		map[React.Event.MouseLeave] = onLeave
		return map
	end

	return {
		events = events,
		scaleRef = scaleRef,
		isHovered = hovered,
		isPressed = pressed,
		-- Kept for call sites that wire handlers individually; `events` is preferred.
		onEnter = if isTouch then noop else onEnter,
		onLeave = if isTouch then noop else onLeave,
		onPress = onPress,
		onRelease = onRelease,
	}
end

return useHoverScale
