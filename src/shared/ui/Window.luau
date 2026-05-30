--!strict
-- Gem-styled window layout: dark glass Panel + top bar (Badge title and/or
-- close Button) + scrollable content area. Children passed in are mounted
-- directly into the scrollable content's UIListLayout.
--
-- Minimal use:
--   React.createElement(ui.Window, {
--       title = "Inventory",
--       icon = "rbxassetid://…",
--       onClose = function() ... end,
--   }, {
--       Row1 = React.createElement(ui.Button, { variant = "red", ... }),
--       Row2 = React.createElement(ui.Button, { variant = "blue", ... }),
--   })
--
-- Pass `onClose = nil` and `title = nil` (and `icon = nil`) to omit either
-- bar element; the top bar stays at `topBarHeight` regardless so the
-- scroll area's height math doesn't shift.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Assets = require(script.Parent.assets)
local Panel = require(script.Parent.Panel)
local Badge = require(script.Parent.Badge)
local Button = require(script.Parent.Button)
local theme = require(script.Parent.theme)
local useTweenedScale = require(script.Parent.useTweenedScale)

type Props = {
	title: string?,
	icon: string?,
	titleVariant: Assets.VariantKey?,
	closeVariant: Assets.VariantKey?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	-- Height of the top bar in pixels.
	topBarHeight: number?,
	-- Horizontal overflow of the top bar past the panel edge (gem-style accent).
	topBarOverflow: number?,
	-- Content area padding (defaults: top=14, bottom=10, left=10, right=10).
	contentPadding: {
		top: number?,
		bottom: number?,
		left: number?,
		right: number?,
	}?,
	-- Vertical gap between content rows.
	contentSpacing: number?,
	onClose: (() -> ())?,
	-- Optional element overlaid on the top bar's right side, just to the
	-- left of the close button. The element fills a slot Frame sized by
	-- `topBarExtraSize` (default 200×1-scale) anchored top-right and
	-- z-indexed above the title badge, so the badge keeps spanning the
	-- full bar width behind it. Use for stats columns, secondary buttons,
	-- search inputs, etc.
	topBarExtra: any?,
	topBarExtraSize: UDim2?,
	-- Optional UIScale hooks. When `scaleRef` is provided, a UIScale is
	-- mounted directly on the Panel root so the whole window scales from its
	-- own center (used by UIShell.Frame for the enter/exit tween).
	scaleRef: useTweenedScale.ScaleRef?,
	initialScale: number?,
	children: { [string]: any }?,
}

return function(props: Props)
	local topBarHeight = props.topBarHeight or theme.topBarHeight
	local topBarOverflow = props.topBarOverflow or theme.topBarOverflow
	local pad = props.contentPadding or {}
	-- Top has to clear the panel stroke, so it's `padding + strokeThickness`
	-- rather than the bare `padding`. Computed at render time so a live
	-- theme edit propagates.
	local padTop = pad.top or (theme.padding + theme.strokeThickness)
	local padBottom = pad.bottom or theme.padding
	local padLeft = pad.left or theme.padding
	local padRight = pad.right or theme.padding
	local contentSpacing = props.contentSpacing or theme.contentSpacing

	-- Top bar: optional badge on the left, optional close button on the right.
	local topBarChildren: { [string]: any } = {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		}),
	}

	if props.title ~= nil or props.icon ~= nil then
		topBarChildren.TitleBadge = React.createElement(Badge, {
			variant = props.titleVariant or "blue",
			text = props.title or "",
			icon = props.icon,
			size = UDim2.fromScale(1, 1),
			layoutOrder = 0,
		})
	end

	if props.onClose ~= nil then
		topBarChildren.CloseButton = React.createElement(Button, {
			variant = props.closeVariant or "red",
			text = "X",
			size = UDim2.fromOffset(topBarHeight, topBarHeight),
			layoutOrder = 1,
			onClick = props.onClose,
		})
	end

	-- Content area: merge caller-supplied children with our padding + layout.
	local contentChildren: { [string]: any } = {
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, padTop),
			PaddingBottom = UDim.new(0, padBottom),
			PaddingLeft = UDim.new(0, padLeft),
			PaddingRight = UDim.new(0, padRight),
		}),
		UIListLayout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, contentSpacing),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		}),
	}
	if props.children then
		for k, v in pairs(props.children) do
			contentChildren[k] = v
		end
	end

	local panelChildren: { [string]: any } = {
		UIListLayout = React.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),

		TopContainer = React.createElement("Frame", {
			Size = UDim2.new(1, topBarOverflow, 0, topBarHeight),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 0,
		}, {
			-- Inner layout frame holds the UIListLayout + Badge + CloseButton.
			-- Nested so the topBarExtra below can mount as an absolute-
			-- positioned overlay sibling without being captured by the layout.
			Layout = React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, topBarChildren),

			-- topBarExtra overlays the badge area, right-anchored just to
			-- the left of the close button. Offset by `topBarHeight` (close
			-- button width) so it never overlaps the X. ZIndex 2 keeps it
			-- visually above the badge.
			TopBarExtra = if props.topBarExtra ~= nil
				then React.createElement("Frame", {
					Size = props.topBarExtraSize or UDim2.new(0, 200, 1, 0),
					Position = UDim2.new(1, -topBarHeight, 0, 0),
					AnchorPoint = Vector2.new(1, 0),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ZIndex = 2,
				}, { Content = props.topBarExtra })
				else nil,
		}),

		Wrapper = React.createElement("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -topBarHeight),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
			ScrollBarImageTransparency = 0.5,
		}, contentChildren),
	}

	if props.scaleRef then
		panelChildren.UIScale = React.createElement("UIScale", {
			Scale = props.initialScale or 1,
			ref = props.scaleRef,
		})
	end

	return React.createElement(Panel, {
		size = props.size or theme.windowSize,
		position = props.position,
		anchorPoint = props.anchorPoint,
	}, panelChildren)
end
