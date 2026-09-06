# Boil — Documentation

Roblox scaffold using **Rojo + Wally + React (jsdotlua)** in a **Feature-Sliced Design** layout, managed by **Rokit**. Code is colocated per feature in `src/features/<Feature>/`; a **Lune prebuild splitter** redistributes files into the correct Roblox services at sync time.

## Index

- [Getting Started](getting-started.md) — install toolchain, install packages, run the dev loop, verify in Studio.
- [Architecture](architecture.md) — why `build/` exists, how the splitter works, how entry scripts load modules, load ordering.
- [Adding a Feature](adding-a-feature.md) — the workflow for creating a new feature and picking the right file suffixes.
- [Reference](reference.md) — file-suffix rules, splitter CLI, `FeatureLoader` API, directory map.
- [Registry](registry.md) — sharing features and skins between games: the package format, the index, and `boil` (install, publish, explore).

## TL;DR

```bash
boil install              # rokit + wally + the Rojo Studio plugin, one command
boil dev                  # splitter (watch) + rojo serve
# connect from Roblox Studio's Rojo plugin

# or by hand:
rokit install && wally install && rojo plugin install
lune run tools/split --watch   # terminal 1
rojo serve                     # terminal 2
```

To add a feature: create `src/features/<Name>/` with files named `Something.server.luau`, `Something.client.luau`, `Something.ui.luau`, or plain `Something.luau`. The splitter routes them to ServerScriptService / StarterPlayerScripts / ReplicatedStorage based on the suffix. Services/controllers expose a `.Start()` function; optionally set `.Priority = <number>` to control load order.
