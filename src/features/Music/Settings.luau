-- Auto-discovery file picked up by the Settings feature's `init.luau` loop.
-- Registers an "Audio" category and the music.enabled toggle on both realms.
-- Receives the Settings table as a parameter to avoid a circular require —
-- this file never imports Features.Settings directly.

return function(Settings)
	local Constants = require(script.Parent.Constants)

	Settings.registerCategory({
		id = "audio",
		title = "Audio",
		order = 1,
	})

	Settings.registerSetting({
		kind = "toggle",
		id = Constants.SETTING_ID,
		label = "Music",
		category = "audio",
		default = true,
		order = 1,
		variant = "blue",
	})
end
