# Boil

Roblox boilerplate: Rojo + Wally + React (jsdotlua), Feature-Sliced Design, managed by Rokit. Features are colocated under `src/features/<Name>/` and a Lune splitter (`tools/split.luau`) routes files to the right Roblox service based on `.server.luau` / `.client.luau` / `.ui.luau` suffixes.

## Read before working on this project

- `docs/architecture.md` — how the split, entry scripts, and load ordering work.
- `docs/adding-a-feature.md` — the workflow for adding a feature or shared utility.
- `docs/reference.md` — filename rules, loader API, sync map.
- `docs/registry.md` — the package format, the index, and the `boil` CLI (install / publish / explore). The CLI is an npm package living in `cli/`, not a Lune script.
- `docs/getting-started.md` — dev loop commands.
- `docs/game/` — the five seams and per-feature docs. Start at `docs/game/index.md`.

Consult the relevant doc first; don't infer structure from the tree alone.

## Working with this codebase

**The Studio MCP, when connected, lets you drive Studio directly.** Some devs run the Roblox Studio MCP (e.g. `@chrrxs/robloxstudio-mcp`), which gives you tools to inspect the live data model, run Luau, Play-test, and profile. When those tools are available to you, use them — the notes below flag what changes. When they aren't, you're code-only: the user is your eyes and hands in Studio. **Confirm which Studio instance is the Boil place before touching anything** — a dev machine commonly has a real game open alongside it, and that game may have Boil installed at an older version.

**Rojo only syncs code; Studio assets are the user's responsibility.** Models, Workspace instances, pre-built StarterGui, sounds, animations, attachments — anything that isn't a script — must be created by the user in Studio. When a feature needs an asset (a part named `SpawnPoint`, a Tool in ServerStorage, a sound at `rbxassetid://…`, a CollectionService tag), tell the user exactly what to create, where it goes, and any required name / tag / property. Don't try to fabricate assets through code workarounds. *If the Studio MCP is connected,* you can inspect the live tree yourself (find instances, read properties) instead of asking the user to describe it, and you can insert Creator Store models / import `.rbxm` — but bespoke game assets (custom models, animations, uploaded sounds) are still the user's to create.

**Don't use `rojo build` for error checking.** Building an `.rbxlx` does not validate Lua/Luau — syntax errors and type mistakes pass through silently. `tools/check-syntax` is the closest thing to a compile step — it runs the same Luau compiler Roblox does. Run the whole set before handing work back:

```bash
lune run tools/split && lune run tools/check-syntax && lune run tools/check-requires && lune run tools/check-framework-boundary && lune run tools/check-views && lune run tools/check-skins && lune run tools/check-ui
```

None of these type-check; that needs `luau-analyze` against a generated sourcemap, which isn't installed here.

**A skin implementation must never require `SkinProvider`** — it *is* a skin. Doing so closes the cycle `skins → gem → <file> → SkinProvider → skins`, which surfaces in Studio as a bare "C stack overflow" blaming an unrelated file. Read `theme` directly instead. Only the semantic wrappers in `init.luau` and the unskinned layout primitives (`Stack`/`Row`/`Grid`/`Slot`, which no skin lists) may call `useSkin`. `check-requires` enforces it.

If the Studio MCP is connected you can also run Luau and Play-test directly to validate; otherwise rely on the user reporting behaviour from an in-Studio Play test.

**Running the game depends on the Studio MCP.** *Without it,* you can't Play-test — only the user can. When they report an error, take the message at face value; if it's thin (no stack, no values, ambiguous about which branch fired), add a few `print` statements at the points you suspect, ask them to repro and paste the output, and **remove the prints once the bug is understood.** *With the Studio MCP connected,* you can drive Studio yourself: run Luau on the server or a specific client, start/stop solo and multiplayer Play-tests, read the output log while it runs, capture the Script Profiler, and take viewport screenshots. Use it to reproduce and verify your own work before handing it back. Either way, don't leave debug scaffolding in committed code, and the user still owns final sign-off on anything security- or replication-sensitive.

**Roblox error line numbers reference `build/`, not `src/`.** The splitter copies files and strips `.server` / `.client` / `.ui` suffixes — so an error at `ServerScriptService.Features.Foo.FooService:42` maps back to `src/features/Foo/FooService.server.luau:42`. Translate before reading the source. `build/shared/<Feature>/Manifest.luau` is **generated** from that feature's `boil.toml` — never edit it.

