# The Boil registry — sharing features and skins between games

Boil is a framework plus a set of removable features. This document describes the
infrastructure that turns "removable" into **distributable**: a package format, a
registry, and a CLI (`boil`) with a built-in terminal explorer for finding and
installing packages.

The goal is two commands:

```bash
boil explore              # browse skins & features, install from the list
boil publish src/features/Shop
```

There is **no website**. The explorer lives in the CLI — the registry is a git
repo of manifests, and browsing it is a terminal UI, not a browser tab.

## Installing the CLI

`boil` is an npm package, installed once per machine rather than per checkout:

```bash
npm install -g @encryptal/boil
```

It has no runtime dependencies — TOML, semver and the prompts all ship inside
it — and needs Node 18.17+ and `git` on your PATH. Commands that touch project
files walk up from the current directory looking for `default.project.json`, so
they work from anywhere inside a checkout; `search`, `info` and `refresh` only
read the cached index and run anywhere at all.

`lune` is optional but expected in a real project: `add`/`remove`/`update` run
`tools/split` afterwards, and `publish` runs the repo's lints. Both degrade to a
warning when the Lune toolchain isn't installed, so the CLI still works in a
checkout that hasn't run `rokit install` yet.

## Walkthrough

### Starting a new project

```bash
npm i -g @encryptal/boil
boil new my-game && cd my-game
rokit install && wally install

boil setup        # names the project, creates/connects the index, caches it
boil explore      # browse and install
```

