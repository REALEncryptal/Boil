# Skin contract & SkinProvider

The shared UI is split along a **skin seam**: *what a primitive looks like* is
swappable independently of *what it does* and *where it sits*. This is seam #1 of
the four (skin / layout / view / presentation).

## The three pieces

1. **`src/shared/ui/contract.luau`** — the typed prop shapes every primitive
   speaks (`ButtonProps`, `WindowProps`, `ScrollListProps`, …), plus the `Skin`,
   `Theme` and `Components` types. Structural insertion points are **named slot
   props** (`children` maps keyed by name) so every skin agrees on where caller
   content goes.

   Since **contract v2** it also fixes two *scales* — see
   [Tokens are part of the contract](#tokens-are-part-of-the-contract). It is no
   longer shape-only, because shape-only turned out to be the reason a call site
   could never portably ask for "a body-size label".

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


## Tokens are part of the contract

`contract.VERSION` is **2**. The change: every skin's `theme` must expose two
scales with fixed keys.

```lua
theme.type  = { display, title, heading, body, label, caption }  -- numbers
theme.space = { xs, sm, md, lg, xl, xxl }                        -- numbers
theme.resolveVariant = function(key: string?): string
```

A skin may retune the **values** — flat's `body` is 20 where gem's is 22 — but not
the **keys**, because call sites depend on them:

```lua
React.createElement(ui.Text, { text = "Rebirth", role = "title" })
React.createElement(ui.Stack, { gap = "md", padding = "lg" })
```

### Why this had to change

v1 said tokens lived under each skin and the contract said nothing about them.
The consequence was that gem declared `textSizeXL … textSizeXS` and flat declared
`textSize` and `titleTextSize` and nothing else. `theme.textSizeRegular` was
simply `nil` on flat, so any call site reading it broke the moment you swapped
skins — and since no shared vocabulary existed, features typed literal numbers
instead. Ten of them at the top of `SettingsUI.ui.luau` alone, in no theme at all,
which is why that screen never matched the rest of the UI and never moved when
the theme did.

Swapping skins now changes typography as well as surfaces, which is what a skin
seam was supposed to mean.

`tools/check-skins` verifies both scales and `resolveVariant`, reading the
required key lists out of the contract so the lint and the runtime can't disagree.

### Sizes are reference pixels

Every number in a theme is authored against 1280×720 and scaled at render by
`ui.Surface`. See [responsive.md](responsive.md).

## Variants are semantic

`variant` names what a control **means**, not what colour it is:

```
primary | secondary | danger | success | warning | neutral | special
```

Each skin maps those onto its own palette through `theme.resolveVariant` — gem to
a gradient, flat to an accent colour.

`VariantKey` is an **open string**, not a closed union. Skins are installable, so
a skin must be able to offer a variant the framework never shipped; an unknown
name falls back to the skin's default rather than erroring. The seven legacy
colour names (`red`, `blue`, …) still resolve, so older call sites keep working.

The old scheme spelled a confirm button `"green"`. That made the seam a lie: a
skin could not reinterpret intent, and the closed union meant an installed skin
could not add a variant even though the skin *set* was open.

## Adding a component to the contract

1. Add the prop type and the `Components` key in `contract.luau`.
2. Implement it in gem (`src/shared/ui/<Name>.luau`) and flat.
3. Export it from `src/shared/ui/init.luau` via `semantic("<Name>")`.
4. Ship a `<Name>.story.luau` — `tools/check-ui` requires one.
5. Run `lune run tools/check-skins`.

Adding a key is a **minor** change: skins that predate it fall back to gem's
implementation per key (`skins.resolve`), degraded but not broken. Changing an
existing prop shape, or the token scales, is **major** — bump `VERSION`.
