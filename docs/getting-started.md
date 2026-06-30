# Getting Started

## Prerequisites

- **Rokit** — toolchain manager. Install from <https://github.com/rojo-rbx/rokit>.
- **Roblox Studio** with the Rojo plugin installed.

## One-time setup

```bash
rokit install   # reads rokit.toml, installs rojo, wally, lune
wally install   # reads wally.toml, populates Packages/
```

After `wally install`, `Packages/` will contain `React.lua`, `ReactRoblox.lua`, `Loader.lua`, and an `_Index/` folder with transitive dependencies.

## Dev loop

Two terminals:

```bash
# terminal 1 — regenerate build/ whenever a file under src/features/ changes
lune run tools/split -- --watch

# terminal 2 — serve the Rojo project to Studio
rojo serve
```

Then in Roblox Studio:

1. Open (or create) an empty place.
2. Click **Connect** in the Rojo plugin (default host/port).
3. File → Save (the place file is gitignored as `Boil.rbxlx`).

### One-shot build

```bash
lune run tools/split        # generate build/ once
rojo build -o Boil.rbxlx    # or --output Boil.rbxl
```

## Verifying the scaffold

Run a Play test. Expected output:

- Server console: `[HealthService] started (priority=10)`
- Client UI: a full-screen `TextLabel` reading `HP: 100` (the React-mounted `HealthUI` component).

If either is missing, check:

- `Packages/` exists and contains `Loader.lua` — otherwise `wally install` hasn't run.
- `build/` exists and contains `shared/HealthSystem/init.luau` etc. — otherwise `lune run tools/split` hasn't run.
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
