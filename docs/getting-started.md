# Getting Started

## Prerequisites

- **Node 18.17+**, for the CLI: `npm install -g @encryptal/boil`. Installing it
  also installs **Rokit**, the toolchain manager that provides rojo, wally and lune.
- **Roblox Studio.** `boil install` installs the Rojo plugin into it for you.

Not using the CLI? Install Rokit yourself from <https://github.com/rojo-rbx/rokit>
and follow the by-hand steps below.

## Starting from scratch

If you're beginning a new game rather than working in this checkout:

```bash
npm install -g @encryptal/boil
boil new my-game && cd my-game
```

It asks for a name, whether you want the example features, and whether to install
the toolchain now — say yes and the setup below is already done. `--no-install`
skips the offer.

## One-time setup

```bash
boil install    # the toolchain, the packages, and the Rojo Studio plugin
```

One command for what used to be four, in the order they have to happen:

| Step | What it does |
| --- | --- |
| `rokit install` | reads `rokit.toml`, installs rojo, wally, lune |
| `wally install` | reads `wally.toml`, populates `Packages/` |
| `rojo plugin install` | installs the Rojo plugin into Studio |
| restore | re-vendors every package in `boil-lock.toml` (fresh clone of a game) |

`wally` is itself a tool Rokit installs, which is why the order matters — and
why running `wally install` first on a new machine fails.

Flags: `--update` runs `rokit update` first, bumping `rokit.toml` to the newest
tool versions (left out of the default run so a plain install never rewrites a
committed manifest). `--no-plugin` skips the Studio plugin — the right choice in
CI, where there's no Studio to install into. `--no-tools` restores packages only,
the command's pre-0.8 behaviour.

Steps that fail are reported and the run carries on, so a missing Studio or a
network blip doesn't cost you the rest of the install.

After `wally install`, `Packages/` will contain `React.lua`, `ReactRoblox.lua`, `Loader.lua`, and an `_Index/` folder with transitive dependencies.

By hand, without the CLI:

```bash
rokit install && wally install && rojo plugin install
```

## Dev loop

If you have the CLI installed, one command runs both halves:

```bash
boil dev                 # splitter (watch) + rojo serve, output prefixed
boil dev --port=34872    # if the default Rojo port is taken
```

Ctrl-C stops both. `--no-split` / `--no-serve` run one half alone.

Or do it by hand, in two terminals:

```bash
# terminal 1 — regenerate build/ whenever a file under src/features/ changes
lune run tools/split --watch

# terminal 2 — serve the Rojo project to Studio
rojo serve
```

Both halves matter: skip the splitter and Studio syncs a stale `build/`, so
edits to `src/features/` appear to do nothing.

Then in Roblox Studio:

1. Open (or create) an empty place.
2. Click **Connect** in the Rojo plugin (default host/port).
3. File → Save (the place file is gitignored as `Boil.rbxlx`).

### One-shot build

```bash
lune run tools/split        # generate build/ once
rojo build -o Boil.rbxlx    # or --output Boil.rbxl
```

## Adding features and skins from the registry

The package CLI is an npm package, installed once per machine — not part of the
Rokit toolchain:

```bash
npm install -g @encryptal/boil
```

```bash
boil setup          # name the project, create/connect the index
boil explore        # browse the index and install from the list
boil add encryptal/shop
boil install        # restore everything after a fresh clone
```

`setup` is a one-time step per project — it creates the index repo on GitHub if
it doesn't exist yet (via the `gh` CLI or `GITHUB_TOKEN`) and points this
checkout at it.

Features land in `src/features/<Name>/`, skins in `src/skins/<Name>/`, both
vendored and committed. Run `wally install` afterwards if the install reported new
Wally dependencies, and read the Studio setup notes it prints — assets are still
yours to create. See [registry.md](registry.md).

## Verifying the scaffold

Run a Play test. Expected output:

- Server console: `[HealthService] started (priority=10)`
- Client UI: a full-screen `TextLabel` reading `HP: 100` (the React-mounted `HealthUI` component).

If either is missing, check:

- `Packages/` exists and contains `Loader.lua` — otherwise `wally install` hasn't run.
- `build/` exists and contains `shared/Settings/init.luau`, `shared/Settings/Manifest.luau` etc. — otherwise `lune run tools/split` hasn't run.
- The Rojo plugin reports no sync errors.

## Optional: let an AI drive Studio (Studio MCP)

By default an AI assistant only sees your code — it can't inspect Studio or Play-test. The [Roblox Studio MCP](https://github.com/Chrrxs/robloxstudio-mcp) bridges your AI tool to a live Studio session, so it can find instances, read properties, run Luau, start/stop Play-tests, and capture the Script Profiler — i.e. verify its own work instead of relying on you to report back.

1. In Studio: **Game Settings → Security → Allow HTTP Requests** (on).
2. Add it to your AI tool (Claude Code shown; also works with Codex, Gemini, Claude Desktop):

   ```bash
   claude mcp add robloxstudio -- npx -y @chrrxs/robloxstudio-mcp@latest --auto-install-plugin
   ```

3. Restart the tool and open the place you want it to work in.

`CLAUDE.md` already adapts its guidance to whether these tools are connected. Check the MCP repo for current setup details.

## Regenerating the sourcemap

For Luau LSP / type inference:

```bash
rojo sourcemap --output sourcemap.json
```

`sourcemap.json` is gitignored; regenerate on demand.
