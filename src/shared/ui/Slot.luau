--!strict
-- Slot — a transparent, named positioning container. Structure-only: a Frame with
-- size / position / anchor / optional padding and no visuals. Two uses:
--   * a plain spacer / positioned region inside a layout, and
--   * a named target for the (future) Studio-extract portal bridge — set `name`
--     and a ReactRoblox.createPortal can render skinned content into this slot
--     inside a hand-built Studio skeleton (see docs/game/layout-surfaces.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local SkinProvider = require(script.Parent.SkinProvider)
local tokens = require(script.Parent.tokens)

export type SlotProps = {
	name: string?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	-- A `theme.space` step name, or reference pixels.
	padding: (string | number)?,
	automaticSize: Enum.AutomaticSize?,
	-- Cut children off at the slot's edge. For art that is deliberately bigger
	-- than the region it sits in (a figure whose trail runs off a card).
	clipsDescendants: boolean?,
	-- Render the slot and everything in it at this multiple of its laid-out
	-- size, text included. `size` stays the unscaled size; layouts around the
	-- slot see the scaled one. For a subtree that is composed at reference
	-- size and then wants to be denser than the type roles would make it
	-- (the Trails card row), not for fitting a device — that is Surface's job.
	scale: number?,
	layoutOrder: number?,
	zIndex: number?,
	children: { [string]: any }?,
}

return function(props: SlotProps)
	local skin = SkinProvider.useSkin()

	local children: { [string]: any } = {}
	if props.scale ~= nil then
		children.Scale = React.createElement("UIScale", {
			Scale = props.scale,
		})
	end
	if props.padding ~= nil then
		local padding = tokens.resolveSpace(skin.theme.space, props.padding, 0)
		children.Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, padding),
			PaddingBottom = UDim.new(0, padding),
			PaddingLeft = UDim.new(0, padding),
			PaddingRight = UDim.new(0, padding),
		})
	end
	if props.children then
		for key, child in props.children do
			children[key] = child
		end
	end

	return React.createElement("Frame", {
		Name = props.name or "Slot",
		Size = props.size or UDim2.fromScale(1, 1),
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		AutomaticSize = props.automaticSize,
		ClipsDescendants = props.clipsDescendants,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, children)
end
