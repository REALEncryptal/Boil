-- Settings' slice of the PlayerData profile template. Discovered by
-- src/features/PlayerData/init.luau at load time; see docs/game/PlayerData.md.
--
-- Persisting setting values lives here (not in PlayerData/Constants) so the
-- PlayerData feature stays agnostic to its consumers.

return function(PlayerData)
	local Constants = require(script.Parent.Constants)
	PlayerData.registerTemplate(Constants.PROFILE_KEY, {})
end
