local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Loader = require(ReplicatedStorage.Packages.Loader)
local ReplicaController = require(ReplicatedStorage.Packages.ReplicaService)
local LoadOrdered = require(ReplicatedStorage.Shared.utils.LoadOrdered)
local UIRegistry = require(ReplicatedStorage.Shared.utils.UIRegistry)
local ui = require(ReplicatedStorage.Shared.ui)

local Features = ReplicatedStorage:WaitForChild("Features")

-- Auto-require every shared feature so its load-time side effects run (the
-- PlayerData / Settings auto-discovery loops, etc.). Replaces the old hardcoded
-- require list — adding a feature needs no edit here. pcall so one bad feature
-- can't stop client boot.
for _, feature in Features:GetChildren() do
	if feature:IsA("ModuleScript") then
		local ok, err = pcall(require, feature)
		if not ok then
			warn(`[client] failed to require feature {feature.Name}: {err}`)
		end
	end
end

-- Client-feature tree (populated by the splitter under StarterPlayerScripts).
local ClientFeatures = script.Parent:WaitForChild("Features")

-- Discover + require self-registering presentations BEFORE the root mounts, so
-- the UI registries (roots + screens) are populated by render time. Side effect
-- only — these modules register and return {} (no Start lifecycle). *Controller
-- modules are loaded separately below; *Command modules are server-realm.
Loader.LoadDescendants(ClientFeatures, function(m)
	return string.match(m.Name, "Presentation$") ~= nil
		or string.match(m.Name, "WorldInteraction$") ~= nil
end)

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

-- The root Frame's children are whatever presentations registered — the HUD host,
-- the Health widget, etc. — so this file names no content feature.
local rootFrame = React.createElement("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, UIRegistry.getRoots())

-- Wrap the tree in every feature-registered provider (e.g. UIShell's
-- FrameProvider, registered from a *Presentation above). First registered ends up
-- outermost. With none registered the root still mounts — the framework boots with
-- zero features — so this file names no feature here either.
local app = rootFrame
local providers = UIRegistry.getProviders()
for i = #providers, 1, -1 do
	app = React.createElement(providers[i], {}, { Child = app })
end

-- SkinProvider sits at the very top so every primitive below resolves the same
-- active skin. Swap "gem" → "flat" (or any future skin) to re-skin the whole UI.
root:render(React.createElement(ui.SkinProvider, { skin = "gem" }, {
	App = app,
}))

-- Load controllers, start them, THEN request replicas from the server.
-- ReplicaController.RequestData must be called once after listeners are wired.
-- Filter to *Controller modules so React components (e.g. NotesView) and the
-- *Presentation modules aren't spawned as controllers.
local controllers = Loader.LoadDescendants(ClientFeatures, Loader.MatchesName("Controller$"))
Loader.SpawnAll(LoadOrdered(controllers), "Start")
ReplicaController.RequestData()
