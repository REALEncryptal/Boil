--!strict
-- Gem-style icon button: same outer stack as Button (Frame outline + invisible
-- Trigger TextButton + GemBackground with shine + hover scale) but with an
-- ImageLabel where the text label would be. Use this for HUD action bars and
-- anywhere you want a square gem with no copy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Assets = require(script.Parent.assets)
local GemBackground = require(script.Parent.GemBackground)
local theme = require(script.Parent.theme)
local tokens = require(script.Parent.tokens)
local useViewport = require(script.Parent.useViewport)
local useHoverScale = require(script.Parent.useHoverScale)

type Props = {
	variant: string?,
	icon: string?, -- rbxassetid:// for the icon; falls back to a placeholder.
	iconColor: Color3?,
	-- ImageLabel size relative to the button (0..1). Default leaves an 8px
	-- visual margin between the icon and the gem outline.
	iconScale: number?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	onClick: (() -> ())?,
	-- Named slot mounted inside the frame; see contract.IconButtonProps.
	children: { [string]: any }?,
}

local PLACEHOLDER_IMAGE = "rbxasset://textures/ui/GuiImagePlaceholder.png"
local WHITE = Color3.fromRGB(255, 255, 255)

return function(props: Props)
	local variantKey = theme.resolveVariant(props.variant or "primary")
	local variant = Assets.Variants[variantKey] or Assets.Variants.blue
	local rotation = if variantKey == "rainbow" then 0 else 90
	local iconScale = props.iconScale or 0.6

	local hover = useHoverScale()
	-- Reference-space floor that renders to the real-pixel minimum tap target.
	local touchMin = tokens.minTouchReference(useViewport.useScale())

	return React.createElement("Frame", {
		Size = props.size or theme.buttonSize,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex or 2,
	}, {
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
			Thickness = theme.strokeThickness,
			LineJoinMode = Enum.LineJoinMode.Miter,
		}),

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
				for key, value in hover.events(props.onClick) do
					trigger[key] = value
				end
				return trigger
			end)()
		),

		BackgroundDeco = React.createElement(GemBackground, {
			fillGradient = variant.fill,
			glowGradient = variant.glow,
			fillRotation = rotation,
			glowRotation = rotation,
			hasShine = true,
		}),

		Content = if props.children
			then React.createElement("Frame", {
				-- Transparent pass-through so caller content is one keyed child
				-- rather than merged into this component's own children, which
				-- would let a caller's key collide with `IconImage`.
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 3,
			}, props.children)
			else nil,

		IconImage = React.createElement("ImageLabel", {
			Size = UDim2.fromScale(iconScale, iconScale),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = props.icon or PLACEHOLDER_IMAGE,
			ImageColor3 = props.iconColor or WHITE,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 2,
		}, {
			UIAspectRatioConstraint = React.createElement("UIAspectRatioConstraint", {}),
		}),
	})
end
