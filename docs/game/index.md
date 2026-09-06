# Game docs

Per-feature and cross-cutting documentation. Start with the conventions, then the
feature you're touching.

## Conventions (cross-cutting)

These describe the five seams the framework is built around — read the relevant
one before changing UI or feature structure. [framework-boundary.md](framework-boundary.md)
sits above them: what's framework vs. feature, the `Shared.Boil` contract, and the
one-way dependency rule that keeps the framework updatable.

| Doc | Seam | What it covers |
| --- | ---- | -------------- |
| [framework-boundary.md](framework-boundary.md) | — | Framework vs. feature, the `Boil` public surface, the no-naming-a-feature rule (enforced by `tools/check-framework-boundary`). |
| [skin-contract.md](skin-contract.md) | #1 skin | The component contract, `SkinProvider`, gem + flat skins. How a primitive *looks*, swappably. |
| [layout-surfaces.md](layout-surfaces.md) | #2 layout | `Stack`/`Row`/`Grid`/`Slot` code primitives + the deferred Studio-extract pipeline. How a screen is *arranged*. |
| [headless-core.md](headless-core.md) | #3 view | Cores are presentation-agnostic; views are dumb; actions are intent. Enforced by `tools/check-views`. |
| [presentations.md](presentations.md) | #4 presentation | Self-registering screen / world / command surfaces and the de-hardcoded entry files. How a feature *shows up*. |
| [responsive.md](responsive.md) | #5 responsive | Reference pixels, `ui.Surface`, device classification, touch. How a screen fits *every device* without a second layout. |
| [registries.md](registries.md) | — | `Boil.Registry.define` — how one feature accepts contributions from another. The mechanism the lego idea runs on. |

Features and skins are also **distributable packages** — one folder, one
`boil.toml`, installed and published with `boil`. See
[registry.md](../registry.md).

## Features

| Doc | Feature |
| --- | ------- |
| [PlayerData.md](PlayerData.md) | Profile persistence + the `registerTemplate` discovery convention |
| [Settings.md](Settings.md) | Settings registry, server validation, the `Settings.luau` discovery convention |
| [HUD.md](HUD.md) | The player HUD and the `Nav` registry every feature plugs into |
| [Music.md](Music.md) | Settings-driven background music |
| [PickupFX.md](PickupFX.md) | Client-side pickup animation system |
| [Sidebar.md](Sidebar.md) | The icon column the HUD renders |
| [UIShell.md](UIShell.md) | Global frame open/close system and the slide-out |
| [Cmdr.md](Cmdr.md) | Admin console bootstrap and the command allowlist |
