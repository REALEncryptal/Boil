local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReplicaController = require(ReplicatedStorage.Packages.ReplicaService)
local Signal = require(ReplicatedStorage.Packages.Signal)

local Constants = require(ReplicatedStorage.Features.PlayerData.Constants)

local PlayerDataController = {}

-- Fires once when the local player's replica first arrives, and again on any change.
PlayerDataController.DataChanged = Signal.new()

local replica: any = nil

function PlayerDataController.GetData(): { [string]: any }?
	return if replica then replica.Data else nil
end

function PlayerDataController.GetReplica()
	return replica
end

function PlayerDataController.Start()
	ReplicaController.ReplicaOfClassCreated(Constants.REPLICA_CLASS, function(newReplica)
		replica = newReplica
		PlayerDataController.DataChanged:Fire(replica.Data)

		newReplica:ListenToRaw(function()
			PlayerDataController.DataChanged:Fire(replica.Data)
		end)
	end)
end

return PlayerDataController
