--!strict
-- Gem button: a Frame outline + invisible Trigger TextButton over a
-- GemBackground, with a Text label.
--
-- `variant` names what the button MEANS — "primary", "danger", "success" — and
-- the skin picks the palette. The seven legacy colour names still resolve, so
-- `variant = "red"` keeps working.
--
-- The visible layers are non-interactive; the Trigger at ZIndex 10 captures the
-- press and gets its event map from `useHoverScale`, which omits hover on touch
-- devices (see that file for why).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Assets = require(script.Parent.assets)
local GemBackground = require(script.Parent.GemBackground)
local Text = require(script.Parent.Text)
local theme = require(script.Parent.theme)
local tokens = require(script.Parent.tokens)
local useViewport = require(script.Parent.useViewport)
local useHoverScale = require(script.Parent.useHoverScale)

type Props = {
	variant: string?,
	text: string?,
	role: string?,
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
-- disabled. Sits below the Trigger so the overlay never blocks the tree.
local DISABLED_OVERLAY_TRANSPARENCY = 0.45

return function(props: Props)
	local variantKey = theme.resolveVariant(props.variant or "primary")
	local variant = Assets.Variants[variantKey] or Assets.Variants.blue
	-- Rainbow only reads correctly when its stops run horizontally.
	local rotation = if variantKey == "rainbow" then 0 else 90

	local disabled = props.disabled == true
	local hover = useHoverScale()
	-- Reference-space floor that renders to the real-pixel minimum tap target.
	local touchMin = tokens.minTouchReference(useViewport.useScale())

	-- A button is a tap target, so its authored size is floored at the minimum
	-- finger-sized box. Reference pixels, so the floor scales with everything else.
	local size = props.size or theme.buttonSize

	return React.createElement("Frame", {
		Size = size,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex or 2,
	}, {
		MinSize = React.createElement("UISizeConstraint", {
			-- Reference-space floor that renders to the real-pixel minimum at this
			-- viewport's scale. See tokens.minTouchTarget.
			MinSize = Vector2.new(touchMin, touchMin),
		}),

		UIScale = React.createElement("UIScale", { Scale = 1, ref = hover.scaleRef }),

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
				for key, value in hover.events(props.onClick, disabled) do
					trigger[key] = value
				end
				return trigger
			end)()
		),

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
			fillRotation = rotation,
			glowRotation = rotation,
			hasShine = true,
		}),

		-- ZIndex 2 keeps the label above BackgroundDeco (at 1). The Studio
		-- template relies on tree order, which React-Roblox doesn't guarantee
		-- for named children.
		TextLabel = React.createElement(Text, {
			text = props.text or "",
			role = props.role or theme.roles.button,
			textSize = props.textSize,
			weight = props.textWeight or Enum.FontWeight.Bold,
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			zIndex = 2,
			shadow = true,
			truncate = true,
		}),
	})
end
