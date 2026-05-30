-- Shared packet definitions for the Settings feature. Both server
-- (SettingsService) and client (SettingsController) import this module.
--
-- One packet per setting kind. The server uses the Registry to validate that
-- the incoming id matches a registered setting of the right kind before
-- writing to the player's profile. New kinds (slider, dropdown, …) get their
-- own packet — we don't smuggle a generic `value: any` through ByteNet because
-- ByteNet's schema-driven (de)serialization is what gives us the safety.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ByteNet = require(ReplicatedStorage.Packages.ByteNet)

return ByteNet.defineNamespace("Settings", function()
	return {
		-- Client → Server: persist a toggle setting on the local player's profile.
		SetToggle = ByteNet.definePacket({
			value = ByteNet.struct({
				id = ByteNet.string,
				value = ByteNet.bool,
			}),
			reliabilityType = "reliable",
		}),
	}
end)
