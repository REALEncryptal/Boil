# Device scale (seam #5)

Seam #5 is **how big the UI is on the player's device**.

The other four seams answer questions about the UI itself: how a primitive *looks*
(skin), how a screen is *arranged* (layout), how a feature *presents* (view), and
whether it's a screen GUI at all (presentation). None of them asks how large the
screen actually is.

That's a real hole, because every skin token is a fixed pixel offset —
`theme.buttonSize = UDim2.fromOffset(60, 60)`, `theme.padding = 10`,
`theme.textSizeXL = 60`, `theme.windowSize = UDim2.fromOffset(797, 595)`. A window
of 797×595 design pixels is a comfortable panel on a 1920×1080 monitor and covers
almost the entire screen of a phone reporting 1136×640. Nothing in the framework
used to ask the question, so every screen was implicitly authored at desktop size.

Without a seam, each feature has to notice the problem and solve it itself: read
the viewport, mount its own root `UIScale`, get the math right. That works exactly
once — the *next* screen anyone writes covers a phone until its author remembers to
repeat the pattern. So scaling is framework infrastructure, mounted once at the
root, and a feature gets it by existing.

## The surface: `ui.Canvas`

```lua
React.createElement(ui.Canvas, {}, { App = … })
```

A Canvas fills the box it's given and draws its contents at the device's scale.
`src/client/init.client.luau` mounts one around the whole client tree, inside the
`SkinProvider`. **A feature does nothing to opt in.**

### How it's built, and why not just a `UIScale`

```
outer Frame       fills the parent, measured — the real pixel box
  └ inner Frame   offset-sized to `box / scale`, centered
      ├ UIScale   Scale = scale
      └ children
```

Scaling the inner frame by `scale` while sizing it `1/scale` larger means it
renders at *exactly* the outer box. The canvas stays full-bleed, and that's the
whole trick:

- a child placed in **scale units** (`UDim2.fromScale(0.5, 0.5)`, an edge anchor)
  lands on the same fraction of the screen it always did;
- a child sized in **offsets** — which is every skinned primitive — gets `scale`×
  pixels.

A bare `UIScale` on a full-scale root frame does not do this. It shrinks the frame
itself, so a corner-anchored badge drifts toward the middle of the screen and a
0.6× HUD leaves 40% of the display empty.

The factor comes from the outer frame's own `AbsoluteSize`, not from the camera. A
Canvas inside a fixed-size frame therefore scales as though that frame were the
whole screen — which is what makes the device simulator in `Canvas.story.luau`
honest rather than a mock-up, and what makes a Canvas behave inside a UI Labs
panel.

## The policy: `src/shared/ui/scale.luau`

`scale.compute(viewport, isTouch)` turns a pixel box into the factor, in four
steps:

1. `raw = min(viewport.X / reference.X, viewport.Y / reference.Y)` — the largest
   uniform factor that still fits the design canvas on both axes.
2. `raw ^ responsiveness` — softening.
3. `× touchBoost` on touch-only devices.
4. clamp to `[minScale, maxScale]`.

| Token | Default | Meaning |
| ----- | ------- | ------- |
| `referenceViewport` | `1920×1080` | The resolution every screen is authored at. Change it only if you re-author the token ladder in `theme.luau` to match. |
| `responsiveness` | `1` | `1` = fully proportional (the design, letterboxed — WYSIWYG). `0` = never scale. Between = shrink less than the viewport did, trading fidelity for legibility. |
| `minScale` / `maxScale` | `0.5` / `1.25` | The clamp — how bad it's allowed to get in either direction. |
| `touchBoost` | `1.1` | Extra size on a touch-only device (touch **and no keyboard**), because a finger needs a bigger target than a cursor. |

These are framework tokens, not skin tokens: how large the UI is on a device is a
property of the *device*, not of the look, and every skin scales by the same
policy. `scale.luau` is the one place they live.

**Tune them in the `Canvas` story.** It renders a frame of exactly the chosen
device's pixels, so you can see what a phone gets, and its sliders mutate
`ui.scale.*` live the way the Theme story mutates `ui.theme.*`. Settle on values,
then copy them back into `scale.luau`.

## What a feature does

Nothing. That's the point. Compose `ui.*` primitives with offset sizes as usual and
the canvas handles the rest.

The hooks are escape hatches, not the normal path:

```lua
local scale = ui.useViewportScale()  -- the factor being drawn at
local surface = ui.useSurface()      -- { scale, viewport, isTouch, insets, locked }
```

Reach for them only when something leaves the canvas's coordinate space:

- sizing or positioning in **absolute screen pixels** (a world-space billboard, an
  overlay that reads `AbsolutePosition`),
- choosing **content** rather than size — a compact layout below some threshold,
- telling a **non-React system** (a viewport-frame camera, a particle emitter) how
  big the UI it has to match is.

> **Don't multiply by `useViewportScale()` inside the canvas.** The canvas already
> applied it; doing it again double-scales. If a size looks wrong on a phone, the
> fix is the policy tokens, not a per-call-site correction.

For "is this a phone", prefer `ui.useSurface().isTouch` over comparing scale
numbers.

### Overriding the factor for a subtree

```lua
React.createElement(ui.ScaleProvider, { scale = 0.75 }, { App = … })
React.createElement(ui.ScaleProvider, { viewport = Vector2.new(1136, 640) }, { App = … })
```

