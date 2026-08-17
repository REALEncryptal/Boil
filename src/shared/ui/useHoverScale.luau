--!strict
-- Hover + (optional) press scale animation, built on useTweenedScale.
--
-- `triggerKind` picks the state machine:
--   "button" — full hover + press (default). Wire all four handlers to a
--              GuiButton's MouseEnter/Leave/Button1Down/Button1Up events.
--   "hover"  — hover only, no press tracking. Wire onEnter/onLeave to any
--              GuiObject's MouseEnter/MouseLeave (Frame, ImageLabel, etc.).
--
-- **Touch.** MouseEnter/MouseLeave never fire on a touchscreen, so a mouse-only
-- wiring leaves every phone player with no feedback at all — the button just sits
-- there. `onInputBegan` / `onInputEnded` fill that in: wire them to the same
-- object's InputBegan/InputEnded and the hook animates on tap. They ignore every
-- input type except Touch, so they stack with the mouse handlers rather than
-- double-firing (a mouse click would otherwise play the press cue twice).
--
-- What a tap animates depends on the kind, because touch has no hover state to
-- speak of: "button" plays press-and-release (the finger-down feedback a phone
-- player expects), "hover" maps touch down/up onto enter/leave so a hover-only
-- affordance still reveals itself on tap.
--
-- `isHovered` / `isPressed` are exposed so callers can drive other effects
-- (color shifts, glow toggles, etc.) off the same state machine. For purely
-- programmatic animations with no pointer trigger, use useTweenedScale directly.
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
	-- Touch equivalents. Signature matches a React-Roblox InputBegan/InputEnded
	-- handler: (instance, inputObject, gameProcessedEvent).
	onInputBegan: (GuiObject, InputObject) -> (),
	onInputEnded: (GuiObject, InputObject) -> (),
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

	local hovered, setHovered = React.useState(false)
	local pressed, setPressed = React.useState(false)

	local target = if pressed then pressScale elseif hovered then hoverScale else idle
	local duration = if pressed then pressDuration else hoverDuration

	local scaleRef = useTweenedScale(target, { duration = duration })

	local noop = function() end

	local function onEnter()
		setHovered(true)
		if hoverInSound then
			audio.playUI(hoverInSound)
		end
	end

	-- Clear pressed too: a drag-off shouldn't leave the element stuck small.
	local function onLeave()
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

	-- A tap drives the press machine on a button and the hover machine on a
	-- hover-only surface (see the note at the top). Non-touch input is left to
	-- the mouse handlers so nothing fires twice.
	local function onInputBegan(_instance: GuiObject, input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if pressEnabled then
			onPress()
			return
		end
		onEnter()
	end

	local function onInputEnded(_instance: GuiObject, input: InputObject)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if pressEnabled then
			onRelease()
			return
		end
		onLeave()
	end

	return {
		scaleRef = scaleRef,
		isHovered = hovered,
		isPressed = pressed,
		onEnter = onEnter,
		onLeave = onLeave,
		onPress = onPress,
		onRelease = onRelease,
		onInputBegan = onInputBegan,
		onInputEnded = onInputEnded,
	}
end

return useHoverScale
