# UIShell

The frame system: at most one frame open at a time, plus a wrapper that slides
HUD content off-screen while one is. It has no visual chrome of its own — pair
`<Frame>` with `ui.Window` for the looks.

## Shape

- `<FrameProvider>` — mounted once near the root by `client/init.client.luau`.
  Features never add their own.
- `useFrame()` → the current open id and `open` / `close` / `toggle`. Errors if
  called outside the provider.
- `<Frame id>` — renders nothing until it is the open id, then mounts its children
  with a UIScale enter tween. Closing runs the exit tween, then unmounts.
- `<HideWhenFrameOpen direction>` — wraps HUD or sidebar content and slides it
  past the given edge whenever any frame is open.

## Decisions

- **The single-frame invariant is emergent, not enforced.** Everyone keys off one
  open id; there is no frame list and no close-the-others bookkeeping. Supporting
  two open frames means rethinking this, not patching it.
- **`Frame` renders no chrome and never modifies its children's props.** The
  close button is wired by the consumer (`onClose = frames.close`). A shell that
  reached into children to inject handlers would make every window's markup a
  guess about what the shell had already done.
- **Enter and exit tweens are deliberately asymmetric** — a slow elastic landing
  in, a very fast flat dismiss out. A window should arrive with weight and leave
  instantly; matching the two makes closing feel sluggish.
- **State is client-only and ephemeral.** What is open is neither replicated nor
  persisted.

## Gotchas

No Studio assets — mounts inside the `BoilRoot` ScreenGui created in
`client/init.client.luau`. Tween and offset defaults live in `Constants.luau`,
and every one of them is overridable per-`Frame`.

## See also

[HUD.md](HUD.md) · [presentations.md](presentations.md)
