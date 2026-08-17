--!strict
-- Canvas — the surface seam #5 renders through: a design canvas that fills the box
-- it's given and draws its contents at the device's scale.
--
-- Every skin token in this project is a fixed pixel offset, so every screen is
-- authored at one resolution (`scale.referenceViewport`). Without a Canvas that
-- authoring is a desktop assumption, and a HUD sized for 1920×1080 covers a phone.
--
-- How it works, and why it isn't just a UIScale on the root frame:
--
--   outer Frame       fills the parent, measured — this is the real pixel box
--     └ inner Frame   offset-sized to `box / scale`, centered
--         ├ UIScale   Scale = scale
--         └ children
--
-- Scaling the inner frame by `scale` while sizing it `1/scale` larger means it
-- renders at exactly the outer box: **the canvas is still full-bleed**. A child
-- placed with scale units (`UDim2.fromScale(0.5, 0.5)`, an edge anchor) lands on
-- the same fraction of the screen it always did, while a child sized in offsets
-- (every skinned primitive) gets `scale`× pixels. A bare UIScale on a full-scale
-- root frame would shrink the frame itself and drag every edge-anchored element
-- toward the middle.
--
-- The factor comes from the outer frame's own AbsoluteSize, not the camera — so a
-- Canvas inside a fixed-size frame scales as though that frame were the whole
-- screen. That's what makes the device simulator in `Canvas.story.luau` honest,
-- and it means a Canvas nested in a UI Labs panel behaves.
--
-- Mounted once by `src/client/init.client.luau`, so a feature gets this for free
-- and never repeats the pattern. A feature that mounts its OWN ScreenGui (for a
-- DisplayOrder it can't get at the root) wraps that root in a Canvas too — unless
-- it works in absolute screen coordinates, in which case it must not (see
-- docs/game/device-scale.md).
--
-- Don't nest a Canvas inside a Canvas: the inner one would scale already-scaled
-- pixels. Use `ui.ScaleProvider` to vary the factor for a subtree instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ScaleProvider = require(script.Parent.ScaleProvider)
local insets = require(script.Parent.insets)
local scale = require(script.Parent.scale)
local useMeasuredSize = require(script.Parent.useMeasuredSize)
local useViewport = require(script.Parent.useViewport)

export type CanvasProps = {
	-- Force the factor instead of deriving it from the measured box.
	scale: number?,
	zIndex: number?,
	children: { [string]: any }?,
}

return function(props: CanvasProps)
	local inherited = React.useContext(ScaleProvider.Context)
	local screenViewport = useViewport()
	-- Seeded with the screen so the very first render (before the outer frame
	-- has laid out) is already at the right factor on a root-level Canvas.
	local measured, sizeRef = useMeasuredSize(screenViewport)
	local screenInsets = insets.useScreenInsets()
	local deviceIsTouch = React.useMemo(scale.isTouchDevice, {})
	-- A surface above can say what kind of device this is (the story simulates
	-- one); otherwise ask the machine we're running on.
	local isTouch = if inherited then inherited.isTouch else deviceIsTouch

	local box = if scale.isMeasured(measured) then measured else screenViewport
	-- A pinned surface above (ui.ScaleProvider with an explicit scale/viewport)
	-- wins; otherwise derive the factor from the box we were actually given.
	local pinned = if inherited and inherited.locked then inherited.scale else nil
	local factor = props.scale or pinned or scale.compute(box, isTouch)
	-- The canvas is sized `box / factor`, so a zero or negative factor — from a
	-- bad override, or a `minScale` dragged to 0 in the story — would produce an
	-- infinite frame. Fall back to 1:1 rather than to a broken tree.
	if factor <= 0 then
		factor = 1
	end

	local surface: ScaleProvider.Surface = {
		scale = factor,
		viewport = box,
		isTouch = isTouch,
		-- Insets come from the surface above when there is one, so a story can
		-- simulate a topbar the Studio viewport doesn't have.
		insets = if inherited then inherited.insets else screenInsets,
		locked = props.scale ~= nil or pinned ~= nil,
	}

	return React.createElement("Frame", {
		Name = "CanvasRoot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = props.zIndex,
		ref = sizeRef,
	}, {
		Canvas = React.createElement("Frame", {
			Name = "Canvas",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(box.X / factor, box.Y / factor),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			UIScale = React.createElement("UIScale", { Scale = factor }),
			-- Republish the resolved surface so `useViewportScale()` and
			-- `useSafeArea()` inside report the factor this canvas is actually
			-- drawing at, rather than re-deriving it from the camera.
			Content = React.createElement(ScaleProvider.Context.Provider, { value = surface }, props.children),
		}),
	})
end
