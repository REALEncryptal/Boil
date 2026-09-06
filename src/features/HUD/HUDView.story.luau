--!nonstrict
-- covers: Sidebar, SidebarItem, Frame, FrameProvider, HideWhenFrameOpen, UIShell
--
-- The game's HUD — the real one, not a mock of it.
--
-- This renders `Shared.App`, the same tree `client/init.client.luau` mounts into
-- the player's ScreenGui: the registered providers, the registered root elements,
-- and every screen the installed features actually supply. What you see here is
-- what a player sees.
--
-- That's why it replaced the old story, which built its own six-entry sidebar
-- from a mock table. It looked convincing and proved nothing — it couldn't have
-- caught an empty nav registry, a screen registered under the wrong id, or a
-- feature that failed to load. This can.
--
-- It also means the story is honest about an empty game: with only Settings
-- installed there is one sidebar button and nothing else. That is correct.
--
-- Since it renders the whole app, it covers the pieces that used to carry their
-- own stories — the sidebar, its items, and UIShell's frame system. Those were
-- plumbing views with no independent design decisions to review; seeing them in
-- place is strictly more useful than seeing them isolated. Click an icon to open
-- a frame and watch the HUD slide away.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local App = require(ReplicatedStorage.Shared.Boil).App

-- Edit mode never runs the entry script, so nothing has registered yet. Reach the
-- client feature tree where the splitter puts it and run the same presentation
-- pass the entry script runs.
--
-- Wrapped: a client module that misbehaves outside a running game (one reaching
-- for LocalPlayer, say) should leave the rest of the HUD renderable rather than
-- blanking the story.
local loaded, loadError = pcall(function()
	local clientFeatures = StarterPlayer.StarterPlayerScripts:FindFirstChild("Features")
	if clientFeatures == nil then
		error("StarterPlayerScripts.Features is missing — has the splitter run?", 0)
	end
	App.loadPresentations(clientFeatures)
end)

if not loaded then
	warn(`[HUDView.story] could not load presentations: {loadError}`)
end

return {
	summary = "The real HUD: Shared.App, the same tree the client entry mounts. Empty game = one sidebar button, which is correct. Switch `device` to check mobile.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		device = UILabs.Choose({ "actual", "desktop", "tablet", "phone" }),
		-- "default" means whatever skin claims `default = true` — the game's own
		-- look. The named options force one for comparison.
		skin = UILabs.Choose({ "default", "slop", "gem", "flat" }),
	},

	story = function(props)
		local c = props.controls

		return App.tree({
			device = if c.device == "actual" then nil else c.device,
			skin = if c.skin == "default" then nil else c.skin,
		})
	end,
}
