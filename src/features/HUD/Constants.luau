--!strict
-- HUD layout defaults.
--
-- All pixel values are REFERENCE pixels (1280x720) — the HUD mounts its content
-- inside `ui.Surface`, which scales them to the real viewport. Author against the
-- reference and the same numbers are right on a phone and a 4K monitor.

return {
	-- Which surfaces this feature mounts. Turn one off to drop it without
	-- deleting code (the presentation checks its flag before registering).
	Presentations = {
		root = true,
	},

	-- Distance from the screen edge to the HUD's outer content, on every side.
	-- One value so the sidebar, the corner widget clusters and the frames all
	-- share a margin instead of each picking its own.
	SCREEN_INSET = 24,

	-- Gap between stacked widgets inside one corner cluster.
	WIDGET_SPACING = 12,

	-- Default window size for a nav entry that doesn't specify one. Reference
	-- pixels; the Window's Surface scales it.
	DEFAULT_WINDOW_SIZE = UDim2.fromOffset(720, 480),

	-- No PHONE_WINDOW_SIZE constant. A fixed reference-pixel size can't express
	-- "fill the screen": the phone boost multiplies it UP, so the old 1180x620
	-- rendered at 830x436 on an iPhone SE — 196px wider than the screen. Phone
	-- windows are computed from the live viewport instead; see HUDView.

	-- Fallback sidebar icon for a nav entry that ships none, so a missing asset
	-- reads as "art pending" rather than an invisible button.
	FALLBACK_ICON = "rbxasset://textures/ui/GuiImagePlaceholder.png",
}
