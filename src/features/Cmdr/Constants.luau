-- Admin config. Edit AllowedUsernames to grant someone Cmdr access.
--
-- Username-based gating is easy to edit but can be bypassed if Roblox lets
-- someone change their name (rare). For a live game, prefer UserIds.

return {
	-- Exact Roblox usernames allowed to run any Cmdr command.
	AllowedUsernames = {
		"Encryptal",
	},

	-- Keys that open the Cmdr console on the client.
	ActivationKeys = { Enum.KeyCode.F2 },
}
