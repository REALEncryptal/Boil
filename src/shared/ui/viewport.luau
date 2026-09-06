--!strict
-- viewport — the one place that knows how big the screen is and what kind of
-- device is holding it.
--
-- Before this module the codebase had no viewport awareness at all: no UIScale,
-- no touch check, no breakpoint. Every size was an absolute pixel authored for
-- one monitor, which is why a 797×595 window overflowed a phone and a 22px label
-- vanished on a 4K display.
--
-- Two things live here, both realm-safe to require (they read Workspace and
-- UserInputService but connect nothing until asked):
--
--   scaleFor(viewport, device) — reference pixels → screen pixels
--   deviceFor(viewport)        — "phone" | "tablet" | "console" | "desktop"
--
-- The React bindings are in useViewport.luau. This file stays plain so a
-- non-React caller (a world-space surface, a Cmdr command) can ask too.

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local tokens = require(script.Parent.tokens)

local viewport = {}

export type Device = "phone" | "tablet" | "console" | "desktop"

-- Below this height (in real screen pixels) a touch device is a phone rather
-- than a tablet. 500 sits between an iPhone landscape (375–430) and an iPad
-- landscape (768+), so it separates them without needing a device database.
local PHONE_MAX_HEIGHT = 500
local PHONE_MAX_WIDTH = 800

-- Scale clamps. Below MIN the UI stops being legible; above MAX it stops being
-- a HUD and starts being a billboard.
local MIN_SCALE = 0.6
local MAX_SCALE = 2.0

-- Per-device multipliers on top of the raw fit. A phone shows fewer elements and
-- needs bigger tap targets, so its UI is deliberately *relatively* larger than a
-- proportional shrink would give — this is the single knob that makes mobile
-- stop feeling cramped.
local DEVICE_BOOST: { [string]: number } = {
	phone = 1.35,
	tablet = 1.1,
	console = 1.15,
	desktop = 1,
}

function viewport.size(): Vector2
	local camera = Workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	-- Edit mode before a camera exists (and the UI Labs first frame).
	return tokens.REFERENCE
end

function viewport.deviceFor(size: Vector2): Device
	if GuiService:IsTenFootInterface() then
		return "console"
	end
	-- Keyboard present means a desktop even on a touchscreen laptop: the player
	-- is not aiming with a finger, so the touch layout would just waste space.
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		if size.Y <= PHONE_MAX_HEIGHT or size.X <= PHONE_MAX_WIDTH then
			return "phone"
		end
		return "tablet"
	end
	return "desktop"
end

-- Reference pixels → screen pixels.
--
-- `min` of the two axis ratios (never `max`, never width-only) so a surface
-- authored at the reference always fits both dimensions — on an ultrawide the
-- height governs, on a tall phone the width does.
function viewport.scaleFor(size: Vector2, device: Device?): number
	local kind = device or viewport.deviceFor(size)
	local fit = math.min(size.X / tokens.REFERENCE.X, size.Y / tokens.REFERENCE.Y)
	local boost = DEVICE_BOOST[kind] or 1
	return math.clamp(fit * boost, MIN_SCALE, MAX_SCALE)
end

function viewport.current(): (Vector2, Device, number)
	local size = viewport.size()
	local device = viewport.deviceFor(size)
	return size, device, viewport.scaleFor(size, device)
end

-- True when the player is driving with a finger. Primitives use this to pick a
-- press-based interaction path instead of a hover-based one — Roblox fires
-- MouseEnter/MouseLeave inconsistently on touch, which is what leaves a button
-- stuck in its hovered state after a tap.
function viewport.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Fires `callback(size, device, scale)` on every viewport change, and once
-- immediately. Returns a disconnect function.
function viewport.observe(callback: (Vector2, Device, number) -> ()): () -> ()
	local connections: { RBXScriptConnection } = {}
	local alive = true

	local function emit()
		if not alive then
			return
		end
		callback(viewport.current())
	end

	local function bindCamera()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		table.insert(connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(emit))
	end

	bindCamera()
	-- The camera is replaced on respawn and on some Studio mode switches; rebind
	-- rather than silently going deaf to resizes.
	table.insert(
		connections,
		Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			bindCamera()
			emit()
		end)
	)
	table.insert(connections, UserInputService.LastInputTypeChanged:Connect(emit))

	emit()

	return function()
		alive = false
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end
end

return viewport
