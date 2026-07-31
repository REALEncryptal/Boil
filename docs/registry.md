# The Boil registry — sharing features and skins between games

Boil is a framework plus a set of removable features. This document describes the
infrastructure that turns "removable" into **distributable**: a package format, a
registry, and a CLI (`tools/boil`) with a built-in terminal explorer for finding
and installing packages.

The goal is two commands:

```bash
lune run tools/boil -- explore              # browse skins & features, install from the list
lune run tools/boil -- publish src/features/Shop
```

There is **no website**. The explorer lives in the CLI — the registry is a git
repo of manifests, and browsing it is a terminal UI, not a browser tab.

## Why this is tractable

A feature is already a package in everything but name:

- `src/features/<Name>/` is a **flat folder of `.luau` files** — the splitter
  (`tools/split.luau`) iterates files and ignores nested directories.
- Both entry scripts **auto-discover** it. Adding a feature is zero edits to
  `src/client/init.client.luau` or `src/server/init.server.luau`.
- It extends other features through **registration files** (`PlayerData.luau`,
  `Settings.luau`), never by editing their source.
- It reaches the framework through exactly one module, `Shared.Boil`, and
  `tools/check-framework-boundary` proves it.

So installing a feature is *drop the folder in, run the splitter*. The registry is
mostly the plumbing to move folders around and record what came from where.

Two properties make this cleaner than it sounds:

- The splitter only copies `.luau` files, so a `boil.toml` manifest can live
  **inside** the package folder and never reach Roblox. A package is exactly one
  self-describing directory.
- Skins are pure shared-realm code, so `src/skins/` is a plain Rojo `$path` →
  `ReplicatedStorage.Skins`. Skins need **no** splitter involvement at all.

## What had to change first (Phase 0)

Features were ready. Skins were not.

| Problem | Fix |
| ------- | --- |
| `skins/init.luau` hardcoded `require(script.gem)` / `require(script.flat)`, so installing a skin meant editing framework source. | The skin registry seeds the built-ins, then **auto-discovers** `ReplicatedStorage.Skins` children on first access. Also exposes `register(skin)` for imperative registration. |
| `SkinName = "gem" \| "flat"` — a closed union in `SkinProvider.luau`. | `SkinName = string`, resolved at runtime, warn-once + fall back to gem on an unknown name. |
| A skin missing a contract key was a **hard runtime error** when that primitive rendered — so adding any primitive to `contract.luau` would break every published skin. | `ui.X` falls back to the gem implementation per missing key. An old skin renders imperfectly instead of crashing the game. |
| Nothing declared which contract a skin was built against. | `contract.VERSION`, and a `contract` compatibility range in every skin's manifest. |
| No way to check a skin was complete before shipping it. | `lune run tools/check-skins` — reports every unimplemented contract key per skin. |
| `check-framework-boundary` only scanned `src/features`. | It now scans `src/skins` too: installed skins reach the framework only via `Shared.Boil`. |

Discovery happens **lazily inside the registry**, not in the client entry script.
That matters because UI Labs runs in Studio edit mode where the entry script never
executes — a lazily-discovering registry means installed skins show up in the
`SkinProvider` story exactly like the built-ins.

Note the framework still ships `gem` and `flat` in `src/shared/ui/`. Moving gem
out to `src/skins/gem/` is the pure end state ("the framework ships zero skins",
mirroring "ships zero features") but it's a wide refactor — the gem
implementations *are* the files in `src/shared/ui/` — and it is not a blocker for
distribution. Deferred.

## The package format

A package is one directory containing a `boil.toml`.

```toml
[package]
name = "encryptal/shop"     # scoped: <owner>/<name>
kind = "feature"            # feature | skin
version = "1.2.0"           # semver
description = "Currency shop with rotating stock"
license = "MIT"
repository = "https://github.com/encryptal/boil-shop"   # where publish pushes
boil = "^0.1"               # compatible Shared.Boil surface versions
contract = "^1"             # skins only: compatible contract.VERSION range

[dependencies]              # other Boil packages
"boil/playerdata" = "^1.0"

[wally]                     # merged into the game's wally.toml at install
ByteNet = "ffrostflame/bytenet@0.4.6"

[studio]                    # printed after install — you create these by hand
tags = ["ShopKiosk"]
notes = """
Tag a part `ShopKiosk` for the world-interaction presentation.
"""
```

