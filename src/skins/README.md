# src/skins/

Installed skins live here — one folder per skin, each with an `init.luau`
returning a `contract.Skin` and a `boil.toml` describing the package.

```
src/skins/
  Neon/
    boil.toml
    init.luau        -- returns { name = "neon", theme = …, components = { … } }
    theme.luau
    Button.luau
    Window.luau
    …
```

This directory syncs **directly** to `ReplicatedStorage.Skins` — skins are pure
shared-realm code, so the splitter isn't involved (unlike `src/features/`, nested
folders are fine here). The skin registry
(`src/shared/ui/skins/init.luau`) discovers every ModuleScript child lazily on
first use, so an installed skin shows up in the `SkinProvider` UI Labs story
without the client entry script ever running.

Install one with:

```bash
lune run tools/boil -- add <owner>/<skin>
```

Or author your own — start from `src/shared/ui/skins/flat/`, the smallest
complete implementation of the contract, and run `lune run tools/check-skins` to
see which keys you still owe. Skins reach the framework only through
`require(ReplicatedStorage.Shared.Boil)`, same rule as features
(`tools/check-framework-boundary` enforces it).

See [docs/registry.md](../../docs/registry.md) and
[docs/game/skin-contract.md](../../docs/game/skin-contract.md).

*(Markdown files aren't synced by Rojo, so this file keeps the directory in git
without becoming an instance.)*
