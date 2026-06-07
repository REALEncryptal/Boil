-- Command presentation for Notes (seam #4: a Cmdr command instead of a screen
-- GUI). `setnote <text>` routes to the SAME server-side core intent the GUI
-- packet routes to — NotesService.setNote — so all three surfaces (window,
-- command, and any future world part) write through one validated path.
--
-- Server-realm: discovered + required by init.server.luau (name ends "Command").
-- Registration is the only side effect. Cmdr's existing BeforeRun hook
-- (CmdrService) still gates execution on the username allowlist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cmdr = require(ReplicatedStorage.Packages.Cmdr)
local Constants = require(ReplicatedStorage.Features.Notes.Constants)

-- Server-realm sibling (ServerScriptService.Features.Notes.NotesService).
local NotesService = require(script.Parent.NotesService)

if not Constants.Presentations.command then
	return {}
end

-- Register programmatically (definition + inline Run) so the command lives next
-- to its feature instead of in a separate Cmdr commands folder. Wrapped in pcall
-- so a Cmdr API hiccup can't break the server-side presentation discovery loop.
local ok, err = pcall(function()
	Cmdr.Registry:RegisterCommandObject({
		Name = "setnote",
		Aliases = {},
		Description = "Set your saved note (Notes feature).",
		Group = "Notes",
		Args = {
			{
				Type = "string",
				Name = "text",
				Description = "The note text to save (clamped server-side).",
			},
		},
		Run = function(context, text: string)
			NotesService.setNote(context.Executor, text)
			return `Note saved: {text}`
		end,
	})
end)

if not ok then
	warn(`[Notes] failed to register the setnote command: {err}`)
end

return {}
