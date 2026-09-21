--!nonstrict
-- UI Labs story for the Counter primitive — the icon-and-number HUD readout,
-- plus the two hooks that animate it.
--
-- This is the primitive on its own, with NO flying icons: PickupFX is a feature
-- and the kit can't require one, so the story drives `credit()` and `trigger()`
-- on a timer instead of on arrivals. That is exactly what an icon landing does,
-- so the roll and the reaction are reviewable here in isolation.
--
-- HOW TO TEST: flip the `gain` toggle. Either direction fires, so toggling back
-- and forth is a repeat button (UI Labs has no button control). The number
-- should ROLL up to the new value in `iconCount` steps rather than snapping, and
-- punch / flash / vibrate on each step.
--
-- `loss` subtracts instead: the number must drop INSTANTLY, since a player who
-- just paid for something and still sees the old value assumes it failed.
--
-- `stall` fires a gain and then credits NOTHING, so nothing ever pays the lag
-- down. The counter should sit at the old value and then give up and snap to the
-- truth after the catch-up timeout (~2.5s) rather than staying wrong forever.
--
-- For the same counter driven by real flying icons, see CashWidget.story.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

-- Stands in for a feature's own accent. Two counters in the game pick their own;
-- this one just needs a gradient to flash.
local GRADIENT = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 119)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 0)),
})

return {
	summary = "Icon + number HUD readout. Flip `gain` to roll it up; `loss` snaps it down.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		value = UILabs.Slider(16, 0, 100000, 1),
		-- Stands in for a button: every flip is one gain.
		gain = false,
		gainAmount = UILabs.Slider(250, 1, 10000, 1),
		-- How many "icons" pay the gain down, spread over `iconInterval`.
		iconCount = UILabs.Slider(5, 1, 12, 1),
		iconInterval = UILabs.Slider(0.12, 0.02, 0.6, 0.02),
		-- Stands in for a button too: every flip subtracts `gainAmount`.
		loss = false,
		-- Fire a gain but never credit it, to watch the catch-up backstop.
		stall = false,
		icon = UILabs.Choose({ "bandOfCash", "flyingShoe", "rocket", "rebirth" }),
		valueWidth = UILabs.Slider(180, 60, 400, 10),
		role = UILabs.Choose({ "title", "display", "heading", "body" }),
		skin = UILabs.Choose({ "default", "slop", "gem", "flat" }),
		device = UILabs.Choose({ "actual", "desktop", "tablet", "phone" }),
	},

	story = function(props)
		local c = props.controls

		-- The live value: seeded from the slider, moved by each gain/loss. Held
		-- in state rather than derived, so a gain survives the next render
		-- without the slider moving.
		local amount, setAmount = React.useState(c.value)

		local reaction = ui.useCounterReaction()
		local count = ui.useCountUp(amount)

		-- Re-seed when the slider moves. Straight assignment, not an add, so
		-- dragging still reads as "set the value to this".
		React.useEffect(function()
			setAmount(c.value)
		end, { c.value })

		-- Fire on EITHER edge, which is what makes a checkbox usable as a button.
		-- Skips the first run so mounting the story isn't a gain.
		local gainMounted = React.useRef(false)
		React.useEffect(function()
			if not gainMounted.current then
				gainMounted.current = true
				return
			end

			setAmount(function(current)
				return current + c.gainAmount
			end)

			if c.stall then
				-- Declare the icons, then never land them. The backstop is what
				-- should rescue the display.
				count.expect(c.iconCount)
				return
			end

			-- Stands in for PickupFX arrivals: one credit + reaction per "icon".
			count.expect(c.iconCount)
			local cancelled = false
			for index = 1, c.iconCount do
				task.delay(index * c.iconInterval, function()
					if cancelled then
						return
					end
					count.credit()
					reaction.trigger()
				end)
			end
			return function()
				cancelled = true
			end
		end, { c.gain })

		-- Spending. Clamped at zero so the story can't drive the counter
		-- somewhere a server never would.
		local lossMounted = React.useRef(false)
		React.useEffect(function()
			if not lossMounted.current then
				lossMounted.current = true
				return
			end
			setAmount(function(current)
				return math.max(0, current - c.gainAmount)
			end)
		end, { c.loss })

		return React.createElement(ui.ViewportProvider, {
			device = if c.device == "actual" then nil else c.device,
		}, {
			Skin = React.createElement(ui.SkinProvider, {
				skin = if c.skin == "default" then nil else c.skin,
			}, {
				Scaled = React.createElement(ui.Surface, {
					name = "Counter",
					size = UDim2.fromScale(0, 0),
					automaticSize = Enum.AutomaticSize.XY,
					anchorPoint = Vector2.new(0.5, 0.5),
					position = UDim2.fromScale(0.5, 0.5),
				}, {
					Counter = React.createElement(ui.Counter, {
						icon = ui.assets.Icons[c.icon],
						text = tostring(count.displayed),
						reaction = reaction,
						valueWidth = c.valueWidth,
						role = c.role,
						gradient = GRADIENT,
						gradientRotation = 90,
						strokeColor = Color3.fromRGB(83, 83, 83),
					}),
				}),
			}),
		})
	end,
}
