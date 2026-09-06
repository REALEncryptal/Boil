# PlayerData

Player profile persistence — [ProfileStore](https://madstudioroblox.github.io/ProfileStore/)
(session-locked DataStore) on the server and
[ReplicaService](https://madstudioroblox.github.io/ReplicaService/) for client
replication, so client reads are zero-latency and writes survive sessions. The
feature ships **no real profile fields**; other features register slices and
PlayerData merges them.

## Shape

- `init.luau` (shared) — the template registry: a flat `[topLevelKey] = default`
  table contributed to by sibling features through their own `PlayerData.luau`.
- `PlayerDataService` — starts the ProfileStore session on `PlayerAdded`, calls
  `profile:Reconcile()`, then creates the Replica.
- `PlayerDataService.SetValue(player, path, value)` — the write API.
- Clients read with `PlayerDataController.GetData()`, or `Boil.useReplica` in
  React so a component re-renders only when its key changes.

## Decisions

- **The Replica's `Data` *is* `profile.Data` — the same table reference.** That is
  what makes every client-visible mutation persist on the next autosave.
  Reassigning `profile.Data` to a new table silently breaks saving; a drift
  warning fires on every save if it happens.
- **`SetValue` is the only blessed mutation path.** It fires the replica diff and
  leaves the autosave correct. Mutating the profile directly skips the diff, so
  the client silently diverges from the server.
- **`Constants.luau` deliberately has no `PROFILE_TEMPLATE`.** An older revision
  listed `{ Coins = 0, … }` there, which coupled a shared feature to whatever
  fields one consumer happened to need. The template is built from
  `registerTemplate` calls — do not put fields back.
- **Discovery runs at require time, not in `Start`,** so the merged template is
  complete before `ProfileStore.New` is called. `PlayerDataService.Priority = 1`;
  feature services that read player data sit at 10 or higher.
- **`profile:Reconcile()` runs on every load,** which is what makes adding a slice
  later safe — existing players get the new keys filled with defaults on their
  next session.

## Gotchas

No Studio assets. A `PlayerData.luau` must not require `Features.PlayerData`
itself (circular) — use the table it is handed. Two features registering the same
key warns and the second is ignored. Bump `Constants.STORE_NAME` only for a
schema change you do *not* want reconciled.

## See also

[registries.md](registries.md) · [Settings.md](Settings.md)
