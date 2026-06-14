--!strict
-- Recreates the gem-button template using the shared/ui Window primitive.
-- Add or rearrange children inside the children table to extend the demo;
-- the Window handles the panel, top bar, scroll, and layout boilerplate.
--
-- Also wires the PickupFX rocket demo: the "Pop" button spawns a burst of
-- rocket icons aimed at the corner RocketCounter (sibling element below).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ui = require(ReplicatedStorage.Shared.Boil).ui
local PickupFX = require(ReplicatedStorage.Features.PickupFX)
local RocketCounter = require(script.Parent.RocketCounter)

-- TODO: swap for your rocket upload; using the rebirth icon as a placeholder
-- so the demo runs out of the box.
local ROCKET_ICON = "rbxassetid://137349421699691"

-- Spawns originate from random points inside the central 60% of the screen,
-- so the burst doesn't look like a fountain from a single source.
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

local function GemButton(text: string, variant: string, order: number)
	return React.createElement(ui.Button, {
		variant = variant :: any,
		text = text,
		size = UDim2.fromOffset(60, 60),
		layoutOrder = order,
	})
end

return function()
	local function spawnBurst()
		for _ = 1, 8 do
			PickupFX.Manager.spawn({
				icon = ROCKET_ICON,
				from = randomCentralPoint(),
				to = "showcase.rockets",
				count = 1,
				size = Vector2.new(56, 56),
			})
		end
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Window = React.createElement(ui.Window, {
			size = UDim2.fromOffset(797, 595),
			title = "Rebirth",
			icon = ROCKET_ICON,
			titleVariant = "blue",
			closeVariant = "red",
			onClose = function()
				print("[UIShowcase] close clicked")
			end,
		}, {
			RedButton = GemButton("Red Button", "red", 1),
			BlueButton = GemButton("Blue Button", "blue", 2),
			GreenButtton = GemButton("Green Button", "green", 3),
			PurpleButton = GemButton("Purple Button", "purple", 4),
			YellowButton = GemButton("Yellow Button", "yellow", 5),
			WhiteButton = GemButton("White Button", "white", 6),
			RainbowButton = GemButton("Ben Button", "rainbow", 7),
			PopButton = React.createElement(ui.Button, {
				variant = "green",
				text = "Pop",
				size = UDim2.fromOffset(60, 60),
				layoutOrder = 8,
				onClick = spawnBurst,
			}),
		}),

		Counter = React.createElement(RocketCounter),
	})
end
