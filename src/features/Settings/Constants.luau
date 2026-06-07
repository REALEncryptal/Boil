-- Shared constants for the Settings feature.

return {
	-- Key in the player's profile that holds the map of settingId → value.
	-- Registered into the PlayerData profile template by src/features/Settings/PlayerData.luau.
	-- Read by the client + server, written by PlayerDataService.SetValue
	-- routed from SettingsService.
	PROFILE_KEY = "Settings",

	-- Defensive cap on inbound packet ids (the client is the source of these,
	-- so we don't trust their length).
	MAX_SETTING_ID_LENGTH = 128,

	-- How long the highlighted row lingers after Settings.linkTo(id) before
	-- the focus state clears on its own.
	LINK_HIGHLIGHT_SECONDS = 1.6,

	-- Which presentations are active. Settings ships a screen (HUD window) and a
	-- world surface: parts tagged `SettingsToggleStation` whose ProximityPrompt
	-- flips the setting named by the part's `SettingId` attribute.
	Presentations = {
		screen = true,
		world = true,
	},

	-- CollectionService tag a part must carry to become a Settings toggle
	-- station, plus the attribute that names which setting it flips.
	WORLD_TAG = "SettingsToggleStation",
	WORLD_SETTING_ATTRIBUTE = "SettingId",
}
