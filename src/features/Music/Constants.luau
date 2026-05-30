-- Tunables for the Music feature. Pulled in by both the Settings auto-discovery
-- file and the client controller so the setting id, track name, and volume
-- stay in lock-step.

return {
	-- Looping track played while the music setting is enabled. Must be a key
	-- in `Shared.audio.Music`; see `src/shared/audio/init.luau` for the list.
	DEFAULT_TRACK = "lobby",

	-- Music sits underneath everything else in the mix; loud enough to be
	-- present, quiet enough not to fight UI sounds.
	VOLUME = 0.2,

	-- The persisted setting id. Registered as a toggle under the "audio"
	-- category in Settings.luau.
	SETTING_ID = "music.enabled",
}
