local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Packages.Net)

local Constants = require(ReplicatedStorage.Features.Notes.Constants)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataService)

local NotesService = {}

-- After PlayerData (1). Lower than typical gameplay services.
NotesService.Priority = 5

function NotesService.Start()
	Net:Connect(Constants.SET_NOTE_EVENT, function(player: Player, text: any)
		-- Validate: server is authoritative, never trust client payloads.
		if typeof(text) ~= "string" then
			return
		end
		if #text > Constants.MAX_LENGTH then
			text = string.sub(text, 1, Constants.MAX_LENGTH)
		end

		local replica = PlayerDataService.GetReplica(player)
		if replica == nil then
			return
		end

		-- Mutating through the replica: ReplicaService ships a diff to the
		-- owning client, and because Data is the same table as Profile.Data,
		-- ProfileStore will persist it on its next autosave.
		replica:SetValue({ "Note" }, text)
	end)
end

return NotesService
