-- Shared config for PlayerData. Read from server (ProfileStore) and client (ReplicaController).

return {
	STORE_NAME = "PlayerData_v1",
	REPLICA_CLASS = "PlayerData",

	-- Profile schema. ProfileStore.New() takes this as the template;
	-- Profile:Reconcile() fills in missing keys for existing players when you add fields.
	PROFILE_TEMPLATE = {
		Coins = 0,
		Level = 1,
		Inventory = {},
		Note = "",
	},
}
