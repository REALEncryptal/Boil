-- Stateful container. Subscribes to the PlayerData replica for the current
-- note and hands it + the save callback down to the dumb NotesUI component.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

-- client-realm siblings resolved via the StarterPlayerScripts.Features tree
local NotesController = require(script.Parent.NotesController)
local PlayerDataController = require(script.Parent.Parent.PlayerData.PlayerDataController)
local NotesUI = require(ReplicatedStorage.Features.Notes.NotesUI)

return function()
	local note, setNote = React.useState("")

	React.useEffect(function()
		local data = PlayerDataController.GetData()
		if data then
			setNote(data.Note or "")
		end

		local conn = PlayerDataController.DataChanged:Connect(function(newData)
			setNote((newData and newData.Note) or "")
		end)

		return function()
			conn:Disconnect()
		end
	end, {} :: { any })

	return React.createElement(NotesUI, {
		note = note,
		onSave = NotesController.SetNote,
	})
end
