local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Loader = require(ReplicatedStorage.Packages.Loader)
local ReplicaController = require(ReplicatedStorage.Packages.ReplicaService)
local LoadOrdered = require(ReplicatedStorage.Shared.utils.LoadOrdered)
local ui = require(ReplicatedStorage.Shared.ui)

local Features = ReplicatedStorage:WaitForChild("Features")
local HealthSystem = require(Features:WaitForChild("HealthSystem"))
local UIShell = require(Features:WaitForChild("UIShell"))
local UIShowcase = require(Features:WaitForChild("UIShowcase"))
local Notes = require(Features:WaitForChild("Notes"))
local Settings = require(Features:WaitForChild("Settings"))

-- Client-feature tree (populated by the splitter under StarterPlayerScripts).
local ClientFeatures = script.Parent:WaitForChild("Features")
local NotesView = require(ClientFeatures:WaitForChild("Notes"):WaitForChild("NotesView"))
local SettingsView = require(ClientFeatures:WaitForChild("Settings"):WaitForChild("SettingsView"))

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "BoilRoot"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
-- Studio's Insert menu defaults to Sibling but Instance.new defaults to
-- Global. Global mode breaks parent/child Z-layering (a child Frame at
-- ZIndex 1 draws behind its parent at ZIndex 2), which is almost never
-- what GUI code wants. Force Sibling so each parent sorts its own children.
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

local root = ReactRoblox.createRoot(screen)
-- SkinProvider sits at the very top so every primitive below resolves the same
-- active skin. Swap "gem" → "flat" (or any future skin) to re-skin the whole UI.
root:render(React.createElement(ui.SkinProvider, { skin = "gem" }, {
	App = React.createElement(UIShell.FrameProvider, {}, {
		Root = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Health = React.createElement(HealthSystem.UI, { hp = 100 }),
			HUD = React.createElement(UIShowcase.HUD, {
				-- Wire feature-owned frame contents into the HUD's window slots.
				-- Any id not provided here falls back to placeholder rows.
				frameContents = {
					[Notes.FRAME_ID] = React.createElement(NotesView),
					[Settings.FRAME_ID] = React.createElement(SettingsView),
				},
			}),
		}),
	}),
}))

-- Load controllers, start them, THEN request replicas from the server.
-- ReplicaController.RequestData must be called once after listeners are wired.
-- Filter to *Controller modules so React components (e.g. NotesView) aren't spawned.
local controllers = Loader.LoadDescendants(ClientFeatures, Loader.MatchesName("Controller$"))
Loader.SpawnAll(LoadOrdered(controllers), "Start")
ReplicaController.RequestData()
