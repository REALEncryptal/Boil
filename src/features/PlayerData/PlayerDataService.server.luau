local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local ReplicaService = require(ReplicatedStorage.Packages.ReplicaService)

-- Requiring PlayerData (the parent init.luau) triggers the auto-discovery loop
-- that pulls every feature's PlayerData.luau slice into the template before
-- we hand it to ProfileStore.
local PlayerData = require(ReplicatedStorage.Features.PlayerData)
local Constants = PlayerData.Constants

local PlayerDataService = {}

-- Runs before any other service that reads player data.
PlayerDataService.Priority = 1

local Store = ProfileStore.New(Constants.STORE_NAME, PlayerData.getTemplate())
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

-- Blessed mutation path. Always route writes through this so:
--   (a) clients receive a Replica diff,
--   (b) ProfileStore autosave persists the change (profile.Data === replica.Data),
--   (c) we get one place to add logging, rate-limiting, or validation later.
function PlayerDataService.SetValue(player: Player, path: { string }, value: any): boolean
	local replica = replicas[player]
	if replica == nil then
		return false
	end
	replica:SetValue(path, value)
	return true
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
		if player.Parent == Players then
			player:Kick("[PlayerData] profile session ended")
		end
	end)

	-- Invariant: replica.Data and profile.Data must remain the same table.
	-- If someone ever re-assigns profile.Data (or builds a new table and swaps
	-- it in) the replica stops saving silently. Fire a loud warning before
	-- every save so the drift is obvious in the output window.
	profile.OnSave:Connect(function()
		local replica = replicas[player]
		if replica ~= nil and replica.Data ~= profile.Data then
			warn(
				`[PlayerData] identity drift for {player.Name}: `
					.. `replica.Data and profile.Data are no longer the same table. `
					.. `Use PlayerDataService.SetValue / .GetReplica to mutate; `
					.. `do not reassign profile.Data.`
			)
		end
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
