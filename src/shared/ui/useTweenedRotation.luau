--!strict
-- Tween a GuiObject's Rotation toward a target value whenever the target
-- changes. Mirrors useTweenedScale / useTweenedUDim2 (same options shape,
-- same cancel-on-cleanup pattern).
--
-- Returns a callback ref — assign it to the target instance's `ref` prop.
--
-- Usage:
--   local rotRef = useTweenedRotation(if hovered then 8 else 0)
--   React.createElement("ImageLabel", { Rotation = 0, ref = rotRef })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)

export type Options = {
	duration: number?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?,
}

export type RotationRef = (GuiObject?) -> ()

local DEFAULT_DURATION = 0.18
local DEFAULT_EASING_STYLE = Enum.EasingStyle.Quad
local DEFAULT_EASING_DIRECTION = Enum.EasingDirection.Out

local function useTweenedRotation(target: number, options: Options?): RotationRef
	local opts = options or {}
	local duration = opts.duration or DEFAULT_DURATION
	local easingStyle = opts.easingStyle or DEFAULT_EASING_STYLE
	local easingDirection = opts.easingDirection or DEFAULT_EASING_DIRECTION

	local instance, setInstance = React.useState(nil :: GuiObject?)

	local ref = React.useMemo(function(): RotationRef
		return function(newInstance: GuiObject?)
			setInstance(newInstance)
		end
	end, {})

	React.useEffect(function()
		if not instance then
			return
		end
		local tween = TweenService:Create(
			instance,
			TweenInfo.new(duration, easingStyle, easingDirection),
			{ Rotation = target }
		)
		tween:Play()
		return function()
			tween:Cancel()
			tween:Destroy()
		end
	end, { instance, target, duration, easingStyle, easingDirection } :: { any })

	return ref
end

return useTweenedRotation
