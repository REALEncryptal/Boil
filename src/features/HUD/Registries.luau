-- HUD registries — the navigation and widget seams, split out of init.luau.
--
-- This replaces the old arrangement, where the sidebar's entries were a
-- four-item literal inside a demo feature (`UIShowcase/HUD.ui.luau`). A feature
-- that wanted a window had to be added to that array by hand, and a screen
-- registered under an id the array didn't contain was silently dropped — no
-- error, no lint failure, nothing on screen.
--
-- Now the HUD owns two registries and names no feature:
--
--   Nav      — sidebar entries + their window frames. A feature contributes by
--              dropping a sibling `Nav.luau` (shared realm, discovered at load).
--   Widgets  — always-visible HUD content anchored to a screen corner: a currency
--              bar, a quest tracker, a minimap. Registered from a client-realm
--              `*Presentation.client.luau`, because widgets are React elements.
--
-- ---------------------------------------------------------------------------
-- Adding a window to the HUD
-- ---------------------------------------------------------------------------
--   -- src/features/Shop/Nav.luau            (shared: id, label, icon, order)
--   return function(nav)
--       nav.add({ id = "Shop", label = "Shop", icon = "rbxassetid://…", order = 20 })
--   end
--
--   -- src/features/Shop/ShopPresentation.client.luau   (client: the content)
--   HUD.setScreen("Shop", React.createElement(ShopView))
--
-- Two files because the two halves live in different realms — the metadata is
-- shared (the server may want to know a screen exists), the React element is
-- client-only. `setScreen` validates its id against Nav, so the silent-drop bug
-- is now a warning that names the mistake.
--
-- Lives beside init.luau rather than inside it so HUDView can read the
-- registries directly: `init` requires the view and the view requires the
-- registries, which would be a cycle if they shared a module.
--
-- See docs/game/HUD.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boil = require(ReplicatedStorage.Shared.Boil)

local HUD = {}

-- The navigation seam. Entries are `{ id, label, icon, order?, variant?,
-- title?, windowSize? }`; see Constants for what each field drives.
HUD.Nav = Boil.Registry.define("Nav", script.Parent)

------------------------------------------------------------------------------
-- Screens
------------------------------------------------------------------------------
-- Window content, keyed by nav id. Client-realm registration, so this is a plain
-- table rather than a discovered registry.
local screens: { [string]: any } = {}

function HUD.setScreen(id: string, element: any)
	-- The old bug: a screen registered under an id no nav entry claimed rendered
	-- nothing and said nothing. Now it names the mistake at boot.
	if not HUD.Nav.has(id) then
		warn(
			`[HUD] setScreen("{id}") has no matching nav entry — the window will `
				.. `never open. Add a sibling Nav.luau registering id "{id}".`
		)
	end
	if screens[id] ~= nil then
		warn(`[HUD] screen "{id}" registered twice; overwriting`)
	end
	screens[id] = element
end

function HUD.getScreen(id: string): any?
	return screens[id]
end

------------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------------
-- Always-visible HUD content, grouped by the corner it anchors to. Widgets slide
-- away with the rest of the HUD while a frame is open.
export type Corner = "topLeft" | "topRight" | "bottomLeft" | "bottomRight" | "bottomCenter"

export type Widget = {
	id: string,
	element: any,
	corner: Corner?,
	order: number?,
}

local widgets: { Widget } = {}

function HUD.registerWidget(widget: Widget)
	if typeof(widget) ~= "table" or typeof(widget.id) ~= "string" then
		error("[HUD] registerWidget expects { id, element, corner?, order? }", 2)
	end
	for _, existing in widgets do
		if existing.id == widget.id then
			warn(`[HUD] widget "{widget.id}" registered twice; ignoring the second`)
			return
		end
	end
	table.insert(widgets, widget)
end

-- Widgets grouped by corner and sorted, ready for the HUD to lay out.
function HUD.widgetsByCorner(): { [string]: { Widget } }
	local grouped: { [string]: { Widget } } = {}
	for _, widget in widgets do
		local corner = widget.corner or "topLeft"
		local bucket = grouped[corner]
		if bucket == nil then
			bucket = {}
			grouped[corner] = bucket
		end
		table.insert(bucket, widget)
	end
	for _, bucket in grouped do
		table.sort(bucket, function(a, b)
			local ao, bo = a.order or math.huge, b.order or math.huge
			if ao ~= bo then
				return ao < bo
			end
			return a.id < b.id
		end)
	end
	return grouped
end

return HUD
