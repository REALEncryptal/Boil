# PickupFX

Flying-icon pop FX. Icons appear at a screen point, sail along a randomized
bezier arc to a destination, then fade. Any client code can trigger a burst, and
any UI can register itself as a destination and react when icons land there.

## Shape

- `Manager` — a singleton, not a React context. Holds the active icon list and
  the destination table.
- `Overlay.ui.luau` — subscribes to the Manager and renders one ImageLabel per
  active icon.
- `PickupFXController.client.luau` — mounts the Overlay in its own ScreenGui at a
  very high `DisplayOrder` so icons draw above every other UI.
- Hooks: `useDestination(id)` hands back a ref that marks a GuiObject as a
  target, `useArrival(id, cb)` fires when icons land there, `usePickupSpawn()` is
  the hook form of `Manager.spawn`.
- Destination ids are plain strings namespaced `feature.thing`
  (`inventory.gold`, `quest.complete`) — nothing enforces a registry.

## Decisions

- **One Heartbeat loop writes `Position` and `UIScale` through refs.** Driving
  the animation from React state would re-render the tree every frame for a
  purely visual effect. Do not "simplify" this into state.
- **The Manager is a singleton, not a Provider.** Spawns come from controllers,
  callbacks and the command bar — code that is not inside a React tree. A
  context would make those call sites impossible.
- **Destinations resolve every frame,** so a curve tracks a target that moves or
  resizes instead of aiming at a stale point captured at spawn.
- **`useArrival` keeps its callback in a ref,** so re-renders do not re-subscribe
  and callers can pass an inline closure freely.
- **Every icon is randomized** — stagger, travel time, and a signed curve offset.
  A burst on identical parameters reads as one clumped object rather than many.
- **Client-only, never replicated.** The server decides *when* a pickup happens;
  the visual carries no authority.

## Gotchas

No Studio assets — the ScreenGui is created at runtime and the default icon id is
a placeholder. Tuning lives in `Constants.luau`, but the ScreenGui's
`DisplayOrder` sits in the controller; bump it there if something ever needs to
draw above the icons. Wrap a target in a plain Frame when the component you want
to aim at does not expose a `ref` prop.

## See also

[HUD.md](HUD.md)
