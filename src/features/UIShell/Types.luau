--!strict
-- Shared type declarations for the UIShell feature. Imported by the
-- provider, the Frame wrapper, and the HideWhenFrameOpen wrapper so the
-- API stays consistent.

export type FrameId = string

export type HideDirection = "left" | "right" | "top" | "bottom"

export type FrameContextValue = {
	openFrameId: FrameId?,
	open: (id: FrameId) -> (),
	close: () -> (),
	toggle: (id: FrameId) -> (),
}

return {}
