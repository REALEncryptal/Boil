--!strict
-- Safe-area insets in **canvas units** — the edges of the screen something else
-- already owns, expressed in the same design pixels every skin token uses, so they
-- compose directly with `theme.padding` and friends inside a Canvas.
--
-- Today that means the Roblox topbar: `BoilRoot` is full-bleed, so anything
-- anchored to the top of the screen draws underneath the chat / menu buttons
-- unless it moves down by `useSafeArea().top`. Device cutouts (notch, rounded
-- corners, home indicator) are handled by the engine via the ScreenGui's
-- `ScreenInsets = DeviceSafeInsets`, so they never show up here.
--
--   local safe = ui.useSafeArea()
--   React.createElement(ui.Stack, { position = UDim2.fromOffset(0, safe.top) }, …)
--
-- Most screens want `ui.SafeArea` instead, which applies these as padding around a
-- whole region. Use the hook when you need the raw number for one widget.
--
-- Insets are divided by the active scale on purpose: a topbar is a fixed number of
-- *device* pixels regardless of how small the UI is drawn, so inside a canvas at
-- 0.6× it covers proportionally more canvas.

local ScaleProvider = require(script.Parent.ScaleProvider)
local insets = require(script.Parent.insets)

export type Insets = insets.Insets

local function useSafeArea(): Insets
	local surface = ScaleProvider.useSurface()
	local raw = surface.insets
	local factor = surface.scale

	if factor <= 0 then
		return raw
	end

	return {
		top = raw.top / factor,
		bottom = raw.bottom / factor,
		left = raw.left / factor,
		right = raw.right / factor,
	}
end

return useSafeArea
