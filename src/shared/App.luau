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
local RunService = game:GetService("RunService")

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

-- How long one presentation gets to load in EDIT MODE before the pass gives up on
-- it. Only ever reached by a module that has wedged, not by a slow one.
local EDIT_LOAD_TIMEOUT = 3

-- Require one module on its own thread, with a deadline.
--
-- Edit mode has no server, so anything that yields waiting on an instance the
-- server creates at runtime yields FOREVER. Both transports Boil ships do exactly
-- that on the client — ByteNet on `ReplicatedStorage.BytenetStorage`,
-- ReplicaController on `ReplicatedStorage.ReplicaRemoteEvents` — and a
-- presentation inherits the wait through view → controller → transport.
--
-- Boil's own features require their transports lazily so this never fires (see
-- any Packets.luau, and PlayerDataController.Start). This is the net for the ones
-- that don't: on a single serial pass the first wedged module takes every later
-- one with it, which reads as a completely blank story rather than as one missing
-- screen.
local function loadIsolated(module: ModuleScript)
	local finished = false
	local failure: string? = nil

	task.spawn(function()
		local ok, err = pcall(require, module)
		failure = if ok then nil else tostring(err)
		finished = true
	end)

	local waited = 0
	while not finished and waited < EDIT_LOAD_TIMEOUT do
		waited += task.wait(0.05)
	end

	if not finished then
		warn(
			`[App] "{module:GetFullName()}" never finished loading and was skipped. `
				.. `Edit mode runs no server, so a require chain that reaches a `
				.. `transport waits forever on an instance only the server creates. `
				.. `Require that transport lazily — inside the function that uses it — `
				.. `and this screen comes back. Everything else still rendered.`
		)
		return
	end

	if failure then
		warn(`[App] "{module:GetFullName()}" failed to load: {failure}`)
	end
end

-- Populate the UI registries from a client feature tree.
--
-- Safe to call more than once: registering twice warns and overwrites rather than
-- duplicating, which matters because a UI Labs story re-requires on reload.
function App.loadPresentations(clientFeatures: Instance)
	-- The running game loads straight through. A presentation that yields there is
	-- waiting on something that genuinely arrives, so a deadline would only
	-- introduce a race the game doesn't have.
	if RunService:IsRunning() then
		Loader.LoadDescendants(clientFeatures, isPresentation)
		return
	end

	-- Edit mode (UI Labs). One wedged module costs only itself; see loadIsolated.
	for _, descendant in clientFeatures:GetDescendants() do
		if descendant:IsA("ModuleScript") and isPresentation(descendant) then
			loadIsolated(descendant)
		end
	end
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
