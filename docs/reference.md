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
| `ByteNet`     | `ffrostflame/bytenet@0.4.6`     | **Networking.** Schema-defined packets, buffer-packed. See `src/features/Notes/Packets.luau` for the canonical pattern. Docs: <https://ffrostflame.github.io/ByteNet/> |
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

`--watch` polls every 500ms using `fs.metadata().modifiedAt.unixTimestamp`. Builds are incremental: only changed files are written and stale files are deleted in place. The three realm directories (`build/shared`, `build/server`, `build/client`) are preserved across runs so Rojo's file watcher never sees them vanish — newly-added feature folders sync without needing a `rojo serve` restart.

### Filename classification

| Pattern               | Realm    | Output                                      |
| --------------------- | -------- | ------------------------------------------- |
| `*.server.luau`       | server   | `build/server/<Feature>/<name>.luau`        |
| `*.client.luau`       | client   | `build/client/<Feature>/<name>.luau`        |
| `*.ui.luau`           | shared   | `build/shared/<Feature>/<name>.luau`        |
| `init.luau`, `*.luau` | shared   | `build/shared/<Feature>/<same-name>`        |

Non-`.luau` files in feature folders are ignored.

## View lint (tools/check-views.luau)

```bash
lune run tools/check-views       # exits non-zero on a logic leak in a view
```

Scans every `*.ui.luau` and `*View*.luau` under `src/features/` for forbidden patterns (`Packets`, `ByteNet`, `.send(` / `.listen(`, `PlayerDataService`, `ProfileStore`) and fails if any appear. Enforces the headless-core rule: views read state and call intent actions only — networking/validation/persistence live in the Controller/Service. The splitter doesn't typecheck Luau and Studio is the only runtime, so run this as the cheap pre-Studio signal. See [headless-core.md](game/headless-core.md).

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

## Shared UI primitives (src/shared/ui/)

React components shared across features. Each `ui.X` is **skin-resolved**: it reads the active skin from `SkinProvider` context and renders that skin's implementation, defaulting to the **gem** skin when no provider is mounted. The prop shapes are the *contract* (`ui.contract`); skins implement them. See [skin-contract.md](game/skin-contract.md) for the full seam — what follows describes the gem look (skin #1).

```lua
local ui = require(ReplicatedStorage.Shared.ui)

-- Gem button (variant: red | blue | green | purple | yellow | white | rainbow)
React.createElement(ui.Button, {
    variant = "red", text = "X", size = UDim2.fromOffset(60, 60),
    onClick = function() ... end,
})

-- Icon + text pill (same palette set; no shine layer)
React.createElement(ui.Badge, {
    variant = "blue", text = "Rebirth", icon = "rbxassetid://…",
})

-- Translucent dark glass container with a white outline
React.createElement(ui.Panel, {
    size = UDim2.fromOffset(800, 600),
}, {
    Title = React.createElement("TextLabel", { ... }),
})
```

Add new color palettes by extending `Assets.Variants` in `src/shared/ui/assets.luau` rather than threading raw `ColorSequence` values through props. The Badge primitive looks up `Assets.BadgeVariants` first and falls back to `Assets.Variants`, so Badge-specific tunings live in their own table.

### Icon registry (`ui.assets.Icons`, `ui.assets.Brainrots`)

UI icon and character-image asset IDs live in `src/shared/ui/assets.luau` so a re-upload is a one-line edit and call sites never paste raw `rbxassetid://…` strings.

```lua
local ui = require(ReplicatedStorage.Shared.ui)

React.createElement(ui.Badge, {
    variant = "blue", text = "Rebirth",
    icon = ui.assets.Icons.rebirth,
})

React.createElement(ui.IconButton, {
    variant = "yellow",
    icon = ui.assets.Icons.bandOfCash,
})
```

| Table                  | Keys                                                                                                  | Intended use                              |
| ---------------------- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------- |
| `assets.Icons`         | `rebirth`, `bandOfCash`, `shoppingBasket`, `questionMark`, `friends`, `wheel`, `rocket`               | UI symbols (Badge / IconButton / HUD)     |
| `assets.Brainrots`     | `tungTungTungSahur`, `liriliLarila`, `trippiTroppi`, `tralaleroTralala`                               | Character art (cards, collectibles)       |

Types `Assets.IconKey` and `Assets.BrainrotKey` are exported for prop signatures.

### Design tokens (`ui.theme`)

`src/shared/ui/theme.luau` holds every shared visual default — stroke width, padding, transparency, text sizes, hover scale, etc. Every primitive in `src/shared/ui/` reads from it on each render (props still override per call site), so bumping a token here updates the whole UI.

```lua
local ui = require(ReplicatedStorage.Shared.ui)

ui.theme.strokeThickness     -- 4   gem outline (Button, Panel, TextField, GemBackground)
ui.theme.thinStrokeThickness -- 2   non-gem text outline (Text shadow, Sidebar label)
ui.theme.glassTransparency   -- 0.8 Panel/TextField translucent dark surfaces
ui.theme.padding             -- 10  default inner padding
ui.theme.hoverScale          -- 1.06
```

