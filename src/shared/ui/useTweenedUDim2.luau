--!strict
-- Tween a GuiObject's Position (or any UDim2 property) toward a target value
-- whenever the target changes.
--
-- Returns a *callback ref* — assign it to the target instance's `ref` prop.
-- The instance is tracked in state so the tween effect re-runs the moment
-- it actually mounts. Mirrors `useTweenedScale`.
--
-- Usage (split fields):
--   local posRef = useTweenedUDim2(if open then onScreen else offScreen, {
--       duration = 0.3, easingStyle = Enum.EasingStyle.Quad,
--   })
--
-- Usage (TweenInfo bundle — preferred when you already have one):
--   local posRef = useTweenedUDim2(target, { tweenInfo = MyConstants.HIDE_TWEEN_INFO })
--
-- `tweenInfo` takes precedence over the split fields.
--
-- Note: render with the *initial* UDim2 in the JSX (a constant). React won't
-- re-apply unchanged props, so TweenService keeps ownership of the property
-- after the first tween.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)

export type Options = {
	duration: number?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?,
	tweenInfo: TweenInfo?,
	property: string?,
}

export type UDim2Ref = (GuiObject?) -> ()

local DEFAULT_DURATION = 0.15
local DEFAULT_EASING_STYLE = Enum.EasingStyle.Quad
local DEFAULT_EASING_DIRECTION = Enum.EasingDirection.Out
local DEFAULT_PROPERTY = "Position"

local function useTweenedUDim2(target: UDim2, options: Options?): UDim2Ref
	local opts = options or {}
	local tweenInfo = opts.tweenInfo
		or TweenInfo.new(
			opts.duration or DEFAULT_DURATION,
			opts.easingStyle or DEFAULT_EASING_STYLE,
			opts.easingDirection or DEFAULT_EASING_DIRECTION
		)
	local property = opts.property or DEFAULT_PROPERTY

	local instance, setInstance = React.useState(nil :: GuiObject?)

	local ref = React.useMemo(function(): UDim2Ref
		return function(newInstance: GuiObject?)
			setInstance(newInstance)
		end
	end, {})

	React.useEffect(function()
		if not instance then
			return
		end
		local tween = TweenService:Create(instance, tweenInfo, { [property] = target })
		tween:Play()
		return function()
			tween:Cancel()
			tween:Destroy()
		end
	end, { instance, target, property, tweenInfo } :: { any })

	return ref
end

return useTweenedUDim2
