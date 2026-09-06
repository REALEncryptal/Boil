# Responsive UI

How a screen authored once ends up correct on a phone, a laptop and a 4K monitor.

## The problem this replaces

Before this, nothing in the codebase knew the viewport existed. No root `UIScale`,
no `ViewportSize` read, no touch check, no breakpoint. The entire layer between
the UI and every device Roblox runs on was:

```lua
screen.IgnoreGuiInset = true
```

Everything below it was absolute pixels — 61 literal `UDim2.fromOffset` sizes in
non-story source. The default window was **797 × 595**. On a 375pt phone that
window is wider than the screen; on a 4K monitor a 60px title is a third the size
it was drawn at. Mobile wasn't hard, it was simply never built.

## The model: reference pixels

**Every size in the codebase is authored against a reference resolution of
1280 × 720**, and multiplied at render by a scale derived from the real viewport.

`theme.space.lg` is `20`. That means 20 reference pixels. On a 1080p monitor it
renders at 30. On a phone it renders at about 14. You never write either of those
numbers, and you never branch to get them.

| Where | Units |
| ----- | ----- |
| `size` on a `Surface`, `theme.type.*`, `theme.space.*`, feature `Constants` | reference pixels |
| `position` on a `Surface` | screen-relative (`UDim2.fromScale`) |
| Anything inside a `Surface` | reference pixels — `fromScale(1, 1)` fills the unscaled box |

Position is screen-relative on purpose. Sizes scale; placement shouldn't drift.

## `ui.Surface` — the one thing that applies the scale

```lua
React.createElement(ui.Surface, {
    size = UDim2.fromOffset(720, 480),        -- reference pixels
    position = UDim2.fromScale(0.5, 0.5),     -- screen-relative
    anchorPoint = Vector2.new(0.5, 0.5),
}, { Body = … })
```

A `Surface` is a transparent Frame with a `UIScale`. Because `UIScale` scales the
element *and* its descendants about its `AnchorPoint`, a centered Surface stays
centered and grows. Everything inside is authored against the unscaled box.

**Wrap every feature UI in a Surface.** `ui.Window` already mounts its own, so a
window-based screen gets this for free.

**Don't wrap a full-bleed layer.** A click-catcher or an FX overlay wants
`UDim2.fromScale(1, 1)` and no scaling. Use a plain Frame and put Surfaces inside
it — that's exactly how the client root is built.

**Never nest two Surfaces**, or the scale is squared. `ui.Window` takes
`responsive = false` for the case where it's already inside one.

## The scale itself

From `src/shared/ui/viewport.luau`:

```
fit   = min(viewport.X / 1280, viewport.Y / 720)
scale = clamp(fit * deviceBoost, 0.6, 2.0)
```

`min` of both axes, never `max` and never width-only, so a surface authored at the
reference always fits both dimensions — on an ultrawide the height governs, on a
tall phone the width does.

| Device | Boost | Why |
| ------ | ----- | --- |
| phone | 1.35 | Fewer elements on screen and a finger needs a bigger target, so phone UI is deliberately *relatively* larger than a proportional shrink |
| tablet | 1.1 | Same effect, milder |
| console | 1.15 | Ten-foot viewing distance |
| desktop | 1.0 | The baseline |

Worked examples:

| Viewport | Device | Scale | `body` (22 ref) renders at |
| -------- | ------ | ----- | ------------------------- |
| 1920 × 1080 | desktop | 1.50 | 33px |
| 2560 × 1440 | desktop | 2.00 | 44px |
| 1024 × 768 | tablet | 0.88 | 19px |
| 812 × 375 | phone | 0.70 | 15px |

## Hooks — for layouts that *change*, not just shrink

Most components never call these. Reach for them when a phone needs a genuinely
different arrangement, not a smaller one.

```lua
local vp = ui.useViewport()   -- { size, device, scale, isTouch }
local device = ui.useDevice() -- "phone" | "tablet" | "console" | "desktop"
local scale = ui.useScale()   -- the number
```

The HUD has exactly one such branch: a phone opens near-fullscreen windows,
because a 720 × 480 float that reads fine on a monitor wastes most of a phone
screen and cramps its own content.

### Previewing another device

`ViewportProvider` overrides the values for a subtree, which is what lets a UI
Labs story show the phone layout on a desktop:

```lua
React.createElement(ui.ViewportProvider, { device = "phone" }, { Screen = … })
```

The Theme, Window, Surface and HUD stories all expose this as a `device` control.
**Use it before shipping any new screen** — it is the whole mobile check.

## Touch

`useHoverScale` does not bind hover on a touch device, and its `events` map omits
`MouseEnter` / `MouseLeave` there. Roblox fires those inconsistently for a finger
(enter on touch-down, leave sometimes never), which is what used to leave a button
stuck in its hovered state after a tap. Touch gets press feedback only, plus an
`InputEnded` guard so a finger dragged off the control still releases.

Wire a control by spreading the map rather than naming handlers:

```lua
local hover = ui.useHoverScale()
-- merge hover.events(onClick, disabled) into your TextButton props
```

`Button`, `IconButton` and `Checkbox` also carry a `UISizeConstraint` floored at
`tokens.minTouchTarget` (38 reference px), so a control can never render below
finger size no matter what the call site asks for.

## Checklist for a new screen

1. Author at the reference resolution. Use roles and space steps, not numbers.
2. Wrap it in a `ui.Surface` (or a `ui.Window`, which is one).
3. Position with `fromScale` + `anchorPoint`.
4. Open its story, flip `device` to `phone`, and look at it.
5. If it only needs to be *smaller* on a phone, you're done. If it needs to be
   *different*, `ui.useDevice()` — and say why in a comment.

## See also

- `src/shared/ui/tokens.luau` — the reference resolution and both scales
- `src/shared/ui/viewport.luau` — scale and device classification
- `src/shared/ui/Surface.luau` — the seam
- [skin-contract.md](skin-contract.md) — the type and space scales
- [layout-surfaces.md](layout-surfaces.md) — arranging content inside a Surface
