# boil

The package CLI for [Boil](https://github.com/REALEncryptal/Boil) — install and
publish Roblox features and skins from a git-backed index.

```bash
npm install -g @encryptal/boil
```

Start a game with it:

```bash
boil new my-game                  # scaffold a project from the framework
```

Then, from anywhere inside a Boil checkout:

```bash
boil dev                          # splitter (watch) + rojo serve, one terminal
boil explore                      # browse skins & features, install from the list
boil add encryptal/shop           # install by name
boil publish                      # pick a feature or skin, gate it, tag it, push it
```

There is no website. The explorer is a terminal UI over one git repo that holds
the packages themselves — so browsing works offline, installing the newest
version is a file copy, and private packages work through normal GitHub
permissions on a single repo.

Multiple indexes are supported — the public one, your company's, a private one —
configured per machine or per project:

```bash
boil registry add company https://github.com/acme/boil-index
boil add company:acme/shop        # qualify when two registries share a name
```

## Commands

| Command | Does |
| ------- | ---- |
| `new [name]` | Scaffold a new game from the framework. Asks for a name and a template; never copies the CLI in. |
| `dev [project-file]` | Run the splitter in watch mode and `rojo serve` together, prefixed and interleaved. `--port=34872`, `--address=`, `--no-split`, `--no-serve`. Ctrl-C stops both. |
| *(no command)* | Opens the hub — browse, installed, publish, registries, dev — in a terminal. Piped or in CI it prints usage instead. |
| `self-update` | Update the CLI itself from npm, using whichever package manager installed it. |
| `migrate <old-index-url>` | Convert a v1 index (listings pointing at other repos) into this registry, once. `--dry-run`, `--registry=`. |
| `upgrade` | Pull a newer framework into this game. Replaces `src/shared`, `src/client`, `src/server`, `tools/`; never touches features or skins. `--dry-run`, `--ref=<tag>`. |
| `setup [url]` | Name the project, create/connect the index, cache it. |
| `registry` | Interactive: add an existing registry, create a new one (repo and all), remove, refresh. Piped or in CI it lists instead. |
| `registry list/add/remove` | The scriptable twins. Machine-wide by default (`~/.boil/config.toml`), `--project` for this game only. |
| `explore` | Interactive registry explorer. |
| `search <term>` | Non-interactive index search — name + description match. |
| `info <pkg>` | The explorer's detail view, printed. |
| `refresh` | Update the cached index clone. |
| `add <registry>:<pkg>` | Qualify which registry when two publish the same name. |
| `add <pkg>[@version]` | Resolve → fetch → copy into `src/` → merge `[wally]` deps → run the splitter → print `[studio]` setup notes. |
| `add github:owner/repo[@tag]` | Install straight from a git URL, no index involved. |
| `add path:<dir>` | Install from a local directory. |
| `remove <pkg>` | Delete the folder, drop it from the lockfile, warn about dependents. |
| `list` | Installed packages, versions, and whether each is locally modified. |
| `outdated` | Installed versions vs. newest compatible in the index. |
| `update [pkg]` | Upgrade in place. Untouched → overwrite; modified → show a diff and ask. |
| `install` | Restore everything in `boil-lock.toml` (fresh clone of a game). |
| `publish [path]` | Gate → lint → write the folder into the registry → commit → tag `<owner>/<name>@<version>` → push. With no path, lists this project's features and skins and asks which one. Offers a version bump if that release exists. |
| `doctor` | Missing dependencies, Wally gaps, packages not in the lockfile. |

`boil help` lists the flags. The full picture — the package format, the index,
the compatibility rules — is in
[docs/registry.md](https://github.com/REALEncryptal/Boil/blob/main/docs/registry.md).

## Installing

```bash
npm i -g @encryptal/boil
```

Boil is a Roblox toolchain, so the install also bootstraps
[Rokit](https://github.com/rojo-rbx/rokit) — the toolchain manager that provides
`rojo`, `wally` and `lune`. Without those, nothing the CLI scaffolds can be built
or synced, and being told to go install something else is a poor first five
minutes.

The bootstrap does nothing when Rokit is already present, never fails the npm
install (a failure prints the manual install link and moves on), and is off when
`BOIL_SKIP_ROKIT=1` is set or npm runs with `--ignore-scripts`. Rokit installs
itself to `~/.rokit/bin` and adds that to your shell profile, so a new terminal
picks it up. Set `GITHUB_PAT` if you're behind a shared IP that's hitting
GitHub's anonymous rate limit — the ambient `GITHUB_TOKEN` from a CI job is
deliberately ignored.

## What it expects

- **Node 18.17+.** No runtime dependencies; TOML, semver, the zip reader and the
  prompts are all in this package, so a global install pulls nothing else in.
- **`git` on PATH.** Every fetch, publish and index refresh shells out to it —
  that's what makes private packages work with no token plumbing.
- **A Boil project.** Commands that touch project files walk up from the current
  directory looking for `default.project.json`, so they work from anywhere in a
  checkout. `search`, `info` and `refresh` only read the index and run anywhere.
- **`lune`, optionally.** `add`/`remove`/`update` run `tools/split` afterwards
  and `publish` runs the repo's lints. Both degrade to a warning if the Lune
  toolchain isn't installed.

Set `BOIL_NONINTERACTIVE=1` (or `CI`) to make every prompt fail loudly instead of
waiting on input — each interactive action has a scriptable twin.

## Staying up to date

Two version numbers answer to the name Boil and they move independently: the
*framework* inside a project (`boil upgrade`) and this *CLI* (npm). Nothing in a
project can update the CLI, so when a newer one is published a command ends with
a toast:

```
  ╭─────────────────────────────────╮
  │ Update available  0.3.4 → 0.4.1 │
  │ npm i -g @encryptal/boil@latest │
  ╰─────────────────────────────────╯
```

…and offers to run it for you. Say yes and it updates in place; the next `boil`
is the new one. `boil self-update` does the same on demand.

The update runs **the package manager that installed it** — pnpm stays pnpm,
yarn stays yarn — because installing with one and updating with another leaves
two copies and a confusing PATH. A source checkout and an `npx` run are both
told they have nothing to update, since neither would change the code that's
running. A permissions failure comes back as the `sudo …` line that fixes it
rather than as npm's stack.

How much it does on its own is one setting in `~/.boil/config.toml`:

```toml
[cli]
autoUpdate = "prompt"   # default: toast, then ask
# autoUpdate = true     # update without asking
# autoUpdate = false    # toast only, never ask
```

npm is asked at most once a day and the answer is cached in
`~/.boil/version-check.json`; a failed lookup is cached too, so being offline
costs one slow command rather than every command. None of it happens in pipes or
CI, and `BOIL_NO_UPDATE_NOTIFIER=1` (or npm's `NO_UPDATE_NOTIFIER`) turns the
whole thing off.

## Developing

```bash
npm test              # node:test, no dependencies
node bin/boil.js help # run it in place
```
