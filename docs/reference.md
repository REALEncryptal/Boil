# Reference

## Toolchain (rokit.toml)

| Tool  | Version  | Purpose                                                     |
| ----- | -------- | ----------------------------------------------------------- |
| rojo  | 7.4.4    | Syncs project tree to Roblox Studio                          |
| wally | 0.3.2    | Roblox package manager (reads `wally.toml`, writes `Packages/`) |
| lune  | 0.8.9    | Runs `tools/split.luau` outside Roblox                       |

## Wally dependencies (wally.toml)

| Package       | Source                          | Usage                                                                 |
| ------------- | ------------------------------- | --------------------------------------------------------------------- |
| `React`       | `jsdotlua/react@17.1.0`         | `require(ReplicatedStorage.Packages.React)`                           |
| `ReactRoblox` | `jsdotlua/react-roblox@17.1.0`  | `require(ReplicatedStorage.Packages.ReactRoblox)` — for `createRoot`  |
| `Loader`      | `sleitnick/loader@2.0.0`        | `require(ReplicatedStorage.Packages.Loader)` — module auto-loader     |
| `ByteNet`     | `ffrostflame/bytenet@0.4.6`     | **Preferred networking.** Schema-defined packets, buffer-packed. See `src/features/Notes/Packets.luau` for the canonical pattern. Docs: <https://ffrostflame.github.io/ByteNet/> |
| `Net`         | `sleitnick/net@0.2.0`           | Simple alternative for one-off RemoteEvents by name. Kept in the toolbox but not the default. Docs: <https://sleitnick.github.io/RbxUtil/api/Net> |
| `Trove`       | `sleitnick/trove@1.8.0`         | `require(ReplicatedStorage.Packages.Trove)` — track & clean up instances, connections, tasks. Docs: <https://sleitnick.github.io/RbxUtil/api/Trove> |
| `Signal`      | `sleitnick/signal@2.0.3`        | `require(ReplicatedStorage.Packages.Signal)` — typed Lua signals (`Signal.new()`). Docs: <https://sleitnick.github.io/RbxUtil/api/Signal> |
| `ReplicaService` | `brittonfischer/replicaservice@0.1.0` | Shared realm. Server: `require(ReplicatedStorage.Packages.ReplicaService)` for `ReplicaService`. Client: the same path exposes `ReplicaController`. Docs: <https://madstudioroblox.github.io/ReplicaService/> |
| `Cmdr`        | `evaera/cmdr@1.12.0`            | In-game command console. Server: `require(ReplicatedStorage.Packages.Cmdr):RegisterDefaultCommands()`. Client: `require(ReplicatedStorage:WaitForChild("CmdrClient"))` — Cmdr inserts CmdrClient into ReplicatedStorage from the server side, so `WaitForChild` is required. Docs: <https://eryn.io/Cmdr/> |

### Server-only dependencies (ServerPackages/)

| Package        | Source                           | Usage                                                                 |
| -------------- | -------------------------------- | --------------------------------------------------------------------- |
| `ProfileStore` | `lm-loleris/profilestore@1.0.3`  | `require(ServerScriptService.ServerPackages.ProfileStore)` — session-locked datastore wrapper (successor to ProfileService). Docs: <https://madstudioroblox.github.io/ProfileStore/> |

## Splitter (tools/split.luau)

### CLI

```bash
lune run tools/split             # one-shot rebuild of build/
lune run tools/split -- --watch  # rebuild when files under src/features/ change
```

`--watch` polls every 500ms using `fs.metadata().modifiedAt.unixTimestamp`. It clears and regenerates `build/` on any detected change.

### Filename classification

| Pattern               | Realm    | Output                                      |
| --------------------- | -------- | ------------------------------------------- |
| `*.server.luau`       | server   | `build/server/<Feature>/<name>.luau`        |
| `*.client.luau`       | client   | `build/client/<Feature>/<name>.luau`        |
| `*.ui.luau`           | shared   | `build/shared/<Feature>/<name>.luau`        |
| `init.luau`, `*.luau` | shared   | `build/shared/<Feature>/<same-name>`        |

