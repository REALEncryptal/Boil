--!strict
-- Track a GuiObject's live AbsoluteSize.
--
-- Returns `(size, ref)`. Assign `ref` to the GuiObject you want measured; `size`
-- is its pixel size, updated whenever it changes. Like useTweenedScale, the ref is
-- a *callback ref* held in state, so the effect re-runs the moment the instance
-- actually mounts instead of firing against a nil.
--
-- Used by `Canvas` to size itself from the box it was given rather than from the
-- camera — which is what lets a Canvas inside a fixed-size frame (the device
-- simulator in the Canvas story, a UI Labs panel) scale as if that frame were the
-- whole screen.
--
-- `initial` seeds the first render so a consumer isn't forced through one frame of
-- zero size; pass the best guess you have (usually the camera viewport).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

export type SizeRef = (GuiObject?) -> ()

local function useMeasuredSize(initial: Vector2?): (Vector2, SizeRef)
	local size, setSize = React.useState(initial or Vector2.zero)
	local instance, setInstance = React.useState(nil :: GuiObject?)

	local ref = React.useMemo(function(): SizeRef
		return function(newInstance: GuiObject?)
			setInstance(newInstance)
		end
	end, {})

	React.useEffect(function()
		if not instance then
			return
		end
		setSize(instance.AbsoluteSize)
		local conn = instance:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			setSize(instance.AbsoluteSize)
		end)
		return function()
			conn:Disconnect()
		end
	end, { instance } :: { any })

	return size, ref
end

return useMeasuredSize