**Avoid git worktrees.** Rojo's sync model is fragile across worktrees (lock files, duplicate `build/`, sourcemap drift, the plugin holding stale paths). Work on the main checkout; don't reach for `git worktree add` to parallelize.

## Composition — the lego rule

**Features extend each other through registration, not by editing each other's source.** Adding a new feature must not require touching another feature's files. If feature B needs feature A's data, schema, lifecycle, or UI surface, the dependency flows *from B into A* via a registration API A exposes — never by hand-editing A's constants/service/UI to know about B. A's source stays agnostic to every consumer; B's code is the one place that mentions B.

**Use `Boil.Registry.define` — never hand-roll a discovery loop.** A shared feature that accepts contributions declares its seam in a line:

```lua
Cash.currencies = Boil.Registry.define("Cash", script)
```

and any other feature contributes by dropping a sibling `Cash.luau` returning `function(cash) cash.add({ id = "gems", … }) end`. Three registries use this today: `PlayerData` (profile template slices), `Settings` (categories and toggles), `Nav` (HUD sidebar entries). If you find yourself writing a fourth walk-require-pcall-warn loop, you're re-solving a solved problem. See `docs/game/registries.md`.

**Every feature declares its dependencies in `boil.toml`.** `[dependencies]` is hard (the feature requires that folder); `[soft-dependencies]` is ordering only. The splitter compiles these into `Manifest.luau`, and `FeatureLoader` topologically sorts features at boot and warns by name about anything declared and missing. `Priority` still exists but is now only a tiebreaker *within* one feature's own services — it is not how cross-feature ordering is expressed.

**When you discover an existing violation, prefer fixing the seam** — add the registration API to the shared feature, move the schema/defaults back to the owning feature — over piling on another hardcoded entry. Don't extend a bad pattern just because it's already there.

## UI

**Name roles and steps, never numbers.** Type and spacing are part of the skin contract:

```lua
React.createElement(ui.Text,  { text = "Rebirth", role = "title" })
React.createElement(ui.Stack, { gap = "md", padding = "lg" })
```

`theme.type` is `display | title | heading | body | label | caption`. `theme.space` is `xs | sm | md | lg | xl | xxl`. A literal `textSize = 32` pins one skin's number into a call site and fails `check-ui`. This is the fix for the old state, where ten magic numbers at the top of a feature's UI file existed in no theme, so that screen never matched the rest of the UI and never moved when the theme did.

**Every size is a REFERENCE pixel (1280×720), scaled at render by `ui.Surface`.** Wrap a feature UI in a `ui.Surface` (or a `ui.Window`, which is one) and it is correct on a phone and a 4K monitor with no breakpoint and no second layout. Position with `fromScale` + `anchorPoint`; size in reference offset. Never nest two Surfaces — the scale squares. Reach for `ui.useDevice()` only when a layout must *change* rather than shrink, and say why in a comment. See `docs/game/responsive.md`. **Before shipping any new screen, open its story and flip `device` to `phone`.**

**Variants are semantic, not colours.** `primary | secondary | danger | success | warning | neutral | special`. The skin maps them to a palette. Legacy colour names still resolve, but don't write new ones.

**Use the prebuilt shared UI components first; only go custom when nothing fits.** Before writing any `React.createElement("TextLabel")`, `"ImageButton"`, etc., check `src/shared/ui/` (`Button`, `IconButton`, `Panel`, `Window`, `Badge`, `Checkbox`, `ProgressBar`, `ScrollList`, `Text`, `TextField`, `Surface`, `Stack`/`Row`/`Grid`/`Slot`, hover/tween hooks, theme, asset registry). `check-ui` enforces this. When something is genuinely bespoke, put `-- boil-allow-raw: <reason>` above it — the reason is required, so the exception is a decision on the record. Prefer adding a missing primitive to `src/shared/ui/` over inlining a bespoke block in a feature.

