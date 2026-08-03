# Boil

Opinionated Roblox boilerplate: **Rojo + Wally + React (jsdotlua)** in a **Feature-Sliced Design** layout, managed by **Rokit**, with a **Lune splitter** that colocates feature code in one folder and routes it to the correct Roblox service at sync time.

## Stack

| Layer         | Choice                                                    |
| ------------- | --------------------------------------------------------- |
| Toolchain     | Rokit (rojo, wally, lune)                                 |
| Sync          | Rojo 7 reading from `build/` (splitter output) + `src/`   |
| Packages      | Wally; React + ReactRoblox (jsdotlua/react 17)            |
| Data          | ProfileStore (server-realm) + ReplicaService              |
| Networking    | ffrostflame/bytenet (schema-defined, buffer-packed)       |
| Admin console | evaera/cmdr with a username allowlist hook                |
| Utilities     | sleitnick: loader, trove, signal                          |

## Layout

```
src/features/<Feature>/       colocated feature code (what you edit)
  ├── init.luau               public shared surface
  ├── Constants.luau          shared config / tunables
  ├── <Name>.ui.luau          React components (shared)
  ├── <Name>Service.server.luau    server-realm logic
  └── <Name>Controller.client.luau client-realm logic

src/server/init.server.luau   Script entry; loads *Service modules
src/client/init.client.luau   LocalScript entry; loads *Controller modules + mounts React
src/shared/utils/             cross-feature utilities (incl. LoadOrdered)

tools/split.luau              Lune splitter (see docs/architecture.md)
build/                        generated, gitignored — Rojo reads from here
cli/                          the `boil` package CLI (npm, see docs/registry.md)
```

Filename suffix → destination:

| Source                    | Resulting Studio path                                     |
| ------------------------- | --------------------------------------------------------- |
| `*.server.luau`           | `ServerScriptService.Features.<Feature>.<Name>`           |
| `*.client.luau`           | `StarterPlayerScripts.Features.<Feature>.<Name>`          |
| `*.ui.luau`, `*.luau`     | `ReplicatedStorage.Features.<Feature>.<Name>`             |

## Example features

- `HealthSystem` — minimal feature with a shared Constants module and a React HUD label.
- `PlayerData` — ProfileStore + ReplicaService lifecycle (load on join, release on leave, per-player replica).
- `Cmdr` — Cmdr console bootstrap with a `BeforeRun` hook gating by username allowlist.
- `Notes` — end-to-end demo: React TextBox → Net event → server validates → Replica mutation → autosave via ProfileStore → replica diff → UI re-renders.

## Getting started

Starting a new game? Scaffold one instead of cloning this repo:

```bash
npm install -g @encryptal/boil
boil new my-game && cd my-game
```

Working in this checkout:

```bash
rokit install                           # installs rojo, wally, lune
wally install                           # populates Packages/ and ServerPackages/
boil dev                                # splitter (watch) + rojo serve together
```

Without the CLI, run the two halves yourself:

```bash
lune run tools/split -- --watch         # terminal 1: regenerate build/ on change
rojo serve                              # terminal 2: sync to Studio
```

Then in Studio connect via the Rojo plugin. For ProfileStore persistence, enable **Game Settings → Security → Enable Studio Access to API Services**.

To install features and skins from the registry, add the package CLI — it's an npm package, not part of the Rokit toolchain:

```bash
npm install -g @encryptal/boil
boil explore                            # browse and install
boil publish src/features/Shop          # share one you built
```

## Load order

Modules expose an optional `Priority` number (lower = earlier). The entry scripts sort via `src/shared/utils/LoadOrdered.luau` before calling `Start`. Used here so `PlayerDataService` (`Priority = 1`) starts before any service that reads player data.

## Auto-start contract

The entry scripts use `Loader.MatchesName("Service$" | "Controller$")`, so only modules whose Studio name ends in `Service` or `Controller` are auto-started. Other modules under a feature folder (UI components, view containers, helpers) are loaded lazily via normal `require`.

## Docs

- [docs/getting-started.md](docs/getting-started.md) — install, dev loop, verification
- [docs/architecture.md](docs/architecture.md) — split model, entry flow, load ordering
- [docs/adding-a-feature.md](docs/adding-a-feature.md) — feature workflow, priority bands, Constants pattern
- [docs/reference.md](docs/reference.md) — package table, sync map, filename rules
- [docs/registry.md](docs/registry.md) — sharing features and skins: the package format, the index, the `boil` CLI
