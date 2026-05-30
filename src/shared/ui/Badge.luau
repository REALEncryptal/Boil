--!strict
-- Gem-style badge: a horizontal icon-and-text card. Uses GemBackground
-- (without shine, with a faded-glow transparency) and Text (shadow enabled).
--
-- Blue badges intentionally use a different palette than blue Buttons —
-- see Assets.BadgeVariants. Other variants fall back to Assets.Variants.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Assets = require(script.Parent.assets)
local GemBackground = require(script.Parent.GemBackground)
local Text = require(script.Parent.Text)
local theme = require(script.Parent.theme)

type Props = {
	variant: Assets.VariantKey?,
	text: string?,
	textSize: number?,
	icon: string?, -- rbxassetid:// for the leading icon; nil hides the slot
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
}

local PLACEHOLDER_IMAGE = "rbxasset://textures/ui/GuiImagePlaceholder.png"

return function(props: Props)
	local variantKey = props.variant or "blue"
	local variant = Assets.BadgeVariants[variantKey]
		or Assets.Variants[variantKey]
		or Assets.Variants.blue

	local innerChildren: { [string]: any } = {
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, theme.tightPadding),
			PaddingBottom = UDim.new(0, theme.tightPadding),
			PaddingLeft = UDim.new(0, theme.padding),
			PaddingRight = UDim.new(0, theme.padding),
		}),
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, theme.itemSpacing),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		}),

		TextLabel = React.createElement(Text, {
			text = props.text or "",
			textSize = props.textSize or theme.badgeTextSize,
			weight = Enum.FontWeight.Heavy,
			xAlignment = Enum.TextXAlignment.Left,
			size = UDim2.fromOffset(200, 50),
			layoutOrder = 2,
			shadow = true,
		}),
	}

	if props.icon then
		innerChildren.IconImage = React.createElement("ImageLabel", {
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0, 0.5),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = props.icon,
		}, {
			UIAspectRatioConstraint = React.createElement("UIAspectRatioConstraint", {}),
		})
	end

	return React.createElement("ImageLabel", {
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = PLACEHOLDER_IMAGE,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, {
		InnerContainer = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, innerChildren),

		BackgroundDeco = React.createElement(GemBackground, {
			fillGradient = variant.fill,
			glowGradient = variant.glow,
			glowTransparency = Assets.BADGE_GLOW_TRANSPARENCY,
			fillRotation = 85,
			glowRotation = 85,
			tileSize = theme.badgeTileSize,
			hasShine = false,
		}),
	})
end
