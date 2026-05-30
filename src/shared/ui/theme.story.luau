--!nonstrict
-- UI Labs story for the shared design tokens (`ui.theme`).
--
-- Each slider mutates the corresponding field on the shared `theme` table.
-- Every primitive reads `theme.X` on each render, so moving a slider
-- updates the showcase below *and* anything else mounted in the session
-- (other open UI Labs stories, the in-game UI if running). The mutations
-- persist for the current Studio session — once you've settled on values,
-- copy them into `src/shared/ui/theme.luau` to make them permanent.
--
-- The showcase deliberately mounts one of each primitive so you can see
-- the effect of token changes on Button, Badge, Panel, TextField, Text,
-- and Window all at once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

local REBIRTH_ICON = "rbxassetid://137349421699691"

return {
	summary = "Live-tune shared design tokens. Sliders mutate `ui.theme.*` — every primitive picks up the new values on next render. Copy values you like back into `theme.luau` to make them permanent.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		-- Strokes
		strokeThickness = UILabs.Slider(ui.theme.strokeThickness, 0, 16, 1),
		thinStrokeThickness = UILabs.Slider(ui.theme.thinStrokeThickness, 0, 10, 1),
		-- Surface
		glassTransparency = UILabs.Slider(ui.theme.glassTransparency, 0, 1, 0.05),
		-- Padding & spacing
		padding = UILabs.Slider(ui.theme.padding, 0, 40, 1),
		tightPadding = UILabs.Slider(ui.theme.tightPadding, 0, 40, 1),
		itemSpacing = UILabs.Slider(ui.theme.itemSpacing, 0, 40, 1),
		contentSpacing = UILabs.Slider(ui.theme.contentSpacing, 0, 60, 1),
		-- Text
		textSize = UILabs.Slider(ui.theme.textSize, 8, 120, 1),
		buttonTextSize = UILabs.Slider(ui.theme.buttonTextSize, 8, 120, 1),
		badgeTextSize = UILabs.Slider(ui.theme.badgeTextSize, 8, 120, 1),
		inputTextSize = UILabs.Slider(ui.theme.inputTextSize, 8, 120, 1),
		textForegroundOffset = UILabs.Slider(ui.theme.textForegroundOffset, -10, 10, 1),
		-- Hover scale
		hoverScale = UILabs.Slider(ui.theme.hoverScale, 1, 1.5, 0.01),
		pressScale = UILabs.Slider(ui.theme.pressScale, 0.5, 1, 0.01),
		hoverDuration = UILabs.Slider(ui.theme.hoverDuration, 0, 1, 0.01),
		pressDuration = UILabs.Slider(ui.theme.pressDuration, 0, 1, 0.01),
	},

	story = function(props)
		local c = props.controls

		-- Push slider values into the shared theme table. Mutating the
		-- module table is intentional — every primitive reads `theme.X` on
		-- each render, so this is how a live edit propagates.
		ui.theme.strokeThickness = c.strokeThickness
		ui.theme.thinStrokeThickness = c.thinStrokeThickness
		ui.theme.glassTransparency = c.glassTransparency
		ui.theme.padding = c.padding
		ui.theme.tightPadding = c.tightPadding
		ui.theme.itemSpacing = c.itemSpacing
		ui.theme.contentSpacing = c.contentSpacing
		ui.theme.textSize = c.textSize
		ui.theme.buttonTextSize = c.buttonTextSize
		ui.theme.badgeTextSize = c.badgeTextSize
		ui.theme.inputTextSize = c.inputTextSize
		ui.theme.textForegroundOffset = c.textForegroundOffset
		ui.theme.hoverScale = c.hoverScale
		ui.theme.pressScale = c.pressScale
		ui.theme.hoverDuration = c.hoverDuration
		ui.theme.pressDuration = c.pressDuration

		-- Showcase: one of each primitive, stacked into the Window's
		-- scroll body so its content padding / spacing tokens are exercised.
		return React.createElement(ui.Window, {
			title = "Theme Showcase",
			icon = REBIRTH_ICON,
			titleVariant = "purple",
			size = UDim2.fromOffset(720, 560),
			onClose = function() end,
		}, {
			RedButton = React.createElement(ui.Button, {
				variant = "red",
				text = "Red",
				size = UDim2.fromOffset(220, 64),
				layoutOrder = 1,
			}),
			BlueBadge = React.createElement(ui.Badge, {
				variant = "blue",
				text = "Blue badge",
				icon = REBIRTH_ICON,
				size = UDim2.fromOffset(360, 72),
				layoutOrder = 2,
			}),
			YellowBadge = React.createElement(ui.Badge, {
				variant = "yellow",
				text = "Yellow badge",
				icon = REBIRTH_ICON,
				size = UDim2.fromOffset(360, 72),
				layoutOrder = 3,
			}),
			Input = React.createElement(ui.TextField, {
				placeholderText = "Type to test input padding…",
				defaultText = "Hello world",
				size = UDim2.fromOffset(420, 72),
				layoutOrder = 4,
			}),
			ShadowText = React.createElement(ui.Text, {
				text = "Shadow text",
				shadow = true,
				size = UDim2.fromOffset(420, 60),
				layoutOrder = 5,
			}),
			PlainText = React.createElement(ui.Text, {
				text = "Plain text",
				strokeThickness = ui.theme.thinStrokeThickness,
				size = UDim2.fromOffset(420, 60),
				layoutOrder = 6,
			}),
		})
	end,
}
