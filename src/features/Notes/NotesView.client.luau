-- Stateful container. Uses the shared useReplica hook instead of reimplementing
-- the connect/disconnect lifecycle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local utils = require(ReplicatedStorage.Shared.utils)

-- client-realm siblings resolved via the StarterPlayerScripts.Features tree
local NotesController = require(script.Parent.NotesController)
local PlayerDataController = require(script.Parent.Parent.PlayerData.PlayerDataController)
local NotesUI = require(ReplicatedStorage.Features.Notes.NotesUI)

return function()
	local note = utils.useReplica(PlayerDataController, "Note") or ""

	return React.createElement(NotesUI, {
		note = note,
		onSave = NotesController.SetNote,
	})
end
