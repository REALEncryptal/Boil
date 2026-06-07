-- Screen presentation for Notes: registers the Notes window content into the
-- HUD's frame slot. Discovered + required by init.client.luau before the root
-- mounts; registration is the only side effect (no Start lifecycle).
--
-- This is the one place that wires Notes into the shell — the root client file
-- never names Notes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIRegistry = require(ReplicatedStorage.Shared.utils.UIRegistry)
local Notes = require(ReplicatedStorage.Features.Notes)
local Constants = require(ReplicatedStorage.Features.Notes.Constants)

-- Client-realm sibling (StarterPlayerScripts.Features.Notes.NotesView).
local NotesView = require(script.Parent.NotesView)

if Constants.Presentations.screen then
	UIRegistry.registerScreen(Notes.FRAME_ID, React.createElement(NotesView))
end

return {}
