--!strict
-- The factor the UI is being drawn at on this device — 1 on a screen the size of
-- `scale.referenceViewport`, smaller on a phone.
--
-- Inside a Canvas (which the client root mounts, so: any feature UI) this is that
-- Canvas's factor. Outside one it's derived live from the camera viewport.
--
-- **You usually don't need this.** The Canvas already scales every offset in the
-- tree; reading the factor and multiplying by it again double-scales. Reach for it
-- only when something escapes the canvas's coordinate space:
--
--   * sizing/positioning in absolute screen pixels (a world-space billboard, an
--     overlay that reads `AbsolutePosition`),
--   * choosing content rather than size — a compact layout under some threshold,
--   * telling a non-React system (a viewport-frame camera, a particle emitter)
--     how big the UI it has to match is.
--
-- For "is this a phone", prefer `ui.useSurface().isTouch` over comparing scales.

local ScaleProvider = require(script.Parent.ScaleProvider)

local function useViewportScale(): number
	return ScaleProvider.useSurface().scale
end

return useViewportScale
