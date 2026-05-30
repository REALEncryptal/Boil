-- PickupFX — flying-icon pop FX.
--
-- Icons pop on screen at a `from` point, then sail along a randomized bezier
-- curve to a `to` point (Vector2 or registered DestinationId). Each spawn
-- in a burst is staggered and uses a different curve so they don't move as
-- a clump.
--
-- The Overlay component is already mounted by src/client/init.client.luau;
-- features just import this module to spawn icons or subscribe to arrivals.
--
-- See docs/game/PickupFX.md for the full API.

local PickupFX = {}

PickupFX.Constants = require(script.Constants)
PickupFX.Types = require(script.Types)
PickupFX.Manager = require(script.Manager)
PickupFX.Overlay = require(script.Overlay)

local hooks = require(script.hooks)
PickupFX.usePickupSpawn = hooks.usePickupSpawn
PickupFX.useDestination = hooks.useDestination
PickupFX.useArrival = hooks.useArrival

return PickupFX
