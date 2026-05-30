# UIShell

The frame system. Ensures at most one frame is open at a time and lets HUD / side-bar content slide off-screen while a frame is open. No visual chrome of its own — pair `<Frame>` with `<Window>` (or any other content) for the looks.

## Studio assets

None. UIShell mounts inside the existing `BoilRoot` ScreenGui (created in `src/client/init.client.luau`).

## Packets

None. State is client-only and ephemeral; not replicated.

## Public API

Require from `ReplicatedStorage.Features.UIShell`:

```lua
local UIShell = require(ReplicatedStorage.Features.UIShell)
```

### `<UIShell.FrameProvider>`

Wraps the React tree once, near the root. Every `<Frame>` and `<HideWhenFrameOpen>` must be a descendant. Already mounted by `src/client/init.client.luau` — features don't need to add their own.

### `UIShell.useFrame()`

Hook returning the shell controls. Call from any descendant of `<FrameProvider>`:

```lua
local frames = UIShell.useFrame()
frames.openFrameId         -- string? — current open id (nil = nothing open)
frames.open("Inventory")   -- opens by id; auto-closes any previous frame
frames.close()             -- closes whatever is open
frames.toggle("Inventory") -- open if closed, close if open
```

Errors if called outside a `<FrameProvider>`.

### `<UIShell.Frame id="…">`

State-driven visibility wrapper. Renders nothing until `openFrameId == id`, then mounts its children with a UIScale enter tween. Closing runs the exit tween, then unmounts. Renders no chrome.

```lua
local frames = UIShell.useFrame()

React.createElement(UIShell.Frame, {
    id = "Inventory",
    -- optional: override either tween (each falls back to Constants).
    -- enterTweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
    -- exitTweenInfo  = TweenInfo.new(0.1, Enum.EasingStyle.Quad,    Enum.EasingDirection.Out),
    -- scaleFrom = 0.8, -- start/exit UIScale value
}, {
    Window = React.createElement(ui.Window, {
        title = "Inventory",
        onClose = frames.close,  -- close button wires to the shell
    }, {
        -- inventory rows...
    }),
})
```

The window grows from `scaleFrom` (default `0.8`) to `1` on enter with the elastic-out tween, and shrinks back on exit with the quad-out tween. The wrapper stays centered — there's no slide-in mode.

The close button on `<Window>` is wired by the consumer (`onClose = frames.close`). `Frame` does not modify its children's props.

### `<UIShell.HideWhenFrameOpen direction="…">`

Wrap HUD / side-bar content. Slides off-screen by `direction` whenever any frame is open.

```lua
React.createElement(UIShell.HideWhenFrameOpen, {
    direction = "left",                       -- "left" | "right" | "top" | "bottom"
    basePosition = UDim2.fromScale(0, 0.5),   -- on-screen position
    anchorPoint = Vector2.new(0, 0.5),
    size = UDim2.fromOffset(220, 400),
    -- optional overrides:
    -- hideTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
    -- showTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}, {
    SideBar = React.createElement(MySideBar),
})
```

## Constants worth knowing

`UIShell.Constants` (`src/features/UIShell/Constants.luau`):

| Key | Default | What it controls |
| --- | --- | --- |
| `ENTER_TWEEN_INFO` | `TweenInfo.new(0.8, Elastic, Out)` | Frame enter tween — snappy elastic landing. |
| `EXIT_TWEEN_INFO` | `TweenInfo.new(0.1, Quad, Out)` | Frame exit tween — flat dismiss. |
| `ENTER_SCALE_FROM` | `0.8` | Start/exit UIScale value for the frame. |
| `HIDE_OFFSCREEN_OFFSET` | `1.0` | Scale-units a hidden element slides past the edge. |
| `HIDE_HIDE_TWEEN_INFO` | `TweenInfo.new(0.3, Quad, In)` | Side-bar slide off-screen (slow part on-screen). |
| `HIDE_SHOW_TWEEN_INFO` | `TweenInfo.new(0.3, Quad, Out)` | Side-bar slide back (gentle on-screen landing). |

## Priority

None — UIShell has no `Service` / `Controller`. The provider is a React component mounted from the client entry script; no startup ordering applies.

## Adding a new frame

1. Pick an id string (e.g., `"Settings"`).
2. Render `<UIShell.Frame id="Settings">{ contents }</UIShell.Frame>` somewhere inside the FrameProvider — typically as a sibling of HUD in the root tree, or owned by the feature itself.
3. Wherever a button should open it, call `UIShell.useFrame().open("Settings")`.

That's the whole contract. The single-frame invariant is enforced by everyone keying off the same `openFrameId`.
