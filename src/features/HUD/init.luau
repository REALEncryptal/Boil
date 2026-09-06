-- HUD — the player's main heads-up display, and the navigation seam.
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
-- See docs/game/HUD.md.

local Registries = require(script.Registries)

local HUD = {}

HUD.Constants = require(script.Constants)

HUD.Nav = Registries.Nav
HUD.setScreen = Registries.setScreen
HUD.getScreen = Registries.getScreen
HUD.registerWidget = Registries.registerWidget
HUD.widgetsByCorner = Registries.widgetsByCorner

HUD.UI = require(script.HUDView)

return HUD
