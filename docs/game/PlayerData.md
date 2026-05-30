# PlayerData

Player profile persistence. Wraps [ProfileStore](https://madstudioroblox.github.io/ProfileStore/) (session-locked DataStore) on the server and [ReplicaService](https://madstudioroblox.github.io/ReplicaService/) for client replication, so reads are zero-latency on the client and writes survive across sessions.

The PlayerData feature ships **no real profile fields** — it provides the mechanism (template merging, profile load, replica plumbing, write API). Other features declare their own slices of the profile and PlayerData merges them in.

## What it does

- **Template registry** (`init.luau`, shared): a flat `[topLevelKey] = default` table contributed to by sibling features. PlayerData itself adds nothing to it.
- **Profile load** (`PlayerDataService`): on `PlayerAdded`, starts a ProfileStore session, calls `profile:Reconcile()` (which fills in keys added since the player last joined), then creates a Replica whose `Data` table **is** `profile.Data` — same table reference, so the autosave persists every client-visible mutation.
- **Write API**: `PlayerDataService.SetValue(player, { "Path", "To", "Key" }, value)`. This is the only blessed mutation path — it fires a Replica diff to the client and the next autosave persists the change. Direct mutation of `profile.Data` (especially reassigning `profile.Data` to a new table) silently breaks saves and is caught by a drift warning on every save.
- **Auto-discovery**: at first require, `init.luau` walks `ReplicatedStorage.Features:GetChildren()` looking for a `PlayerData` ModuleScript child on each feature; each is required and called with the PlayerData table so it can register its slice.

## Studio assets it expects

None. Everything is code.

## Adding profile fields from another feature

Drop a `PlayerData.luau` file as a sibling of your feature's `init.luau`:

```lua
-- src/features/Pets/PlayerData.luau
return function(PlayerData)
    PlayerData.registerTemplate("Pets", {
        Owned = {},      -- list of pet ids
        Equipped = nil,  -- currently equipped pet id, or nil
    })
end
```

After `lune run tools/split`, the file lands at `ReplicatedStorage.Features.Pets.PlayerData` and is auto-discovered the first time anything requires `Features.PlayerData`. Each feature gets one top-level key on the profile; if you need nested data, the default value is a table.

Rules:
- The discovery file is required exactly once per realm. Put only `registerTemplate` calls inside — no service start-up logic, no `Players.PlayerAdded` connections.
- The PlayerData.luau module body must not require `Features.PlayerData` itself (circular require). The function it returns receives `PlayerData` as an argument — use that.
- Two features registering the same key warns and the second registration is ignored. Pick a unique key per feature.
- `profile:Reconcile()` runs on every load, so adding a new slice later is safe — existing players get the new keys filled in with the defaults on their next session.

## Reading values from feature code

```lua
local PlayerDataController = require(StarterPlayerScripts.Features.PlayerData.PlayerDataController)

local data = PlayerDataController.GetData() -- nil until the replica arrives
local pets = data and data.Pets
```

For React components, subscribe via `useReplica` so the component re-renders when the value changes:

```lua
local utils = require(ReplicatedStorage.Shared.utils)
local pets = utils.useReplica(PlayerDataController, "Pets") -- re-renders only when "Pets" changes
local data = utils.useReplica(PlayerDataController)         -- re-renders on any change
```

## Writing values from feature code (server)

```lua
local PlayerDataService = require(ServerScriptService.Features.PlayerData.PlayerDataService)

PlayerDataService.SetValue(player, { "Pets", "Equipped" }, petId)
-- replica diff fires immediately; ProfileStore autosaves on its own cadence
```

Clients never mutate the profile directly — route through a feature-owned ByteNet packet to the server, validate, then `SetValue`. See `src/features/Settings/SettingsService.server.luau` for the canonical pattern.

## Constants worth knowing

- `Constants.STORE_NAME = "PlayerData_v1"` — ProfileStore key. Bump the suffix when you ship an incompatible schema change you don't want to reconcile.
- `Constants.REPLICA_CLASS = "PlayerData"` — Replica class token. The client subscribes via `ReplicaController.ReplicaOfClassCreated`.

## What `Constants.luau` deliberately doesn't have

Older revisions of this scaffold listed `PROFILE_TEMPLATE = { Coins = 0, … }` here. That was wrong: it couples the shared PlayerData feature to whatever game-specific fields one consumer happened to need. The template is built dynamically from `registerTemplate` calls — `Constants.luau` is just `STORE_NAME` and `REPLICA_CLASS`.

## How auto-discovery interacts with load order

`PlayerDataService.Priority = 1` so the service starts before any feature that depends on player data. The discovery loop runs at module require time (not in `Start`), so `getTemplate()` returns the full merged template by the time `ProfileStore.New` is called. Feature services that read player data should sit at `Priority = 10` or higher.
