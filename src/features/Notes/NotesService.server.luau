local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Features.Notes.Constants)
local Packets = require(ReplicatedStorage.Features.Notes.Packets)
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataService)

local NotesService = {}

-- After PlayerData (1). Lower than typical gameplay services.
NotesService.Priority = 5

-- The server-side core intent: validate + clamp + write. Every presentation
-- routes through here (the ByteNet packet from the GUI, the `setnote` Cmdr
-- command), so they share one validated path. Keep validation here, not in the
-- callers — the view/command stay dumb.
function NotesService.setNote(player: Player, text: string)
	if typeof(text) ~= "string" then
		return
	end
	-- The client could send a valid-typed but pathologically long string, so
	-- clamp on the server regardless of source.
	if #text > Constants.MAX_LENGTH then
		text = string.sub(text, 1, Constants.MAX_LENGTH)
	end

	-- Blessed mutation path: replica + profile stay in sync.
	PlayerDataService.SetValue(player, { "Note" }, text)
end

function NotesService.Start()
	Packets.SetNote.listen(function(payload, player)
		-- ByteNet decoded the payload against the schema; the core intent does
		-- the clamping and the write.
		NotesService.setNote(player, payload.text)
	end)
end

return NotesService
