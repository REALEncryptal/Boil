--!strict
-- Shared type declarations for PickupFX. Manager, Overlay, and the React
-- hooks all import from here so the public surface stays in sync.

export type DestinationId = string

export type DestinationGetter = () -> Vector2?

-- What callers pass to Manager.spawn(). Only `icon` and `from` are required;
-- `to` defaults to `from` (the icon just pops in place and fades).
export type PickupOptions = {
	icon: string,
	from: Vector2,
	to: (Vector2 | DestinationId)?,
	count: number?,
	size: Vector2?,
	onArrival: (() -> ())?,
}

-- Internal: one queued/animating icon. The Overlay walks Manager.active each
-- frame and reads these fields to drive the per-icon animation phases.
export type ActiveIcon = {
	id: number,
	icon: string,
	from: Vector2,
	to: Vector2 | DestinationId,
	size: Vector2,
	spawnTime: number,
	delay: number,
	popDuration: number,
	travelDuration: number,
	fadeDuration: number,
	curveOffset: number,
	onArrival: (() -> ())?,
	arrived: boolean,
}

return {}
