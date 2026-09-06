# Presentations & the self-registering client entry

A **presentation** is one way a feature shows up for the player. The same headless
core (see [headless-core.md](headless-core.md)) can drive several at once:

| Kind | File suffix | Realm | Discovered by | Registers / binds |
| ---- | ----------- | ----- | ------------- | ----------------- |
| **Screen** | `*Presentation.client.luau` | client | `init.client.luau` | a HUD window slot (`HUD.setScreen`, paired with a shared `Nav.luau`) |
| **Root** | `*Presentation.client.luau` | client | `init.client.luau` | an always-mounted top-level element (`UIRegistry.registerRoot`) |
| **World** | `*WorldInteraction.client.luau` | client | `init.client.luau` | a CollectionService-tagged part → calls a core intent |
| **Command** | `*Command.server.luau` | server | `init.server.luau` | a Cmdr command → calls a core intent |

Presentations are **peers**. They never reference each other; they stay in sync
because they all read/write the same replicated state through the feature's core
intent. Adding or removing one is local to the feature.

## Zero edits to the root client file

`src/client/init.client.luau` names **no content feature**. It:

1. auto-requires every feature (so load-time auto-discovery runs),
2. discovers + requires all `*Presentation` / `*WorldInteraction` modules **before
   the root mounts** (they self-register into `UIRegistry`),
3. mounts `SkinProvider → FrameProvider → Frame(UIRegistry.getRoots())`,
4. then loads + starts `*Controller` modules and requests replicas.

`src/server/init.server.luau` likewise discovers `*Command` modules after the
services start. So **adding a feature or a presentation is zero edits to either
entry file** — drop the feature folder and its presentation modules.

The one feature the client root still names is **UIShell**, because its
`FrameProvider` is the structural shell that must wrap the whole tree. That's
infrastructure, not content.

## The registry

`src/shared/utils/UIRegistry.luau` holds two client-side maps:
- **roots** — `registerRoot(name, element)` / `getRoots()`: always-mounted
  top-level UI (the HUD host, the Health widget).
- **screens** — `HUD.setScreen(navId, element)`: HUD window
  contents keyed by UIShell frame id. The HUD reads these to fill its slots
  (`frameContents` prop still overrides, used by the UI Labs preview).

## Per-feature config

Each feature's `Constants.luau` carries a `Presentations` table; every
presentation module checks its flag before registering, so a game can switch a
surface off without deleting code:

```lua
-- Settings/Constants.luau
Presentations = { screen = true, world = true },
-- HUD/Constants.luau
Presentations = { root = true },
```

## The shipped proofs

- **Settings** — screen (`SettingsPresentation`) + world
  (`SettingsWorldInteraction`). The world part's ProximityPrompt and the Settings
  window both call `SettingsController.setToggle`, staying in sync via the replica.
  Neither surface knows the other exists.
- **HUD** — root (`HUDPresentation`). Mounts the heads-up display itself, which is
  where every other feature's screen surface lands.

A screen surface is now two files rather than one, because its halves live in
different realms: a shared `Nav.luau` declaring the entry, and a client
`*Presentation.client.luau` supplying the element via `HUD.setScreen`. See
[HUD.md](HUD.md).

### Studio assets the world proof needs (Rojo only syncs code)

For the Settings world toggle to do anything, create in Studio:

1. A **Part** (anchored, reachable) with the CollectionService tag
   **`SettingsToggleStation`** (Tag Editor, or the attribute/tag UI).
2. A **String attribute** named **`SettingId`** on that part, set to an existing
   setting id — e.g. **`music.enabled`** (the Music feature's toggle).

A `ProximityPrompt` is added automatically if the part doesn't already have one.
Walk up to the part, trigger the prompt, and watch the Settings window's Music
toggle flip in lock-step.

### Adding a Cmdr command

Drop a `*Command.server.luau` in your feature folder; the server entry discovers
it with no edit anywhere else. Route it through the feature's one core intent —
the same function the GUI calls — so the two surfaces can't drift:

```lua
-- Shop/ShopCommand.server.luau
Cmdr.Registry:RegisterCommand(definition, function(context, amount)
    ShopService.grant(context.Executor, amount)   -- the same validated write the UI uses
end)
```

Commands are gated by the username allowlist in `CmdrService`'s BeforeRun hook.
