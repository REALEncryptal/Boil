# Music

Plays a single looping background track on the client while the persisted `music.enabled` setting is true. Demonstrates the Settings feature's auto-discovery convention end-to-end — registry → persistence → reactive playback.

## What it does

- **Registers** an "Audio" category and a `music.enabled` toggle setting (default on) via the Settings feature. The registration lives in `Settings.luau` and is picked up by the Settings feature's auto-discovery loop on both realms.
- **Plays** `Shared.audio.Music.lobby` at volume `0.2` via `audio.playMusic` whenever the setting is on. When the setting flips off, calls `audio.stopMusic`.
- **Reacts** to `PlayerDataController.DataChanged`, then re-reads the current value via `SettingsController.get`. Idempotent `playMusic` / `stopMusic` calls make redundant fires harmless.

## Studio assets it expects

None. The Sound is created on the fly by `audio.playMusic` and parented to `SoundService`.

## Packets it speaks

None directly. Toggle writes go through the Settings feature's `SetToggle` packet → `PlayerDataService.SetValue` → Replica diff → `MusicController` reacts.

## Constants worth knowing

| Constant | Value | Notes |
| -------- | ----- | ----- |
| `DEFAULT_TRACK` | `"lobby"` | Must be a key in `Shared.audio.Music`. Swap to any other entry to change the loop. |
| `VOLUME` | `0.2` | Music mix volume. The audio module's `DEFAULT_MUSIC_VOLUME` matches; passed explicitly so a change here is local to Music. |
| `SETTING_ID` | `"music.enabled"` | The persisted Settings id. Read elsewhere via `SettingsController.get(Music.Constants.SETTING_ID)`. |

## Changing the track

Edit `src/features/Music/Constants.luau` and set `DEFAULT_TRACK` to another key in `src/shared/audio/init.luau`'s `Audio.Music` table (e.g. `"phonk"`, `"xmas"`). No other code changes needed.

If you want the track to vary per-player or per-context (lobby vs. arena), promote `DEFAULT_TRACK` into something runtime-driven and add a `setTrack(name)` helper on the controller that calls `audio.playMusic(name, Constants.VOLUME)` when music is enabled.

## Adding more audio settings (SFX, ambience, voice)

Each new toggle follows the same pattern:

1. Add a constant for the setting id in `Constants.luau` (e.g. `SFX_SETTING_ID = "sfx.enabled"`).
2. Register it in `Settings.luau` next to the music toggle (same category, bump `order`).
3. In `MusicController` (or a new controller per concern), gate the relevant `audio.playUI` / `audio.playSoundId` calls on `SettingsController.get(...)`.

For SFX specifically, the cleanest pattern is to wrap `audio.playUI` with a "are SFX enabled?" check at the call site, since SFX fire from many places. A `Sound.lua` shared helper that consults `SettingsController.get` before forwarding to `audio.playUI` keeps the gate in one spot.