`boil new` clones the framework, strips the parts that belong to *its* repo
rather than to your game (the CLI itself, the framework's LICENSE, its lockfile),
renames the project in `boil.toml` and `default.project.json`, writes a README
for it, and makes the first commit. It asks whether you want the example features
or an empty framework — the framework boots either way, which is the point of the
[framework/feature boundary](game/framework-boundary.md).

Non-interactive: `boil new my-game --starter --yes` (or `--empty`). Scaffold from
a fork or a pinned release with `--template=<url>` / `--ref=<tag>`.

The CLI is deliberately **not** copied into the new project — it's a tool you
install once, not something every game vendors.

`setup` is once per project. It creates the index repo on GitHub if it doesn't
exist yet — see [Setting up](#setting-up-boil-setup) — and writes the URL into
`boil.toml`. Then the normal dev loop: `lune run tools/split -- --watch` in one
terminal, `rojo serve` in another.

If someone clones your game later, `boil install` restores anything in
`boil-lock.toml` that isn't on disk. Usually that's nothing — installs are
committed — but it repairs a missing folder.

### Publishing a feature you built

Say `src/features/Shop/` works in a real game and you want it everywhere. Check
it's publishable *before* creating any repos:

```bash
boil publish src/features/Shop --dry-run
```

With no `boil.toml` in the folder, this prompts for scope/name/description/
version/repo URL, writes the manifest, and stops. Open it and fill in what it
can't know — dependencies, Wally requirements, Studio assets:

```toml
[package]
name = "encryptal/shop"
kind = "feature"
version = "1.0.0"
description = "Currency shop with rotating stock"
repository = "https://github.com/encryptal/boil-shop"
boil = "^0.1.0"

[dependencies]
"boil/playerdata" = "^1.0"          # because it has a PlayerData.luau registration file

[wally]
ByteNet = "ffrostflame/bytenet@0.4.6"

[studio]
tags = ["ShopKiosk"]
notes = "Tag a part `ShopKiosk` in Workspace for the world interaction."
```

Re-run the dry run until it's green. It fails on undeclared `Packages.*`
requires, on `.luau` files in subfolders (the splitter only reads a feature
folder's top level, so those would silently never build), and on registration
files with no matching `[dependencies]` entry. Those are exactly the mistakes
that install cleanly and then break in *someone else's* game.

Then create the package repo and publish for real:

```bash
# create encryptal/boil-shop on GitHub (empty), then:
boil publish src/features/Shop
```

It runs the gate, runs all four lints, shows what it's about to do, and asks. On
yes: pushes the folder to `boil-shop` tagged `v1.0.0`, then registers the version
in the index. If you lack write access to the index it says so and points you at
a PR — the package push has already succeeded at that point.

Shipping an update is the same with `version` bumped. `--yes` skips the prompt.
A skin is identical but `kind = "skin"`, a `contract` range, and it lives in
`src/skins/<Name>/`.

### Adding a feature to a game

```bash
boil explore                                  # menu: Features / Skins / Installed / Search
boil add encryptal/shop                       # newest compatible
boil add encryptal/shop@1.0.0                 # pinned
boil add github:encryptal/boil-shop@v1.0.0    # no index involved
boil add path:../boil-shop                    # local folder, before you publish
```

`add` copies the folder into `src/features/Shop/`, merges its Wally deps into
`wally.toml`, installs what it depends on, runs the splitter, and prints what's
left for you:

```
✓ installed encryptal/shop 1.0.0 → src/features/Shop/

Added to wally.toml — run `wally install`
  ByteNet = "ffrostflame/bytenet@0.4.6"

Studio setup — you have to create these by hand
  CollectionService tag: ShopKiosk
  Tag a part `ShopKiosk` in Workspace for the world interaction.
```

So: `wally install`, then build the Studio assets. Commit the new folder.

### Living with installed packages

```bash
boil list          # what's installed, and which ones you've edited
boil outdated      # newer versions available
boil update        # upgrade; shows the upstream diff first if you've edited it
boil doctor        # missing deps, Wally gaps, packages not in the lockfile
boil remove encryptal/shop
```

Editing an installed package is fine and expected — that's the point of
vendoring. `list` marks it modified and `update` shows you what upstream changed
before overwriting anything.

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
boil <command>
```

The source is `cli/` in this repo, published to npm as `@encryptal/boil`. It's a
zero-dependency Node package: the TOML parser, the semver subset and the prompts
are all in `cli/src/`, so a global install pulls in nothing else and the CLI has
no Roblox toolchain of its own to keep in sync. `cd cli && npm test` runs its
suite.

Why npm rather than a Lune script in `tools/`: the CLI is the thing you reach for
*before* a project exists — to browse the index, to install into a checkout you
just cloned — and a per-repo script can only ever run in a repo that already has
it. One global install now serves every Boil project on the machine.

| Command | Does |
| ------- | ---- |
| `new [name]` | Scaffold a new game from the framework template. |
| `dev [project-file]` | Splitter (watch) + `rojo serve` in one terminal. `--port=`, `--address=`. |
| `upgrade` | Pull a newer framework in; features and skins untouched. See [framework-boundary.md](game/framework-boundary.md). |
| `setup [url]` | Name the project, create/connect the index, cache it. See below. |
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

### Setting up (`boil setup`)

The index is a git repo that has to exist before anything can be published to it.
`setup` creates it for you rather than making that a manual checklist:

```bash
boil setup                    # asks, defaults to <your-org>/boil-index
boil setup https://github.com/me/boil-index --yes
boil setup ../boil-index --local    # a plain directory, no git
```

It names the project, then makes sure the index exists — creating the GitHub repo
with the `gh` CLI if it's installed and authenticated, otherwise through the
GitHub API with `GITHUB_TOKEN` / `GH_TOKEN`, otherwise printing the one command
for you to run. Once it exists it's seeded with `packages/` and a README, the URL
is written to `[registries] default`, and the index is cached so `explore` works
immediately.

Everything it does is idempotent and additive: an index that already exists keeps
its contents (it only gains `packages/` if that's missing), and nothing here ever
force-pushes or deletes. Re-running it is safe.

Defaults to a **private** repo; pass `--public` for a shared one. `--skip-index`
writes just the project manifest.

### The explorer

`boil explore` is the front end. It is a terminal UI — an arrow-key list drawn
straight onto stdout — and it's the reason there's no website:

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
boil publish src/features/Shop
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
  work against an index, and `boil setup` creates and seeds one. The
  `boil-index` repo referenced by the default config doesn't exist yet — run
  `boil setup` to create it. Until then `add github:owner/repo` and
  `add path:<dir>` work with no index at all. ✅
- **Phase 3 — distribution.** The CLI moved from a Lune script in `tools/boil/`
  to an npm package (`cli/`, published as `@encryptal/boil`), installed globally
  and runnable from anywhere inside a checkout. Same commands, same file formats,
  same lockfiles — `lune run tools/boil -- <cmd>` is now just `boil <cmd>`. ✅

A registry URL that resolves to a local directory is used in place rather than
cloned, so you can develop against an index before publishing it anywhere:

```toml
[registries]
default = "../boil-index"
```
