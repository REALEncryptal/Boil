--!strict
-- Overlay — mount once at the React root. Renders the active pickup icons
-- and drives their per-frame bezier interpolation.
--
-- Subscribes to Manager._changed to re-render only when icons are added or
-- removed. The animation itself runs in a single RunService.Heartbeat that
-- mutates each icon's GuiObject.Position and UIScale.Scale via refs — no
-- per-frame React re-renders.
--
-- Already mounted by src/client/init.client.luau; features should not mount
-- a second instance.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local Manager = require(script.Parent.Manager)
local Constants = require(script.Parent.Constants)
local bezier = require(script.Parent.bezier)
local Types = require(script.Parent.Types)

type IconRefs = { image: ImageLabel?, scale: UIScale? }
type RefsMap = { [number]: IconRefs }

-- Per-icon child. Owns its own refs and writes them into the shared map on
-- mount; clears on unmount. This is how the Heartbeat loop in Overlay finds
-- each icon's GuiObject without going through React state.
local function PickupIcon(props: { icon: Types.ActiveIcon, refsMap: { current: RefsMap } })
	local icon = props.icon
	local refsMap = props.refsMap
	local imageRef = React.useRef(nil :: ImageLabel?)
	local scaleRef = React.useRef(nil :: UIScale?)

	React.useEffect(function()
		refsMap.current[icon.id] = {
			image = imageRef.current,
			scale = scaleRef.current,
		}
		return function()
			refsMap.current[icon.id] = nil
		end
	end, {})

	return React.createElement("ImageLabel", {
		Image = icon.icon,
		Size = UDim2.fromOffset(icon.size.X, icon.size.Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(icon.from.X, icon.from.Y),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = Constants.ICON_ZINDEX,
		ref = imageRef,
	}, {
		Scale = React.createElement("UIScale", {
			Scale = 0,
			ref = scaleRef,
		}),
	})
end

local function Overlay()
	local refsMap = React.useRef({} :: RefsMap)
	local _, setVersion = React.useState(0)

	-- Bump version on every Manager mutation so React re-renders the child list.
	React.useEffect(function()
		local conn = Manager._changed:Connect(function()
			setVersion(function(v: number)
				return v + 1
			end)
		end)
		return function()
			conn:Disconnect()
		end
	end, {})

	-- Per-frame animation. One Heartbeat for the whole overlay; the loop body
	-- walks Manager.active and resolves each icon's phase from elapsed time.
	React.useEffect(function()
		local conn = RunService.Heartbeat:Connect(function()
			local now = os.clock()
			local toRemove: { number } = {}

			for _, icon in ipairs(Manager.active) do
				local refs = refsMap.current[icon.id]
				if not refs or not refs.image or not refs.scale then
					continue
				end
				local image = refs.image :: ImageLabel
				local scale = refs.scale :: UIScale

				local elapsed = now - icon.spawnTime
				local popStart = icon.delay
				local popEnd = popStart + icon.popDuration
				local travelEnd = popEnd + icon.travelDuration
				local fadeEnd = travelEnd + icon.fadeDuration

				if elapsed < popStart then
					-- Stagger delay: keep invisible at the spawn point.
					scale.Scale = 0
				elseif elapsed < popEnd then
					-- Pop-in: scale 0 → overshoot → 1, anchored at `from`.
					local t = (elapsed - popStart) / icon.popDuration
					scale.Scale = bezier.easeBackOut(t)
					image.Position = UDim2.fromOffset(icon.from.X, icon.from.Y)
				elseif elapsed < travelEnd then
					-- Travel: quadratic bezier, eased t, destination resolved
					-- each frame so the curve tracks moving HUD targets.
					local rawT = (elapsed - popEnd) / icon.travelDuration
					local t = bezier.easeQuadInOut(rawT)
					local destination = Manager.resolveDestination(icon.to) or icon.from
					local mid = (icon.from + destination) / 2
					local perp = bezier.perpendicular(destination - icon.from)
					local control = mid + perp * icon.curveOffset
					local pos = bezier.quadratic(icon.from, control, destination, t)
					image.Position = UDim2.fromOffset(pos.X, pos.Y)
					scale.Scale = 1
				elseif not icon.arrived then
					-- Just landed — snap to destination, fire arrival.
					local destination = Manager.resolveDestination(icon.to) or icon.from
					image.Position = UDim2.fromOffset(destination.X, destination.Y)
					scale.Scale = 1
					Manager._complete(icon)
				elseif elapsed < fadeEnd then
					-- Fade-out at the destination.
					local t = (elapsed - travelEnd) / icon.fadeDuration
					scale.Scale = 1 - t
				else
					table.insert(toRemove, icon.id)
				end
			end

			for _, id in ipairs(toRemove) do
				Manager._remove(id)
			end
		end)

		return function()
			conn:Disconnect()
		end
	end, {})

	local children: { [string]: any } = {}
	for _, icon in ipairs(Manager.active) do
		children["Icon" .. tostring(icon.id)] = React.createElement(PickupIcon, {
			icon = icon,
			refsMap = refsMap,
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = Constants.OVERLAY_ZINDEX,
	}, children)
end

return Overlay
