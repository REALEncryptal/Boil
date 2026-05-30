--!strict
-- Gem-style decorative background: tiled noise texture + gradient fill +
-- black outer outline + inner gradient glow, optionally with a top shine
-- highlight. Used by both Button (`hasShine = true`) and Badge.
--
-- All strokes use ZIndex to enforce stack order (React-Roblox doesn't
-- guarantee insertion order for named children), and `BorderStrokePosition`
-- = Inner so Border-mode strokes draw inside the parent edge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Assets = require(script.Parent.assets)
local theme = require(script.Parent.theme)

type Props = {
	fillGradient: ColorSequence,
	glowGradient: ColorSequence,
	glowTransparency: NumberSequence?,
	fillRotation: number?,
	glowRotation: number?,
	tileSize: UDim2?,
	hasShine: boolean?,
	size: UDim2?,
	layoutOrder: number?,
	zIndex: number?,
}

return function(props: Props)
	local fillRot = props.fillRotation or 90
	local glowRot = props.glowRotation or 90
	-- Button names its glow "UIStrokeGlow" (Outer/Glow/Shine triplet); Badge
	-- uses the bare "UIStroke" name (Glow + Outer pair). Match the template.
	local glowName = if props.hasShine then "UIStrokeGlow" else "UIStroke"

	local children: { [string]: any } = {
		ImageLabel = React.createElement("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = Assets.NOISE_TEXTURE,
			ImageTransparency = 0.2,
			ScaleType = Enum.ScaleType.Tile,
			TileSize = props.tileSize or theme.tileSize,
		}),

		UIGradient = React.createElement("UIGradient", {
			Color = props.fillGradient,
			Rotation = fillRot,
		}),

		UIStrokeOuter = React.createElement("UIStroke", {
			Thickness = theme.strokeThickness,
			LineJoinMode = Enum.LineJoinMode.Miter,
			ZIndex = 2,
		}),

		[glowName] = React.createElement("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = theme.strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			LineJoinMode = Enum.LineJoinMode.Miter,
			ZIndex = 1,
		}, {
			UIGradient = React.createElement("UIGradient", {
				Color = props.glowGradient,
				Transparency = props.glowTransparency,
				Rotation = glowRot,
			}),
		}),
	}

	if props.hasShine then
		children.UIStrokeShine = React.createElement("UIStroke", {
			Color = Color3.fromRGB(255, 255, 255),
			Thickness = theme.strokeThickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			LineJoinMode = Enum.LineJoinMode.Miter,
			ZIndex = 2,
		}, {
			UIGradient = React.createElement("UIGradient", {
				Transparency = Assets.SHINE_TRANSPARENCY,
				Rotation = 90,
			}),
		})
	end

	return React.createElement("Frame", {
		Size = props.size or UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex or 1,
	}, children)
end
