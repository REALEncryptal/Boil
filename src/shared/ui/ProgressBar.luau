--!strict
-- Translucent dark glass progress bar. Same outer shape as Panel (black + 0.8
-- transparency + Miter UIStroke) with ClipsDescendants so the bar can't bleed
-- past the rounded outline.
--
-- The inner Bar paints `variant.fill` and a `variant.glow` border stroke (same
-- gem palette Button uses, minus the noise texture and shine). The Bar's Size
-- is tweened to the latest `progress` via `useTweenedUDim2` — the JSX initial
-- size is captured once on mount so React doesn't fight the tween on prop
-- updates (see useTweenedUDim2's docstring).
--
-- Two atmospheric "EdgeGlowBleed" frames at the left and right edges sit at
-- ZIndex 1 (behind the Bar at ZIndex 2). When the bar is short they peek out
-- as a soft halo at the container edges; the full bar covers them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Assets = require(script.Parent.assets)
local Text = require(script.Parent.Text)
local theme = require(script.Parent.theme)
local useTweenedUDim2 = require(script.Parent.useTweenedUDim2)

type Props = {
	-- Clamped to [0, 1].
	progress: number,
	variant: Assets.VariantKey?,
	-- Override the centered label. Pass an empty string to show no text;
	-- pass nil to use the default "N%" formatter.
	text: string?,
	showText: boolean?,
	textSize: number?,

	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	transparency: number?,
	strokeThickness: number?,

	tweenDuration: number?,
	showBleeds: boolean?,
}

local WHITE = Color3.fromRGB(255, 255, 255)
local DEFAULT_SIZE = UDim2.new(1, 0, 0, 60)
local DEFAULT_TWEEN_DURATION = 0.3
local BLEED_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.76875),
	NumberSequenceKeypoint.new(1, 1),
})

return function(props: Props)
	local variantKey = props.variant or "yellow"
	local variant = Assets.Variants[variantKey] or Assets.Variants.yellow
	local clamped = math.clamp(props.progress, 0, 1)
	local strokeThickness = props.strokeThickness or theme.strokeThickness
	local showText = if props.showText == nil then true else props.showText
	local showBleeds = if props.showBleeds == nil then true else props.showBleeds

	-- Capture initial progress once so the JSX Size prop is stable across
	-- renders; the tween hook owns the property after mount.
	local initialProgressRef = React.useRef(clamped)
	local initialSize = UDim2.new(initialProgressRef.current, 0, 1, 0)

	local targetSize = UDim2.new(clamped, 0, 1, 0)
	local sizeRef = useTweenedUDim2(targetSize, {
		property = "Size",
		duration = props.tweenDuration or DEFAULT_TWEEN_DURATION,
	})

	-- Single-color sequence sampled from the variant's glow first stop, so the
	-- bleed reads as a related-but-paler halo for every variant.
	local bleedColor = variant.glow.Keypoints[1].Value
	local bleedColorSequence = ColorSequence.new(bleedColor)

	local children: { [string]: any } = {
		UIStroke = React.createElement("UIStroke", {
			Thickness = strokeThickness,
			LineJoinMode = Enum.LineJoinMode.Miter,
		}),

		Bar = React.createElement("Frame", {
			Size = initialSize,
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 2,
			ref = sizeRef,
		}, {
			UIGradient = React.createElement("UIGradient", {
				Color = variant.fill,
				Rotation = 90,
			}),
			UIStrokeGlow = React.createElement("UIStroke", {
				Color = WHITE,
				Thickness = strokeThickness,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				LineJoinMode = Enum.LineJoinMode.Miter,
			}, {
				UIGradient = React.createElement("UIGradient", {
					Color = variant.glow,
					Rotation = 90,
				}),
			}),
		}),
	}

	if showBleeds then
		children.EdgeGlowBleedLeft = React.createElement("Frame", {
			Size = UDim2.new(0.4, 0, 1, 0),
			Position = UDim2.new(0, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			ColorAndFade = React.createElement("UIGradient", {
				Color = bleedColorSequence,
				Transparency = BLEED_TRANSPARENCY,
				Rotation = 0,
			}),
		})

		children.EdgeGlowBleedRight = React.createElement("Frame", {
			Size = UDim2.new(0.4, 0, 1, 0),
			Position = UDim2.new(1, 0, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			ColorAndFade = React.createElement("UIGradient", {
				Color = bleedColorSequence,
				Transparency = BLEED_TRANSPARENCY,
				Rotation = 180,
			}),
		})
	end

	if showText then
		local displayText: string
		if props.text ~= nil then
			displayText = props.text
		else
			displayText = string.format("%d%%", math.round(clamped * 100))
		end

		children.TextLabel = React.createElement(Text, {
			text = displayText,
			textSize = props.textSize or 50,
			weight = Enum.FontWeight.Bold,
			size = UDim2.fromScale(1, 1),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			zIndex = 3,
			shadow = true,
		})
	end

	return React.createElement("Frame", {
		Size = props.size or DEFAULT_SIZE,
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = props.transparency or theme.glassTransparency,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		ClipsDescendants = true,
	}, children)
end
