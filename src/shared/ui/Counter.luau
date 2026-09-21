--!strict
-- Counter — an icon and a number, no surface behind them. The HUD readout shape:
-- a money balance, a walk speed, an ammo count.
--
-- Deliberately not a `ui.Badge`: a Badge is an icon and text inside a skinned
-- pill, and this reads as bare HUD chrome over the world. `ui.Icon` + a skinned
-- Text is the same pair without the surface.
--
--   local react = ui.useCounterReaction()
--   local count = ui.useCountUp(props.amount)
--
--   React.createElement(ui.Counter, {
--       icon = ui.assets.Icons.bandOfCash,
--       text = format(count.displayed),
--       reaction = react,
--       gradient = MONEY_GRADIENT,
--   })
--
-- The caller owns the two hooks rather than the component owning them, because
-- the caller is what fires the flying icons: it needs `react.trigger` and
-- `count.credit` in its PickupFX arrival handler, and `react.anchorRef` is the
-- destination those icons fly to.
--
-- ---------------------------------------------------------------------------
-- Why this is NOT skin-resolved
-- ---------------------------------------------------------------------------
-- Like Stack/Row/Grid/Slot, this is structure — no skin lists it, so there is
-- nothing for one to draw. But the NUMBER inside it must still be a skinned
-- `Text`, so the counter keeps the typography and stroke treatment of every
-- other label when the skin changes. That's the one resolve below, and it's the
-- same two lines `init.luau`'s `semantic()` does. Safe from the skin cycle
-- because no skin implements `Counter`: nothing under skins/ requires this file.
--
-- ---------------------------------------------------------------------------
-- Frame layout, and what each one is for
-- ---------------------------------------------------------------------------
--   Anchor  — the PickupFX destination. Never moves, so icons don't chase a
--             vibrating target and visibly wander on approach.
--   Row     — icon and number, side by side.
--   Slot    — the Row's layout child, holding the number's fixed width.
--   Shaker  — wraps the NUMBER only, and carries both Rotation and the UIScale.
--             The icon deliberately sits outside it: shaking the whole counter
--             reads as the HUD glitching, where shaking just the number reads
--             as the number reacting to what landed.
--
-- Slot and Shaker look redundant and are not: **a UIListLayout zeroes the
-- Rotation of children it manages**, so the rotating frame has to sit one level
-- BELOW the Row's layout. Collapse them and the shake silently stops working
-- while the scale keeps going — `Rotation` still reads back as what you set, but
-- `AbsoluteRotation` is 0. That cost real debugging time; don't merge them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local Icon = require(script.Parent.Icon)
local Row = require(script.Parent.Row)
local SkinProvider = require(script.Parent.SkinProvider)
local useCounterReaction = require(script.Parent.useCounterReaction)

-- The counter's line height. The icon is a square of the same height, so one
-- number sizes the whole widget. REFERENCE pixels (1280x720).
local DEFAULT_LINE_HEIGHT = 52
-- Width of the value box. Fixed, not auto — a skin may render Text with
-- TextScaled (slop does), and TextScaled with AutomaticSize.X collapses the
-- label to a pixel wide. A fixed box means the number scales down inside it
-- instead of clipping, so a long value still reads and the HUD never reflows as
-- digits change. Left-aligned so the slack falls inward, away from the screen edge.
local DEFAULT_VALUE_WIDTH = 180
local DEFAULT_FLASH_COLOR = Color3.fromRGB(255, 255, 255)

export type CounterProps = {
	-- Image for the glyph beside the number. `ui.assets.Icons.<key>` — never a
	-- raw rbxassetid at the call site.
	icon: string,
	-- Already formatted. The counter renders a string, so the feature owns how
	-- its number reads ("$14.25K", "16").
	text: string,
	-- From `ui.useCounterReaction()`. The caller holds it so it can trigger the
	-- reaction from its own PickupFX arrival handler.
	reaction: useCounterReaction.Handle,

	lineHeight: number?,
	valueWidth: number?,
	-- Type role for the number. A role, not a size — the skin picks the number.
	role: string?,

	-- The number's treatment. Raw colours at a call site are what the theme
	-- normally exists to prevent; they're a prop here because a counter's accent
	-- is one readout's identity, not a property of every label in the game, and
	-- promoting it to a skin token would oblige every skin to have an opinion
	-- about money. `role` and `shadow` still come from the skin.
	gradient: ColorSequence?,
	gradientRotation: number?,
	-- Outline COLOUR only. Thickness stays the skin's, so the counter's outline
	-- keeps the same weight as every other label.
	strokeColor: Color3?,
	-- What the gradient lerps toward as each icon lands.
	flashColor: Color3?,

	layoutOrder: number?,
}

-- Lerp every stop of `sequence` toward a flat colour. alpha 0 returns the
-- sequence untouched, so the idle path allocates nothing.
local function towards(sequence: ColorSequence, target: Color3, alpha: number): ColorSequence
	if alpha <= 0 then
		return sequence
	end

	local keypoints: { ColorSequenceKeypoint } = {}
	for index, keypoint in sequence.Keypoints do
		keypoints[index] = ColorSequenceKeypoint.new(keypoint.Time, keypoint.Value:Lerp(target, alpha))
	end
	return ColorSequence.new(keypoints)
end
return function(props: CounterProps)
	local height = props.lineHeight or DEFAULT_LINE_HEIGHT
	local reaction = props.reaction

	-- The skinned Text implementation, resolved the same way init.luau's
	-- `semantic()` wrapper does. See the header for why this file may.
	local Text = SkinProvider.skins.resolve(SkinProvider.useSkin(), "Text")

	local gradient = if props.gradient
		then towards(props.gradient, props.flashColor or DEFAULT_FLASH_COLOR, reaction.flash)
		else nil

	local value = React.createElement(Text, {
		text = props.text,
		role = props.role or "title",
		weight = Enum.FontWeight.Heavy,
		xAlignment = Enum.TextXAlignment.Left,
		-- Fills the Shaker, which is what carries the fixed width.
		size = UDim2.fromScale(1, 1),
		-- A counter's value is one token; wrapping it mid-number is never the
		-- right answer.
		wrap = false,
		shadow = true,
		gradient = gradient,
		gradientRotation = props.gradientRotation,
		strokeColor = props.strokeColor,
	})

	local content = React.createElement(Row, {
		gap = "sm",
		size = UDim2.fromOffset(0, height),
		automaticSize = Enum.AutomaticSize.X,
		horizontalAlignment = Enum.HorizontalAlignment.Left,
	}, {
		Icon = React.createElement(Icon, {
			image = props.icon,
			size = UDim2.fromOffset(height, height),
			layoutOrder = 1,
		}),

		-- Two frames, and the split is load-bearing — see the header.
		ValueSlot = React.createElement("Frame", {
			Size = UDim2.fromOffset(props.valueWidth or DEFAULT_VALUE_WIDTH, height),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 2,
		}, {
			Shaker = React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ref = reaction.shakeRef,
			}, {
				Scale = React.createElement("UIScale", { Scale = 1, ref = reaction.scaleRef }),
				Value = value,
			}),
		}),
	})

	return React.createElement("Frame", {
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ref = reaction.anchorRef,
	}, {
		Content = content,
	})
end
