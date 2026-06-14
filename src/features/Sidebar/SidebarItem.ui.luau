--!strict
-- Single entry for the Sidebar: a transparent square ImageButton (click
-- target) containing an inner ImageLabel for the icon art and a Text label
-- overlaid at the bottom. No gem background, no frame chrome.
--
-- Hover affordances:
--   • whole item scales up via useHoverScale (icon + label scale together).
--   • the *icon only* tilts on hover-enter to an angle picked **once at
--     mount** (random magnitude in [HOVER_TILT_MIN_DEG, HOVER_TILT_MAX_DEG],
--     sign 50/50). Each item keeps its signature tilt across every hover;
--     the label stays upright because rotation is on the inner ImageLabel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ui = require(ReplicatedStorage.Shared.Boil).ui
local Constants = require(script.Parent.Constants)

type Props = {
	icon: string,
	label: string,
	iconSize: number?,
	labelSize: number?,
	onClick: (() -> ())?,
	layoutOrder: number?,
}

local DEFAULT_ICON_SIZE = Constants.DEFAULT_ICON_SIZE
local DEFAULT_LABEL_SIZE = Constants.DEFAULT_LABEL_SIZE
local LABEL_BOTTOM_INSET = Constants.LABEL_BOTTOM_INSET
local TILT_MIN = Constants.HOVER_TILT_MIN_DEG
local TILT_MAX = Constants.HOVER_TILT_MAX_DEG

local function randomTilt(): number
	local magnitude = TILT_MIN + math.random() * (TILT_MAX - TILT_MIN)
	if math.random() < 0.5 then
		return -magnitude
	end
	return magnitude
end

return function(props: Props)
	local hover = ui.useHoverScale()
	local size = props.iconSize or DEFAULT_ICON_SIZE
	local labelSize = props.labelSize or DEFAULT_LABEL_SIZE

	-- Per-item signature tilt: rolled once on mount, reused for every hover.
	-- useRef holds the angle across renders without re-running randomTilt().
	local tiltRef = React.useRef(nil :: number?)
	if tiltRef.current == nil then
		tiltRef.current = randomTilt()
	end
	local tilt = tiltRef.current :: number

	local rotation, setRotation = React.useState(0)
	local rotationRef = ui.useTweenedRotation(rotation, {
		easingStyle = Enum.EasingStyle.Back,
		easingDirection = Enum.EasingDirection.Out,
		duration = 0.22,
	})

	local function onEnter()
		setRotation(tilt)
		hover.onEnter()
	end
	local function onLeave()
		setRotation(0)
		hover.onLeave()
	end

	return React.createElement("ImageButton", {
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "",
		AutoButtonColor = false,
		LayoutOrder = props.layoutOrder,
		[React.Event.MouseEnter] = onEnter,
		[React.Event.MouseLeave] = onLeave,
		[React.Event.MouseButton1Down] = hover.onPress,
		[React.Event.MouseButton1Up] = hover.onRelease,
		[React.Event.Activated] = props.onClick,
	}, {
		UIScale = React.createElement("UIScale", {
			Scale = 1,
			ref = hover.scaleRef,
		}),

		-- Icon-only — rotation lives here so the label below isn't affected.
		Icon = React.createElement("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = props.icon,
			ScaleType = Enum.ScaleType.Fit,
			Rotation = 0,
			ref = rotationRef,
			ZIndex = 1,
		}),

		-- Label is anchored to the bottom-center, inset by LABEL_BOTTOM_INSET
		-- so it sits inside the icon's bounds rather than below them. Plain
		-- (non-shadow) Text with a Miter UIStroke for readability over the
		-- icon art. Sibling of Icon — does not inherit the rotation tween.
		Label = React.createElement(ui.Text, {
			text = props.label,
			textSize = labelSize,
			weight = Enum.FontWeight.Heavy,
			strokeThickness = Constants.LABEL_STROKE_THICKNESS,
			yAlignment = Enum.TextYAlignment.Bottom,
			position = UDim2.new(0.5, 0, 1, -LABEL_BOTTOM_INSET),
			anchorPoint = Vector2.new(0.5, 1),
			size = UDim2.new(1, 0, 0, labelSize + 4),
			zIndex = 2,
		}),
	})
end
