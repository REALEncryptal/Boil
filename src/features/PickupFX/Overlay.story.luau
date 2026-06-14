--!nonstrict
-- UI Labs story for the PickupFX Overlay.
--
-- Click "Fire" to spawn a burst from the button toward the target badge.
-- Drag the count slider to change how many icons spawn per click. Watch the
-- bezier curves arc both ways and the stagger spread the icons out.
--
-- The Overlay is rendered as a sibling here so the icons appear in this
-- story's ScreenGui (in-game it's mounted by PickupFXController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local PickupFX = require(ReplicatedStorage.Features.PickupFX)
local ui = require(ReplicatedStorage.Shared.Boil).ui

local ROCKET_ICON = "rbxassetid://137349421699691"
local SPAWN_INSET = 0.2

local function randomCentralPoint(): Vector2
	local viewport = Workspace.CurrentCamera.ViewportSize
	local insetX = viewport.X * SPAWN_INSET
	local insetY = viewport.Y * SPAWN_INSET
	return Vector2.new(
		insetX + math.random() * (viewport.X - 2 * insetX),
		insetY + math.random() * (viewport.Y - 2 * insetY)
	)
end

local function StoryRoot(props)
	local count = props.controls.count
	local targetRef = PickupFX.useDestination("labs.target")
	local arrivals, setArrivals = React.useState(0)

	PickupFX.useArrival("labs.target", function()
		setArrivals(function(c)
			return c + 1
		end)
	end)

	local function fire()
		for _ = 1, count do
			PickupFX.Manager.spawn({
				icon = ROCKET_ICON,
				from = randomCentralPoint(),
				to = "labs.target",
				count = 1,
				size = Vector2.new(48, 48),
			})
		end
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Overlay = React.createElement(PickupFX.Overlay),

		FireButton = React.createElement(ui.Button, {
			variant = "green",
			text = "Fire",
			size = UDim2.fromOffset(140, 60),
			position = UDim2.fromScale(0.2, 0.8),
			anchorPoint = Vector2.new(0.5, 0.5),
			onClick = fire,
		}),

		TargetSlot = React.createElement("Frame", {
			Size = UDim2.fromOffset(280, 64),
			Position = UDim2.fromScale(0.8, 0.2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ref = targetRef,
		}, {
			Badge = React.createElement(ui.Badge, {
				variant = "yellow",
				text = "Hits: " .. tostring(arrivals),
				textSize = 36,
				icon = ROCKET_ICON,
				size = UDim2.fromScale(1, 1),
			}),
		}),
	})
end

return {
	summary = "Click Fire to launch a burst of icons along randomized bezier curves toward the target Badge. Slider sets burst size.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		count = UILabs.Slider(8, 1, 30, 1),
	},

	story = function(props)
		return React.createElement(StoryRoot, props)
	end,
}
