# HUD

The player's heads-up display, and the navigation seam every other feature plugs
into. It owns a sidebar of nav entries, corner widget clusters, and one window
frame per entry — and it learns about all of them by registration, never by
naming a feature.

## Shape

- `Registries.luau` — `Nav` (a `Boil.Registry`) plus the screen and widget
  tables. Split out of `init.luau` so `HUDView` can read it without a require
  cycle.
- `HUDView.ui.luau` — the view, and dumb: it reads the registries and renders
  the sidebar, the clusters, and the open frame.
- A feature contributes its nav entry from a shared `Nav.luau`, and its screen
  from `<Feature>Presentation.client.luau` via `HUD.setScreen(id, element)`.
- Opening any frame slides the sidebar and every cluster off-screen through
  UIShell's `HideWhenFrameOpen`; each cluster leaves toward its own edge.
- Entries sort on `order` — gameplay features use 10–100, `Settings` sits at 900
  so it stays at the bottom.

## Decisions

- **Nav is a registry, not a list.** It used to be a four-entry literal inside a
  *demo* feature, so adding a feature meant editing another feature's source,
  and deleting the demo took all navigation with it. Collapsing it back to a
  literal re-breaks the lego rule.
- **`setScreen` warns on an unknown id.** A screen registered under an id with no
  matching nav entry used to be dropped silently — no error, nothing on screen.
  The warning is that bug turned into a message that names the mistake.
- **The nav entry is shared, the screen is client.** Both realms need to know a
  screen exists; only the client can hold a React element. That is why it is two
  files and not one.
- **A missing icon falls back to a placeholder,** so art-pending reads as
  art-pending instead of an invisible button.
- **Phone gets a near-fullscreen window.** The one place the HUD branches on
  device: a small float wastes a phone screen and cramps its own content.

## Gotchas

No Studio assets — the HUD builds itself from what features register. Icons come
from the features that register them, and the bundled ids are placeholders.
Depend on HUD through `[soft-dependencies]` unless your feature is useless
without a window.

## See also

[presentations.md](presentations.md) · [registries.md](registries.md) ·
[UIShell.md](UIShell.md) · [Sidebar.md](Sidebar.md)
