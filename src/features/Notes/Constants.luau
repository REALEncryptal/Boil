return {
	MAX_LENGTH = 140,

	-- Which presentations are active for this feature. Each *Presentation /
	-- *Command module checks its flag before registering, so a game can turn a
	-- surface off without deleting code. Notes ships a screen (HUD window) and a
	-- Cmdr command (`setnote`); a world surface doesn't fit a free-text note.
	Presentations = {
		screen = true,
		command = true,
	},
}
