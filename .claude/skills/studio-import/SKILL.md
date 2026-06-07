---
name: studio-import
description: Scaffold shared/ui code or theme entries from a Roblox Studio template. Use when the user says they built something in Studio and wants it converted to React/Luau — phrases like "I made a button in Studio", "add a new variant", "import this template", "scaffold from Studio", "new theme", "new gem palette". The user runs an inspector module in the command bar; you receive the property dump and generate the code.
---

# Studio Import

End-to-end workflow for turning a Studio-designed UI into shared/ui code.

## Step 1 — Have the user run the inspector

In the very first response, ask them to **select the root instance(s)** of their template in Explorer, then paste this one-liner into the Studio command bar:

```lua
require(game.ReplicatedStorage.Shared.dev.Inspect)()
```

The inspector walks the selection recursively, dumps only non-default properties for every known UI class (Frames, Labels, Strokes, Gradients, Layouts, Constraints, FlexItems, ScrollingFrames, etc.), prints to Output, and copies to clipboard. Ask them to paste the clipboard contents back.

**If `require` errors with "Inspect is not a valid member of dev"** — Rojo hasn't synced `src/shared/dev/Inspect.luau` yet. Have them connect Rojo and run `lune run tools/split` once.

## Step 2 — Classify the intent

Match the user's request and the dump shape to one of these categories. Ask if it's genuinely ambiguous; don't ask if a single category is obvious from context.

| Intent | Signal | Output location |
| ------ | ------ | --------------- |
| **New color variant** | "new variant", "palette"; dump is mostly a single Frame with one or two `UIGradient.Color` values | Append entry to `Assets.Variants` (Button-style) or `Assets.BadgeVariants` (Badge-style) in `src/shared/ui/assets.luau` |
| **Theme tweak** | "theme", "rebrand"; multiple ColorSequence values that change across all existing variants | Edit existing entries in `Assets.Variants` / `Assets.BadgeVariants` |
| **New gem-style component** | Dump shows the gem pattern (BackgroundDeco with tiled noise + UIGradient + UIStroke ladder, FgTextLabel pattern) | New file in `src/shared/ui/<Name>.luau`; **compose `GemBackground` and `ui.Text` with `shadow = true`** — don't re-roll the visual stack |
| **New non-gem component** | Different visual style (plain panel, tooltip, list row, etc.) | New file in `src/shared/ui/<Name>.luau`; mirror `Panel.luau`'s simple pattern |
| **Feature-specific UI** | User refers to a gameplay feature ("inventory window", "shop card") | `src/features/<Feature>/<Name>.ui.luau`; `init.luau` re-exports |

## Step 3 — Scaffold

Hard rules (don't skip):

- **Match child names exactly** to the Studio template (`UIStroke`, `UIListLayout`, `BackgroundDeco`, `FgTextLabel`, etc.). The diff tool in `tools/` matches by name; divergent names break it. Roblox allows duplicate names at different parents — that's fine.
- **Set explicit `ZIndex` on every sibling that visually layers.** React-Roblox doesn't guarantee tree order for named-table children, so ZIndex-tied layering randomizes per render. UIStrokes also need explicit ZIndex (new property; defaults to 1).
- **Set explicit `LayoutOrder`** on children of a UIListLayout when order matters. Same reason as ZIndex.
- **Use `BorderStrokePosition = Inner`** on Border-mode UIStrokes if the template does — default is Outer and the stroke draws outside the parent edge.
- **Compose `ui.Text` (with `shadow = true`) and `GemBackground`** for any new gem-styled surface. They live in `src/shared/ui/` and are exported from `init.luau`.
- **Put palettes in `Assets`**, not raw ColorSequences at the call site.
- **Export new top-level components** via `src/shared/ui/init.luau`.
- **Drop a `<Name>.story.luau`** next to any new top-level component for UI Labs. Use `UILabs.Choose({...})` for enums and `UILabs.Slider(value, min, max, step)` for numerics — a bare array gives "Malformed control object."

Project conventions to consult:

- `docs/reference.md` — sync map, primitives, story format
- `docs/adding-a-feature.md` — feature layout and load order
- `CLAUDE.md` — Studio-vs-code split, error mapping, doc discipline

## Step 3.5 — Skin awareness & the deferred skeleton/skin split

The shared UI now sits behind a **skin seam** (see `docs/game/skin-contract.md`). When you scaffold a top-level primitive:

- The gem implementations live in `src/shared/ui/` and are gathered into the **gem** skin (`src/shared/ui/skins/gem.luau`). A new gem primitive is added there the same as before, but its prop shape should match (or be added to) the **contract** in `src/shared/ui/contract.luau` — that's the single source of truth skins implement. `ui.X` is a thin semantic wrapper that resolves the active skin; you don't hand-write the wrapper, just the gem implementation + the contract type.
- If you add a brand-new primitive, also give the **flat** skin (`src/shared/ui/skins/flat/`) a minimal gray-box implementation of the same contract, so the debug skin stays complete.

**Deferred — the skeleton/skin split (seam #2).** The plan (`docs/game/layout-surfaces.md`) is to extend this skill so a hand-built Studio *hero screen* emits **two** artifacts instead of one:

- a **layout skeleton** — hierarchy + sizes/positions/anchors + `UI*Layout`/padding + **named `Slot`s**, style-stripped (no colors/strokes/gradients), and
- a **skin styling** dump — colors/strokes/gradients keyed by element name, which becomes gem-skin content.

A `ReactRoblox.createPortal` bridge then renders skinned content into the skeleton's named `Slot`s. This pipeline is **not built yet** — when asked to import a hero screen, scaffold with the `Stack`/`Row`/`Grid`/`Slot` code primitives for now, and flag that the skeleton/skin extraction is the future path. Studio skeletons must be visually neutral or skin and skeleton fight over the look.

## Step 4 — Verify

1. Run `lune run tools/split` and confirm it exits clean.
2. Tell the user to sync Rojo and reload Play (or check UI Labs).
3. If they want pixel-parity with the original template, offer the diff script (it lives in conversation history; paste it again if needed). They'd select [reference, recreation] and ctrl-click both in Explorer.

## Common failure modes — verify before reporting done

- **`Assets.<NewKey>` not present at runtime** → an Edit's `old_string` didn't match and the addition was silently skipped. Re-read `assets.luau` after every edit to confirm the entry is there.
- **"attempt to index nil"** → referenced a variant or palette that doesn't exist. Trace the lookup chain.
- **UIStrokes layering randomly** → forgot explicit ZIndex. All three Button strokes (Outer, Glow, Shine) need it; Badge's two strokes need it.
- **Border-mode stroke is wrong size** → `BorderStrokePosition` left at default `Outer`. Check the inspector dump for the template's value.
- **Buttons render white with no color in Play but look correct in UI Labs** → the ScreenGui hosting the component has `ZIndexBehavior = Global` (Instance.new default). Force `Sibling`.
