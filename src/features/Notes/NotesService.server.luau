local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Features.Notes.Constants)
local Packets = require(ReplicatedStorage.Features.Notes.Packets)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataService)

local NotesService = {}

-- After PlayerData (1). Lower than typical gameplay services.
NotesService.Priority = 5

function NotesService.Start()
	Packets.SetNote.listen(function(payload, player)
		-- ByteNet decoded the payload against the schema, but we still clamp
		-- length on the server — the client could send a valid-typed but
		-- pathologically long string.
		local text = payload.text
		if #text > Constants.MAX_LENGTH then
			text = string.sub(text, 1, Constants.MAX_LENGTH)
		end

		-- Blessed mutation path: replica + profile stay in sync.
		PlayerDataService.SetValue(player, { "Note" }, text)
	end)
end

return NotesService
