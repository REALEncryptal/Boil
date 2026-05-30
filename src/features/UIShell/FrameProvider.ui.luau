--!strict
-- Global frame state. Stores which frame id (if any) is currently open and
-- exposes open/close/toggle to descendants via the useFrame() hook.
--
-- Mount the provider once at the root of the React tree (see
-- src/client/init.client.luau). Every <Frame> and <HideWhenFrameOpen>
-- consumer must live inside it; useFrame() errors if no provider is found.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Types = require(script.Parent.Types)

local FrameContext = React.createContext(nil :: Types.FrameContextValue?)

type ProviderProps = {
	children: { [string]: any }?,
}

local function FrameProvider(props: ProviderProps)
	local openFrameId, setOpenFrameId = React.useState(nil :: Types.FrameId?)

	local open = React.useCallback(function(id: Types.FrameId)
		setOpenFrameId(id)
	end, {})

	local close = React.useCallback(function()
		setOpenFrameId(nil :: Types.FrameId?)
	end, {})

	local toggle = React.useCallback(function(id: Types.FrameId)
		if openFrameId == id then
			setOpenFrameId(nil :: Types.FrameId?)
		else
			setOpenFrameId(id)
		end
	end, { openFrameId } :: { any })

	local value = React.useMemo(function(): Types.FrameContextValue
		return {
			openFrameId = openFrameId,
			open = open,
			close = close,
			toggle = toggle,
		}
	end, { openFrameId, open, close, toggle } :: { any })

	return React.createElement(FrameContext.Provider, { value = value }, props.children)
end

local function useFrame(): Types.FrameContextValue
	local value = React.useContext(FrameContext)
	if value == nil then
		error("useFrame() must be called inside a <FrameProvider>", 2)
	end
	return value
end

return {
	FrameProvider = FrameProvider,
	useFrame = useFrame,
	Context = FrameContext,
}
