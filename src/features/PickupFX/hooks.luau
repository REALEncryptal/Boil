--!strict
-- React hooks wrapping the Manager API. Non-React code can call into the
-- Manager directly; these exist so UI code doesn't have to reimplement the
-- Signal connect/disconnect dance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Manager = require(script.Parent.Manager)
local Types = require(script.Parent.Types)

local hooks = {}

-- Returns the stable Manager.spawn function. Hook form is for symmetry with
-- the other hooks; non-React callers can just use Manager.spawn directly.
function hooks.usePickupSpawn(): (Types.PickupOptions) -> ()
	return Manager.spawn
end

-- Attach the returned ref to any GuiObject; that object's center becomes the
-- live destination for the given id. Auto-registers on mount, cleans up on
-- unmount. The Manager re-resolves position every frame so this tracks if
-- the HUD element moves or resizes.
function hooks.useDestination(id: Types.DestinationId): { current: GuiObject? }
	local ref = React.useRef(nil :: GuiObject?)

	React.useEffect(function()
		Manager.registerDestination(id, function(): Vector2?
			local inst = ref.current
			if not inst or not inst.Parent then
				return nil
			end
			return inst.AbsolutePosition + inst.AbsoluteSize / 2
		end)
		return function()
			Manager.removeDestination(id)
		end
	end, { id } :: { any })

	return ref
end

-- Subscribe a callback to arrivals at `id`. The callback is stored in a ref
-- so re-renders don't churn the underlying Signal:Connect; the consumer can
-- pass an inline closure without memoizing.
function hooks.useArrival(id: Types.DestinationId, callback: () -> ())
	local cbRef = React.useRef(callback)
	cbRef.current = callback

	React.useEffect(function()
		local conn = Manager.onArrival:Connect(function(destinationId: Types.DestinationId?)
			if destinationId == id then
				cbRef.current()
			end
		end)
		return function()
			conn:Disconnect()
		end
	end, { id } :: { any })
end

return hooks
