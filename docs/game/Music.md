# Music

Plays a single looping background track on the client while the persisted
`music.enabled` setting is true. It exists mostly as a worked example of the
registry conventions end to end — registration → persistence → reactive
playback — in about forty lines of feature code.

## Shape

- `Settings.luau` registers an "Audio" category and a `music.enabled` toggle,
  default on.
- `MusicController` reacts to `PlayerDataController.DataChanged`, re-reads the
  value through `SettingsController.get`, and calls `audio.playMusic` or
  `audio.stopMusic`.
- Speaks no packets of its own — a toggle travels Settings' `SetToggle` →
  `SetValue` → replica diff → this controller.

## Decisions

- **It re-reads the setting instead of diffing the change payload.** `playMusic`
  and `stopMusic` are idempotent, so a redundant fire is harmless, and the
  controller stays a two-line reaction rather than a diff parser.
- **`VOLUME` is passed explicitly** even though it matches the audio module's
  default, so changing the music mix stays local to this feature.

## Gotchas

No Studio assets — the Sound is created by `audio.playMusic` and parented to
`SoundService`. `DEFAULT_TRACK` must be a key in the `Music` table of
`src/shared/audio`.

## See also

[Settings.md](Settings.md)
