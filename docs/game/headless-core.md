# Headless feature cores

A feature's **core is presentation-agnostic**: state and behavior only. Views are
thin consumers that read state and call intent actions. Keeping this line clean is
what makes seams #3 (view swap) and #4 (presentation swap) possible — the same
core can be driven by a screen GUI, an in-world part, or a Cmdr command at once.

## The layers

| Layer | Realm | Owns | Examples |
| ----- | ----- | ---- | -------- |
| **Registry / store** | shared | content & schema | `Settings/Registry.luau` |
| **Service** | server | validation, persistence, packet handling | `SettingsService`, `NotesService` |
| **Controller** | client | the client-side API: read state + **intent actions** | `SettingsController.setToggle`, `NotesController.SetNote` |
| **Packets** | shared | the wire schema (ByteNet) | `Settings/Packets.luau` |
| **View / UI** | client / shared | read state, call actions, render | `SettingsView` + `SettingsUI`, `NotesView` + `NotesUI` |

## The rules

1. **Actions are intent, not UI events.** A Controller exposes
   `setToggle(id, value)` / `setNote(text)` — *what the user wants_, not
   `onButtonClick`. The view calls the intent; the core reflects/broadcasts the
   resulting state.

2. **Views are dumb.** A `*View` / `*UI` file may read state (via `useReplica` /
   a `useX()` hook) and call Controller intents. It must **not** contain:
   - networking — no `Packets.*`, no `ByteNet`, no `.send(` / `.listen(`
   - validation — clamping, membership checks, kind agreement live in the Service
   - persistence — no `PlayerDataService`, no `ProfileStore`

3. **The core never imports a view.** Dependencies point *from* the view *into*
   the core, never back.

## Enforcement

`lune run tools/check-views` scans every `*.ui.luau` and `*View*.luau` under
`src/features/` for the forbidden patterns above and exits non-zero on a hit. The
splitter doesn't typecheck Luau and Studio is the only runtime, so run this as the
cheap pre-Studio signal whenever you touch a presentation file.

## Why it pays off

Because the view only reads state and fires intents, a second presentation
(seam #4) is purely additive: a world part's `ProximityPrompt` calls the same
`setToggle` intent and reads the same `useX()` state, so the GUI and the world
part stay in sync through one source of truth with no shared code between them.
See [presentations.md](presentations.md).
