local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Loader = require(ReplicatedStorage.Packages.Loader)
local ReplicaController = require(ReplicatedStorage.Packages.ReplicaService)
local LoadOrdered = require(ReplicatedStorage.Shared.utils.LoadOrdered)

local Features = ReplicatedStorage:WaitForChild("Features")
local HealthSystem = require(Features:WaitForChild("HealthSystem"))

-- Client-feature tree (populated by the splitter under StarterPlayerScripts).
local ClientFeatures = script.Parent:WaitForChild("Features")
local NotesView = require(ClientFeatures:WaitForChild("Notes"):WaitForChild("NotesView"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "BoilRoot"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.Parent = playerGui

local root = ReactRoblox.createRoot(screen)
root:render(React.createElement("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, {
	Health = React.createElement(HealthSystem.UI, { hp = 100 }),
	Notes = React.createElement(NotesView),
}))

-- Load controllers, start them, THEN request replicas from the server.
-- ReplicaController.RequestData must be called once after listeners are wired.
-- Filter to *Controller modules so React components (e.g. NotesView) aren't spawned.
local controllers = Loader.LoadDescendants(ClientFeatures, Loader.MatchesName("Controller$"))
Loader.SpawnAll(LoadOrdered(controllers), "Start")
ReplicaController.RequestData()
