# Skin contract & SkinProvider

The shared UI is split along a **skin seam**: *what a primitive looks like* is
swappable independently of *what it does* and *where it sits*. This is seam #1 of
the four (skin / layout / view / presentation).

## The three pieces

1. **`src/shared/ui/contract.luau`** — the typed prop shapes every primitive
   speaks (`ButtonProps`, `WindowProps`, `ScrollListProps`, …), plus the `Skin`
   and `Components` types. This is the keystone: it's shape-only — it says nothing
   about colors, strokes, or spacing. Structural insertion points are **named slot
   props** (`children` maps keyed by name) so every skin agrees on where caller
   content goes.

2. **`src/shared/ui/SkinProvider.luau`** — a React context holding the active
   skin. `useSkin()` returns it, falling back to the **gem** skin when no provider
   is mounted (so existing call sites and UI Labs stories work untouched).

3. **`src/shared/ui/skins/`** — the registry (name → skin, with lazy discovery of
   installed skins under `ReplicatedStorage.Skins`) plus the two built-ins:
   - `gem.luau` — skin #1, the polished gem look. It just gathers the primitive
     implementations that still live in `src/shared/ui/` (`Button.luau`,
     `Window.luau`, …). Those files compose each other directly, so the gem look
     is internally consistent regardless of the active skin.
   - `flat/` — skin #2, a debug skin of plain gray boxes with accent borders. Its
     job is to prove the swap and be verifiable by eye on plain shapes.

## How resolution works

`ui.Button` (and every other `ui.X`) is a **semantic** component. At render it
calls `useSkin()` and renders `skin.components.Button(props)`, passing props
(including the named-children slot) straight through. Feature code never mentions
a skin — it just uses `ui.Button`.

```lua
-- Swap the skin for a subtree:
React.createElement(ui.SkinProvider, { skin = "flat" }, { App = … })

-- Default (no provider) resolves to gem.
React.createElement(ui.Button, { variant = "red", text = "Go" })
```

The production root mounts `<SkinProvider skin="gem">` at the top of the tree
(`src/client/init.client.luau`). The `SkinProvider.story` flips gem ↔ flat live.

## Rules

- **Every skin implements every component key** in `contract.Components` with the
  documented props. A missing key falls back to gem's implementation and warns
  once; `tools/check-skins` is how you catch it before shipping.
- **`variant` is per-skin.** Each skin interprets the `VariantKey`
  (`red`/`blue`/…) however it likes — gem maps it to a gradient palette, flat to a
  flat accent color. Unknown variants fall back to the skin's default.
- **Tokens live under each skin** (`skin.theme`), not in the contract. `ui.theme`
  exposes the default (gem) tokens that the UI Labs Theme story tunes live; for
  skin-aware token reads inside a component use `ui.useSkin().theme`.
- **Don't reach past the seam.** Feature code uses `ui.X`; it should not require a
  specific skin's implementation directly.

## Authoring a new skin

1. Create `src/skins/<Name>/` with an `init.luau` returning a `contract.Skin`:
   `{ name, theme, components = { Button = …, … } }`. Type it as `Boil.Skin` —
   the contract's types are re-exported from the public surface, since a skin
   reaches the framework only through `Shared.Boil` like any other package.
2. Implement each component against its `contract.*Props` type. Honor the named
   slot props so caller content lands where the gem/flat skins put it.
3. Run `lune run tools/check-skins` — it reports every contract key you haven't
   implemented yet.

There is **no registration step.** The registry discovers every ModuleScript
under `ReplicatedStorage.Skins` lazily on first use, and the `SkinProvider` story
builds its chooser from `ui.skins.names()`, so a new skin appears in UI Labs
without touching a framework file. (Discovery is lazy rather than driven by the
client entry script precisely so it works in Studio edit mode, where that script
never runs.)

Skins are shareable packages — add a `boil.toml` and `boil publish
src/skins/<Name>` puts them in the index. See [registry.md](../registry.md).

The framework's own two skins still live in `src/shared/ui/skins/` (gem's
implementations *are* the files in `src/shared/ui/`). Moving gem out to
`src/skins/gem/` — so the framework ships zero skins, mirroring how it ships zero
features — is the eventual clean state, but it's a wide refactor and nothing
depends on it.

### Forward compatibility

`contract.VERSION` is the skin API's compatibility number, and a published skin
declares the range it was built against (`contract = "^1"`).

Adding a component key to the contract is a **minor** change: `ui.X` falls back to
gem's implementation for any key the active skin doesn't implement
(`skins.resolve`), so a skin that predates the addition renders that one primitive
in gem and everything else in its own look. Degraded, not broken — which is what
makes it safe to grow the contract once skins are out in the world. Changing an
existing prop shape is a **major** change: bump `VERSION`, because every published
skin now renders the wrong thing.

The gem skin is the reference for the polished path; the flat skin (`skins/flat/`)
is the minimal reference — read it first when building a new skin, it's the
smallest complete implementation of the contract.
