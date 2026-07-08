# UIShowcase

A client-only demo feature that mounts a screen recreating the Studio gem-button template using the shared UI primitives in `src/shared/ui/`. It exists as a visual smoke test — delete the folder (`src/features/UIShowcase/`) once you're confident the primitives match the artwork.

## What it does

`UIShowcaseController.client.luau` runs on player join, creates a `ScreenGui` named `UIShowcase` under `PlayerGui`, and renders `UIShowcase.ui.luau` into it. The component composes:

- One `ui.Panel` (translucent dark glass container, 797×595).
- A top row: `ui.Badge` ("Rebirth" + icon) on the left, `ui.Button` ("X", red) on the right, sized so they share the row without overflow.
- A vertical column of `ui.Button`s — one per palette in `assets.Variants` — to visually exercise every color.

`HUD.ui.luau` is the HUD demo — a Sidebar of icon+label entries that toggle `ui.Window` frames via `UIShell`. It takes an optional `frameContents: { [id]: React.Element }` prop; any id supplied there gets mounted as that window's content instead of the default placeholder rows. The client entry script (`src/client/init.client.luau`) uses this to wire the Settings sidebar entry to the real Settings feature:

```lua
HUD = React.createElement(UIShowcase.HUD, {
    frameContents = {
        [Settings.FRAME_ID] = React.createElement(SettingsView),
    },
}),
```

Inventory and Shop currently fall through to placeholder rows; mount real feature components the same way once they exist.

## Prototype stories

Besides the mounted demo, the folder carries story-only screen prototypes (no `.ui.luau`, nothing ships to the game) used to iterate layouts in UI Labs before a real feature owns them: `IndexUI.story.luau`, `RebirthUI.story.luau`, and `UpgradesUI.story.luau` (upgrade list — name over a muted level label, now ► next stat preview, green price button that flips to a disabled MAXED at cap; cost/level advance live on click).

## Studio assets it expects

None at runtime — every asset is referenced as a literal `rbxassetid://`. The "Rebirth" icon (`rbxassetid://137349421699691`), gem font (`rbxassetid://12187373592`), and noise texture (`rbxassetid://127211237265741`) are all uploaded assets, not Studio instances.

## Packets it speaks

None — the showcase is local-only.

## Constants worth knowing

- `REBIRTH_ICON` (local in `UIShowcase.ui.luau`) — change if the badge icon changes.
- `UIShowcaseController.Priority = 100` — mounts after gameplay controllers so it doesn't compete for early bootstrap.

## When to remove

This is intentionally a demo. When real HUD features take over, delete `src/features/UIShowcase/`; nothing else depends on it.
