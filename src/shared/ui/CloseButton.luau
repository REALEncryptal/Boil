--!strict
-- CloseButton — the project's close control, recreated from the Studio instance
-- at StarterGui.ScreenGui.ImageLabel.
--
-- Structure, straight off that instance:
--
--   ImageButton   Image = assets.Icons.close, ScaleType = Fit,
--                 opaque black background (the disc behind the glyph)
--     UICorner    CornerRadius = UDim.new(1, 0)   -- fully round
--     UIStroke    black, 5, LineJoinMode = Round
--     UIAspectRatioConstraint  0.8957, FitWithinMaxSize, DominantAxis = Width
--
-- Two departures from the raw instance, both deliberate:
--
--   * It's an ImageButton, not an ImageLabel, and carries `useHoverScale` — so it
--     grows on hover, shrinks on press, and drops hover on touch like every other
--     control in the kit.
--   * Its minimum size is floored at the real-pixel tap target. A close control
--     is the one button a player must always be able to hit.
--
-- ---------------------------------------------------------------------------
-- Why this is NOT skin-resolved
-- ---------------------------------------------------------------------------
-- Every other visual primitive resolves through SkinProvider, so a skin swap
-- changes it. This one doesn't: it is fixed art, by explicit project decision —
-- "from now on use this as the close button". Swapping skins keeps this button.
--
-- That is a real trade-off against the skin seam, so it's stated here rather
-- than hidden. If a future skin needs its own close control, promote this to a
-- contract key (`Components.CloseButton`) and let each skin implement it; the
-- call sites in the Window implementations won't have to change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Assets = require(script.Parent.assets)
local tokens = require(script.Parent.tokens)
local useHoverScale = require(script.Parent.useHoverScale)
local useViewport = require(script.Parent.useViewport)

-- From the source instance's UIAspectRatioConstraint: slightly taller than wide.
local ASPECT_RATIO = 0.8957
-- The disc behind the glyph, and the outline around it.
local DISC_COLOR = Color3.fromRGB(0, 0, 0)
local STROKE_COLOR = Color3.fromRGB(0, 0, 0)
local STROKE_THICKNESS = 5

export type CloseButtonProps = {
	-- Reference pixels. Square is fine — the aspect constraint fits the art.
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	-- Tint the glyph. The art ships its own colour, so leave unset normally.
	iconColor: Color3?,
	onClick: (() -> ())?,
}

return function(props: CloseButtonProps)
	local hover = useHoverScale()
	local touchMin = tokens.minTouchReference(useViewport.useScale())

	local button: { [any]: any } = {
		Size = props.size or UDim2.fromOffset(60, 60),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		Image = Assets.Icons.close,
		ImageColor3 = props.iconColor,
		ScaleType = Enum.ScaleType.Fit,
		BackgroundColor3 = DISC_COLOR,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}
	for key, value in hover.events(props.onClick) do
		button[key] = value
	end

	return React.createElement("ImageButton", button, {
		-- Reference-space floor that renders to the real-pixel minimum tap target.
		MinSize = React.createElement("UISizeConstraint", {
			MinSize = Vector2.new(touchMin, touchMin),
		}),
		UIScale = React.createElement("UIScale", { Scale = 1, ref = hover.scaleRef }),
		-- A scale radius of 1 rounds to a full circle whatever the size.
		UICorner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
		UIStroke = React.createElement("UIStroke", {
			Color = STROKE_COLOR,
			Thickness = STROKE_THICKNESS,
			LineJoinMode = Enum.LineJoinMode.Round,
		}),
		UIAspectRatioConstraint = React.createElement("UIAspectRatioConstraint", {
			AspectRatio = ASPECT_RATIO,
			AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Width,
		}),
	})
end
