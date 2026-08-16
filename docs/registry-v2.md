# Registry v2 — one repo that holds the packages

Status: **plan**. Supersedes [registry.md](registry.md) when it ships.

Two changes, one motivating the other:

1. **The index stops being a list of links and becomes the packages.** One
   private git repo holds every package's code, versioned by tag.
2. **The CLI gets a front door.** `boil` on its own opens a hub; every verb it
   routes to still works as a command.

## Why the pointer model has to go

Today an index entry is a *listing* — a manifest naming another repo and a tag.
Publishing therefore means: create a GitHub repo by hand, push the folder there,
tag it, then push a listing into the index. Four consequences, all of them felt:

| Symptom | Cause |
| ------- | ----- |
| "Create the repository first, then re-run publish." | The package repo must exist before the CLI will do anything. |
| A publish can half-succeed — code pushed, index not | Two pushes to two repos, no transaction (`publish.js` even has an error for it). |
| An install breaks months later | The package repo was renamed, made private, or deleted. The index still points at it. |
| Sharing a private package means granting access N times | One grant per package repo, plus the index. |

One repo containing the content removes all four: nothing to create in advance,
one push, nothing to rot, one access grant.

## Layout

```
boil-index/                        # one private repo
  registry.toml                    # format = 2, display name
  packages/
    encryptal/
      shop/
        boil.toml                  # the manifest IS the listing now
        ShopService.server.luau
        ShopView.ui.luau
      neon/
        boil.toml                  # kind = "skin"
        init.luau
```

Content lives once, at HEAD, always the newest release. **Versions are tags:**

```
encryptal/shop@1.0.0
encryptal/shop@1.1.0
encryptal/shop@1.2.0
```

Older versions resolve out of the clone you already have — `git show
encryptal/shop@1.1.0:packages/encryptal/shop/` — so no version costs a directory
and `update` can diff two releases without a network round trip.

Tag names with a slash and an `@` are legal refs; the only rule git enforces is
that no tag may be a directory prefix of another, and `owner/name@version` never
is (the directory part is always `refs/tags/<owner>/`).

Two notes on the clone:

- `refresh` becomes `git fetch --tags --prune`, and happens **automatically when
  the cache is stale** (same pattern as the update toast — a timestamp in
  `~/.boil/`), not only when someone remembers to run it.
- Clone with `--filter=blob:none` rather than `--depth 1`. A blobless partial
  clone keeps every tag reachable while fetching file contents lazily, which is
  what makes "check out any old version" cheap on a repo that only grows.

## What this deletes

- **`repository` in `boil.toml` stops being required.** It was the publish
  target; now it's optional metadata pointing at where the source is developed.
- **The listing format** (`packages/<name>.toml` with a `[[version]]` array).
  The package's own `boil.toml` plus the tag list replaces it.
- **`pushPackage` / `pushIndex` as separate steps**, and the "the package was
  pushed, but the index was not updated" failure with them.

## The new publish

```
boil publish
  ├─ pick a folder                     (already shipped)
  ├─ gate + lints                      (unchanged — this is the valuable part)
  ├─ version check: tag already exists? offer patch / minor / major
  ├─ copy into the registry clone at packages/<owner>/<name>/
  └─ commit → tag owner/name@version → push        one repo, one push
```

Concurrent publishes race on the push, exactly as they do today. Handle it
properly this time: on rejection, `git pull --rebase` and retry, up to three
times, before reporting a genuine conflict.

## The new install

```
boil add encryptal/shop[@1.2.0]
  ├─ refresh if the clone is stale
  ├─ resolve: newest tag satisfying the range and the compat rules
  ├─ materialise packages/encryptal/shop/ at that tag → src/features/Shop/
  ├─ merge [wally] deps, install [dependencies], run the splitter
  └─ lockfile: registry + tag + commit SHA + fingerprint
```

Recording the **commit SHA** alongside the tag is new, and worth it: a moved tag
can no longer change what `boil install` restores in a fresh clone.

## The CLI's front door

`boil` with no arguments currently prints a welcome or a usage screen. It should
open a hub instead:

```
  Boil — my-game

  ❯ Browse packages          42 available
    Installed                6 packages, 1 outdated
    Publish from this game   10 folders
    Registry                 company (private)
    Dev                      splitter + rojo serve

  ↑/↓ move · enter select · q quit
```

Every row routes into the same function a script would call, which is the
existing rule for `explore` and keeps the hub from becoming the only way to do
anything. `boil --version`, `boil help`, and every verb keep working untouched,
and a non-interactive shell still gets the usage text.

### Principles for the verbs

1. **Every interactive action has a scriptable twin.** Already true; stays true.
2. **Say what will happen, then ask.** `publish` does this. `add` and `update`
   should too, when they're about to touch more than one folder.
3. **Errors name the fix, not the field.** "no `repository` in boil.toml" became
   the exact line to paste; the rest of the failures deserve the same pass.
4. **Never require a step outside the CLI.** The v2 layout removes the last one
   ("go create a repo on GitHub first").
5. **Freshness is the CLI's job.** Auto-refresh a stale index instead of making
   people remember `boil refresh`.

### Verb changes

| Today | v2 | Why |
| ----- | -- | --- |
| `explore` | hub → Browse | Same code, reachable without knowing the word. |
| `refresh` | automatic + still a verb | Staleness is a machine's problem. |
| `search`, `info` | unchanged | The scriptable twins of Browse. |
| `setup` | creates *the* registry repo, or joins one by URL | One repo now, so setup means one thing. |
| `publish <path>` | `publish [path]` | Shipped. |
| `add`/`remove`/`update`/`outdated`/`list`/`install` | unchanged | npm-shaped and already familiar. |
| `new`, `dev`, `upgrade`, `doctor`, `registry` | unchanged | |

## Migration

A one-shot `boil migrate <old-index-url>`:

1. Read the old listings.
2. For each package, clone its repo at each released tag.
3. Write the contents into `packages/<owner>/<name>/`, commit, and tag
   `owner/name@version` — oldest first, so history reads in release order.
4. Push, and print what moved and what couldn't (a repo that's gone).

`registry.toml` carries `format = 2`, so the CLI can recognise an unmigrated
index and say so instead of finding no packages.

## Phasing

| Phase | Contains | Ships as |
| ----- | -------- | -------- |
| 1 | v2 resolve + install + publish, `registry.toml`, lockfile SHA | 0.5.0 |
| 2 | `boil migrate`, old-format detection message | 0.5.0 |
| 3 | The hub, auto-refresh, the error-message pass | 0.6.0 |

Phases 1 and 2 land together — migration is useless without the format, and the
format is hostile without migration.

## Known trade-offs

- **The repo only grows.** Luau is text and blobless clones are lazy, so this is
  a decade-scale problem, not a launch problem.
- **Access is all-or-nothing.** Read on the registry is read on every package in
  it. That's the intended shape for a team's private registry; a package that
  needs its own permissions needs its own registry.
- **`github:owner/repo` installs stay.** Installing straight from a git URL is
  unaffected and remains the escape hatch for a package that shouldn't live in a
  shared registry at all.
