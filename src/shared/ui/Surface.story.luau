--!nonstrict
-- UI Labs story for Surface — the responsive seam.
--
-- The point of this story is the comparison: the same content authored once at
-- the reference resolution, rendered at each device's scale. Nothing inside the
-- Surface knows what device it is on; only the UIScale changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

local ICON = "rbxassetid://137349421699691"

return {
	summary = "Reference pixels in, screen pixels out. `device` previews another device's scale; the panel is authored at one size and never re-laid-out.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		device = UILabs.Choose({ "actual", "desktop", "tablet", "phone", "console" }),
		width = UILabs.Slider(420, 160, 900, 10),
		height = UILabs.Slider(260, 120, 600, 10),
		scaleMultiplier = UILabs.Slider(1, 0.5, 1.6, 0.05),
	},

	story = function(props)
		local c = props.controls
		local device = if c.device == "actual" then nil else c.device
		local scale = ui.viewport.scaleFor(ui.viewport.size(), device)

		local panel = React.createElement(ui.Surface, {
			size = UDim2.fromOffset(c.width, c.height),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			scaleMultiplier = c.scaleMultiplier,
		}, {
			Body = React.createElement(ui.Panel, { padding = "lg" }, {
				Stack = React.createElement(ui.Stack, {
					gap = "md",
					horizontalAlignment = Enum.HorizontalAlignment.Left,
				}, {
					Title = React.createElement(ui.Text, {
						text = "Authored once",
						role = "title",
						xAlignment = Enum.TextXAlignment.Left,
						size = UDim2.new(1, 0, 0, ui.theme.type.title + 6),
						layoutOrder = 1,
					}),
					Detail = React.createElement(ui.Text, {
						text = `{c.width}x{c.height} reference · {math.round(c.width * scale * c.scaleMultiplier)}x`
							.. `{math.round(c.height * scale * c.scaleMultiplier)} on screen`,
						role = "label",
						color = ui.theme.mutedText,
						xAlignment = Enum.TextXAlignment.Left,
						wrap = true,
						size = UDim2.new(1, 0, 0, ui.theme.type.label * 2),
						layoutOrder = 2,
					}),
					Badge = React.createElement(ui.Badge, {
						variant = "success",
						text = "4,200",
						icon = ICON,
						size = UDim2.new(1, 0, 0, 56),
						layoutOrder = 3,
					}),
					Action = React.createElement(ui.Button, {
						variant = "primary",
						text = "Claim",
						size = UDim2.new(1, 0, 0, 56),
						layoutOrder = 4,
					}),
				}),
			}),
		})

		if device == nil then
			return panel
		end
		return React.createElement(ui.ViewportProvider, { device = device }, { Panel = panel })
	end,
}
