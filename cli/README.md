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
boil publish src/features/Shop    # lint, tag, push, register
```

There is no website. The explorer is a terminal UI over a git repo of manifests,
so browsing works offline and private packages work through normal GitHub
permissions.

## Commands

| Command | Does |
| ------- | ---- |
| `new [name]` | Scaffold a new game from the framework. Asks for a name and a template; never copies the CLI in. |
| `dev [project-file]` | Run the splitter in watch mode and `rojo serve` together, prefixed and interleaved. `--port=34872`, `--address=`, `--no-split`, `--no-serve`. Ctrl-C stops both. |
| `setup [url]` | Name the project, create/connect the index, cache it. |
| `explore` | Interactive registry explorer. |
| `search <term>` | Non-interactive index search — name + description match. |
| `info <pkg>` | The explorer's detail view, printed. |
| `refresh` | Update the cached index clone. |
| `add <pkg>[@version]` | Resolve → fetch → copy into `src/` → merge `[wally]` deps → run the splitter → print `[studio]` setup notes. |
| `add github:owner/repo[@tag]` | Install straight from a git URL, no index involved. |
| `add path:<dir>` | Install from a local directory. |
| `remove <pkg>` | Delete the folder, drop it from the lockfile, warn about dependents. |
| `list` | Installed packages, versions, and whether each is locally modified. |
| `outdated` | Installed versions vs. newest compatible in the index. |
| `update [pkg]` | Upgrade in place. Untouched → overwrite; modified → show a diff and ask. |
| `install` | Restore everything in `boil-lock.toml` (fresh clone of a game). |
| `publish <path>` | Lint → tag → push the package repo → register the version in the index. |
| `doctor` | Missing dependencies, Wally gaps, packages not in the lockfile. |

`boil help` lists the flags. The full picture — the package format, the index,
the compatibility rules — is in
[docs/registry.md](https://github.com/REALEncryptal/Boil/blob/main/docs/registry.md).

## What it expects

- **Node 18.17+.** No runtime dependencies; TOML, semver and the prompts are all
  in this package, so a global install pulls nothing else in.
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

## Developing

```bash
npm test              # node:test, no dependencies
node bin/boil.js help # run it in place
```
