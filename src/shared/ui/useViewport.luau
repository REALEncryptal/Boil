--!strict
-- React bindings for viewport.luau: the hooks a component uses to know how big
-- the screen is, what device it is, and what to multiply reference pixels by.
--
--   local vp = ui.useViewport()   -- { size, device, scale, isTouch }
--   local scale = ui.useScale()   -- just the number
--   local device = ui.useDevice() -- "phone" | "tablet" | "console" | "desktop"
--
-- Most components never call these — they sit inside a `ui.Surface`, which
-- mounts the UIScale that applies the factor to everything below it. Reach for
-- the hooks when a layout has to *change*, not just shrink: a sidebar that
-- becomes a bottom bar on a phone, a two-column grid that becomes one.
--
-- `ViewportProvider` overrides the real values for a subtree. That's what lets a
-- UI Labs story preview a phone layout on a desktop monitor without a device.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local viewport = require(script.Parent.viewport)

export type Device = viewport.Device

export type ViewportInfo = {
	size: Vector2,
	device: Device,
	scale: number,
	isTouch: boolean,
}

local ViewportContext = React.createContext(nil :: ViewportInfo?)

local function read(): ViewportInfo
	local size, device, scale = viewport.current()
	return {
		size = size,
		device = device,
		scale = scale,
		isTouch = viewport.isTouch(),
	}
end

type ProviderProps = {
	-- Any subset overrides the live value; anything omitted stays real. A story
	-- previewing a phone usually sets `device`, and lets scale follow from it.
	size: Vector2?,
	device: Device?,
	scale: number?,
	children: { [string]: any }?,
}

local function ViewportProvider(props: ProviderProps)
	local live, setLive = React.useState(read)

	React.useEffect(function()
		return viewport.observe(function(size, device, scale)
			setLive({ size = size, device = device, scale = scale, isTouch = viewport.isTouch() })
		end)
	end, {})

	local value = React.useMemo(function(): ViewportInfo
		local size = props.size or live.size
		local device = props.device or live.device
		-- An explicit device with no explicit scale should re-derive the scale,
		-- otherwise a "preview as phone" story would render phone breakpoints at
		-- desktop sizes and prove nothing.
		local scale = props.scale
		if scale == nil then
			scale = if props.device or props.size then viewport.scaleFor(size, device) else live.scale
		end
		return {
			size = size,
			device = device,
			scale = scale :: number,
			isTouch = if props.device then props.device == "phone" or props.device == "tablet" else live.isTouch,
		}
	end, { props.size, props.device, props.scale, live } :: { any })

	return React.createElement(ViewportContext.Provider, { value = value }, props.children)
end

-- Falls back to a live read when no provider is mounted, so a component works
-- standalone in a story exactly as it does under the client root.
local function useViewport(): ViewportInfo
	local override = React.useContext(ViewportContext)
	local live, setLive = React.useState(read)

	React.useEffect(function()
		if override ~= nil then
			return
		end
		return viewport.observe(function(size, device, scale)
			setLive({ size = size, device = device, scale = scale, isTouch = viewport.isTouch() })
		end)
	end, { override } :: { any })

	if override ~= nil then
		return override
	end
	return live
end

local function useScale(): number
	return useViewport().scale
end

local function useDevice(): Device
	return useViewport().device
end

return {
	ViewportProvider = ViewportProvider,
	Context = ViewportContext,
	useViewport = useViewport,
	useScale = useScale,
	useDevice = useDevice,
}
