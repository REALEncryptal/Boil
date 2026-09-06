--!strict
-- Flat Window: gray panel + a top bar (title label + close button) + a scrolling
-- content body that mounts the named-children slot. Ignores gem-only props
-- (scaleRef/initialScale/topBarExtra) — it's a debug skin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local contract = require(ReplicatedStorage.Shared.ui.contract)
local tokens = require(ReplicatedStorage.Shared.ui.tokens)
local CloseButton = require(ReplicatedStorage.Shared.ui.CloseButton)
local Surface = require(ReplicatedStorage.Shared.ui.Surface)
local theme = require(script.Parent.theme)

return function(props: contract.WindowProps)
	local topBarHeight = props.topBarHeight or theme.topBarHeight
	local accent = theme.accent(props.titleVariant or "primary")
	local space = theme.space
	local function pad_(value: any, fallback: number): number
		return tokens.resolveSpace(space, value, fallback)
	end

	local pad = props.contentPadding or {}
	local content: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, pad_(props.contentSpacing, space.md)),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = React.createElement("UIPadding", {
			-- Skin chrome clearance (the border) plus the caller's inset. Flat's
			-- top bar is a sibling row, so the border is all there is to clear.
			PaddingTop = UDim.new(0, theme.strokeThickness + pad_(pad.top, space.lg)),
			PaddingBottom = UDim.new(0, pad_(pad.bottom, space.lg)),
			PaddingLeft = UDim.new(0, pad_(pad.left, space.lg)),
			PaddingRight = UDim.new(0, pad_(pad.right, space.lg)),
		}),
	}
	if props.children then
		for key, child in props.children do
			content[key] = child
		end
	end

	local responsive = props.responsive ~= false
	local size = props.size or theme.windowSize

	local frame = React.createElement("Frame", {
		-- Inside a Surface the frame just fills it and the Surface owns the
		-- placement; standalone it keeps its own size and position.
		Size = if responsive then UDim2.fromScale(1, 1) else size,
		Position = if responsive then UDim2.fromScale(0.5, 0.5) else (props.position or UDim2.fromScale(0.5, 0.5)),
		AnchorPoint = if responsive
			then Vector2.new(0.5, 0.5)
			else (props.anchorPoint or Vector2.new(0.5, 0.5)),
		BackgroundColor3 = theme.surface,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, {
		UICorner = React.createElement("UICorner", { CornerRadius = theme.cornerRadius }),
		UIStroke = React.createElement("UIStroke", { Thickness = theme.strokeThickness, Color = theme.border }),

		TopBar = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, topBarHeight),
			BackgroundColor3 = theme.surfaceAlt,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, {
			UICorner = React.createElement("UICorner", { CornerRadius = theme.cornerRadius }),
			AccentStripe = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, theme.strokeThickness),
				Position = UDim2.fromScale(0, 1),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
			}),
			Title = React.createElement("TextLabel", {
				Size = UDim2.new(1, -topBarHeight, 1, 0),
				Position = UDim2.fromOffset(space.lg, 0),
				BackgroundTransparency = 1,
				Text = props.title or "",
				TextColor3 = theme.textColor,
				TextSize = theme.type[props.titleRole or theme.roles.windowTitle],
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
			}),
			-- The project's fixed close control, not a flat-styled button — see
			-- Shared.ui.CloseButton for why that one primitive opts out of the seam.
			Close = React.createElement(CloseButton, {
				size = UDim2.fromOffset(topBarHeight - space.lg, topBarHeight - space.lg),
				position = UDim2.new(1, -space.sm, 0.5, 0),
				anchorPoint = Vector2.new(1, 0.5),
				onClick = props.onClose,
			}),
		}),

		Body = React.createElement("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -topBarHeight),
			Position = UDim2.fromOffset(0, topBarHeight),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 6,
			ZIndex = 2,
		}, content),
	})

	if not responsive then
		return frame
	end

	-- Same responsive wrapper as the gem Window: `size` is reference pixels and
	-- the Surface scales the whole thing to the viewport.
	return React.createElement(Surface, {
		name = "Window",
		size = size,
		position = props.position or UDim2.fromScale(0.5, 0.5),
		anchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
	}, { Frame = frame })
end
