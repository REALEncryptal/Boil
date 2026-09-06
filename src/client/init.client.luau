local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Loader = require(ReplicatedStorage.Packages.Loader)
local ReplicaController = require(ReplicatedStorage.Packages.ReplicaService)
local App = require(ReplicatedStorage.Shared.App)
local FeatureLoader = require(ReplicatedStorage.Shared.utils.FeatureLoader)

local Features = ReplicatedStorage:WaitForChild("Features")

-- Report anything a feature declared in its boil.toml and didn't get, before the
-- first require fails on it. One warning naming the feature and the missing
-- dependency beats a raw require error from inside someone else's module.
FeatureLoader.verify(Features)

-- Auto-require every shared feature so its load-time side effects run (the
-- registry discovery passes, etc.). Adding a feature needs no edit here. pcall so
-- one bad feature can't stop client boot.
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

-- Presentations register themselves into the UI registries, so this must happen
-- BEFORE the tree is composed. Side effect only — they return {}.
App.loadPresentations(ClientFeatures)

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

-- The whole tree lives in Shared.App so the UI Labs story renders exactly this,
-- rather than an approximation of it that can drift.
ReactRoblox.createRoot(screen):render(App.tree({}))

-- Load controllers, start them, THEN request replicas from the server.
-- ReplicaController.RequestData must be called once after listeners are wired.
--
-- Controllers load in dependency order: features are topologically sorted by
-- their manifests (read from the shared tree, where tools/split writes them), and
-- each feature's own `Priority` orders its controllers among themselves.
local controllers = FeatureLoader.load(ClientFeatures, "Controller$", Features)
Loader.SpawnAll(controllers, "Start")
ReplicaController.RequestData()
