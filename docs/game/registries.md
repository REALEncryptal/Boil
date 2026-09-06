# Registries

`Boil.Registry.define` — how one feature accepts contributions from another. This
is the mechanism the "features stack like legos" idea runs on.

## The problem it solves

A shared feature that wanted contributions used to hand-roll its own discovery
loop. PlayerData wrote one. Settings wrote a second — the same twenty-five lines
of walk-require-pcall-warn, with rules that had already diverged (Settings sealed
its registry, PlayerData never did). A third shared feature — Cash, Levels, Pets —
would have written a fourth copy.

There was no way to say *"any feature may contribute to me"* once.

## Declaring a seam

A shared feature declares its seam in a line:

```lua
-- src/features/Cash/init.luau
local Boil = require(ReplicatedStorage.Shared.Boil)

local Cash = {}
Cash.currencies = Boil.Registry.define("Cash", script)
return Cash
```

The name (`"Cash"`) is the filename other features drop. `script` is the owner, so
discovery skips the defining feature itself.

## Contributing

Any other feature opts in by dropping a sibling file with that name, returning a
function that receives the registry:

```lua
-- src/features/Rebirth/Cash.luau
return function(cash)
    cash.add({ id = "gems", label = "Gems", order = 20 })
end
```

**Rebirth names Cash; Cash never names Rebirth.** The dependency arrow points one
way, which is what lets you delete either folder. Declare it in Rebirth's
`boil.toml` so the loader can order them and warn if Cash is missing:

```toml
[dependencies]
"encryptal/cash" = "^1.0.0"
```

## The API

```lua
registry.add(entry)   -- entry must be a table with a string `id`
registry.get(id)
registry.has(id)
registry.list()       -- sorted by `order` (low first, unset last), then `id`
registry.count()
registry.Changed      -- Signal, fires on every add
registry.discover()   -- force the discovery pass now
registry.seal()       -- reject later registrations
```

### Attaching your own methods

Discovery is lazy, so the owner can attach extra methods to the registry before
anything reads it — and contributors receive them. That's how Settings keeps its
own data model (categories *and* settings are two collections with their own
sorting, not one flat list) while letting the shared registry own discovery:

```lua
local seam = Boil.Registry.define("Settings", script)
seam.registerCategory = Settings.registerCategory
seam.registerSetting = Settings.registerSetting
```

## Discovery timing

**Lazy by default** — the pass runs on the first `list` / `get` / `count`, not at
define time. Two reasons:

- A registry defined inside a feature's `init.luau` cannot walk the Features tree
  during its own require without recursing into itself.
- UI Labs never runs an entry script, so anything eager at boot would be invisible
  in stories.

**Call `discover()` explicitly** when the list must be complete before the first
read could plausibly happen. Settings does, because the server validates inbound
packets against it and a packet can arrive before any UI reads the registry.

## Realms

Lua state is per-realm, so each realm builds its own copy from the same shared
files. **Register only from shared code** — a sibling `<Name>.luau` with no
`.client` / `.server` suffix. Registering from realm-specific code lets the two
sides drift, and then server validation is checking a different list than the
client rendered.

`seal()` turns that mistake into a loud error at the call site instead of silent
drift. Call it once discovery is done, if your registry is security-relevant.

## Failure handling

Every contributor is required and called under `pcall`. One feature with a typo
warns by name and the rest still register — a bad new feature must not take the
whole game's UI down with it. Watch the output for:

```
[Registry:Nav] registration error in ReplicatedStorage.Features.Shop.Nav: …
[Registry:Nav] … must return function(Nav) … end; got table
```

## Who uses it

| Registry | Owner | Contributor file | What it collects |
| -------- | ----- | ---------------- | ---------------- |
| `PlayerData` | PlayerData | `PlayerData.luau` | Profile template slices |
| `Settings` | Settings | `Settings.luau` | Categories and toggles |
| `Nav` | HUD | `Nav.luau` | Sidebar entries and their windows |

## See also

- `src/shared/utils/Registry.luau`
- [framework-boundary.md](framework-boundary.md) — why the container is read generically
- [HUD.md](HUD.md) — the `Nav` registry in practice
- [../registry.md](../registry.md) — the *package* registry, a different thing with a confusingly similar name
