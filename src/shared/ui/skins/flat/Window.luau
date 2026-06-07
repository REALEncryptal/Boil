--!strict
-- Flat Window: gray panel + a top bar (title label + close button) + a scrolling
-- content body that mounts the named-children slot. Ignores gem-only props
-- (scaleRef/initialScale/topBarExtra) — it's a debug skin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local contract = require(ReplicatedStorage.Shared.ui.contract)
local theme = require(script.Parent.theme)

return function(props: contract.WindowProps)
	local topBarHeight = props.topBarHeight or theme.topBarHeight
	local accent = theme.accent(props.titleVariant or "blue")

	local pad = props.contentPadding or {}
	local content: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, props.contentSpacing or theme.contentSpacing),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, (pad.top or theme.padding) + theme.strokeThickness),
			PaddingBottom = UDim.new(0, pad.bottom or theme.padding),
			PaddingLeft = UDim.new(0, pad.left or theme.padding),
			PaddingRight = UDim.new(0, pad.right or theme.padding),
		}),
	}
	if props.children then
		for key, child in props.children do
			content[key] = child
		end
	end

	return React.createElement("Frame", {
		Size = props.size or theme.windowSize,
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
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
				Position = UDim2.fromOffset(theme.padding, 0),
				BackgroundTransparency = 1,
				Text = props.title or "",
				TextColor3 = theme.textColor,
				TextSize = theme.titleTextSize,
				TextXAlignment = Enum.TextXAlignment.Left,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
			}),
			Close = React.createElement("TextButton", {
				Size = UDim2.fromOffset(topBarHeight - theme.padding, topBarHeight - theme.padding),
				Position = UDim2.new(1, -theme.tightPadding, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundColor3 = theme.accent("red"),
				BorderSizePixel = 0,
				Text = "X",
				TextColor3 = theme.textColor,
				TextSize = theme.textSize,
				FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold),
				[React.Event.Activated] = props.onClose,
			}, {
				UICorner = React.createElement("UICorner", { CornerRadius = theme.cornerRadius }),
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
end
