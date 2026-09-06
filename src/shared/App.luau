--!strict
-- App — the client UI tree, defined once.
--
-- The entry script mounts this into a ScreenGui; the HUD story renders the same
-- function in UI Labs. That's the point: "what the player sees" has one
-- definition, so a story can't drift from the game by construction. Before this
-- the story rebuilt an approximation of the tree by hand, with mock data — it
-- looked right and proved nothing.
--
-- The tree, outermost first:
--
--   ViewportProvider — viewport size, device class, and the reference→screen
--                      scale. Outermost so a skin swap never remounts the
--                      viewport subscription.
--   SkinProvider     — resolves every primitive to the active skin. With no
--                      `skin` override it uses the game's default: whichever
--                      installed skin declares `default = true`, else gem.
--   feature providers — everything registered via UIRegistry.registerProvider
--                      (UIShell's FrameProvider, for instance). First registered
--                      ends up outermost.
--   root Frame       — full-screen and transparent, holding every registered
--                      root element (the HUD, a persistent widget, …).
--
-- This file names no feature. With none installed it still mounts: an empty
-- Frame under two providers.
--
-- IMPORTANT: presentations must already have run, or the registries are empty and
-- this renders nothing. The caller owns that, because *how* you reach the client
-- feature tree differs between the running game and edit mode — see
-- `loadPresentations` below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Loader = require(ReplicatedStorage.Packages.Loader)
local UIRegistry = require(ReplicatedStorage.Shared.utils.UIRegistry)
local ui = require(ReplicatedStorage.Shared.ui)

export type Props = {
	-- Story overrides. Both nil in the running game.
	skin: string?,
	device: string?,
}

local App = {}

-- A presentation module registers and returns {} — no lifecycle. Requiring one is
-- the whole point, so this is a side-effect-only pass.
local function isPresentation(module: Instance): boolean
	return string.match(module.Name, "Presentation$") ~= nil
		or string.match(module.Name, "WorldInteraction$") ~= nil
end

-- Populate the UI registries from a client feature tree.
--
-- Safe to call more than once: registering twice warns and overwrites rather than
-- duplicating, which matters because a UI Labs story re-requires on reload.
function App.loadPresentations(clientFeatures: Instance)
	Loader.LoadDescendants(clientFeatures, isPresentation)
end

-- The composed tree. Render it with `root:render(App.tree({}))`.
function App.tree(props: Props): any
	local rootFrame = React.createElement("Frame", {
		Name = "Root",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, UIRegistry.getRoots())

	local app = rootFrame
	local providers = UIRegistry.getProviders()
	for index = #providers, 1, -1 do
		app = React.createElement(providers[index], {}, { Child = app })
	end

	return React.createElement(ui.ViewportProvider, { device = props.device }, {
		Skin = React.createElement(ui.SkinProvider, { skin = props.skin }, {
			App = app,
		}),
	})
end

return App
