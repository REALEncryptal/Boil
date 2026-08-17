--!strict
-- ScaleProvider — the scale seam (seam #5: how big the UI is on the *device*).
--
-- Holds the resolved surface in React context: the factor design pixels are drawn
-- at, the box that factor was computed from, whether we're on touch, and the
-- screen insets. `Canvas` republishes it with its own measurements, so anything
-- rendered inside a Canvas reads the scale it is actually being drawn at.
--
-- You rarely mount this yourself — `Canvas` is the surface you compose with, and
-- `useSurface` / `useViewportScale` fall back to live camera measurement when no
-- provider is mounted (so a UI Labs story with neither still gets sane numbers).
-- Mount it directly only to *override*: force a subtree to a fixed scale, or
-- pretend the screen is a different size.
--
--   React.createElement(ui.ScaleProvider, { scale = 0.75 }, { App = … })
--   React.createElement(ui.ScaleProvider, { viewport = Vector2.new(1136, 640) }, { App = … })
--
-- Mirrors SkinProvider deliberately: same shape, same fallback-when-absent rule.
-- See docs/game/device-scale.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local insets = require(script.Parent.insets)
local scale = require(script.Parent.scale)
local useViewport = require(script.Parent.useViewport)

export type Surface = {
	-- The factor design pixels are multiplied by on this device.
	scale: number,
	-- The box `scale` was computed from, in device pixels. At the root this is
	-- the screen; inside a Canvas it's that Canvas's own box.
	viewport: Vector2,
	-- Touch-only device (no keyboard) — a finger, not a cursor.
	isTouch: boolean,
	-- Screen insets in DEVICE pixels. `useSafeArea` converts these to canvas
	-- units, which is the form you want inside a Canvas.
	insets: insets.Insets,
	-- The factor was pinned by an explicit `scale` / `viewport` override rather
	-- than derived from a real measurement. A Canvas below a pinned surface uses
	-- that factor instead of recomputing from its own box — which is what makes
	-- "render this subtree at 0.75×" and the device simulator in the story work.
	-- Without the flag a provider that only overrode, say, `insets` would also
	-- silently pin a camera-derived factor onto every Canvas beneath it.
	locked: boolean,
}

export type ProviderProps = {
	-- Force the factor outright. Wins over everything.
	scale: number?,
	-- Compute the factor from this box instead of the live viewport.
	viewport: Vector2?,
	isTouch: boolean?,
	insets: insets.Insets?,
	children: { [string]: any }?,
}

local SurfaceContext = React.createContext(nil :: Surface?)

-- Resolve a surface from explicit overrides, an inherited surface, and live
-- measurement — in that order, per field. Shared by the provider and the
-- no-provider fallback in `useSurface`, so both agree on precedence.
local function resolve(
	overrides: ProviderProps,
	inherited: Surface?,
	liveViewport: Vector2,
	liveInsets: insets.Insets,
	liveIsTouch: boolean
): Surface
	local viewport = overrides.viewport or (if inherited then inherited.viewport else nil) or liveViewport
	local isTouch = overrides.isTouch
	if isTouch == nil then
		isTouch = if inherited then inherited.isTouch else liveIsTouch
	end
	local resolvedInsets = overrides.insets or (if inherited then inherited.insets else nil) or liveInsets

	-- An explicit `scale` wins; an explicit `viewport` means recompute rather
	-- than inherit (otherwise simulating a phone would keep the desktop factor).
	local factor = overrides.scale
	if factor == nil and overrides.viewport == nil and inherited then
		factor = inherited.scale
	end

	local locked = overrides.scale ~= nil
		or overrides.viewport ~= nil
		or (inherited ~= nil and (inherited :: Surface).locked)

	return {
		scale = factor or scale.compute(viewport, isTouch),
		viewport = viewport,
		isTouch = isTouch :: boolean,
		insets = resolvedInsets,
		locked = locked,
	}
end

-- The live, un-overridden surface. Always calls its hooks (React requires an
-- unconditional call order), so a consumer under a provider pays one viewport
-- signal connection for the fallback it doesn't use — cheap, and it's what keeps
-- the provider genuinely optional.
--
-- Not memoized: the deps would be a mostly-nil array (every override is optional),
-- and a dependency list with holes is exactly the case React's `#deps` comparison
-- can't be trusted on. Rebuilding a five-field table is cheaper than the bug, and
-- the hooks above already gate re-renders on the values actually changing.
local function useLiveSurface(overrides: ProviderProps?, inherited: Surface?): Surface
	local liveViewport = useViewport()
	local liveInsets = insets.useScreenInsets()
	local liveIsTouch = React.useMemo(scale.isTouchDevice, {})

	return resolve(overrides or {}, inherited, liveViewport, liveInsets, liveIsTouch)
end

local function ScaleProvider(props: ProviderProps)
	local inherited = React.useContext(SurfaceContext)
	local surface = useLiveSurface(props, inherited)

	return React.createElement(SurfaceContext.Provider, { value = surface }, props.children)
end

-- The active surface. Reads context when a provider (or an enclosing Canvas) is
-- mounted, otherwise measures the screen itself.
local function useSurface(): Surface
	local inherited = React.useContext(SurfaceContext)
	local live = useLiveSurface(nil, inherited)
	return live
end

return {
	ScaleProvider = ScaleProvider,
	useSurface = useSurface,
	Context = SurfaceContext,
	resolve = resolve,
}