`ScaleProvider` mirrors `SkinProvider`: context, optional, falls back to live
measurement when absent. An explicit `scale` or `viewport` *pins* the surface
(`locked = true`) and a Canvas below uses that factor instead of recomputing from
its own box. Overriding only `insets` or `isTouch` does not pin anything — which is
what lets the `SafeArea` story fake a topbar without also freezing the scale.

### Two things not to do

- **Don't nest a Canvas inside a Canvas.** The inner one scales already-scaled
  pixels. Use `ScaleProvider` to vary the factor for a subtree.
- **Don't wrap an absolute-coordinate overlay in a Canvas.** `PickupFX` mounts its
  own high-`DisplayOrder` ScreenGui and animates icons between screen positions
  read from `AbsolutePosition` — real device pixels. A Canvas around it would scale
  those coordinates and send every icon to the wrong place. A feature that mounts
  its own ScreenGui wraps it in a Canvas *if it lays out in design pixels*, and
  leaves it bare if it works in screen pixels.

## Safe area

Two different intrusions, handled in two different places:

- **Device cutouts** — notch, rounded corners, home indicator. The engine handles
  these. `BoilRoot` sets `ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets`, which
  supersedes the older `IgnoreGuiInset`: the GUI still spans the whole screen
  (including under the Roblox topbar, which centered content wants) while the
  engine keeps it clear of the cutouts. No UI code participates.
- **The Roblox topbar** — the engine does *not* reserve this for a full-bleed
  ScreenGui, so anything anchored to the top edge draws underneath the chat and
  menu buttons. This one is ours.

Wrap top-anchored chrome in `ui.SafeArea`:

```lua
React.createElement(ui.SafeArea, { extra = 10 }, {
    Hud = React.createElement(ui.Row, { … }),
})
```

It's a structure-only layout primitive in the same family as `Stack` / `Row` /
`Grid` / `Slot` — it draws nothing, it just insets. Sides opt out individually
(`{ top = false }` for a bottom-anchored action bar), and `extra` adds padding on
every enabled side.

For a single widget rather than a region, `ui.useSafeArea()` returns the raw
numbers. **They're in canvas units** — already divided by the active scale — so they
compose with `theme.padding` and friends. That conversion matters: a topbar is a
fixed number of *device* pixels no matter how small the UI is drawn, so inside a
canvas at 0.6× it covers proportionally more canvas.

The root is deliberately **not** wrapped in a `SafeArea`. Full-bleed is right for a
root canvas — a background, a vignette, a centered window all want the whole screen
— and only the elements that actually reach for an edge need insetting.

## Touch input

`useHoverScale` was mouse-shaped: `MouseEnter` / `MouseLeave` never fire on a
touchscreen, so a phone player got no feedback at all — the button just sat there.
The handle now also exposes `onInputBegan` / `onInputEnded`, wired alongside the
mouse events on every shared button:

```lua
[React.Event.MouseEnter] = hover.onEnter,
[React.Event.MouseLeave] = hover.onLeave,
[React.Event.MouseButton1Down] = hover.onPress,
[React.Event.MouseButton1Up] = hover.onRelease,
[React.Event.InputBegan] = hover.onInputBegan,
[React.Event.InputEnded] = hover.onInputEnded,
```

Both touch handlers ignore every input type except `Touch`, so they stack with the
mouse handlers rather than double-firing (a mouse click would otherwise play the
press cue twice).

What a tap animates depends on `triggerKind`, because touch has no hover state:
`"button"` plays press-and-release (the finger-down feedback a phone player
expects), `"hover"` maps touch down/up onto enter/leave so a hover-only affordance
still reveals itself on tap.

A new interactive element should wire all six. `Button`, `IconButton`, `Checkbox`
(gem and flat) and the Sidebar item already do.

## Files

| File | Role |
| ---- | ---- |
| `src/shared/ui/scale.luau` | The policy: tokens + `compute` (pure). |
| `src/shared/ui/Canvas.luau` | The surface. Mounted at the client root. |
| `src/shared/ui/ScaleProvider.luau` | Context + `useSurface`; the override escape hatch. |
| `src/shared/ui/SafeArea.luau` | Structure-only region inset from the topbar. |
| `src/shared/ui/useViewportScale.luau` | The factor, for code that leaves canvas space. |
| `src/shared/ui/useSafeArea.luau` | Insets in canvas units. |
| `src/shared/ui/useViewport.luau` | Live camera viewport (handles camera swap on respawn). |
| `src/shared/ui/useMeasuredSize.luau` | Live `AbsoluteSize` of a GuiObject. |
| `src/shared/ui/insets.luau` | Raw screen insets from `GuiService`. |
| `src/shared/ui/Canvas.story.luau` | Device simulator + policy sliders. |
| `src/shared/ui/SafeArea.story.luau` | Topbar simulator. |

## Studio assets

None. The seam is entirely code.

## Verifying

`lune run tools/split` is the build signal as always. Beyond that, the honest check
is the `Canvas` story: switch between the phone and desktop presets and confirm the
window fits, the HUD row clears the simulated topbar, and the corner badge stays in
its corner. In-game, a Studio Play test with the device emulator set to a phone is
the final word — and `useHoverScale`'s touch path only really proves itself with
Studio's touch emulation on.
