local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Loader = require(ReplicatedStorage.Packages.Loader)
local LoadOrdered = require(ReplicatedStorage.Shared.utils.LoadOrdered)

local ServerFeatures = ServerScriptService:WaitForChild("Features")

-- Only load modules whose name ends in "Service" — skips anything else
-- that might happen to live under a feature folder.
local modules = Loader.LoadDescendants(ServerFeatures, Loader.MatchesName("Service$"))
Loader.SpawnAll(LoadOrdered(modules), "Start")

-- Discover server-realm presentations (e.g. Cmdr commands) — required for their
-- side effect (they self-register). No Start lifecycle; a feature adds a command
-- by dropping a *Command.server.luau, with no edit here.
Loader.LoadDescendants(ServerFeatures, Loader.MatchesName("Command$"))