**Know the five seams; render through them.** (1) **Skin** — how a primitive *looks*. Compose `ui.*` and let the skin draw; never hardcode a skin's look at a call site or reach into `skins/gem` directly. (2) **Layout** — how a screen is *arranged*. Use the transparent `ui.Stack`/`Row`/`Grid`/`Slot` primitives over hand-rolled `UIListLayout`. (3) **View** — how a feature *presents*; views are dumb. (4) **Presentation** — *whether it's a screen GUI at all* vs a world part or command. (5) **Responsive** — how it fits every device. Docs: `docs/game/skin-contract.md`, `layout-surfaces.md`, `headless-core.md`, `presentations.md`, `responsive.md` (indexed in `docs/game/index.md`).

**Account for stroke thickness when padding stroked surfaces.** Strokes consume visual space at the edge of a parent — a child placed at the mathematically-correct `padding` distance visually crowds the stroke and looks wrong even though the numbers are "right." On any padding side that sits against a stroked edge, use `space.<step> + strokeThickness` instead of the bare step. Compute the sum at render time so a live theme edit in the UI Labs Theme story propagates. See `src/shared/ui/Window.luau` for the canonical pattern.

**Center new feature UIs by default; off-center is reserved for large content surfaces.** Anchor a popup, prompt, settings panel, HUD widget, notification or small window at screen center (`AnchorPoint = Vector2.new(0.5, 0.5)`, `Position = UDim2.fromScale(0.5, 0.5)`) and let its content stack centered inside. Off-center, edge-anchored layouts are for *large* surfaces meant to dominate the view: full inventories, shops, leaderboards, codex grids. Persistent chrome (the HUD sidebar, corner widget clusters) is its own category and isn't covered by this rule. If unsure, default to centered.

**Ship a UI Labs story with every UI you make.** Any new React component — a shared primitive or a feature-level UI — gets a sibling `<Component>.story.luau`. Visuals are iterated through UI Labs, so a UI without a story is incomplete; `check-ui` enforces it. When one story genuinely exercises several siblings, declare `-- covers: A, B` inside it rather than writing near-duplicate stories. Stories require `ReplicatedStorage.DevPackages.UILabs` (UI Labs is a dev dependency and is stripped from production builds by `split --no-stories`).

**Features register their presentations; the root client file names no content feature.** A feature shows up for the player through *presentations* — a screen GUI (`*Presentation.client.luau` → `HUD.setScreen` / `UIRegistry.registerRoot`), an in-world part (`*WorldInteraction.client.luau`, bound to a CollectionService tag), or a Cmdr command (`*Command.server.luau`). `src/client/init.client.luau` and `src/server/init.server.luau` auto-discover these, so **adding a feature or a presentation is zero edits to either entry file**. Presentations are peers: they never reference each other and stay in sync by routing through the feature's one core intent. Gate surfaces per-feature via a `Presentations` table in `Constants.luau`. See `docs/game/presentations.md`.

**Keep feature cores headless; keep views dumb.** A feature's core (Registry/store, Service, Controller, Packets) is presentation-agnostic — state and behavior only. Controller methods are *intent actions* (`setToggle(id, value)`), never UI-event handlers (`onButtonClick`). A `*View` / `*UI` file may read state (via `useReplica` / a `useX()` hook) and call those intents — and nothing else. No networking, validation, or persistence inside a view; those live in the Controller/Service. `check-views` enforces it. This is what lets a feature grow a second presentation with zero shared code — see `docs/game/headless-core.md`.

## Framework boundary

**The framework ships empty; framework code never names a feature.** Boil is two layers — the *framework* (`src/shared/`, `src/client/`, `src/server/`, `tools/`) and the *features* (`src/features/<Name>/`, every one removable). The framework distributes with zero features and must boot with `src/features/` empty, so the dependency arrow points one way. Features consume the framework through the single public surface `require(ReplicatedStorage.Shared.Boil)` (`Boil.ui`, `Boil.Registry`, `Boil.FeatureLoader`, `Boil.UIRegistry`, `Boil.useReplica`, `Boil.audio`) — not deep paths. Framework code touching the `Features` container *generically* (iterating, `GetChildren`) is fine; reaching a *named* child (`Features.Settings`) is a violation — invert the seam so the feature registers into the framework instead. A feature naming *itself* is fine. Enforced by `check-framework-boundary`. See `docs/game/framework-boundary.md`.

