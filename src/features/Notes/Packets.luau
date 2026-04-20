-- Shared packet definitions. Both server (NotesService) and client
-- (NotesController) import this module; ByteNet takes care of (de)serialization
-- and reliability on top of the underlying RemoteEvent.
--
-- Plain .luau file => splitter routes to ReplicatedStorage.Features.Notes.Packets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ByteNet = require(ReplicatedStorage.Packages.ByteNet)

return ByteNet.defineNamespace("Notes", function()
	return {
		-- Client -> Server: ask to persist a new note on the local player's profile.
		SetNote = ByteNet.definePacket({
			value = ByteNet.struct({
				text = ByteNet.string,
			}),
			reliabilityType = "reliable",
		}),
	}
end)
