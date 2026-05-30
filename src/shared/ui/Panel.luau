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

type Props = {
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	-- Dark-glass tuning. Ignored in gem mode.
	transparency: number?,
	strokeThickness: number?,
	-- Gem mode. When set, the surface paints the gem stud background instead.
	variant: Assets.VariantKey?,
	hasShine: boolean?,
	tileSize: UDim2?,
	children: { [string]: any }?,
}

return function(props: Props)
	if props.variant then
		local variant = Assets.Variants[props.variant] or Assets.Variants.red
		local fillRotation = if props.variant == "rainbow" then 0 else 90
		local glowRotation = if props.variant == "rainbow" then 0 else 90

		local content: { [string]: any } = {}
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
				fillRotation = fillRotation,
				glowRotation = glowRotation,
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
