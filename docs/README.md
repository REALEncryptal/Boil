# Boil — Documentation

Roblox scaffold using **Rojo + Wally + React (jsdotlua)** in a **Feature-Sliced Design** layout, managed by **Rokit**. Code is colocated per feature in `src/features/<Feature>/`; a **Lune prebuild splitter** redistributes files into the correct Roblox services at sync time.

## Index

- [Getting Started](getting-started.md) — install toolchain, install packages, run the dev loop, verify in Studio.
- [Architecture](architecture.md) — why `build/` exists, how the splitter works, how entry scripts load modules, load ordering.
- [Adding a Feature](adding-a-feature.md) — the workflow for creating a new feature and picking the right file suffixes.
- [Reference](reference.md) — file-suffix rules, splitter CLI, `LoadOrdered` API, directory map.

## TL;DR

```bash
rokit install             # one-time: installs rojo, wally, lune
wally install             # populate Packages/
lune run tools/split -- --watch   # terminal 1
rojo serve                        # terminal 2
# connect from Roblox Studio's Rojo plugin
```

To add a feature: create `src/features/<Name>/` with files named `Something.server.luau`, `Something.client.luau`, `Something.ui.luau`, or plain `Something.luau`. The splitter routes them to ServerScriptService / StarterPlayerScripts / ReplicatedStorage based on the suffix. Services/controllers expose a `.Start()` function; optionally set `.Priority = <number>` to control load order.
