# Cmdr

Admin console bootstrap. It registers Cmdr's default commands and gates every
command behind a username allowlist; features add their own commands by dropping
a `*Command.server.luau`, which the server entry script discovers on its own.

## Shape

- `CmdrService.server.luau` — registers the default commands, then installs a
  `BeforeRun` hook. `Priority = 2`: after PlayerData, before gameplay services.
- `Constants.luau` — `AllowedUsernames` (who may run anything) and
  `ActivationKeys` (what opens the console).
- `CmdrController.client.luau` — sets the activation keys. It must
  `WaitForChild("CmdrClient")`, because the server side inserts that module into
  `ReplicatedStorage` at runtime.
- A command is a presentation like any other: it self-registers and calls a core
  intent, exactly as a screen or a world part does.

## Decisions

- **The gate is a server-side `BeforeRun` hook, not a client-side check.** Cmdr
  runs the hook before dispatch, and returning a string both blocks execution and
  surfaces the reason to the user. Hiding the console on the client instead would
  leave every command callable by anyone.
- **Commands live in the feature they act on,** never in this folder. Cmdr must
  not name a feature; features name Cmdr.
- **Gating is by username, which is the easy-to-edit option, not the robust one.**
  A username can change. For a live game, switch `AllowedUsernames` to UserIds.

## Gotchas

**Edit `Constants.AllowedUsernames` before shipping** — the bundled list is not
yours.

## See also

[presentations.md](presentations.md) · [headless-core.md](headless-core.md)
