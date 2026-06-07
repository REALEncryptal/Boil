# Layout surfaces

Seam #2 is *how a screen is arranged*. Two surfaces, chosen per screen:

1. **Code primitives** (the default) — `Stack` / `Row` / `Grid` / `Slot`.
2. **Studio-extract skeleton** (for hero screens) — hand-built in Studio, extracted
   to a style-stripped skeleton, filled with skinned content via a portal. *Deferred*
   — the design is below; build it when a screen actually needs it.

## Code primitives (`src/shared/ui/`)

Transparent, structure-only. They wrap `UI*Layout` / `UIPadding` / sizing / anchors
and draw **nothing** — no background, no stroke. Put skinned primitives inside them.

| Primitive | Wraps | Notes |
| --------- | ----- | ----- |
| `Stack` | UIListLayout (vertical) | gap, padding, alignment, flex |
| `Row` | Stack (horizontal) | same props, forces horizontal |
| `Grid` | UIGridLayout | cell size/padding, columns; children are **direct** (the layout only sizes direct children — don't wrap a cell, animate it with a child `UIScale`) |
| `Slot` | a named transparent Frame | a positioned region; also the named target for the future portal bridge |

Each has a UI Labs story. Default to these for most screens; they keep arrangement
in code where it's diffable and live-tunable.

Honor the standing rules: pad against a stroked edge with `padding +
strokeThickness`, and center new feature UIs by default (off-center is for large
content surfaces).

## Studio-extract skeleton (deferred design)

When a hero screen is painful to arrange in code, the plan is to let the user build
it in Studio and extract two artifacts from one hand-built UI:

- **layout skeleton** — hierarchy + sizes / positions / anchors + `UI*Layout` /
  padding + **named slots**, *style-stripped* (no colors/strokes/gradients).
- **skin styling** — colors / strokes / gradients / decoration keyed by element
  name, which becomes gem-skin content.

A **portal bridge** (`ReactRoblox.createPortal`) then renders skinned content into
the skeleton's named `Slot`s. Discipline: **Studio skeletons must be visually
neutral**, or the skin and the skeleton fight over who draws the look.

**Status:** not built. To build it, extend the `studio-import` skill / the Inspect
tool to emit the skeleton + styling split, and add the portal helper that maps
skin output into the skeleton's `Slot` names. Until a screen demands it, code
primitives cover the need — don't build the pipeline speculatively.
