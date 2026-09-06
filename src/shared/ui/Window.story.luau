--!nonstrict
-- UI Labs story for Window — the kit's most-composed primitive, and until now
-- the only one shipping without a story.
--
-- `size` is in REFERENCE pixels: the Window mounts its own `ui.Surface`, so the
-- same 760x520 is ~1140x780 on a 1080p monitor and shrinks to fit a phone. Flip
-- `device` to see it. That is the fix for the old fixed 797x595, which simply
-- overflowed a phone screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

local ICON = "rbxassetid://137349421699691"

return {
	summary = "Window at the reference resolution, scaled by its own Surface. Switch `device` to preview a phone; `contentSpacing` and `contentPadding` take space-step names.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		title = "Inventory",
		device = UILabs.Choose({ "actual", "desktop", "tablet", "phone" }),
		skin = UILabs.Choose({ "gem", "flat" }),
		titleVariant = UILabs.Choose({ "primary", "success", "warning", "danger", "special", "neutral" }),
		width = UILabs.Slider(760, 320, 1200, 10),
		height = UILabs.Slider(520, 240, 700, 10),
		contentSpacing = UILabs.Choose({ "md", "xs", "sm", "lg", "xl" }),
		contentPadding = UILabs.Choose({ "lg", "sm", "md", "xl" }),
		showTopBarExtra = false,
		rows = UILabs.Slider(5, 0, 12, 1),
	},

	story = function(props)
		local c = props.controls

		local rows: { [string]: any } = {}
		for i = 1, c.rows do
			rows[`Row{i}`] = React.createElement(ui.Panel, {
				size = UDim2.new(1, 0, 0, 56),
				padding = "md",
				layoutOrder = i,
			}, {
				Label = React.createElement(ui.Text, {
					text = `Slot {i}`,
					role = "body",
					xAlignment = Enum.TextXAlignment.Left,
					truncate = true,
					size = UDim2.new(1, -90, 1, 0),
					position = UDim2.new(0, 0, 0.5, 0),
					anchorPoint = Vector2.new(0, 0.5),
				}),
				Count = React.createElement(ui.Text, {
					text = `x{i * 3}`,
					role = "label",
					xAlignment = Enum.TextXAlignment.Right,
					size = UDim2.new(0, 80, 1, 0),
					position = UDim2.new(1, 0, 0.5, 0),
					anchorPoint = Vector2.new(1, 0.5),
				}),
			})
		end

		-- Long copy proves wrapping: before `wrap` existed this clipped mid-word.
		rows.Blurb = React.createElement(ui.Text, {
			text = "Content wraps inside the window body instead of clipping, and the"
				.. " scroll canvas grows to fit whatever the feature mounts here.",
			role = "label",
			color = ui.theme.mutedText,
			wrap = true,
			xAlignment = Enum.TextXAlignment.Left,
			size = UDim2.new(1, 0, 0, 56),
			layoutOrder = 100,
		})

		local window = React.createElement(ui.Window, {
			title = c.title,
			icon = ICON,
			titleVariant = c.titleVariant,
			size = UDim2.fromOffset(c.width, c.height),
			contentSpacing = c.contentSpacing,
			contentPadding = {
				top = c.contentPadding,
				bottom = c.contentPadding,
				left = c.contentPadding,
				right = c.contentPadding,
			},
			onClose = function() end,
			topBarExtra = if c.showTopBarExtra
				then React.createElement(ui.Text, {
					text = "4,200",
					role = "heading",
					xAlignment = Enum.TextXAlignment.Right,
					shadow = true,
				})
				else nil,
		}, rows)

		local skinned = React.createElement(ui.SkinProvider, { skin = c.skin }, { Window = window })

		if c.device == "actual" then
			return skinned
		end
		return React.createElement(ui.ViewportProvider, { device = c.device }, { Skinned = skinned })
	end,
}
