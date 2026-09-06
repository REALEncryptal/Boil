--!strict
-- Client-side UI registries that let presentations register *themselves* into
-- the root client tree, so src/client/init.client.luau names no content feature.
--
--   * Roots     — always-mounted top-level elements (a HUD host, a persistent
--                 widget). Keyed by name so React has a stable key.
--   * Providers — React context providers wrapped around the whole tree.
--
-- Window CONTENT is not here. It used to be ("screens", keyed by frame id), but
-- the registry had no idea which ids were real, so a screen registered under an
-- id no sidebar entry claimed was silently dropped. That belongs to whichever
-- feature owns navigation — see the HUD feature's `setScreen`, which validates
-- against its own nav registry — not to the framework, which must not know that
-- navigation exists at all.
--
-- A feature opts in by dropping a `*Presentation.client.luau` that registers
-- here at load. init.client.luau discovers + requires those modules BEFORE the
-- root mounts, so the registries are populated by render time.
--
-- This module is realm-neutral, but registration happens on the client (Views
-- are client-realm) and the HUD reads it on the client — one shared instance.

local roots: { [string]: any } = {}
local providers: { any } = {}

local UIRegistry = {}

-- Register an always-mounted top-level element (e.g. a HUD host or a persistent
-- widget). `name` is the React child key; keep it unique per feature.
function UIRegistry.registerRoot(name: string, element: any)
	if roots[name] ~= nil then
		warn(`[UIRegistry] root "{name}" registered twice; overwriting`)
	end
	roots[name] = element
end

-- The map of all registered roots, for mounting as named children of the root
-- Frame. Returns a copy so callers can't mutate the registry.
function UIRegistry.getRoots(): { [string]: any }
	return table.clone(roots)
end

-- Register a top-level React provider component to wrap the whole client tree
-- (e.g. a context provider like UIShell's FrameProvider). The root composes every
-- registered provider around the root Frame, so the client entry names no feature
-- — and with none registered the tree still mounts (the framework boots empty).
-- Registration order = nesting order, first registered outermost.
function UIRegistry.registerProvider(component: any)
	table.insert(providers, component)
end

-- The list of registered providers, outermost first, for the root to compose.
function UIRegistry.getProviders(): { any }
	return table.clone(providers)
end

return UIRegistry
