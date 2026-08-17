--!strict
-- Screen insets — the edges of the screen something else already owns, in raw
-- device pixels. The low-level source behind `ui.useSafeArea` (which converts
-- these to canvas units) and `useSurface().insets`.
--
-- Two different intrusions, handled in two different places:
--
--   * **Device cutouts** (notch, rounded corners, home indicator) — the engine
--     handles these. `BoilRoot` sets `ScreenInsets = DeviceSafeInsets`, so the
--     ScreenGui's own box already excludes them and no UI code has to care.
--   * **The Roblox topbar** — the engine does NOT reserve this for a full-bleed
--     ScreenGui, so anything anchored to the top of the screen draws underneath
--     the chat / menu buttons. That's what this module reports.
--
-- Feature code should not require this directly; use `ui.useSafeArea()` (canvas
-- units, which is what you want inside a Canvas) or `ui.SafeArea`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local React = require(ReplicatedStorage.Packages.React)

export type Insets = {
	top: number,
	bottom: number,
	left: number,
	right: number,
}

local ZERO: Insets = { top = 0, bottom = 0, left = 0, right = 0 }

local function current(): Insets
	local topLeft, bottomRight = GuiService:GetGuiInset()
	return {
		top = topLeft.Y,
		left = topLeft.X,
		bottom = bottomRight.Y,
		right = bottomRight.X,
	}
end

local function equal(a: Insets, b: Insets): boolean
	return a.top == b.top and a.bottom == b.bottom and a.left == b.left and a.right == b.right
end

-- Connect `handler` to whichever inset signals this engine version exposes, and
-- return the connections. Each is optional on purpose: TopbarInset and
-- SafeZoneOffsetsChanged are both newer than the oldest client this could run on,
-- and a missing one degrades to "insets are read once at mount" rather than
-- erroring during boot.
local function connectInsetSignals(handler: () -> ()): { RBXScriptConnection }
	local conns: { RBXScriptConnection } = {}
	local function try(get: () -> RBXScriptSignal)
		local ok, signal = pcall(get)
		if ok and signal then
			table.insert(conns, signal:Connect(handler))
		end
	end
	try(function()
		return GuiService:GetPropertyChangedSignal("TopbarInset")
	end)
	try(function()
		return GuiService.SafeZoneOffsetsChanged
	end)
	return conns
end

-- Live insets in screen pixels.
local function useScreenInsets(): Insets
	local insets, setInsets = React.useState(current)

	React.useEffect(function()
		local function update()
			local next = current()
			setInsets(function(previous: Insets): Insets
				-- The signals above fire for unrelated churn; returning the
				-- previous table on a no-op keeps React from re-rendering the
				-- whole tree every time the topbar reasserts the same value.
				if equal(previous, next) then
					return previous
				end
				return next
			end)
		end

		local conns = connectInsetSignals(update)
		update()

		return function()
			for _, conn in conns do
				conn:Disconnect()
			end
		end
	end, {})

	return insets
end

return {
	zero = ZERO,
	current = current,
	equal = equal,
	useScreenInsets = useScreenInsets,
}
