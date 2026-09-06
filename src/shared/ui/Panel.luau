--!strict
-- Panel surface. Two modes:
--   - Dark glass (default): translucent black + white outline. The default
--     surface for HUD windows.
--   - Gem (pass `variant = "red" | "blue" | ...`): the same gem stud
--     background used by Button / Badge — tiled noise + fill gradient +
--     outer black stroke + glow stroke (and optionally shine).
--
-- In gem mode, user children are wrapped in a content Frame at ZIndex 2 so
-- they sit above the GemBackground (at ZIndex 1) without each caller having
-- to set ZIndex themselves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Assets = require(script.Parent.assets)
local GemBackground = require(script.Parent.GemBackground)
local theme = require(script.Parent.theme)
local tokens = require(script.Parent.tokens)

type Props = {
	size: UDim2?,
	-- Inner inset on all sides. A `theme.space` step name, or reference pixels.
	padding: (string | number)?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	-- Dark-glass tuning. Ignored in gem mode.
	transparency: number?,
	strokeThickness: number?,
	-- Gem mode. When set, the surface paints the gem stud background instead.
	variant: string?,
	hasShine: boolean?,
	tileSize: UDim2?,
	children: { [string]: any }?,
}

return function(props: Props)
	-- Nil unless the caller asked for an inset, so a Panel stays a bare surface by
	-- default and only pays for padding when it wants it.
	local padding = if props.padding ~= nil
		then tokens.resolveSpace(theme.space, props.padding, 0)
		else nil

	local function paddingElement()
		if padding == nil then
			return nil
		end
		return React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, padding),
			PaddingBottom = UDim.new(0, padding),
			PaddingLeft = UDim.new(0, padding),
			PaddingRight = UDim.new(0, padding),
		})
	end

	if props.variant then
		local variantKey = theme.resolveVariant(props.variant)
		local variant = Assets.Variants[variantKey] or Assets.Variants.blue
		local rotation = if variantKey == "rainbow" then 0 else 90

		local content: { [string]: any } = { UIPadding = paddingElement() }
		if props.children then
			for k, v in pairs(props.children) do
				content[k] = v
			end
		end

		return React.createElement("Frame", {
			Size = props.size or theme.windowSize,
			Position = props.position or UDim2.fromScale(0.5, 0.5),
			AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = props.layoutOrder,
			ZIndex = props.zIndex,
		}, {
			BackgroundDeco = React.createElement(GemBackground, {
				fillGradient = variant.fill,
				glowGradient = variant.glow,
				fillRotation = rotation,
				glowRotation = rotation,
				tileSize = props.tileSize,
				hasShine = if props.hasShine == nil then false else props.hasShine,
			}),
			Content = React.createElement("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, content),
		})
	end

	local children: { [string]: any } = {
		UIPadding = paddingElement(),
		UIStroke = React.createElement("UIStroke", {
			Thickness = props.strokeThickness or theme.strokeThickness,
			LineJoinMode = Enum.LineJoinMode.Miter,
		}),
	}
	if props.children then
		for k, v in pairs(props.children) do
			children[k] = v
		end
	end

	return React.createElement("Frame", {
		Size = props.size or theme.windowSize,
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = props.transparency or theme.glassTransparency,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, children)
end
