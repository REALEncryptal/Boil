--!strict
-- Wraps HUD / side-bar content and slides it off-screen whenever *any*
-- frame is open. Composes with FrameProvider through useFrame().
--
-- Usage:
--   React.createElement(UIShell.HideWhenFrameOpen, {
--       direction = "left",
--       basePosition = UDim2.fromScale(0, 0.5),
--       anchorPoint = Vector2.new(0, 0.5),
--       size = UDim2.fromOffset(220, 400),
--   }, {
--       SideBar = React.createElement(MySideBar),
--   })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ui = require(ReplicatedStorage.Shared.Boil).ui
local Constants = require(script.Parent.Constants)
local FrameProvider = require(script.Parent.FrameProvider)
local Types = require(script.Parent.Types)

type Props = {
	direction: Types.HideDirection?,
	basePosition: UDim2?,
	anchorPoint: Vector2?,
	size: UDim2?,
	-- Override the hide / show tween (each falls back to Constants).
	hideTweenInfo: TweenInfo?,
	showTweenInfo: TweenInfo?,
	children: { [string]: any }?,
}

local function hiddenPositionFor(base: UDim2, direction: Types.HideDirection): UDim2
	local offset = Constants.HIDE_OFFSCREEN_OFFSET
	if direction == "left" then
		return base - UDim2.fromScale(offset, 0)
	elseif direction == "right" then
		return base + UDim2.fromScale(offset, 0)
	elseif direction == "top" then
		return base - UDim2.fromScale(0, offset)
	end
	-- "bottom"
	return base + UDim2.fromScale(0, offset)
end

return function(props: Props)
	local frames = FrameProvider.useFrame()
	local direction: Types.HideDirection = props.direction or "left"
	local basePosition = props.basePosition or UDim2.fromScale(0, 0)
	local hideTweenInfo = props.hideTweenInfo or Constants.HIDE_HIDE_TWEEN_INFO
	local showTweenInfo = props.showTweenInfo or Constants.HIDE_SHOW_TWEEN_INFO

	local anyOpen = frames.openFrameId ~= nil

	local hiddenPos = hiddenPositionFor(basePosition, direction)
	local target: UDim2 = if anyOpen then hiddenPos else basePosition

	-- Sliding out (anyOpen flipping true) eases In so the slow part of the
	-- motion happens on-screen — otherwise the side bar looks like it just
	-- vanishes because Quad.Out's fast-start has it off-screen in ~1 frame.
	local tweenInfo: TweenInfo = if anyOpen then hideTweenInfo else showTweenInfo

	local ref = ui.useTweenedUDim2(target, { tweenInfo = tweenInfo })

	return React.createElement("Frame", {
		Size = props.size or UDim2.fromScale(1, 1),
		Position = basePosition,
		AnchorPoint = props.anchorPoint or Vector2.new(0, 0),
		BackgroundTransparency = 1,
		ref = ref,
	}, props.children)
end
