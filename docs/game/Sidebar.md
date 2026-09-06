# Sidebar

A vertical column of clickable icon entries. Each entry is *just the icon image*
with its label overlaid inside the bottom — no panel, no gem background, no drop
shadow. It renders no chrome and holds no position of its own; the HUD places it
and wraps it in `HideWhenFrameOpen`.

## Shape

- `Sidebar.ui.luau` — the column. Auto-sizes vertically with the item count;
  width is one icon plus padding.
- `SidebarItem.ui.luau` — one entry: an outer click target wrapping an inner
  `ImageLabel`, with the label drawn over it.
- Items arrive as a list (`id`, `icon`, `label`, `onClick`). The Sidebar owns no
  state — `HUDView` builds that list from the Nav registry.
- `Sidebar.Item` is exported on its own, for a layout that wants one entry
  outside a column.

## Decisions

- **The label is plain `ui.Text` with a Miter stroke, not the gem ShadowText.**
  Same outline, without the offset shadow layer. If an icon's busy bottom edge
  swallows the label, iterate the icon — re-adding the shadow was tried and reads
  badly against arbitrary art.
- **Rotation lives on the inner `ImageLabel`, not the click target,** so the icon
  tilts on hover while the label stays upright.
- **Each item rolls its tilt magnitude once at mount** and reuses it for every
  hover, so an item has one signature angle instead of a new random one each
  time. Zero both `HOVER_TILT_*_DEG` to turn the tilt off.
- **No chrome and no position.** The Sidebar is a primitive its parent arranges;
  giving it a panel or a default screen position would fight whatever holds it.

## Gotchas

No Studio assets, but every item needs an icon you upload — the bundled ids are
placeholders. Sizing, spacing and tilt range live in `Constants.luau`.

## See also

[HUD.md](HUD.md) · [UIShell.md](UIShell.md)
