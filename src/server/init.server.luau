local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Creates the ByteNet remotes before any client waits on them. Features define
-- their packets lazily, so without this the transport would only come up when a
-- service first touched its own packets. See src/client/init.client.luau.
require(ReplicatedStorage.Packages.ByteNet)

local Loader = require(ReplicatedStorage.Packages.Loader)
local FeatureLoader = require(ReplicatedStorage.Shared.utils.FeatureLoader)

local SharedFeatures = ReplicatedStorage:WaitForChild("Features")
local ServerFeatures = ServerScriptService:WaitForChild("Features")

-- Report anything a feature declared in its boil.toml and didn't get, before the
-- first require fails on it. One warning naming the feature and the missing
-- dependency beats a raw require error from inside someone else's module.
FeatureLoader.verify(SharedFeatures)

-- Services, in dependency order: features are topologically sorted by their
-- manifests, and each feature's own `Priority` orders its services among
-- themselves. The manifests live in the shared tree, so that's where the graph is
-- read from even though the modules are server-realm.
local services = FeatureLoader.load(ServerFeatures, "Service$", SharedFeatures)
Loader.SpawnAll(services, "Start")

-- Server-realm presentations (Cmdr commands). Required for their side effect —
-- they self-register, so a feature adds a command by dropping a
-- *Command.server.luau with no edit here.
Loader.LoadDescendants(ServerFeatures, Loader.MatchesName("Command$"))
