--!strict
-- Slop ScrollList: a glass surface that scrolls — the same body, outline and
-- inner glow as Panel, with a UIListLayout mounting the caller's items.
--
-- This is the one primitive the Studio template left unstyled, so it's derived
-- from Panel rather than extracted; the padding (10) and item gap (8) do come
-- from the template's placeholder. Pass `backgroundTransparency = 1` for a
-- layout-only list with no surface.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Boil = require(ReplicatedStorage.Shared.Boil)
local parts = require(script.Parent.parts)
local theme = require(script.Parent.theme)
-- Shared space-role resolver. Module scope is safe: the skin registry discovers
-- this folder lazily, so requiring the kit here can't re-enter Slop.
local tokens = Boil.ui.tokens

local DEFAULT_SCROLLBAR_THICKNESS = 6
local DEFAULT_SCROLLBAR_TRANSPARENCY = 0.4

return function(props: Boil.ScrollListProps)
	local horizontal = (props.direction or "vertical") == "horizontal"
	local padding = tokens.resolveSpace(theme.space, props.padding, theme.space.md) + theme.strokeThickness

	local children: { [string]: any } = {
		InnerGlow = parts.innerGlow(),
		Outline = parts.outline(),

		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
			Padding = UDim.new(0, tokens.resolveSpace(theme.space, props.gap, theme.space.sm)),
			HorizontalAlignment = props.horizontalAlignment or Enum.HorizontalAlignment.Center,
			VerticalAlignment = props.verticalAlignment or Enum.VerticalAlignment.Top,
			HorizontalFlex = if props.fillHorizontal then Enum.UIFlexAlignment.Fill else Enum.UIFlexAlignment.None,
			VerticalFlex = if props.fillVertical then Enum.UIFlexAlignment.Fill else Enum.UIFlexAlignment.None,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		-- Clears the inner-drawn outline on every side.
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, padding),
			PaddingBottom = UDim.new(0, padding),
			PaddingLeft = UDim.new(0, padding),
			PaddingRight = UDim.new(0, padding),
		}),
	}

	if props.children then
		for key, child in props.children do
			children[key] = child
		end
	end

	return React.createElement("ScrollingFrame", {
		Size = props.size or theme.scrollListSize,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = props.background or theme.glass,
		BackgroundTransparency = props.backgroundTransparency or theme.glassTransparency,
		BorderSizePixel = 0,
		ClipsDescendants = if props.clipsDescendants ~= nil then props.clipsDescendants else true,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
		CanvasSize = UDim2.fromScale(0, 0),
		AutomaticCanvasSize = if horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
		ScrollBarThickness = props.scrollBarThickness or DEFAULT_SCROLLBAR_THICKNESS,
		ScrollBarImageColor3 = props.scrollBarColor or theme.mutedTextColor,
		ScrollBarImageTransparency = props.scrollBarTransparency or DEFAULT_SCROLLBAR_TRANSPARENCY,
	}, children)
end
