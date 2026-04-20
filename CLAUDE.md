# Boil

Roblox boilerplate: Rojo + Wally + React (jsdotlua), Feature-Sliced Design, managed by Rokit. Features are colocated under `src/features/<Name>/` and a Lune splitter (`tools/split.luau`) routes files to the right Roblox service based on `.server.luau` / `.client.luau` / `.ui.luau` suffixes.

## Read before working on this project

- `docs/architecture.md` — how the split, entry scripts, and load ordering work.
- `docs/adding-a-feature.md` — the workflow for adding a feature or shared utility.
- `docs/reference.md` — filename rules, Loader/LoadOrdered API, sync map.
- `docs/getting-started.md` — dev loop commands.

Consult the relevant doc first; don't infer structure from the tree alone.
