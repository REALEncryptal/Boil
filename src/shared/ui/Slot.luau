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
	layoutOrder: number?,
	zIndex: number?,
	children: { [string]: any }?,
}

return function(props: SlotProps)
	local skin = SkinProvider.useSkin()

	local children: { [string]: any } = {}
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
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, children)
end