**Features and skins are distributable packages; keep them installable.** A feature (`src/features/<Name>/`) and a skin (`src/skins/<Name>/`) are each one self-describing folder with a `boil.toml`, published to a git-backed index and installed by the `boil` CLI (`npm i -g @encryptal/boil`; source in `cli/`) — see `docs/registry.md`. Three consequences: **(1)** a feature folder must stay *flat* — the splitter only reads its top level, so a `.luau` in a subfolder silently never builds; **(2)** installing content must never require editing framework source — skins are discovered from `ReplicatedStorage.Skins`, so don't reintroduce a hardcoded skin list or a closed `SkinName` union; **(3)** every feature needs a `boil.toml`, or it isn't publishable and the loader can't order it. A new component key goes in `contract.luau` (bump `contract.VERSION` on a breaking prop or token change) and every skin picks it up or falls back to gem. Run `lune run tools/check-skins` after touching the contract or a skin, and `boil publish <path> --dry-run` to see whether a folder is publishable.

**Bump `cli/package.json` in the same commit as any change under `cli/`.** The CLI ships to npm as `@encryptal/boil`, and **a published version can never be replaced** — so a fix reaches users as a new version or not at all. Patch for fixes, minor for a new command or flag. First check what's actually out there: `npm view @encryptal/boil version`. If the local version is *ahead* of the published one it's unreleased, so the change rides in it and you bump nothing; if they match, bump. Publishing itself is the user's call (`cd cli && npm publish`) — never run it unasked.

## Style

**Flatten control flow; avoid nesting when you can.** Prefer early returns, guard clauses, and `continue` over pyramids of `if`/`else`. Handle the unhappy path first and bail (`if not player then return end`), then let the happy path live unindented at the bottom of the function. Same for loops — `if not match then continue end` beats wrapping the body in another `if`. Aim to keep working code at one or two levels of indentation; if you're at three-plus, that's a signal to invert a condition, extract a helper, or split the function. This applies to Luau, React render bodies (extract a sub-component instead of nesting ternaries), and Lune scripts alike.

**Commit confirmed wins immediately, then ask about pushing.** This project overrides the default "wait for explicit ask before committing." When a bug is fixed or a feature is added and the user confirms it works — or clearly implies it ("perfect", "yep", "nice", moving straight to the next task) — create a commit right then for that unit of work, then ask whether to push. One working change = one commit; don't let unrelated wins pile up under a single message. Still no committing speculatively (before any confirmation) and no pushing without asking.

## Documentation discipline

**A feature doc is a decision record, not a manual.** Its job is to stop a future session from quietly unpicking a choice that was made on purpose. The code is the reference for *what* the API is — the doc exists for *why* it is shaped that way. When you add or significantly change a feature, write/update `docs/game/<Feature>.md` to this template and **keep it under 60 lines**:

````markdown
# <Feature>

One paragraph — what it does and why it exists. Two or three sentences.

## Shape
3–6 bullets: the parts and how they connect. Name modules, not signatures.

## Decisions
- **<the choice>** — why it was made, and what breaks if someone reverts it.

## Gotchas
Studio assets it needs, or a value that will surprise someone. Omit if none.
````

Do **not** put in a feature doc:

- **An API reference.** No signatures, no prop tables, no field tables. It duplicates source that will move without it, and a confidently wrong doc is worse than no doc. Name the module and stop.
- **A how-to.** "Adding a …" belongs in `docs/adding-a-feature.md` once, not once per feature.
- **A file table.** The folder is the file list.
- **A constants table.** Link `Constants.luau`; call out only a value someone would otherwise get wrong.
- **Speculation.** No "if you later want to…". A doc describes what exists, not what someone might build.
- **More than two code blocks, or one longer than 8 lines.** If the snippet needs more than that, it is a how-to and belongs elsewhere.

Write the `Decisions` section for the reader who is about to undo something: name the choice, the reason, and the consequence. "Rejected X because Y" is worth more than three paragraphs describing the happy path.

The cross-cutting docs (`skin-contract.md`, `framework-boundary.md`, `responsive.md`, `registries.md`, …) are the exception — they are the long-form design guides and carry no budget.

- Keep `docs/game/` organized: one file per feature, indexed in `docs/game/index.md`.
- If this `CLAUDE.md` or anything under `docs/` drifts out of sync with the code, fix the doc as part of the same change. A stale instruction is worse than no instruction — if you notice drift while working on something else, update it.
