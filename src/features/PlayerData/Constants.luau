-- Shared config for PlayerData. Read from server (ProfileStore) and client (ReplicatedStorage).
--
-- The profile schema is NOT defined here. Each feature owns its own slice and
-- registers it via a sibling `PlayerData.luau` file — see docs/game/PlayerData.md.

return {
	STORE_NAME = "PlayerData_v1",
	REPLICA_CLASS = "PlayerData",
}