Non-`.luau` files in feature folders are ignored.

## Loader (sleitnick/loader)

| API                          | Usage                                                    |
| ---------------------------- | -------------------------------------------------------- |
| `Loader.LoadDescendants(root, predicate?)` | `require`s every descendant ModuleScript, returns a list of returned values. Optional predicate filters by ModuleScript instance. |
| `Loader.LoadChildren(root, predicate?)`    | Same, but only direct children.                          |
| `Loader.MatchesName(pattern)`              | Returns a predicate matching by Lua pattern on the instance name. |
| `Loader.SpawnAll(modules, methodName)`     | Calls `module[methodName]()` on each loaded module under `task.spawn`. |

Full docs: <https://sleitnick.github.io/RbxUtil/api/Loader>

## useReplica (src/shared/utils/useReplica.luau)

React hook for subscribing to any data controller that exposes `GetData()` + `DataChanged: Signal`. Handles connect/disconnect lifecycle so features don't reimplement the `useEffect` pattern.

```lua
local utils = require(ReplicatedStorage.Shared.utils)

-- whole data table (re-renders on any change)
local data  = utils.useReplica(PlayerDataController)

-- single key (re-renders when that key changes; cheaper)
local coins = utils.useReplica(PlayerDataController, "Coins")
```

## LoadOrdered (src/shared/utils/LoadOrdered.luau)

```lua
local LoadOrdered = require(ReplicatedStorage.Shared.utils.LoadOrdered)

local modules = Loader.LoadDescendants(root)
Loader.SpawnAll(LoadOrdered(modules), "Start")
```

Sorts in place by each module's `.Priority` field (ascending). Modules where `.Priority` is absent or not a number sort to the end. Returns the same list for chaining.

## Entry scripts

### `src/server/init.server.luau`
Synced to `ServerScriptService.Server` as a `Script`. Runs once at server start. Loads and starts every service under `ServerScriptService.Features`.

### `src/client/init.client.luau`
Synced to `StarterPlayerScripts.Client` as a `LocalScript`. Runs once per player join. Mounts the root React app, then loads and starts every controller under `StarterPlayerScripts.Features`.

## Rojo sync map (default.project.json)

| Rojo path                                        | Filesystem source  | Contents                                             |
| ------------------------------------------------ | ------------------ | ---------------------------------------------------- |
| `ReplicatedStorage.Packages`                     | `Packages/`        | Wally output (shared deps)                           |
| `ServerScriptService.ServerPackages`             | `ServerPackages/`  | Wally output (server-only deps, e.g. ProfileStore)   |
| `ReplicatedStorage.Shared`                       | `src/shared/`      | Cross-realm shared code (incl. `utils/`)             |
| `ReplicatedStorage.Features`                     | `build/shared/`    | Shared surface of each feature (`init`, UI, types)   |
| `ServerScriptService.Server`                     | `src/server/`      | Server entry (`init.server.luau` → Script)           |
| `ServerScriptService.Features`                   | `build/server/`    | Per-feature server modules (`*.server.luau` stripped)|
| `StarterPlayer.StarterPlayerScripts.Client`      | `src/client/`      | Client entry (`init.client.luau` → LocalScript)      |
| `StarterPlayer.StarterPlayerScripts.Features`    | `build/client/`    | Per-feature client modules (`*.client.luau` stripped)|

## Gitignored paths

See `.gitignore`:

- `/Packages` — Wally output (shared)
- `/ServerPackages` — Wally output (server-only)
- `/build` — splitter output
- `/.rokit` — Rokit tool cache
- `/node_modules` — reserved
- `sourcemap.json`, `/Boil.rbxlx`, `/*.rbxlx.lock`, `/*.rbxl.lock` — generated artifacts
