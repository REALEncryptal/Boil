--!strict
-- Mounts the PickupFX Overlay in its own ScreenGui with a very high
-- DisplayOrder so the flying icons draw above every other ScreenGui
-- (BoilRoot, UIShowcase, future feature UIs).
--
-- The Overlay subscribes to the PickupFX Manager singleton; the hooks
-- (useDestination, useArrival, usePickupSpawn) also talk to the singleton,
-- so they work from inside any React tree — no Provider required.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local PickupFX = require(ReplicatedStorage.Features.PickupFX)

local PickupFXController = {}

-- Run early so the Overlay is mounted before any feature's first spawn() call.
PickupFXController.Priority = 5

function PickupFXController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screen = Instance.new("ScreenGui")
	screen.Name = "PickupFX"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 1000
	screen.Parent = playerGui

	local root = ReactRoblox.createRoot(screen)
	root:render(React.createElement(PickupFX.Overlay))
end

return PickupFXController
