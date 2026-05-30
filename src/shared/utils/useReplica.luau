-- useReplica: React hook for subscribing to a data controller that exposes
--   .GetData() -> table?
--   .DataChanged: Signal   (fires with the new data table)
--
-- Usage:
--   local data  = useReplica(PlayerDataController)          -- whole data table
--   local coins = useReplica(PlayerDataController, "Coins") -- pluck one key
--
-- The hook owns the connect/disconnect lifecycle, so features don't reimplement
-- the useEffect + Signal:Connect + return () disconnect pattern every time.
--
-- Important: ReplicaService writes mutate values in place — `replica:SetValue(
-- { "Settings", "music.enabled" }, false)` updates the existing `Settings`
-- table rather than swapping in a new one, so its reference is stable across
-- changes. React.useState bails out of re-rendering when the new value passes
-- Object.is against the old one, which means a same-reference table mutation
-- wouldn't propagate. To make the hook correct for table-typed values, we
-- shallow-clone tables on every pick so React always sees a fresh reference.
-- Primitive values (strings, numbers, booleans) pass through unchanged.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

type Controller = {
	GetData: () -> any,
	DataChanged: { Connect: (self: any, cb: (any) -> ()) -> { Disconnect: (self: any) -> () } },
}

local function useReplica(controller: Controller, key: string?): any
	local function pick(data: any)
		if data == nil then
			return nil
		end
		local v = if key == nil then data else data[key]
		-- Force a new reference for tables. Shallow-only: deep nested tables
		-- still share identity, but consumers picking a deeper key will see
		-- their slice clone on each fire too.
		if typeof(v) == "table" then
			return table.clone(v)
		end
		return v
	end

	local value, setValue = React.useState(function()
		return pick(controller.GetData())
	end)

	React.useEffect(function()
		-- Prime in case data arrived between the useState initializer and effect mount.
		setValue(pick(controller.GetData()))

		local conn = controller.DataChanged:Connect(function(data)
			setValue(pick(data))
		end)

		return function()
			conn:Disconnect()
		end
	end, { controller, key } :: { any })

	return value
end

return useReplica
