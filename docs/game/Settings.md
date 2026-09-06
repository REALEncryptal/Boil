# Settings

Player settings with a feature-extensible registry. The feature ships **no real
settings** — it provides the registry, persistence, networking and UI, and every
actual setting arrives from another feature dropping a `Settings.luau`.

## Shape

- `Registry.luau` (shared) — flat `settings` and `categories` tables plus a
  `Changed` signal. Both realms load it and keep their own copy.
- Any feature's `Settings.luau` registers a category and its settings; discovery
  runs through `Boil.Registry.define`.
- `Settings/PlayerData.luau` registers the `Settings` profile key, so values
  persist through the PlayerData feature.
- `Packets.luau` — one packet per setting *kind* (today just `SetToggle`).
- `SettingsUI.ui.luau` is pure; `SettingsView.client.luau` wires it to
  `useReplica`, `Registry.Changed` and `LinkRequested`.

## Decisions

- **Settings registers itself into PlayerData, not the reverse.** PlayerData has
  no idea Settings exists. Adding a `Settings` key to the profile template by
  hand would close exactly the loop the lego rule forbids.
- **The client never writes locally.** `setToggle` sends a packet; the server
  validates the id against the Registry, type-checks the kind, and routes through
  `PlayerDataService.SetValue`. The UI updates from the replica diff that comes
  back. An optimistic local write would let a client invent settings.
- **One packet per kind, and the kind threads registry → packet → service
  validation → UI.** Adding a slider means touching all four in lock-step. A
  single generic `SetValue` packet would hand clients an arbitrary profile write.
- **`Registry.Changed` re-renders the open panel,** so a setting registered at
  runtime appears without a remount.
- **A discovery file is required once per realm and may only register.** Start-up
  logic or `PlayerAdded` connections placed there run at require time and will
  misbehave.

## Gotchas

No Studio assets. `Constants.MAX_SETTING_ID_LENGTH` is a deliberate cap on
inbound packet ids — keep it. `SettingsController.linkTo(id)` opens the panel
with one row highlighted for `LINK_HIGHLIGHT_SECONDS`, which is how another UI
points at a specific setting.

## See also

[PlayerData.md](PlayerData.md) · [registries.md](registries.md)
