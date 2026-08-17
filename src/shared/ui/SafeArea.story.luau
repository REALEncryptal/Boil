--!nonstrict
-- UI Labs story for `ui.SafeArea`.
--
-- Studio's edit-mode viewport reports no GUI inset, so the real topbar can't be
-- seen here — `topbarInset` fakes one through a `ScaleProvider` override, and the
-- striped bar at the top of the frame draws where it would be. Toggle `safeArea`
-- to watch the HUD row slide out from under it.
--
-- Note the per-side controls: a bottom-anchored action bar shouldn't lose room at
-- the top, so SafeArea lets you inset only the edges your content actually
-- touches.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

local REBIRTH_ICON = "rbxassetid://137349421699691"

local function Hud(props)
	local row = React.createElement(ui.Row, {
		gap = 10,
		size = UDim2.new(1, 0, 0, 60),
		horizontalAlignment = Enum.HorizontalAlignment.Left,
		verticalAlignment = Enum.VerticalAlignment.Top,
	}, {
		A = React.createElement(ui.IconButton, { variant = "blue", icon = REBIRTH_ICON, layoutOrder = 1 }),
		B = React.createElement(ui.IconButton, { variant = "green", icon = REBIRTH_ICON, layoutOrder = 2 }),
		Label = React.createElement(ui.Badge, {
			variant = "yellow",
			text = "Coins",
			icon = REBIRTH_ICON,
			size = UDim2.fromOffset(240, 60),
			layoutOrder = 3,
		}),
	})

	if not props.safeArea then
		return row
	end

	return React.createElement(ui.SafeArea, {
		top = props.top,
		bottom = props.bottom,
		left = props.left,
		right = props.right,
		extra = props.extra,
	}, { Row = row })
end

return {
	summary = "Insets a region away from the Roblox topbar. `topbarInset` fakes the inset Studio's edit viewport doesn't have; toggle `safeArea` to see the HUD clear it.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		safeArea = true,
		topbarInset = UILabs.Slider(36, 0, 100, 1),
		extra = UILabs.Slider(0, 0, 40, 1),
		top = true,
		bottom = true,
		left = true,
		right = true,
	},

	story = function(props)
		local c = props.controls
		local insets = { top = c.topbarInset, bottom = 0, left = 0, right = 0 }

		return React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Surface = React.createElement(ui.ScaleProvider, { insets = insets }, {
				Canvas = React.createElement(ui.Canvas, {}, {
					Hud = React.createElement(Hud, {
						safeArea = c.safeArea,
						top = c.top,
						bottom = c.bottom,
						left = c.left,
						right = c.right,
						extra = c.extra,
					}),
				}),
			}),

			-- Stand-in for the real topbar: the strip the engine hands to
			-- Roblox's own chat / menu buttons. It lives OUTSIDE the Canvas
			-- because the real one is a fixed number of *device* pixels no
			-- matter how small the UI is drawn — putting it inside would scale
			-- it along with the HUD and hide the very mismatch SafeArea exists
			-- to absorb.
			Topbar = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, c.topbarInset),
				BackgroundColor3 = Color3.fromRGB(220, 80, 80),
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				ZIndex = 50,
			}),
		})
	end,
}
