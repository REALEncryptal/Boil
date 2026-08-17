--!strict
-- The player's live viewport size in pixels.
--
-- Reads `Workspace.CurrentCamera.ViewportSize` and re-renders on every change —
-- window resize, device rotation, and the camera swap that happens on respawn (the
-- old camera is destroyed, so a connection to it alone would go stale).
--
-- This is the *screen* measurement. Inside a `Canvas`, prefer `useSurface().viewport`
-- — that's the canvas's own box, which is the screen at the root but the enclosing
-- frame in a UI Labs story.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local scale = require(script.Parent.scale)

local function currentViewport(): Vector2
	local camera = Workspace.CurrentCamera
	if not camera then
		return scale.referenceViewport
	end
	return camera.ViewportSize
end

local function useViewport(): Vector2
	local viewport, setViewport = React.useState(currentViewport)

	React.useEffect(function()
		local cameraConn: RBXScriptConnection? = nil

		-- The engine reports a 1×1 viewport for a frame or two on join. Ignoring
		-- those keeps the seeded value (or the last real one) until a real
		-- measurement lands, so nothing flashes at a bogus scale.
		local function update()
			local size = currentViewport()
			if scale.isMeasured(size) then
				setViewport(size)
			end
		end

		local function bindCamera()
			if cameraConn then
				cameraConn:Disconnect()
				cameraConn = nil
			end
			local camera = Workspace.CurrentCamera
			if camera then
				cameraConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
			end
			update()
		end

		local swapConn = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
		bindCamera()

		return function()
			swapConn:Disconnect()
			if cameraConn then
				cameraConn:Disconnect()
			end
		end
	end, {})

	return viewport
end

return useViewport
