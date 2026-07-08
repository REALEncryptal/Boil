--!strict
-- Gem-style button: a Frame outline + invisible Trigger TextButton on top of
-- a GemBackground (with shine) and a Text label (shadow enabled).
--
-- Click handling is wired via the `onClick` prop. The visible visuals are
-- non-interactive — the Trigger at ZIndex 10 captures the press.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Assets = require(script.Parent.assets)
local GemBackground = require(script.Parent.GemBackground)
local Text = require(script.Parent.Text)
local theme = require(script.Parent.theme)
local useHoverScale = require(script.Parent.useHoverScale)

type Props = {
	variant: Assets.VariantKey?,
	text: string?,
	textSize: number?,
	textWeight: Enum.FontWeight?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	-- Dims the button under a dark overlay and ignores clicks/hover.
	disabled: boolean?,
	onClick: (() -> ())?,
}

-- Semi-transparent black wash drawn over the gem (and its label) while
-- disabled. Sits below the Trigger so the overlay never blocks the tree,
-- only the look.
local DISABLED_OVERLAY_TRANSPARENCY = 0.45

return function(props: Props)
	local variantKey = props.variant or "red"
	local variant = Assets.Variants[variantKey] or Assets.Variants.red
	local text = props.text or ""
	-- Rainbow palette only reads correctly when stops run horizontally.
	local fillRotation = if variantKey == "rainbow" then 0 else 90
	local glowRotation = if variantKey == "rainbow" then 0 else 90

	local disabled = props.disabled == true

	local hover = useHoverScale()

	return React.createElement("Frame", {
		Size = props.size or theme.buttonSize,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex or 2,
	}, {
		UIScale = React.createElement("UIScale", {
			Scale = 1,
			ref = hover.scaleRef,
		}),

		UIStroke = React.createElement("UIStroke", {
			Thickness = theme.strokeThickness,
			LineJoinMode = Enum.LineJoinMode.Miter,
		}),

		Trigger = React.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			TextColor3 = Color3.fromRGB(0, 0, 0),
			TextSize = 14,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Regular,
				Enum.FontStyle.Normal
			),
			ZIndex = 10,
			[React.Event.MouseEnter] = if disabled then nil else hover.onEnter,
			[React.Event.MouseLeave] = if disabled then nil else hover.onLeave,
			[React.Event.MouseButton1Down] = if disabled then nil else hover.onPress,
			[React.Event.MouseButton1Up] = if disabled then nil else hover.onRelease,
			[React.Event.Activated] = if disabled then nil else props.onClick,
		}),

		DisabledOverlay = if disabled
			then React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = DISABLED_OVERLAY_TRANSPARENCY,
				BorderSizePixel = 0,
				ZIndex = 9,
			})
			else nil,

		BackgroundDeco = React.createElement(GemBackground, {
			fillGradient = variant.fill,
			glowGradient = variant.glow,
			fillRotation = fillRotation,
			glowRotation = glowRotation,
			hasShine = true,
		}),

		-- ZIndex = 2 keeps the label above BackgroundDeco (at ZIndex 1).
		-- Template uses 1 for both and relies on Studio tree order, which
		-- React-Roblox doesn't guarantee for named children.
		TextLabel = React.createElement(Text, {
			text = text,
			textSize = props.textSize or theme.buttonTextSize,
			weight = props.textWeight or Enum.FontWeight.Bold,
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			zIndex = 2,
			shadow = true,
		}),
	})
end
