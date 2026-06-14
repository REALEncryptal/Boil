--!strict
-- Animated, state-driven visibility wrapper. Reads the active frame id from
-- FrameProvider and tweens its children's UIScale in when that id matches.
--
-- Renders no chrome — pair with a <Window> (or anything that accepts the
-- `scaleRef` / `initialScale` props) for the visuals:
--
--   local frames = UIShell.useFrame()
--   React.createElement(UIShell.Frame, { id = "Inventory" }, {
--       Window = React.createElement(ui.Window, {
--           title = "Inventory",
--           onClose = frames.close,
--       }, { ... rows ... }),
--   })
--
-- Switching frames: calling frames.open("B") while "A" is open causes A's
-- Frame to read "not me" → exit tween, and B's Frame to read "me" → enter
-- tween, simultaneously. No manual close-then-open dance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ui = require(ReplicatedStorage.Shared.Boil).ui
local Constants = require(script.Parent.Constants)
local FrameProvider = require(script.Parent.FrameProvider)
local Types = require(script.Parent.Types)

type Props = {
	id: Types.FrameId,
	-- Override the enter/exit tween (each falls back to Constants).
	enterTweenInfo: TweenInfo?,
	exitTweenInfo: TweenInfo?,
	-- Override the start/exit UIScale value (defaults to Constants.ENTER_SCALE_FROM).
	scaleFrom: number?,
	children: { [string]: any }?,
}

return function(props: Props)
	local frames = FrameProvider.useFrame()
	local enterTweenInfo = props.enterTweenInfo or Constants.ENTER_TWEEN_INFO
	local exitTweenInfo = props.exitTweenInfo or Constants.EXIT_TWEEN_INFO
	local scaleFrom = props.scaleFrom or Constants.ENTER_SCALE_FROM

	local isOpen = frames.openFrameId == props.id
	-- `mounted` lags behind `isOpen` on close: stays true through the exit
	-- tween, then flips false so the children unmount and Visible turns off.
	local mounted, setMounted = React.useState(isOpen)

	React.useEffect(function()
		if isOpen then
			setMounted(true)
			return nil
		end
		local cancelled = false
		task.delay(exitTweenInfo.Time, function()
			if cancelled then
				return
			end
			setMounted(false)
		end)
		return function()
			cancelled = true
		end
	end, { isOpen, exitTweenInfo } :: { any })

	local targetScale: number = if isOpen then 1 else scaleFrom
	local tweenInfo: TweenInfo = if isOpen then enterTweenInfo else exitTweenInfo

	local scaleRef = ui.useTweenedScale(targetScale, { tweenInfo = tweenInfo })

	-- Inject scaleRef + initialScale into each child element so the UIScale
	-- lives inside the child (e.g. inside <Window>'s Panel) rather than on
	-- this wrapper. Scales from the child's own center, not the screen.
	local injectedChildren: { [string]: any } = {}
	if mounted and props.children then
		for k, v in pairs(props.children) do
			injectedChildren[k] = React.cloneElement(v, {
				scaleRef = scaleRef,
				initialScale = scaleFrom,
			})
		end
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = mounted,
	}, injectedChildren)
end
