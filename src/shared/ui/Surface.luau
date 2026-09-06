--!strict
-- Surface — the responsive seam. A transparent container that mounts the one
-- `UIScale` turning reference pixels into screen pixels.
--
-- This is the piece the kit was missing. Author a screen once, at the reference
-- resolution (1280×720, see tokens.luau), wrap it in a Surface, and it is correct
-- on a phone, a laptop and a 4K monitor with no breakpoint and no second layout.
--
--   React.createElement(ui.Surface, {
--       size = UDim2.fromOffset(720, 560),          -- REFERENCE pixels
--       position = UDim2.fromScale(0.5, 0.5),       -- screen-relative
--       anchorPoint = Vector2.new(0.5, 0.5),
--   }, { Body = … })
--
-- Two rules, and they're the whole mental model:
--
--   1. `size` is in REFERENCE pixels (offset). UIScale multiplies the Surface and
--      every descendant about its AnchorPoint, so a centered Surface stays
--      centered and grows. Everything INSIDE is authored against that unscaled
--      box — `UDim2.fromScale(1, 1)` fills it, `theme.space.lg` is 20 there too.
--   2. `position` is screen-relative (scale) so the Surface lands in the same
--      place on every display. Offset positions would drift.
--
-- Don't wrap a full-bleed layer (a click-catcher, an FX overlay) in a Surface —
-- those want `UDim2.fromScale(1, 1)` and no scaling at all. Use a plain Frame and
-- put Surfaces inside it. That is exactly how the root client tree is built: a
-- full-screen Frame holding independently-scaled Surfaces.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local useViewport = require(script.Parent.useViewport)

export type SurfaceProps = {
	-- Reference-pixel size. Offset units; the scale is applied for you.
	size: UDim2?,
	-- Screen-relative placement. Scale units.
	position: UDim2?,
	anchorPoint: Vector2?,
	automaticSize: Enum.AutomaticSize?,
	layoutOrder: number?,
	zIndex: number?,
	-- Multiply the viewport scale. Use for a surface that should read smaller or
	-- larger than the rest of the UI (a subtle toast at 0.85, a hero at 1.2).
	scaleMultiplier: number?,
	-- Replace the viewport scale outright. Escape hatch; prefer scaleMultiplier.
	scale: number?,
	-- Name of the underlying Frame, so the instance tree stays readable in the
	-- Studio explorer when you're debugging a live layout.
	name: string?,
	children: { [string]: any }?,
}

return function(props: SurfaceProps)
	local viewportScale = useViewport.useScale()
	local scale = props.scale or (viewportScale * (props.scaleMultiplier or 1))

	local children: { [string]: any } = {
		UIScale = React.createElement("UIScale", { Scale = scale }),
	}
	if props.children then
		for key, child in props.children do
			children[key] = child
		end
	end

	return React.createElement("Frame", {
		Name = props.name or "Surface",
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		AutomaticSize = props.automaticSize,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, children)
end
