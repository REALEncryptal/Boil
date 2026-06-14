--!nonstrict
-- UI Labs story for the showcase RocketCounter.
--
-- Renders the counter + the PickupFX Overlay + a "Send 1" button that
-- spawns a single rocket from the button toward the counter. Verifies the
-- useDestination/useArrival wiring end-to-end without leaving Edit mode.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local PickupFX = require(ReplicatedStorage.Features.PickupFX)
local ui = require(ReplicatedStorage.Shared.Boil).ui

local RocketCounter = require(ReplicatedStorage.Features.UIShowcase.RocketCounter)

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

local function StoryRoot()
	local function send()
		PickupFX.Manager.spawn({
			icon = ROCKET_ICON,
			from = randomCentralPoint(),
			to = "showcase.rockets",
			count = 1,
			size = Vector2.new(48, 48),
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Overlay = React.createElement(PickupFX.Overlay),
		Counter = React.createElement(RocketCounter),
		SendButton = React.createElement(ui.Button, {
			variant = "green",
			text = "Send",
			size = UDim2.fromOffset(140, 60),
			position = UDim2.fromScale(0.2, 0.8),
			anchorPoint = Vector2.new(0.5, 0.5),
			onClick = send,
		}),
	})
end

return {
	summary = "Corner Badge that counts arrivals at destination id \"showcase.rockets\". Click Send to fire a rocket; the count ticks up when it lands.",
	react = React,
	reactRoblox = ReactRoblox,

	story = function()
		return React.createElement(StoryRoot)
	end,
}
