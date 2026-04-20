local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local ReplicaService = require(ReplicatedStorage.Packages.ReplicaService)

local Constants = require(ReplicatedStorage.Features.PlayerData.Constants)

local PlayerDataService = {}

-- Runs before any other service that reads player data.
PlayerDataService.Priority = 1

local Store = ProfileStore.New(Constants.STORE_NAME, Constants.PROFILE_TEMPLATE)
local ReplicaToken = ReplicaService.NewClassToken(Constants.REPLICA_CLASS)

local profiles: { [Player]: any } = {}
local replicas: { [Player]: any } = {}

-- Public API -----------------------------------------------------------------

function PlayerDataService.GetData(player: Player): { [string]: any }?
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function PlayerDataService.GetReplica(player: Player)
	return replicas[player]
end

-- Lifecycle ------------------------------------------------------------------

local function onPlayerAdded(player: Player)
	local profile = Store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		player:Kick("[PlayerData] couldn't load profile; please rejoin")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		local replica = replicas[player]
		if replica then
			replica:Destroy()
			replicas[player] = nil
		end
		player:Kick("[PlayerData] profile session ended")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	replicas[player] = ReplicaService.NewReplica({
		ClassToken = ReplicaToken,
		Tags = { UserId = player.UserId },
		Data = profile.Data,
		Replication = player,
	})
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profile:EndSession()
	end
end

function PlayerDataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- handle players already in the server (e.g. after a hot reload)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerDataService
