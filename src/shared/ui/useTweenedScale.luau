--!strict
-- Tween a UIScale's Scale toward a target value whenever the target changes.
--
-- The returned value is a *callback ref* — assign it to a UIScale's `ref`
-- prop. The instance is tracked in state so the tween effect re-runs the
-- moment the UIScale actually mounts (otherwise the effect could fire while
-- the instance is still nil and silently miss the tween).
--
-- Usage (split fields):
--   local scaleRef = useTweenedScale(if selected then 1.1 else 1, {
--       duration = 0.2, easingStyle = Enum.EasingStyle.Quad,
--   })
--
-- Usage (TweenInfo bundle — preferred when you already have one):
--   local scaleRef = useTweenedScale(target, { tweenInfo = MyConstants.ENTER_TWEEN_INFO })
--
-- `tweenInfo` takes precedence over the split fields; mix them only if you
-- know what you're doing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)

export type Options = {
	duration: number?,
	easingStyle: Enum.EasingStyle?,
	easingDirection: Enum.EasingDirection?,
	tweenInfo: TweenInfo?,
}

export type ScaleRef = (UIScale?) -> ()

local DEFAULT_DURATION = 0.15
local DEFAULT_EASING_STYLE = Enum.EasingStyle.Quad
local DEFAULT_EASING_DIRECTION = Enum.EasingDirection.Out

local function useTweenedScale(target: number, options: Options?): ScaleRef
	local opts = options or {}
	local tweenInfo = opts.tweenInfo
		or TweenInfo.new(
			opts.duration or DEFAULT_DURATION,
			opts.easingStyle or DEFAULT_EASING_STYLE,
			opts.easingDirection or DEFAULT_EASING_DIRECTION
		)

	local instance, setInstance = React.useState(nil :: UIScale?)

	local ref = React.useMemo(function(): ScaleRef
		return function(newInstance: UIScale?)
			setInstance(newInstance)
		end
	end, {})

	React.useEffect(function()
		if not instance then
			return
		end
		local tween = TweenService:Create(instance, tweenInfo, { Scale = target })
		tween:Play()
		return function()
			tween:Cancel()
			tween:Destroy()
		end
	end, { instance, target, tweenInfo } :: { any })

	return ref
end

return useTweenedScale
