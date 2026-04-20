local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Features.Notes.Constants)
local Packets = require(ReplicatedStorage.Features.Notes.Packets)

local NotesController = {}

-- Called by the UI on "Save". Fires a ByteNet packet to the server, which
-- validates and writes through the Replica. We don't apply the change locally
-- — we wait for the replica diff so the UI reflects the server's truth.
function NotesController.SetNote(text: string)
	if typeof(text) ~= "string" then
		return
	end
	if #text > Constants.MAX_LENGTH then
		text = string.sub(text, 1, Constants.MAX_LENGTH)
	end
	Packets.SetNote.send({ text = text })
end

function NotesController.Start()
	-- nothing to wire; SetNote is called from the UI on demand.
end

return NotesController