`kind` decides the install directory: `feature` → `src/features/<Name>/`,
`skin` → `src/skins/<Name>/`. The folder name is the package name's last segment
in PascalCase, because that name becomes the Roblox instance name and the
registration key — it must be unique within a game.

The **project manifest** is a `boil.toml` at the repo root, same file name and the
same role Cargo's `Cargo.toml` plays for both packages and projects:

```toml
[project]
name = "my-game"
boil = "0.1.0"              # framework version this checkout provides

[registries]
default = "https://github.com/REALEncryptal/boil-index"

[dependencies]
"encryptal/shop" = "^1.2"
"encryptal/neon" = "^0.4"
```

`add` writes the `[dependencies]` entry for what you asked for directly;
transitive dependencies are resolved and installed but only recorded in the
lockfile, so the project manifest stays a list of intent rather than a flattened
graph.

`boil-lock.toml` records what's actually on disk — resolved version, source repo,
tag, and a **content fingerprint** of the installed folder:

```toml
[[package]]
name = "encryptal/shop"
version = "1.2.0"
kind = "feature"
source = "git+https://github.com/encryptal/boil-shop"
tag = "v1.2.0"
path = "src/features/Shop"
fingerprint = "a3f19c02"
```

The fingerprint is a truncated SHA-256 over the installed folder's sorted file
contents (`serde.hash`, so it behaves identically on Windows where most Roblox
devs work). It's what lets `boil update` tell "you never touched this, overwrite
it" from "you edited it — here's what upstream changed, still want to?"

## Install model: vendored

`boil add` **copies the folder into `src/` and you commit it.** No gitignored
package directory, no second source root.

That's a deliberate trade. A `boil_packages/` directory would keep git cleaner,
but every tool in the repo — the splitter, Rojo's `default.project.json`,
`check-views`, `check-framework-boundary` — would need to learn about a second
root, and editing an installed package would require ejecting it first. Vendoring
costs a lockfile and a fingerprint; it buys "installed code behaves exactly like
code you wrote," which is the whole point of a boilerplate.

Local edits are legal and expected. `boil update` shows you what upstream changed
and lets you decide.

## The registry

An **index repo** — one TOML file per package, listing every published version:

```
boil-index/
  packages/
    encryptal/
      shop.toml
      neon.toml
    boil/
      playerdata.toml
```

```toml
# packages/encryptal/shop.toml
name = "encryptal/shop"
kind = "feature"
description = "Currency shop with rotating stock"

[[version]]
version = "1.2.0"
source = "git+https://github.com/encryptal/boil-shop"
tag = "v1.2.0"
boil = "^0.3"
published = "2026-07-14"
```

The index is cloned to `~/.boil/index` and refreshed on demand. Package *contents*
live in their own git repos, fetched by tag with `git clone --depth 1 --branch`.

Why git and not a hosted service: zero infrastructure to operate, free, private
packages work through normal GitHub permissions, and `git` is already installed
and already authenticated on any machine that has this repo checked out. There's
no upload endpoint to secure and no server to keep alive.

## The CLI

```
lune run tools/boil -- <command>
```

| Command | Does |
| ------- | ---- |
| `explore` | **Interactive terminal explorer** (see below). |
| `search <term>` | Non-interactive index search — name + description match. |
| `info <pkg>` | The explorer's detail view, printed. Same code path, scriptable. |
| `refresh` | Update the cached index clone. |
| `add <pkg>[@version]` | Resolve → fetch → copy into `src/` → merge `[wally]` deps → run splitter → print `[studio]` setup notes. |
| `add github:owner/repo[@tag]` | Install straight from a git URL, no index involved. |
| `remove <pkg>` | Delete the folder, drop it from the lockfile, warn about dependents. |
| `list` | Installed packages, versions, and whether each is locally modified. |
| `outdated` | Installed versions vs. newest compatible in the index. |
| `update [pkg]` | Upgrade in place. Untouched → overwrite; modified → show a diff and ask. |
| `install` | Restore everything in `boil-lock.toml` (fresh clone of a game repo). |
| `publish <path>` | Lint → tag → push the package repo → register the version in the index. |
| `doctor` | Missing dependencies, unimplemented contract keys, undeclared Wally requires, Studio assets you haven't created. |

### The explorer

`boil explore` is the front end. It is a terminal UI built on Lune's
`stdio.prompt`, and it's the reason there's no website:

```
  Boil registry — 24 packages

  > Features (14)
    Skins (6)
    Installed (4)
    Search…
    Refresh index
    Quit
```

Selecting a category lists packages with their one-line descriptions and an
install marker; selecting a package opens a detail view — description, latest
version, `boil`/`contract` compatibility against *this* checkout, dependencies,
Wally requirements, and the Studio assets it will ask you to create — with actions
`Install`, `Install a specific version…`, `Back`.

Design rules:

- **Compatibility is shown, not discovered on failure.** Packages whose `boil` or
  `contract` range doesn't match the current checkout are marked incompatible in
  the list and refuse to install without `--force`.
- **Works offline.** Everything renders from the cached index clone; refreshing is
  an explicit menu item, so a plane ride still gets you a list.
- **Every action has a non-interactive equivalent.** The explorer is a discovery
  aid, never the only way to do something — CI and scripts use `add`/`install`.

## Publishing

The flow that matters is "I built this in a real game, now I want it everywhere":

```bash
lune run tools/boil -- publish src/features/Shop
```

1. Scaffold `boil.toml` if it's missing (prompts for name/description/version).
2. Run the gate: `split`, `check-views`, `check-framework-boundary`,
   `check-skins`, `check-package`.
3. `check-package` is the publishability lint — flat folder only (the splitter
   ignores nested dirs), manifest valid, no `require` of another feature's
   internals, every `Packages.*` require declared in `[wally]`, every
   cross-feature registration file backed by a `[dependencies]` entry.
4. Push the folder to its package repo at `v<version>`.
5. Add the version to the index and push (or open a PR against it).

Undeclared dependencies are the failure mode that matters — a feature that
silently assumes PlayerData exists installs fine and breaks at runtime in someone
else's game. Step 3 is what stops that.

## Authoring a skin package

`src/skins/<Name>/` with an `init.luau` returning a `contract.Skin` and a
`boil.toml` (`kind = "skin"`, `contract = "^1"`). The registry discovers it; you
don't register it anywhere.

Skins obey the same boundary rule as features — the framework is reachable only
through `Shared.Boil` — so the contract *types* are re-exported from that surface
for exactly this purpose:

```lua
local Boil = require(ReplicatedStorage.Shared.Boil)

local skin: Boil.Skin = {
    name = "neon",
    theme = require(script.theme),
    components = { Button = require(script.Button), … },
}
```

`Boil.Skin`, `Boil.Components`, and every `Boil.*Props` are aliases of the
contract's types. (This is the one eager require on the `Boil` surface — Luau can
only re-export a type through a real binding — and it's cheap: `contract.luau`
pulls in the asset table and nothing else, no React.)

Run `lune run tools/check-skins` to see which contract keys you still owe.

## Compatibility rules

- **`Shared.Boil` is the framework's public API.** Its surface version lives in the
  root `boil.toml` (`[project] boil`). Adding a member is a minor bump; removing
  or changing one is a major bump. Packages declare a caret range.
- **`contract.VERSION` is the skin API.** Adding a component key is a minor bump —
  old skins keep working via per-key gem fallback, degraded. Changing an existing
  prop shape is a major bump.
- **Package names are scoped** (`encryptal/shop`), but the installed *folder* is
  unscoped (`src/features/Shop/`), so two packages that want the same folder name
  collide. `add` detects this and refuses.

## Status

- **Phase 0 — framework prerequisites.** Skin registry + auto-discovery, runtime
  skin names, per-key gem fallback, `contract.VERSION`, `src/skins/` route,
  `check-skins`, boundary lint extended. ✅
- **Phase 1 — package format + CLI.** Manifests, lockfile, fingerprinting, semver,
  git fetch, `add`/`remove`/`list`/`install`/`update`/`doctor`, the explorer over a
  local index. ✅
- **Phase 2 — the index.** `publish`, `search`, `outdated` and the explorer all
  work against an index today, and the whole flow is verified end to end against a
  local one. ⏳ **Pending: the `boil-index` repo doesn't exist yet.** Create it
  with a `packages/` directory and point `[registries] default` at it — until
  then, `add github:owner/repo` and `add path:<dir>` work with no index at all.

A registry URL that resolves to a local directory is used in place rather than
cloned, so you can develop against an index before publishing it anywhere:

```toml
[registries]
default = "../boil-index"
```
