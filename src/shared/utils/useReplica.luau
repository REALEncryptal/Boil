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
		if key == nil then
			return data
		end
		return data[key]
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
