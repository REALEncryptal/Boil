# Boil

[![npm](https://img.shields.io/npm/v/@encryptal/boil?label=%40encryptal%2Fboil)](https://www.npmjs.com/package/@encryptal/boil)

A Roblox **framework** — Rojo + Wally + React (jsdotlua), Feature-Sliced Design,
managed by Rokit — where features and UI skins are **installable packages** you
can share between games.

```bash
npm install -g @encryptal/boil
boil new my-game && cd my-game
rokit install && wally install
boil dev
```

## Three things, not one

**1. A framework that ships empty.** `src/shared/`, `src/client/`, `src/server/`
and `tools/` are the framework; everything else is a feature you can delete.
Features reach it through exactly one module — `require(ReplicatedStorage.Shared.Boil)` —
and the framework never names a feature back. The dependency arrow points one
way, which is what makes updating the framework a command rather than a merge:

```bash
boil upgrade      # replaces the four framework paths; features and skins untouched
```

**2. A package ecosystem.** A feature (`src/features/<Name>/`) or a skin
(`src/skins/<Name>/`) is one self-describing folder with a `boil.toml`. Publish
it to a git-backed index, install it into any other game:

```bash
boil publish src/features/Shop    # lint, tag, push, register
boil add encryptal/shop           # fetch, vendor into src/, merge Wally deps, rebuild
```

The index is a git repo of manifests — no server, no website. Browsing it is
`boil explore`, a terminal UI that works offline. Registries can be public,
private, or a company's, configured per machine or per project.

**3. A UI kit built on four seams.** *Skin* (how a primitive looks — swappable and
installable), *layout* (how a screen is arranged), *view* (how a feature presents;
views stay dumb), *presentation* (whether it's a screen GUI, a world part, or a
console command). Feature code writes `ui.Button`; the active skin draws it.

## How a feature works

Everything about a feature lives in one flat folder, and a filename suffix routes
each file to the right Roblox service at sync time:

| Source | Resulting Studio path |
| ------ | --------------------- |
| `*.server.luau` | `ServerScriptService.Features.<Feature>.<Name>` |
| `*.client.luau` | `StarterPlayerScripts.Features.<Feature>.<Name>` |
| `*.ui.luau`, `*.luau` | `ReplicatedStorage.Features.<Feature>.<Name>` |

Both entry scripts discover features automatically, so **adding one is zero edits
anywhere else** — drop the folder in. Features extend each other by registration,
never by editing each other's source: a feature that needs saved data drops a
`PlayerData.luau` beside its own code, and the PlayerData feature merges it into
the profile template without ever mentioning the newcomer.

## The CLI

```bash
boil new [name]              scaffold a game from the framework
boil dev [--port=34872]      splitter (watch) + rojo serve, one terminal
boil upgrade                 pull a newer framework into an existing game
boil setup                   create/connect a package index
boil explore                 browse registries and install
boil add / remove / update / list / outdated / install
boil publish <path>          share a feature or skin
boil registry add <name> <url>
boil doctor                  missing deps, Wally gaps, untracked packages
```

`boil help` lists everything. The CLI is an npm package and lives in `cli/`; it's
never copied into the games it makes.

## Layout

```
src/features/<Name>/      one flat folder per feature — what you edit
src/skins/<Name>/         installed skins → ReplicatedStorage.Skins
src/shared/               the framework: UI kit, Boil surface, utils
src/server/ src/client/   entry scripts (discover everything, name nothing)
tools/                    splitter + lints (Lune)
cli/                      the boil CLI (npm: @encryptal/boil)
build/                    generated, gitignored — Rojo reads from here
```

## Bundled features

Removable examples, and the reference for the conventions: `PlayerData`
(ProfileStore + ReplicaService), `Settings` (registry, server validation),
`Notes` (full stack: React → ByteNet → validate → replica → autosave),
`HealthSystem`, `Music`, `PickupFX`, `Sidebar`, `UIShell`, `UIShowcase`, `Cmdr`.

Remove all of them and the framework still boots and mounts — that's the boundary
being real rather than aspirational. (Individually they're removable too, minus
the ones another feature declares a dependency on; `boil doctor` tells you which.)

## Checks

```bash
lune run tools/split                       # the build; the signal that always matters
lune run tools/check-views                 # views stay dumb (no networking/persistence)
lune run tools/check-framework-boundary    # the one-way dependency rule, both directions
lune run tools/check-skins                 # every skin implements the full contract
```

## Stack

| Layer | Choice |
| ----- | ------ |
| Toolchain | Rokit (rojo, wally, lune) |
| Sync | Rojo 7, reading `build/` (splitter output) + `src/` |
| UI | React + ReactRoblox (jsdotlua/react 17), UI Labs for stories |
| Data | ProfileStore (server realm) + ReplicaService |
| Networking | ffrostflame/bytenet — schema-defined, buffer-packed |
| Console | evaera/cmdr with a username allowlist hook |
| Utilities | sleitnick: loader, trove, signal |

## Docs

- [getting-started.md](docs/getting-started.md) — install, the dev loop, verifying in Studio
- [architecture.md](docs/architecture.md) — the split model, entry flow, load ordering
- [adding-a-feature.md](docs/adding-a-feature.md) — the feature workflow
- [reference.md](docs/reference.md) — filename rules, sync map, APIs, lints
- [registry.md](docs/registry.md) — packages, registries, and the CLI, with a walkthrough
- [docs/game/](docs/game/index.md) — the four seams, the framework boundary, per-feature docs
