# Notes

Per-player text scratchpad. The player opens it from the HUD sidebar, types something, and Save persists the value to their profile via PlayerData (ProfileStore + Replica). The note survives across sessions and reads zero-latency from the client.

This is a thin feature — it exists mainly as the canonical example of "feature UI mounted as a HUD window with replica-backed state". The data path is identical to Settings; if you're adding a new HUD-mounted feature, copy this shape.

## What it does

- **Shared surface** (`Notes/init.luau`): exposes `Constants`, `UI` (the React component), and `FRAME_ID = "Notes"` — the UIShell id the HUD uses to address the Notes window.
- **Persistence**: a single `Note: ""` key on the player profile, registered via `src/features/Notes/PlayerData.luau`.
- **Networking**: one ByteNet packet, `SetNote { text }`, client → server, reliable.
- **UI**: `NotesUI.ui.luau` is a pure React component built on shared widgets (`ui.Text`, `ui.TextField`, `ui.Button`). It renders the *contents* of a window — title row, current-saved row, draft input, Save button. The HUD wraps it in `ui.Window`.
- **Container**: `NotesView.client.luau` subscribes via `utils.useReplica(PlayerDataController, "Note")` and wires `onSave` to `NotesController.SetNote`.

## Studio assets it expects

None. Everything is code.

## Packets it speaks

| Packet    | Direction       | Payload          | Notes                                                                  |
| --------- | --------------- | ---------------- | ---------------------------------------------------------------------- |
| `SetNote` | client → server | `{ text: string }` | Server clamps `text` to `Constants.MAX_LENGTH`, then writes via `PlayerDataService.SetValue({ "Note" }, text)`. The client doesn't apply locally — it waits for the replica diff. |

## HUD integration

The Notes window is mounted as a `frameContents` entry in the HUD's sidebar:

```lua
-- src/client/init.client.luau
local Notes = require(Features:WaitForChild("Notes"))
local NotesView = require(ClientFeatures:WaitForChild("Notes"):WaitForChild("NotesView"))

React.createElement(UIShowcase.HUD, {
    frameContents = {
        [Notes.FRAME_ID] = React.createElement(NotesView),
        -- ... other features
    },
})
```

The matching sidebar entry lives in `src/features/UIShowcase/HUD.ui.luau`'s `SIDEBAR_ENTRIES`:

```lua
{ id = "Notes", label = "Notes", icon = REBIRTH_ICON, titleVariant = "blue" },
```

Clicking the entry calls `frames.toggle("Notes")` which UIShell tweens in/out. The Window chrome (title bar, close button, scrollable body) is provided by `ui.Window` inside the HUD — `NotesUI` itself returns only the body contents.

## UI Labs

`src/features/Notes/NotesUI.story.luau` mounts NotesUI inside a `ui.Window` with local React state for "saved", so typing + clicking Save updates the `saved:` label without needing a live replica or any packet wiring. To verify the real persistence path, Play-test the game instead.

## Constants worth knowing

- `Constants.MAX_LENGTH = 140` — clamps both the client-side draft and the server-side packet payload. Bump in `src/features/Notes/Constants.luau` if you want a longer note.
- `Notes.FRAME_ID = "Notes"` — UIShell frame id used by the HUD's Notes sidebar entry.

## Linking from another UI

```lua
local UIShell = require(ReplicatedStorage.Features.UIShell)
local Notes = require(ReplicatedStorage.Features.Notes)

local frames = UIShell.useFrame()
frames.open(Notes.FRAME_ID)
```

## Adding writable fields beyond a single string

If you need more than one field (e.g. a list of pinned notes, or note + tags), follow this shape:

1. Bump `PlayerData.luau` to register a richer template (`PlayerData.registerTemplate("Note", { text = "", pinned = false })` etc.).
2. Extend `Packets.luau` with the new packet (or extend the `SetNote` struct).
3. Update `NotesService` to clamp and write through `PlayerDataService.SetValue`.
4. Update `NotesController` to send the new packet.
5. Update `NotesUI` props + the `NotesView` container's `useReplica` call.

The "client only sends packets; server writes through PlayerDataService; replica diff drives UI" loop stays the same — only the schema widens.
