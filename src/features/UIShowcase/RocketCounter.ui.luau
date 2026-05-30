--!strict
-- Showcase counter Badge that doubles as a destination for PickupFX.
-- Pinned to the top-right of the screen; increments whenever a rocket
-- spawned by the showcase button arrives.
--
-- Demonstrates the two reactive sides of the PickupFX API:
--   useDestination(id) — registers this Badge's live screen position as `id`
--   useArrival(id, cb) — subscribes to arrivals at `id`

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PickupFX = require(ReplicatedStorage.Features.PickupFX)
local ui = require(ReplicatedStorage.Shared.ui)

local ROCKET_ICON = "rbxassetid://137349421699691"

return function()
	local count, setCount = React.useState(0)
	local destRef = PickupFX.useDestination("showcase.rockets")

	PickupFX.useArrival("showcase.rockets", function()
		setCount(function(c: number)
			return c + 1
		end)
	end)

	return React.createElement("Frame", {
		Size = UDim2.fromOffset(260, 64),
		Position = UDim2.new(1, -16, 0, 16),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ref = destRef,
	}, {
		Badge = React.createElement(ui.Badge, {
			variant = "yellow",
			text = "Rockets: " .. tostring(count),
			textSize = 36,
			icon = ROCKET_ICON,
			size = UDim2.fromScale(1, 1),
		}),
	})
end
