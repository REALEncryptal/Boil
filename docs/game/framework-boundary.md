# Framework / feature boundary

Boil is two layers: a **framework** (reusable infrastructure) and the **features**
built on top of it. The framework ships *empty* — zero features, not even the
"basic" ones (PlayerData, Settings, UIShell are all features). This split is what
lets an existing project pull a newer framework without re-merging its features.

## What's framework, what's a feature

| Layer | Lives in | Owns |
| ----- | -------- | ---- |
| **Framework** | `src/shared/`, `src/client/`, `src/server/`, `tools/` | The mechanism: the UI kit + seams, the load helpers, the presentation registry, the splitter, the lints, the entry scripts. |
| **Feature** | `src/features/<Name>/` | Content: one self-contained, removable unit. Everything else is built out of these. |

The splitter (`tools/split`) and `tools/check-views` only ever touch
`src/features/`, so the physical boundary is already clean. A fresh framework is
this repo with `src/features/` empty — the entries, registries, and UI kit all
still load and the client still mounts.

## The contract: `Shared.Boil`

Features consume the framework through **one** module — `src/shared/Boil.luau` —
and nothing deeper:

```lua
local Boil = require(ReplicatedStorage.Shared.Boil)

React.createElement(Boil.ui.Button, { variant = "red", text = "X" })
Boil.UIRegistry.registerScreen("Notes", element)
local data = Boil.useReplica(...)
```

`Boil` exposes `ui`, `audio`, `Loader`, `LoadOrdered`, `UIRegistry`, and
`useReplica`. Members load lazily on first access, so requiring `Boil` is cheap and
realm-safe — a server Service that only touches `Boil.LoadOrdered` never pulls in
the React UI kit behind `Boil.ui`. It deliberately does **not** export third-party
Wally packages (React, ByteNet, ReplicaService — require those directly) or
anything a feature owns. Because features bind to this surface instead of deep
paths, the framework can refactor its internals freely; only this surface has to
stay stable. That's what turns a framework update into a version bump instead of a
merge conflict.

## The rule: the dependency arrow points one way

**Framework code must never name a feature.** Features depend on the framework;
the framework is agnostic to every feature. If the framework seems to need
something from a feature, the seam is backwards — the feature should *register
into* the framework, not the other way around.

- Touching the `Features` container generically is fine: iterating it,
  `LoadDescendants(Features, …)`, `Features:GetChildren()`. That names nobody.
- Reaching a *named* child is a violation: `Features:WaitForChild("UIShell")`,
  `require(ReplicatedStorage.Features.Notes)`, `Features.Settings`.

`tools/check-framework-boundary` enforces the boundary **both ways**: it scans the
runtime framework realms for any named-feature reference (this rule), *and* scans
`src/features` to ensure features reach the framework only through `Shared.Boil` —
a deep `require(ReplicatedStorage.Shared.ui)` from a feature fails it. Run it
alongside `check-views`:

```
lune run tools/check-framework-boundary
```

(The build tools under `tools/` are generic Lune scripts that operate on the
features *directory* by design, so they're out of scope for the lint. A feature
requiring its own modules under `ReplicatedStorage.Features.<Self>` is fine.)

### Worked example: how UIShell stays optional

The client root needs *some* provider wrapping the tree for frame open/close
state — but it can't name `UIShell`, or the framework wouldn't boot empty. So the
registry carries it:

- `UIRegistry.registerProvider(component)` / `getProviders()` — a feature registers
  a top-level React provider to wrap the whole client tree.
- `src/features/UIShell/UIShellPresentation.client.luau` registers
  `UIShell.FrameProvider` at load (discovered before mount, like any presentation).
- `src/client/init.client.luau` composes whatever's registered around the root
  Frame. With **none** registered, the root still mounts.

Remove the `UIShell` folder → no provider registers → the framework boots fine
without it. A feature naming *itself* (the presentation requires `UIShell`) is
allowed; only *framework* code naming a feature is not.

## Adding to the public surface

When the framework grows a genuinely shared capability that features should
consume, add it to `Boil` (and document it here). Resist exporting feature-owned
things or third-party packages — keep the surface small and stable, because every
symbol on it is a compatibility promise to every downstream project.
