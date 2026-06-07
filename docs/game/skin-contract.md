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

3. **`src/shared/ui/skins/`** — the skins themselves:
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
  documented props. A missing key is a runtime error when that primitive renders.
- **`variant` is per-skin.** Each skin interprets the `VariantKey`
  (`red`/`blue`/…) however it likes — gem maps it to a gradient palette, flat to a
  flat accent color. Unknown variants fall back to the skin's default.
- **Tokens live under each skin** (`skin.theme`), not in the contract. `ui.theme`
  exposes the default (gem) tokens that the UI Labs Theme story tunes live; for
  skin-aware token reads inside a component use `ui.useSkin().theme`.
- **Don't reach past the seam.** Feature code uses `ui.X`; it should not require a
  specific skin's implementation directly.

## Authoring a new skin

1. Create `src/shared/ui/skins/<name>/` (folder) or `<name>.luau` (single file)
   returning a `contract.Skin`: `{ name, theme, components = { Button = …, … } }`.
2. Implement each component against its `contract.*Props` type. Honor the named
   slot props so caller content lands where the gem/flat skins put it.
3. Register it in `src/shared/ui/skins/init.luau` and add its name to the
   `SkinName` union in `SkinProvider.luau`.
4. Add it to the `SkinProvider.story` chooser so it's verifiable in UI Labs.

The gem skin is the reference for the polished path; the flat skin (`skins/flat/`)
is the minimal reference — read it first when building a new skin, it's the
smallest complete implementation of the contract.
