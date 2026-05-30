-- Notes — persisted per-player text scratchpad. Surfaced as a HUD window
-- (sidebar entry "Notes") that opens a Window containing NotesUI.
--
-- See docs/game/Notes.md for the data flow + HUD wiring.

local Notes = {}

Notes.Constants = require(script.Constants)
Notes.UI = require(script.NotesUI)

-- The UIShell frame id used by the HUD. Mirrors Settings.FRAME_ID so the
-- HUD's sidebar entry and the `frameContents` map share the same key.
Notes.FRAME_ID = "Notes"

return Notes
