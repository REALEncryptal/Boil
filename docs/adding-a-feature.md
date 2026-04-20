# Adding a Feature

A feature is a self-contained slice that may have server logic, client logic, shared code, and UI. Everything lives under `src/features/<FeatureName>/`.

## Minimal feature

```
src/features/Inventory/
└── init.luau            -- public surface (usually re-exports UI, types)
```

`init.luau` becomes a ModuleScript at `ReplicatedStorage.Features.Inventory`. Both realms can `require` it.

## Full feature

```
src/features/Inventory/
├── init.luau                        -- shared public surface
├── Constants.luau                   -- shared config / tunables (see below)
├── Packets.luau                     -- shared ByteNet packet schema (see below)
├── InventoryService.server.luau     -- server-only logic
├── InventoryController.client.luau  -- client-only logic
├── InventoryUI.ui.luau              -- React component (shared replicated)
└── Types.luau                       -- shared type definitions
```

After `lune run tools/split`:

```
ReplicatedStorage.Features.Inventory
  ├── init            (from init.luau)
  ├── Constants       (from Constants.luau)
  ├── InventoryUI     (from InventoryUI.ui.luau; .ui suffix stripped)
  └── Types
ServerScriptService.Features.Inventory
  └── InventoryService      (from InventoryService.server.luau; .server stripped)
StarterPlayerScripts.Features.Inventory
  └── InventoryController   (from InventoryController.client.luau; .client stripped)
```

## Networking (ByteNet Packets module)

If a feature has server ↔ client traffic, define packets in a shared `Packets.luau` inside the feature folder. Both realms require the same module; ByteNet handles wire format and reliability.

```lua
-- src/features/Inventory/Packets.luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ByteNet = require(ReplicatedStorage.Packages.ByteNet)

return ByteNet.defineNamespace("Inventory", function()
    return {
        EquipItem = ByteNet.definePacket({
            value = ByteNet.struct({
                slot = ByteNet.uint8,
                itemId = ByteNet.string,
            }),
            reliabilityType = "reliable",
        }),
    }
end)
```

Usage:
```lua
-- server (InventoryService.server.luau)
Packets.EquipItem.listen(function(payload, player) ... end)

-- client (InventoryController.client.luau)
Packets.EquipItem.send({ slot = 2, itemId = "WoodenSword" })
```

Why Packets.luau over `sleitnick/net`: the namespace is strongly typed by schema, payloads are buffer-packed (much smaller on the wire), and typos in packet names fail at require-time instead of silently sending to the void.

See `src/features/Notes/Packets.luau` for the working example.

## Constants module

Features often want a single place for tunable numbers, IDs, and strings that both realms read. By convention, put them in `Constants.luau` (plain `.luau` → shared realm) and re-export via `init.luau`:

```lua
-- src/features/Inventory/Constants.luau
return {
    MAX_SLOTS = 24,
    STARTER_ITEMS = { "WoodenSword", "Bread" },
    UI_ANIMATION_TIME = 0.25,
}

-- src/features/Inventory/init.luau
local Inventory = {}
Inventory.Constants = require(script.Constants)
Inventory.UI = require(script.InventoryUI)
return Inventory
```

Consumers then read `require(ReplicatedStorage.Features.Inventory).Constants.MAX_SLOTS` — no magic numbers scattered across service/controller/UI code.

Keep `Constants.luau` pure data (no functions that touch services, no RemoteEvents). If you need shared *logic* both realms run, use a separately-named module (e.g. `Math.luau`).

## Service and controller convention

**Filename suffix matters for auto-loading.** The entry scripts filter with `Loader.MatchesName("Service$")` / `Controller$` and only call `.Start()` on modules whose Studio name ends in `Service` (server) or `Controller` (client). So:

- `InventoryService.server.luau` → auto-loaded on server, `.Start()` called.
- `InventoryController.client.luau` → auto-loaded on client, `.Start()` called.
- `InventoryView.client.luau` → **not** auto-started. Use this for client-realm React containers or helper modules that get `require`d on demand.

Each service / controller should return a table with a `Start` function.

```lua
-- InventoryService.server.luau
local InventoryService = {}

InventoryService.Priority = 20      -- optional; lower = earlier

function InventoryService.Start()
    -- wire up RemoteEvents, start loops, etc.
end

return InventoryService
```

If a module doesn't expose `Start`, `SpawnAll` silently skips it — so plain data modules are fine.

## Referencing other features

From anywhere, the shared surface of a feature is at `ReplicatedStorage.Features.<Name>`:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Inventory = require(ReplicatedStorage.Features.Inventory)

-- Render its UI
root:render(React.createElement(Inventory.UI, { slots = 12 }))
```

Server code can additionally reach its own backend via `ServerScriptService.Features.Inventory.InventoryService` (but usually you'd call `InventoryService` from within the same feature only).

## Load order

- Declare `Module.Priority = <number>` to make a service start earlier. Lower numbers run first.
- Modules without `Priority` run last, in arbitrary order.
- Keep priority numbers sparse (10, 20, 30…) so you can insert new services between existing ones.

Typical priority bands:

| Priority | Purpose |
| -------- | ------- |
| 1–9      | Core infrastructure (config, datastore, remotes) |
| 10–49    | Core gameplay services |
| 50–99    | Feature services |
| unset    | Leaf services with no peers depending on their `Start` completion |

## Adding shared utilities (not feature-specific)

Put them in `src/shared/utils/`:

```
src/shared/utils/
├── init.luau            -- re-exports utilities
├── LoadOrdered.luau
└── MyNewUtil.luau
```

Then update `src/shared/utils/init.luau`:

```lua
local utils = {}
utils.LoadOrdered = require(script.LoadOrdered)
utils.MyNewUtil = require(script.MyNewUtil)
return utils
```

Use from anywhere:

```lua
local utils = require(ReplicatedStorage.Shared.utils)
utils.MyNewUtil(...)
```

## Gotchas

- **Don't put `.server.luau` files outside `src/features/`.** The splitter only walks `src/features/`. A `.server.luau` elsewhere would be synced by Rojo as a `Script` (auto-running), which is almost never what you want for a module.
- **Filenames are the contract.** `Inventory.Service.server.luau` and `InventoryService.server.luau` both produce different Studio names. Pick one convention per project (this scaffold uses `<Thing>Service.server.luau`).
- **UI components don't have to use `.ui.luau`.** The `.ui` suffix is a naming convention — splitter treats it the same as plain `.luau` (shared realm, suffix stripped). Use it when you want the filename to signal "this is a React component".
