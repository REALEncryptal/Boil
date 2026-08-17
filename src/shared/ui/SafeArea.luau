--!strict
-- SafeArea — a transparent, structure-only region inset away from whatever the
-- platform already owns (today: the Roblox topbar; device cutouts are handled by
-- the ScreenGui's `ScreenInsets`).
--
-- Same family as Stack / Row / Grid / Slot: it draws nothing, it just positions.
-- Wrap the part of a screen that must stay clear of the topbar — HUD chrome
-- anchored to the top, a notification stack, a currency row:
--
--   React.createElement(ui.SafeArea, {}, {
--       Hud = React.createElement(ui.Stack, { … }),
--   })
--
-- Insets are in canvas units (see useSafeArea), so this composes with the Canvas
-- rather than fighting it. Opt individual sides out when the content only touches
-- one edge — a bottom-anchored action bar doesn't want to lose room at the top:
--
--   React.createElement(ui.SafeArea, { top = false }, { … })
--
-- `extra` adds padding on every enabled side, so a caller doesn't have to nest a
-- SafeArea inside a padded Stack just to get breathing room off the topbar.
--
-- This is NOT applied to the root by default. Full-bleed is the right default for
-- a root canvas — a background, a vignette, a centered window all want the whole
-- screen — and only the elements that actually reach for an edge need insetting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local useSafeArea = require(script.Parent.useSafeArea)

export type SafeAreaProps = {
	-- Per-side opt-out; each defaults to true.
	top: boolean?,
	bottom: boolean?,
	left: boolean?,
	right: boolean?,
	-- Additional padding (canvas units) added to every enabled side.
	extra: number?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	children: { [string]: any }?,
}

local function side(enabled: boolean?, inset: number, extra: number): UDim
	if enabled == false then
		return UDim.new(0, 0)
	end
	return UDim.new(0, inset + extra)
end

return function(props: SafeAreaProps)
	local safe = useSafeArea()
	local extra = props.extra or 0

	local children: { [string]: any } = {
		Padding = React.createElement("UIPadding", {
			PaddingTop = side(props.top, safe.top, extra),
			PaddingBottom = side(props.bottom, safe.bottom, extra),
			PaddingLeft = side(props.left, safe.left, extra),
			PaddingRight = side(props.right, safe.right, extra),
		}),
	}
	if props.children then
		for key, child in props.children do
			children[key] = child
		end
	end

	return React.createElement("Frame", {
		Name = "SafeArea",
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, children)
end
