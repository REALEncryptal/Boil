--!nonstrict
-- UI Labs story for the device seam — a device simulator for the whole UI.
--
-- Pick a `device` preset and the story renders a frame of exactly that many
-- pixels, with a Canvas inside it. Because a Canvas derives its factor from its
-- own measured box rather than from the camera, that frame behaves like a real
-- screen of that size: this is what a phone actually gets.
--
-- The frame is drawn at TRUE pixel size, deliberately — a zoomed preview would
-- lie about the one thing you're here to check. The phone and tablet presets fit a
-- normal UI Labs panel; for the desktop presets, drag the panel out wide or just
-- use "Fill panel", which hands the Canvas whatever room the panel has.
--
-- The sliders mutate `ui.scale.*` live (same trick as the Theme story), so you can
-- tune the policy by eye across presets and then copy what you settle on back into
-- `scale.luau`:
--
--   responsiveness — 1 follows the viewport exactly (the design, letterboxed);
--                    0 never scales; between shrinks less than the screen did.
--   min/maxScale   — the clamp, i.e. how bad it's allowed to get either way.
--   touchBoost     — extra size on a touch-only device, because fingers are fat.
--
-- `topbarInset` fakes the Roblox topbar (Studio's edit-mode viewport reports none),
-- so you can see `ui.SafeArea` push the HUD row clear of it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

local REBIRTH_ICON = "rbxassetid://137349421699691"

local FILL_PANEL = "Fill panel"

-- Real-ish Roblox viewport sizes. Phones report far fewer pixels than their
-- physical resolution suggests (the engine renders UI in points), which is exactly
-- why a desktop-authored HUD swallows one.
local DEVICES: { { name: string, size: Vector2? } } = {
	{ name = FILL_PANEL, size = nil },
	{ name = "Phone 800×480", size = Vector2.new(800, 480) },
	{ name = "Phone 1136×640", size = Vector2.new(1136, 640) },
	{ name = "Tablet 1024×768", size = Vector2.new(1024, 768) },
	{ name = "Laptop 1366×768", size = Vector2.new(1366, 768) },
	{ name = "Desktop 1920×1080", size = Vector2.new(1920, 1080) },
}

local function deviceNames(): { string }
	local names = {}
	for _, device in DEVICES do
		table.insert(names, device.name)
	end
	return names
end

local function deviceSize(name: string): Vector2?
	for _, device in DEVICES do
		if device.name == name then
			return device.size
		end
	end
	return nil
end

-- A representative screen: top-anchored HUD chrome (which has to clear the
-- topbar), a centered window (the default for feature UIs), and a corner badge
-- (the edge-anchored case a naive root UIScale would drag toward the middle).
local function SampleScreen()
	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Hud = React.createElement(ui.SafeArea, { extra = 10 }, {
			Row = React.createElement(ui.Row, {
				gap = 10,
				size = UDim2.new(1, 0, 0, 60),
				position = UDim2.fromScale(0, 0),
				horizontalAlignment = Enum.HorizontalAlignment.Left,
				verticalAlignment = Enum.VerticalAlignment.Top,
			}, {
				A = React.createElement(ui.IconButton, { variant = "blue", icon = REBIRTH_ICON, layoutOrder = 1 }),
				B = React.createElement(ui.IconButton, { variant = "green", icon = REBIRTH_ICON, layoutOrder = 2 }),
				C = React.createElement(ui.IconButton, { variant = "purple", icon = REBIRTH_ICON, layoutOrder = 3 }),
			}),
		}),

		Window = React.createElement(ui.Window, {
			title = "Shop",
			icon = REBIRTH_ICON,
			titleVariant = "blue",
			anchorPoint = Vector2.new(0.5, 0.5),
			position = UDim2.fromScale(0.5, 0.5),
			onClose = function() end,
		}, {
			Buy = React.createElement(ui.Button, {
				variant = "green",
				text = "Buy",
				size = UDim2.fromOffset(300, 80),
				layoutOrder = 1,
			}),
			Progress = React.createElement(ui.ProgressBar, {
				variant = "blue",
				progress = 0.45,
				size = UDim2.fromOffset(420, 44),
				layoutOrder = 2,
			}),
		}),

		Corner = React.createElement(ui.Badge, {
			variant = "yellow",
			text = "1.2K",
			icon = REBIRTH_ICON,
			size = UDim2.fromOffset(240, 72),
			anchorPoint = Vector2.new(1, 1),
			position = UDim2.new(1, -20, 1, -20),
		}),
	})
end

return {
	summary = "Device simulator for the scale seam. Pick a device preset — the frame is that many real pixels, and the Canvas inside scales the UI the way it would on that screen. Sliders tune `ui.scale.*` live.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		device = UILabs.Choose(deviceNames()),
		responsiveness = UILabs.Slider(ui.scale.responsiveness, 0, 1, 0.05),
		minScale = UILabs.Slider(ui.scale.minScale, 0.1, 1, 0.05),
		maxScale = UILabs.Slider(ui.scale.maxScale, 1, 3, 0.05),
		touchBoost = UILabs.Slider(ui.scale.touchBoost, 1, 1.6, 0.05),
		isTouch = false,
		topbarInset = UILabs.Slider(0, 0, 100, 1),
		showBounds = true,
	},

	story = function(props)
		local c = props.controls

		-- Push the sliders into the shared policy table. Everything reads
		-- `ui.scale.X` at compute time, so this propagates to the preview below
		-- and to any other mounted UI in the session.
		ui.scale.responsiveness = c.responsiveness
		ui.scale.minScale = c.minScale
		ui.scale.maxScale = c.maxScale
		ui.scale.touchBoost = c.touchBoost

		local size = deviceSize(c.device)
		local simulated = size or Vector2.new(1920, 1080)
		local factor = ui.scale.compute(simulated, c.isTouch)

		local insets = {
			top = c.topbarInset,
			bottom = 0,
			left = 0,
			right = 0,
		}

		-- The readout sits OUTSIDE the canvas on purpose — it reports on the
		-- canvas, so it shouldn't be scaled by it.
		local readout = if size
			then `{c.device}  →  scale {string.format("%.2f", factor)}  ·  canvas {math.round(simulated.X / factor)}×{math.round(simulated.Y / factor)}`
			else "Filling the panel — resize it to see the factor track the box."

		return React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Readout = React.createElement(ui.Text, {
				text = readout,
				textSize = 18,
				size = UDim2.new(1, 0, 0, 24),
				position = UDim2.fromScale(0, 0),
			}),

			Device = React.createElement("Frame", {
				Name = "Device",
				Size = if size then UDim2.fromOffset(size.X, size.Y) else UDim2.new(1, 0, 1, -34),
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				BackgroundColor3 = Color3.fromRGB(20, 20, 24),
				BackgroundTransparency = if c.showBounds then 0.4 else 1,
				BorderSizePixel = 0,
				ClipsDescendants = true,
			}, {
				Bounds = if c.showBounds
					then React.createElement("UIStroke", {
						Thickness = 2,
						Color = Color3.fromRGB(120, 200, 255),
					})
					else nil,

				-- Only insets and device kind are overridden here: no scale /
				-- viewport override, so the Canvas still derives the factor from
				-- the box it measures — which IS the simulated device.
				Surface = React.createElement(ui.ScaleProvider, { insets = insets, isTouch = c.isTouch }, {
					Canvas = React.createElement(ui.Canvas, {}, {
						Screen = React.createElement(SampleScreen),
					}),
				}),
			}),
		})
	end,
}