The token table holds **base values only**. Token relationships (e.g. Window's top content padding being `padding + strokeThickness` to clear the stroke) live at the consumer's render site so they recompute every frame — that way a live theme mutation in the Theme UI Labs story propagates immediately. See `Window.luau` for the canonical pattern.

To iterate visually, open the **Theme** story in UI Labs (`src/shared/ui/theme.story.luau`). Each base token gets a slider; moving one mutates the shared `theme` table, and the showcase plus every other open story picks up the new value on its next render. Settle on values you like, then bake them into `theme.luau`.

When you need a new shared knob, add it to `theme.luau` rather than inlining a magic number. When you genuinely need a value that's almost-but-not-quite a token, decide whether the token itself should change or whether the difference is component-specific; only the second case stays inline.

Three lower-level pieces are also exported and reusable when building new gem-styled surfaces:

- `ui.Text` — TextLabel using the gem display font. `shadow = true` opts into the two-layer drop-shadow (black shadow + white foreground offset by `-2px`, each with a Miter UIStroke) that Button and Badge use internally. Default is a plain single-layer label — use that for cleaner non-gem surfaces (e.g. the Sidebar's labels).
- `ui.GemBackground` — the noise-tiled gradient Frame with the inner-glow stroke, black miter outline, and an optional `hasShine` shine stroke. Used internally by Button (`hasShine = true`) and Badge.
- `ui.Window` — full window layout: dark glass Panel + top bar (optional Badge title + optional close Button) + scrollable content area. Children passed in are mounted directly into the scroll body. Use for any new feature window — see `src/features/UIShowcase/UIShowcase.ui.luau` for the call pattern.

### Skin seam (`ui.SkinProvider` / `ui.useSkin` / `ui.contract`)

`ui.X` primitives resolve their look from the active skin in React context. Wrap a subtree to swap; default (no provider) is gem.

```lua
local ui = require(ReplicatedStorage.Shared.ui)

React.createElement(ui.SkinProvider, { skin = "flat" }, { App = … })  -- gem | flat
local skin = ui.useSkin()        -- { name, theme, components }
ui.skins                          -- { gem = …, flat = … }
ui.contract                       -- typed prop shapes (ButtonProps, WindowProps, …)
```

- **gem** — the polished look (skin #1); its implementations are the files in `src/shared/ui/`.
- **flat** — a debug skin of plain gray boxes with accent borders (`src/shared/ui/skins/flat/`), verifiable by eye.
- Tokens live under each skin (`ui.useSkin().theme`); `ui.theme` is the gem/default token table.
- `variant` is per-skin. Author a new skin per [skin-contract.md](game/skin-contract.md); flip skins live in the `SkinProvider` story.

### Layout primitives (`ui.Stack` / `ui.Row` / `ui.Grid` / `ui.Slot`)

Transparent, structure-only — they wrap `UI*Layout` / padding / sizing and draw nothing. **Not** skin-resolved. Put skinned primitives inside them. Default surface for arranging a screen in code; see [layout-surfaces.md](game/layout-surfaces.md).

```lua
React.createElement(ui.Stack, { gap = 12, padding = 10, fillHorizontal = true }, {
    A = React.createElement(ui.Button, { variant = "red", text = "One", layoutOrder = 1 }),
    B = React.createElement(ui.Button, { variant = "blue", text = "Two", layoutOrder = 2 }),
})
```

| Primitive | Wraps | Notes |
| --------- | ----- | ----- |
| `ui.Stack` | UIListLayout (vertical) | gap, padding, alignment, flex |
| `ui.Row` | Stack (horizontal) | forwards to Stack with `direction = "horizontal"` |
| `ui.Grid` | UIGridLayout | cell size/padding, columns; children are **direct** cells |
| `ui.Slot` | named transparent Frame | a positioned region; future portal-bridge target |

### Importing from Studio (`src/shared/dev/Inspect`)

Studio-built templates can be dumped to clipboard with a one-liner — select the root instance(s) in Explorer, then paste in the command bar:

```lua
require(game.ReplicatedStorage.Shared.dev.Inspect)()
```

The inspector walks the selection, prints non-default properties for every known UI class (Frames, Labels, Strokes, Gradients, Layouts, Constraints), and copies the dump to the clipboard. Paste it back to Claude alongside the `/studio-import` skill and it scaffolds the matching `shared/ui/` code, palette entry, or feature UI.

### UI Labs stories

Each primitive has a sibling `*.story.luau` file that the [UI Labs](https://pepeeltoro41.github.io/ui-labs/) Studio plugin auto-discovers. Stories return `{ react, reactRoblox, story, controls, summary }`. The splitter passes `.story.luau` through unchanged (no special suffix handling), so a feature can ship its own story too — see `src/features/UIShowcase/UIShowcase.story.luau`.

Non-trivial controls use the UI Labs utility package (Wally `pepeeltoro41/ui-labs`):

```lua
local UILabs = require(ReplicatedStorage.Packages.UILabs)

controls = {
    variant = UILabs.Choose({ "red", "blue", "green" }),  -- dropdown
    size = UILabs.Slider(60, 20, 400, 1),                 -- value, min, max, step
    text = "Click",                                        -- plain string control
}
```

Passing a bare list (`{ "red", "blue" }`) gives "Malformed control object" — always wrap multi-choice in `UILabs.Choose`.

## Audio (src/shared/audio/)

Centralized sound and music registry plus thin playback helpers. **Client-side**: UI sounds use `SoundService:PlayLocalSound` (errors if called from the server); the looping music Sound is parented to the client's `SoundService` so each player drives their own track. For server-broadcast audio (a global jingle), use a Sound parented to Workspace replicated over ByteNet instead.

**Roblox does not play audio inside Studio plugins**, so the Audio UI Labs story below is silent in-edit. Audition the registry by Play-testing the game, not from UI Labs.

```lua
local audio = require(ReplicatedStorage.Shared.audio)

audio.playUI("click")              -- fire-and-forget one-shot SFX
audio.playUI("levelUp", 0.7)       -- override volume (default 1)
audio.playMusic("lobby")           -- swap looping background track
audio.playMusic("phonk", 0.4)      -- override volume (default 0.2)
audio.stopMusic()
audio.currentTrack()               -- nil | the active music Sound
audio.currentTrackName()           -- nil | the key passed to playMusic
audio.playSoundId("rbxassetid://…", 0.6) -- arbitrary one-shot outside the registry
```

| Function                              | Behavior                                                                                            |
| ------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `playUI(name, volume?)`               | One-shot via `SoundService:PlayLocalSound`. Sound is destroyed on `Ended` (with a 15s safety net for bad assets).|
| `playSoundId(id, volume?)`            | Same as `playUI` but takes a raw `rbxassetid://…` for sounds outside the registry.                  |
| `playMusic(name, volume?)`            | Swap looping background. No-op when the requested track is already playing. Returns the active Sound.|
| `stopMusic()`                         | Destroy the current looping Sound.                                                                  |
| `currentTrack()` / `currentTrackName()` | The active Sound / registry key, or `nil` when no music is playing.                                |

Add new SFX/music by extending `Audio.UI` or `Audio.Music` in `src/shared/audio/init.luau`. Update the corresponding `UISoundKey` / `MusicKey` union so callers get autocomplete.

The **Audio** UI Labs story (`src/shared/audio/Audio.story.luau`) mounts a button per UI sound and per music track plus a stop-music button — useful as a manifest, but silent in-edit (see plugin-audio caveat above). Use it during Play-test.

### Widget hover + click sounds

Every shared widget that runs through `useHoverScale` (Button, IconButton, Checkbox, and feature widgets like `SidebarItem` that reuse the hook) automatically plays:

- `hoverIn` on `MouseEnter`
- `hoverOut` on `MouseLeave`
- `click` on `MouseButton1Down`

To override per call site, pass `sounds` to `useHoverScale`:

```lua
-- Mute the whole hook (e.g. a tooltip target with no click affordance):
local hover = ui.useHoverScale({ sounds = false })

-- Swap individual cues; omitted keys keep the default:
local hover = ui.useHoverScale({
    sounds = { press = "purchase" },     -- buy button uses the purchase cue
})
```

The defaults live in `DEFAULT_SOUNDS` at the top of `src/shared/ui/useHoverScale.luau`. Change a key there and every consumer follows.

### Registered tracks

| Table             | Keys                                                                                                                       |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `audio.UI`        | `click`, `click2`, `purchase`, `hoverIn`, `hoverOut`, `levelUp`, `swipe`, `select`, `reward`, `tick`, `money`               |
| `audio.Music`     | `lobby`, `lobby2`, `lobby3`, `fastMusic`, `phonk`, `phonk2`, `xmas`                                                         |

## Entry scripts

### `src/server/init.server.luau`
Synced to `ServerScriptService.Server` as a `Script`. Runs once at server start. Loads and starts every service under `ServerScriptService.Features`.

### `src/client/init.client.luau`
Synced to `StarterPlayerScripts.Client` as a `LocalScript`. Runs once per player join. Auto-requires every feature, discovers + requires `*Presentation` / `*WorldInteraction` modules (which self-register into `UIRegistry`), mounts the root React app (`SkinProvider → FrameProvider → Frame(UIRegistry.getRoots())`), then loads + starts every controller and requests replicas. Names no content feature — see [presentations.md](game/presentations.md) and [UIRegistry](#uiregistry-srcsharedutilsuiregistryluau).

## UIRegistry (src/shared/utils/UIRegistry.luau)

Client-side registries presentations register themselves into, so the entry file names no feature.

| API | Usage |
| --- | ----- |
| `UIRegistry.registerRoot(name, element)` / `getRoots()` | Always-mounted top-level UI (HUD host, Health widget). |
| `UIRegistry.registerScreen(frameId, element)` / `getScreens()` | HUD window contents keyed by UIShell frame id. |

A feature opts in with a `*Presentation.client.luau` that registers at load; `init.client.luau` requires those before mounting. See [presentations.md](game/presentations.md).

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
