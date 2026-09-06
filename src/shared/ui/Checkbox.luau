--!strict
-- Translucent dark glass checkbox. Same outer shape as Panel/TextField (black +
-- 0.8 transparency + Miter UIStroke) with a UIAspectRatioConstraint that pins
-- it square, an inner 5px UIPadding, and an invisible Trigger TextButton on top
-- that toggles the controlled `checked` prop via `onToggle`.
--
-- The inner Check frame paints the gem variant gradient + glow stroke and is
-- mounted at all times — `props.checked` drives a UIScale tween (0 ↔ 1) so the
-- check pops in with a Back/Out overshoot and snaps out with a fast Quad/In.
-- See CHECK_IN_TWEEN / CHECK_OUT_TWEEN below for the timing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Assets = require(script.Parent.assets)
local theme = require(script.Parent.theme)
local tokens = require(script.Parent.tokens)
local useViewport = require(script.Parent.useViewport)
local useHoverScale = require(script.Parent.useHoverScale)
local useTweenedScale = require(script.Parent.useTweenedScale)

-- Check pop animation. Back/Out overshoots slightly on check-in for the "snap"
-- feel; uncheck pulls in fast with a plain Quad/In so it doesn't undershoot.
local CHECK_IN_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CHECK_OUT_TWEEN = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

type Props = {
	checked: boolean,
	onToggle: ((next: boolean) -> ())?,
	-- Variant used to paint the check fill/glow (defaults to "secondary").
	variant: string?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	transparency: number?,
	strokeThickness: number?,
	-- A `theme.space` step name, or reference pixels.
	padding: (string | number)?,
}

local WHITE = Color3.fromRGB(255, 255, 255)

return function(props: Props)
	local variantKey = theme.resolveVariant(props.variant or "secondary")
	local variant = Assets.Variants[variantKey] or Assets.Variants.white
	local padding = tokens.resolveSpace(theme.space, props.padding, theme.space.xs)
	local strokeThickness = props.strokeThickness or theme.strokeThickness

	local hover = useHoverScale()
	-- Reference-space floor that renders to the real-pixel minimum tap target.
	local touchMin = tokens.minTouchReference(useViewport.useScale())

	-- Pop the check on toggle: scale the inner Check frame from 0 → 1 (in) or
	-- 1 → 0 (out). The UIScale's initial `Scale = 0` means an already-checked
	-- box on mount also plays the pop animation — cosmetic, lasts ~0.22s.
	local checkTarget = if props.checked then 1 else 0
	local checkScaleRef = useTweenedScale(checkTarget, {
		tweenInfo = if props.checked then CHECK_IN_TWEEN else CHECK_OUT_TWEEN,
	})

	local children: { [string]: any } = {
		-- A checkbox is a tap target, so it never renders below finger size.
		MinSize = React.createElement("UISizeConstraint", {
			-- Reference-space floor that renders to the real-pixel minimum at this
			-- viewport's scale. See tokens.minTouchTarget.
			MinSize = Vector2.new(touchMin, touchMin),
		}),

		UIScale = React.createElement("UIScale", {
			Scale = 1,
			ref = hover.scaleRef,
		}),

		UIStroke = React.createElement("UIStroke", {
			Thickness = strokeThickness,
			LineJoinMode = Enum.LineJoinMode.Miter,
		}),

		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, padding),
			PaddingBottom = UDim.new(0, padding),
			PaddingLeft = UDim.new(0, padding),
			PaddingRight = UDim.new(0, padding),
		}),

		UIAspectRatioConstraint = React.createElement("UIAspectRatioConstraint", {}),

		Trigger = React.createElement(
			"TextButton",
			(function()
				local trigger: { [any]: any } = {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Text = "",
					AutoButtonColor = false,
					ZIndex = 10,
				}
				local onToggle = function()
					if props.onToggle then
						props.onToggle(not props.checked)
					end
				end
				for key, value in hover.events(onToggle) do
					trigger[key] = value
				end
				return trigger
			end)()
		),
	}

	-- Always mount the Check frame; visibility is driven by its UIScale
	-- tweening 0 ↔ 1. Mounting it conditionally on `props.checked` would
	-- destroy the instance before the out-tween could play.
	children.Check = React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, {
		-- Initial Scale = 0 so the very first tween animates IN if the
		-- checkbox mounts already checked, and stays invisible if not.
		UIScale = React.createElement("UIScale", {
			Scale = 0,
			ref = checkScaleRef,
		}),
		UIGradient = React.createElement("UIGradient", {
			Color = variant.fill,
			Rotation = 90,
		}),
		UIStroke = React.createElement("UIStroke", {
			Color = WHITE,
			Thickness = strokeThickness,
			LineJoinMode = Enum.LineJoinMode.Miter,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
		}, {
			UIGradient = React.createElement("UIGradient", {
				Color = variant.glow,
				Rotation = 90,
			}),
		}),
	})

	return React.createElement("Frame", {
		Size = props.size or UDim2.fromOffset(theme.checkboxSize, theme.checkboxSize),
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = props.transparency or theme.glassTransparency,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, children)
end
