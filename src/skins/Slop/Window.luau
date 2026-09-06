--!strict
-- Slop Window: a glass body with a *transparent* top bar straddling its top
-- edge, exactly as the Studio template has it.
--
-- Nothing draws the bar itself — the title, the icon and the close button float
-- across the window's top edge, the icon centered on the left corner and the
-- close button on the right. That's why the content's default top padding adds
-- half the bar height: the bar's lower half overlaps the body, and content has
-- to clear it.
--
-- `topBarOverflow` widens gem's drawn bar past the panel edge; with no bar to
-- draw it has nothing to do here and is ignored.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Boil = require(ReplicatedStorage.Shared.Boil)
local Button = require(script.Parent.Button)
local parts = require(script.Parent.parts)
local theme = require(script.Parent.theme)
-- Shared space-role resolver, so `contentPadding = { top = "lg" }` works here too.
local tokens = Boil.ui.tokens

-- Icon inset within the top bar, from the template.
local ICON_SCALE = 0.9
-- Title height as a fraction of the bar. Under TextScaled this *is* the rendered
-- text size, so it also has to leave the glyph outline somewhere to draw.
local TITLE_HEIGHT = 0.7

return function(props: Boil.WindowProps)
	local topBarHeight = props.topBarHeight or theme.topBarHeight
	local iconSize = topBarHeight * ICON_SCALE
	local contentSpacing = tokens.resolveSpace(theme.space, props.contentSpacing, theme.contentSpacing)

	local pad = props.contentPadding or {}
	-- Chrome clearance this skin needs no matter what the caller asks for: the
	-- inner-drawn outline, plus half the top bar, which floats over the body
	-- rather than sitting above it. ADDED to the caller's inset — a caller can't
	-- know about the overlap, and a total-inset reading of `pad.top` put the
	-- title badge straight on top of the first row.
	local chromeTop = theme.strokeThickness + topBarHeight / 2
	local chrome = theme.strokeThickness

	local padTop = chromeTop + tokens.resolveSpace(theme.space, pad.top, theme.padding)
	local padBottom = chrome + tokens.resolveSpace(theme.space, pad.bottom, theme.padding)
	local padLeft = chrome + tokens.resolveSpace(theme.space, pad.left, theme.padding)
	local padRight = chrome + tokens.resolveSpace(theme.space, pad.right, theme.padding)

	-- The title starts where the overhanging icon ends.
	local titleLeft = if props.icon
		then iconSize / 2 + theme.tightPadding
		else theme.padding + theme.strokeThickness

	local body: { [string]: any } = {
		UIListLayout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, contentSpacing),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			-- Rows span the content width, matching gem's Window. A child that
			-- must stay its own width (a square Checkbox, an icon button) opts
			-- out with a UIFlexItem of FlexMode = None.
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		}),
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, padTop),
			PaddingBottom = UDim.new(0, padBottom),
			PaddingLeft = UDim.new(0, padLeft),
			PaddingRight = UDim.new(0, padRight),
		}),
	}
	if props.children then
		for key, child in props.children do
			body[key] = child
		end
	end

	local topBar: { [string]: any } = {}

	if props.icon then
		topBar.Icon = React.createElement("ImageLabel", {
			Size = UDim2.fromOffset(iconSize, iconSize),
			Position = UDim2.fromScale(0, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = props.icon,
			ImageColor3 = theme.mutedTextColor,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
		})
	end

	if props.title then
		topBar.Title = React.createElement("TextLabel", {
			Size = UDim2.new(1, -(titleLeft + topBarHeight), TITLE_HEIGHT, 0),
			Position = UDim2.new(0, titleLeft, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Text = props.title,
			TextColor3 = theme.textColor,
			TextScaled = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = theme.font(Enum.FontWeight.Bold),
			ZIndex = 3,
		}, {
			-- Plain black, never the variant: the template's title sits on the
			-- transparent bar with a flat dark outline, so `titleVariant` (which
			-- gem uses to paint a title badge) has nothing to drive here.
			TextStroke = parts.textStroke(),
		})
	end

	-- Overlay pinned just left of the close button, matching gem's slot.
	if props.topBarExtra ~= nil then
		topBar.TopBarExtra = React.createElement("Frame", {
			Size = props.topBarExtraSize or UDim2.new(0, 200, 1, 0),
			Position = UDim2.new(1, -topBarHeight, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, { Content = props.topBarExtra })
	end

	if props.onClose then
		-- The project's fixed close control, not a skinned Button — see
		-- Shared.ui.CloseButton for why that one primitive opts out of the seam.
		topBar.CloseButton = React.createElement(Boil.ui.CloseButton, {
			size = UDim2.fromOffset(topBarHeight, topBarHeight),
			position = UDim2.fromScale(1, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
			zIndex = 5,
			onClick = props.onClose,
		})
	end

	local children: { [string]: any } = {
		Content = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = theme.glass,
			BackgroundTransparency = theme.glassTransparency,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			InnerGlow = parts.innerGlow(),
			Outline = parts.outline(),
			Body = React.createElement("ScrollingFrame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 2,
				CanvasSize = UDim2.fromScale(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = theme.mutedTextColor,
				ScrollBarImageTransparency = 0.4,
			}, body),
		}),

		TopBar = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, topBarHeight),
			Position = UDim2.fromScale(0, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, topBar),
	}

	if props.scaleRef then
		children.UIScale = React.createElement("UIScale", {
			Scale = props.initialScale or 1,
			ref = props.scaleRef,
		})
	end

	return React.createElement("Frame", {
		Size = props.size or theme.windowSize,
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, children)
end
