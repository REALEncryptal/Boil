# Sidebar

A vertical column of clickable icons. Each entry is **just the icon image**,
with its label overlaid inside the bottom of the icon — no gem background,
no panel chrome, no drop-shadow. Designed to live at the edge of the screen
and act as the primary navigation surface (open Inventory, Shop, Settings,
etc.). Wraps cleanly inside `UIShell.HideWhenFrameOpen` so it slides off
when any frame is open.

The label uses plain `ui.Text` (no `shadow`) with a Miter UIStroke for
contrast — same outline as the gem ShadowText, just without the offset
shadow layer. Weight is `Heavy`. If a chosen icon has a busy bottom edge
that swallows the label, prefer iterating the icon over re-adding shadow.

Hover behavior: the whole entry scales up (`useHoverScale`), and the **icon
only** tilts on hover. The tilt magnitude is rolled once at mount (random in
`[HOVER_TILT_MIN_DEG, HOVER_TILT_MAX_DEG]`, sign 50/50) and reused for every
subsequent hover — each item has its own signature angle. The label stays
upright because rotation lives on an inner `ImageLabel`, not the outer
click target.

## Studio assets

None. Sidebar mounts inside the existing `BoilRoot` ScreenGui created in
`src/client/init.client.luau`.

Icon assets: each item needs an `icon` (rbxassetid://…) you upload yourself.
The boilerplate uses `rbxassetid://137349421699691` (the same placeholder as
UIShowcase) for the bundled items — swap them for your own art.

## Packets

None. Sidebar is a pure-UI primitive; state lives in whatever the items'
`onClick` handlers do (typically `UIShell.useFrame().open(id)`).

## Public API

```lua
local Sidebar = require(ReplicatedStorage.Features.Sidebar)
```

### `<Sidebar.UI items={…}>`

```lua
React.createElement(Sidebar.UI, {
    items = {
        { id = "Inventory", icon = "rbxassetid://…", label = "Inventory",
          onClick = function() ... end },
        { id = "Shop",      icon = "rbxassetid://…", label = "Shop",
          onClick = function() ... end },
    },
    iconSize  = 72,                       -- optional, square item size (px)
    labelSize = 18,                       -- optional, label TextSize
    spacing   = 12,                       -- optional, gap between items
    padding   = 12,                       -- optional, outer padding
    position  = UDim2.fromScale(0, 0.5),  -- defaults to left-center
    anchorPoint = Vector2.new(0, 0.5),
})
```

Each item:

| Key       | Type             | Notes                                                          |
| --------- | ---------------- | -------------------------------------------------------------- |
| `id`      | `string`         | React child key. Must be unique across the items list.         |
| `icon`    | `string`         | `rbxassetid://…` image. Drawn `ScaleType = Fit`.               |
| `label`   | `string`         | Plain text overlaid at the bottom-inside of the icon.          |
| `onClick` | `(() -> ())?`    | Fired on Activated. `nil` makes the item visually inert.       |

The container auto-sizes vertically — height follows item count. Width is
fixed by `iconSize + 2 * padding`.

### `<Sidebar.Item>`

The single-entry component, exported for when you need to drop an icon+label
into a layout that isn't a Sidebar column.

```lua
React.createElement(Sidebar.Item, {
    icon = "rbxassetid://…",
    label = "Inventory",
    onClick = function() ... end,
})
```

## Constants worth knowing

`Sidebar.Constants` (`src/features/Sidebar/Constants.luau`):

| Key | Default | What it controls |
| --- | --- | --- |
| `DEFAULT_ICON_SIZE`      | `72` | Square item side length (px). |
| `DEFAULT_LABEL_SIZE`     | `26` | Label `TextSize` (px). |
| `LABEL_STROKE_THICKNESS` | `2`  | Miter UIStroke thickness on the label. Set to `0` and update SidebarItem to drop the outline. |
| `LABEL_BOTTOM_INSET`     | `6`  | Pixels between the label's bottom edge and the icon's bottom edge — keeps the label inside the icon. |
| `HOVER_TILT_MIN_DEG`     | `4`  | Minimum random tilt magnitude applied to the icon on hover (degrees). |
| `HOVER_TILT_MAX_DEG`     | `12` | Maximum random tilt magnitude. Set to `0` (both) to disable the tilt entirely. |
| `ITEM_SPACING`       | `12` | Vertical gap between sibling items (px). |
| `PADDING`            | `12` | Outer Sidebar padding (px). |

## Priority

None — Sidebar has no `Service` / `Controller`. It's mounted as a React
subtree from `src/client/init.client.luau`.

## Wiring to UIShell

The bundled sidebar (in the client entry) toggles two demo frames:

```lua
local frames = UIShell.useFrame()
items = {
    { id = "Inventory", ..., onClick = function() frames.toggle("Inventory") end },
    { id = "Shop",      ..., onClick = function() frames.toggle("Shop") end },
}
```

`useFrame` must be called inside the React tree, so the sidebar item list is
built inside a small wrapper component (`SidebarMount`) in the entry script.
Mirror that pattern when extending the menu.

To make a sidebar entry actually open a window, render the matching
`<UIShell.Frame id="Inventory">` somewhere in the tree with your window
contents — see `docs/game/UIShell.md` § "Adding a new frame".
