# PickupFX

Flying-icon pop FX. Icons appear at a screen point, sail along a randomized bezier arc to a destination (HUD label, inventory slot, anything with a screen position), then fade. Any client code can trigger a burst; any UI can register itself as a destination and react when icons land.

## What it does

`PickupFXController.client.luau` mounts the `Overlay` React component into its own ScreenGui (`DisplayOrder = 1000`), so the icons always draw above every other UI. The Overlay subscribes to the `Manager` singleton, renders one ImageLabel per active icon, and runs a single `RunService.Heartbeat` loop that walks the active list and advances each icon's phase (delay → pop-in → travel → arrive → fade) by writing `Position` and `UIScale.Scale` directly via refs. No per-frame React re-renders.

Per-icon randomization (configured in `Constants.luau`):

| Knob | Range | Why |
| --- | --- | --- |
| Stagger delay | 0 .. 180 ms | Spreads a burst so icons don't move as a clump. |
| Travel duration | 0.55 .. 0.85 s | So icons don't arrive in lockstep. |
| Curve offset | ±150 .. ±350 px | Signed random, so curves arc both ways across the direct line. |
| Pop-in overshoot | 1.15× | Fixed; gives the bounce-in feel without per-icon variance. |

## Studio assets it expects

None. The ScreenGui is created at runtime by the controller. The default rocket icon used in the showcase (`rbxassetid://137349421699691`) is a placeholder — swap `ROCKET_ICON` in `src/features/UIShowcase/UIShowcase.ui.luau` and `RocketCounter.ui.luau` once you have a real upload.

## Packets it speaks

None — client-only FX, not replicated. The server should decide *when* a pickup happens (e.g. via a ByteNet "loot collected" packet) and the client triggers the visual.

## Public API

Require from `ReplicatedStorage.Features.PickupFX`:

```lua
local PickupFX = require(ReplicatedStorage.Features.PickupFX)
```

### `PickupFX.Manager.spawn(opts)`

Queue one or more icons. Works from any client code (controllers, callbacks, command bar — does not require a React tree).

```lua
PickupFX.Manager.spawn({
    icon = "rbxassetid://…",         -- required
    from = Vector2.new(800, 500),    -- required; screen-space, top-left origin
    to = "inventory.gold",           -- optional; Vector2 or registered DestinationId; defaults to `from`
    count = 6,                       -- optional; default 1
    size = Vector2.new(48, 48),      -- optional; default Constants.DEFAULT_SIZE
    onArrival = function() end,      -- optional; per-icon, fires once when that icon lands
})
```

`to` resolution:
- `Vector2` → used as-is.
- `DestinationId` (string) → resolved each frame against `Manager.destinations[id]()`, so the curve tracks a destination that moves/resizes. If unregistered, the icon parks at `from`.

### `PickupFX.Manager.onArrival: Signal`

Fires once per icon as it reaches its destination. Receives the originating `DestinationId` (or `nil` if `to` was a raw Vector2).

```lua
PickupFX.Manager.onArrival:Connect(function(destinationId)
    if destinationId == "inventory.gold" then
        playGoldSound()
    end
end)
```

### `PickupFX.usePickupSpawn()`

Hook form of `Manager.spawn` for symmetry. Identical behaviour; use either.

### `PickupFX.useDestination(id)`

Returns a `ref` to attach to any GuiObject. That object's center (`AbsolutePosition + AbsoluteSize/2`) becomes the live destination for `id`. Auto-registers on mount, removes on unmount.

```lua
local destRef = PickupFX.useDestination("inventory.gold")

React.createElement("Frame", {
    -- …
    ref = destRef,
})
```

Wrap the consumer in a plain Frame if the underlying component (e.g. `ui.Badge`) doesn't expose a `ref` prop — cheaper than threading refs through a shared primitive.

### `PickupFX.useArrival(id, callback)`

Subscribes `callback` to arrivals at destination `id`. The callback is stored in a ref, so re-renders don't re-subscribe — pass an inline closure freely.

```lua
PickupFX.useArrival("inventory.gold", function()
    setCount(function(c) return c + 1 end)
end)
```

## Destination id convention

Namespace by `feature.thing` so ids don't collide as more features adopt the system:

- `inventory.gold`, `inventory.gems`
- `quest.complete`
- `showcase.rockets` (used by the demo)

Ids are plain strings; the Manager doesn't enforce a registry.

## Constants worth knowing

`PickupFX.Constants` (`src/features/PickupFX/Constants.luau`):

| Key | Default | What it controls |
| --- | --- | --- |
| `DEFAULT_SIZE` | `Vector2(48, 48)` | Icon size when `opts.size` is nil. |
| `STAGGER_MIN/MAX` | `0` / `0.18` | Per-icon delay before pop-in. |
| `POP_DURATION` | `0.14` | Pop-in (scale 0 → overshoot → 1). |
| `POP_OVERSHOOT_SCALE` | `1.15` | Peak scale during pop-in. |
| `TRAVEL_MIN/MAX` | `0.55` / `0.85` | Bezier travel duration. |
| `CURVE_OFFSET_MIN/MAX` | `150` / `350` | Perpendicular offset (px) at curve midpoint, signed randomly. |
| `FADE_DURATION` | `0.08` | Scale 1 → 0 after arrival. |
| `OVERLAY_ZINDEX` | `1000` | Overlay's root Frame ZIndex within its ScreenGui. |

The Overlay's ScreenGui `DisplayOrder` (1000) is hard-coded in `PickupFXController.client.luau` — bump it there if another ScreenGui ever needs to draw above pickup icons.

## Priority

`PickupFXController.Priority = 5` — mounts in the early-bootstrap band so the Overlay exists before any feature controller calls `Manager.spawn`. (Manager calls without an Overlay are safe — icons sit in `active` until the Overlay subscribes — but visuals are smoother if the Overlay is up first.)

## Showcase demo

The "Pop" button in `UIShowcase.ui.luau` spawns 8 rockets — each from an independently-chosen random point in the central 60% of the screen — toward destination id `"showcase.rockets"`. `RocketCounter.ui.luau` pins a yellow Badge to the top-right of the screen, registers itself as that destination via `useDestination`, and increments its `useState` count via `useArrival`. Both pieces are deleted along with the rest of `src/features/UIShowcase/` when the demo's no longer wanted.

## Adding a new pickup target

1. Pick an id, namespaced by feature (e.g., `"inventory.coins"`).
2. In the HUD component, wrap the target in a Frame and attach `PickupFX.useDestination("inventory.coins")` as its ref (or attach directly to the GuiObject if it accepts a ref).
3. Optionally call `PickupFX.useArrival("inventory.coins", cb)` in the same component to bump a counter / play a sound / pulse a tween.
4. Wherever the pickup occurs, call `PickupFX.Manager.spawn({ icon = …, from = origin, to = "inventory.coins", count = N })`.

That's the contract. No server code required for the visual; the server only decides when to trigger.
