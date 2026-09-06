--!nonstrict
-- UI Labs story for the design tokens — the place to settle how big everything is.
--
-- Sliders mutate the shared `theme` table in place. Every primitive reads
-- `theme.type.*` / `theme.space.*` on each render, so moving a slider updates
-- this story AND anything else mounted in the session (other stories, the live
-- game if it's running). Changes last for the Studio session; once you like a
-- value, copy it into `src/shared/ui/tokens.luau` (shared defaults) or
-- `src/shared/ui/theme.luau` (gem-only) to keep it.
--
-- ---------------------------------------------------------------------------
-- Two knobs do most of the work
-- ---------------------------------------------------------------------------
--   Type scale   — multiplies all six type roles at once. Start here: if the UI
--                  reads small or shouty as a whole, this is the fix, and it
--                  keeps the ratios between roles intact.
--   Space scale  — same idea for the six spacing steps.
--
-- The per-role sliders below are for adjusting ONE role relative to the others
-- (a title that's fighting its window, say). Reach for them second.
--
-- ---------------------------------------------------------------------------
-- Sizes here are REFERENCE pixels (1280x720)
-- ---------------------------------------------------------------------------
-- `Preview device` re-renders the showcase at another device's scale, so you can
-- see what a phone actually gets without leaving the desktop. Numbers on the
-- ruler show `reference → screen` at the previewed scale.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

local ICON = "rbxassetid://137349421699691"

local TYPE_ROLES = { "display", "title", "heading", "body", "label", "caption" }
local SPACE_STEPS = { "xs", "sm", "md", "lg", "xl", "xxl" }

-- Base values captured once at module load, so the multipliers always scale the
-- ORIGINAL ladder rather than compounding on the last frame's result.
local BASE_TYPE = table.clone(ui.tokens.type)
local BASE_SPACE = table.clone(ui.tokens.space)

-- One row of the type ruler: the role name, its numbers, and a sample set at it.
local function typeRow(role: string, order: number, scale: number)
	local size = ui.theme.type[role]
	return React.createElement(ui.Row, {
		gap = "md",
		size = UDim2.new(1, 0, 0, math.max(size, 24) + 8),
		layoutOrder = order,
		horizontalAlignment = Enum.HorizontalAlignment.Left,
	}, {
		Meta = React.createElement(ui.Text, {
			text = `{role}  {math.round(size)} → {math.round(size * scale)}px`,
			role = "caption",
			color = ui.theme.mutedText,
			xAlignment = Enum.TextXAlignment.Left,
			size = UDim2.fromOffset(240, 0),
			layoutOrder = 1,
		}),
		Sample = React.createElement(ui.Text, {
			text = "Rebirth 12  ·  Gems 4,200",
			role = role,
			xAlignment = Enum.TextXAlignment.Left,
			truncate = true,
			size = UDim2.new(1, -252, 1, 0),
			layoutOrder = 2,
		}),
	})
end

-- One swatch of the space ruler: a bar as wide as the step.
local function spaceRow(step: string, order: number, scale: number)
	local value = ui.theme.space[step]
	return React.createElement(ui.Row, {
		gap = "md",
		size = UDim2.new(1, 0, 0, 28),
		layoutOrder = order,
		horizontalAlignment = Enum.HorizontalAlignment.Left,
	}, {
		Meta = React.createElement(ui.Text, {
			text = `{step}  {math.round(value)} → {math.round(value * scale)}px`,
			role = "caption",
			color = ui.theme.mutedText,
			xAlignment = Enum.TextXAlignment.Left,
			size = UDim2.fromOffset(240, 0),
			layoutOrder = 1,
		}),
		Bar = React.createElement("Frame", {
			Size = UDim2.fromOffset(math.max(value, 1), 14),
			BackgroundColor3 = ui.theme.textColor,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			LayoutOrder = 2,
		}),
	})
end

return {
	summary = "Settle how big everything is. `Type scale` and `Space scale` move the whole ladder; the per-role sliders nudge one role. `Preview device` shows what a phone gets. Copy values you like into tokens.luau.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		-- The two you want first.
		typeScale = UILabs.Slider(1, 0.6, 1.8, 0.05),
		spaceScale = UILabs.Slider(1, 0.5, 2, 0.05),
		previewDevice = UILabs.Choose({ "actual", "desktop", "tablet", "phone" }),

		-- Per-role type, as a multiplier on that role alone.
		display = UILabs.Slider(1, 0.5, 2, 0.05),
		title = UILabs.Slider(1, 0.5, 2, 0.05),
		heading = UILabs.Slider(1, 0.5, 2, 0.05),
		body = UILabs.Slider(1, 0.5, 2, 0.05),
		label = UILabs.Slider(1, 0.5, 2, 0.05),
		caption = UILabs.Slider(1, 0.5, 2, 0.05),

		-- Surface details.
		strokeThickness = UILabs.Slider(ui.theme.strokeThickness, 0, 16, 1),
		thinStrokeThickness = UILabs.Slider(ui.theme.thinStrokeThickness, 0, 10, 1),
		glassTransparency = UILabs.Slider(ui.theme.glassTransparency, 0, 1, 0.05),

		-- Motion.
		hoverScale = UILabs.Slider(ui.theme.hoverScale, 1, 1.5, 0.01),
		pressScale = UILabs.Slider(ui.theme.pressScale, 0.5, 1, 0.01),
	},

	story = function(props)
		local c = props.controls

		-- Mutating the shared module table is deliberate: every primitive reads
		-- these on render, so one assignment re-pitches the whole kit live.
		for _, role in TYPE_ROLES do
			ui.theme.type[role] = math.round(BASE_TYPE[role] * c.typeScale * (c[role] or 1))
		end
		for _, step in SPACE_STEPS do
			ui.theme.space[step] = math.round(BASE_SPACE[step] * c.spaceScale)
		end
		ui.theme.strokeThickness = c.strokeThickness
		ui.theme.thinStrokeThickness = c.thinStrokeThickness
		ui.theme.glassTransparency = c.glassTransparency
		ui.theme.motion.hoverScale = c.hoverScale
		ui.theme.motion.pressScale = c.pressScale

		local device = if c.previewDevice == "actual" then nil else c.previewDevice
		local scale = if device
			then ui.viewport.scaleFor(ui.viewport.size(), device)
			else ui.viewport.scaleFor(ui.viewport.size())

		local showcase = React.createElement(ui.Window, {
			title = "Type & space",
			icon = ICON,
			titleVariant = "special",
			size = UDim2.fromOffset(760, 560),
			onClose = function() end,
		}, {
			TypeHeader = React.createElement(ui.Text, {
				text = `TYPE  ·  {c.previewDevice} @ {string.format("%.2f", scale)}x`,
				role = "caption",
				color = ui.theme.mutedText,
				xAlignment = Enum.TextXAlignment.Left,
				size = UDim2.new(1, 0, 0, 22),
				layoutOrder = 1,
			}),
			Display = typeRow("display", 2, scale),
			Title = typeRow("title", 3, scale),
			Heading = typeRow("heading", 4, scale),
			Body = typeRow("body", 5, scale),
			Label = typeRow("label", 6, scale),
			Caption = typeRow("caption", 7, scale),

			Wrapped = React.createElement(ui.Text, {
				text = "Body copy wraps now instead of clipping, which is what lets a"
					.. " description sit in a window without being cut off mid-word.",
				role = "body",
				color = ui.theme.mutedText,
				wrap = true,
				xAlignment = Enum.TextXAlignment.Left,
				size = UDim2.new(1, 0, 0, 64),
				layoutOrder = 8,
			}),

			SpaceHeader = React.createElement(ui.Text, {
				text = "SPACE",
				role = "caption",
				color = ui.theme.mutedText,
				xAlignment = Enum.TextXAlignment.Left,
				size = UDim2.new(1, 0, 0, 22),
				layoutOrder = 9,
			}),
			Xs = spaceRow("xs", 10, scale),
			Sm = spaceRow("sm", 11, scale),
			Md = spaceRow("md", 12, scale),
			Lg = spaceRow("lg", 13, scale),
			Xl = spaceRow("xl", 14, scale),
			Xxl = spaceRow("xxl", 15, scale),

			ControlsHeader = React.createElement(ui.Text, {
				text = "IN CONTEXT",
				role = "caption",
				color = ui.theme.mutedText,
				xAlignment = Enum.TextXAlignment.Left,
				size = UDim2.new(1, 0, 0, 22),
				layoutOrder = 16,
			}),
			Buttons = React.createElement(ui.Row, {
				gap = "md",
				size = UDim2.new(1, 0, 0, 64),
				layoutOrder = 17,
				horizontalAlignment = Enum.HorizontalAlignment.Left,
			}, {
				Primary = React.createElement(ui.Button, {
					variant = "primary",
					text = "Claim",
					size = UDim2.fromOffset(180, 60),
					layoutOrder = 1,
				}),
				Danger = React.createElement(ui.Button, {
					variant = "danger",
					text = "Reset",
					size = UDim2.fromOffset(180, 60),
					layoutOrder = 2,
				}),
				Check = React.createElement(ui.Checkbox, { checked = true, variant = "success", layoutOrder = 3 }),
			}),
			BadgeRow = React.createElement(ui.Badge, {
				variant = "warning",
				text = "4,200 Gems",
				icon = ICON,
				size = UDim2.new(1, 0, 0, 72),
				layoutOrder = 18,
			}),
			Input = React.createElement(ui.TextField, {
				placeholderText = "Input at the body role…",
				size = UDim2.new(1, 0, 0, 64),
				layoutOrder = 19,
			}),
		})

		-- Previewing a device means overriding the viewport the Surfaces read, so
		-- the whole showcase renders at that device's scale.
		if device then
			return React.createElement(ui.ViewportProvider, { device = device }, { Showcase = showcase })
		end
		return showcase
	end,
}
