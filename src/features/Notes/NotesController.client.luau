local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

local Net = require(ReplicatedStorage.Packages.Net)
local Constants = require(ReplicatedStorage.Features.Notes.Constants)

local NotesController = {}

-- Called by the UI on "Save". Fires a Net event to the server, which validates
-- and writes through the Replica; we don't apply the change locally — we wait
-- for the replica diff so the UI reflects the server's truth.
function NotesController.SetNote(text: string)
	if typeof(text) ~= "string" then
		return
	end
	if #text > Constants.MAX_LENGTH then
		text = string.sub(text, 1, Constants.MAX_LENGTH)
	end
	Net:RemoteEvent(Constants.SET_NOTE_EVENT):FireServer(text)
end

function NotesController.Start()
	-- nothing to wire; lazy require from the UI component.
end

return NotesController
