local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Loader = require(ReplicatedStorage.Packages.Loader)
local LoadOrdered = require(ReplicatedStorage.Shared.utils.LoadOrdered)

-- Only load modules whose name ends in "Service" — skips anything else
-- that might happen to live under a feature folder.
local modules = Loader.LoadDescendants(
	ServerScriptService:WaitForChild("Features"),
	Loader.MatchesName("Service$")
)
Loader.SpawnAll(LoadOrdered(modules), "Start")
