-- Settings' entry in the HUD navigation, discovered by the HUD feature's Nav
-- registry at load time.
--
-- This file is the whole wiring: Settings names HUD, HUD never names Settings.
-- Deleting src/features/HUD/ leaves this file inert rather than broken, and
-- deleting Settings takes its sidebar button with it.
--
-- Shared realm (no .client/.server suffix) so both realms see the same entry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Features.Settings.Constants)

return function(nav)
	nav.add({
		id = Constants.FRAME_ID,
		label = "Settings",
		icon = Constants.NAV_ICON,
		-- High order keeps Settings at the bottom of the sidebar, below whatever
		-- gameplay features a game installs.
		order = 900,
		variant = "neutral",
	})
end
