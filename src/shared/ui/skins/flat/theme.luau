--!strict
-- Flat skin tokens. Deliberately plain: solid gray surfaces, thin borders, no
-- gradients/noise/shine. Tokens live under the skin (per the contract), so these
-- are independent of the gem theme. The `variants` map proves variant routing —
-- each VariantKey resolves to a flat accent used for borders/fills — without any
-- gem artwork, so the swap is verifiable by eye on plain shapes.

local theme = {}

theme.strokeThickness = 2
theme.padding = 10
theme.tightPadding = 6
theme.itemSpacing = 8
theme.contentSpacing = 12
theme.cornerRadius = UDim.new(0, 4)

theme.textSize = 24
theme.titleTextSize = 28

theme.buttonSize = UDim2.fromOffset(60, 60)
theme.windowSize = UDim2.fromOffset(797, 595)
theme.topBarHeight = 60
theme.textFieldSize = UDim2.fromOffset(300, 60)

-- Neutral surfaces.
theme.surface = Color3.fromRGB(58, 58, 64)
theme.surfaceAlt = Color3.fromRGB(78, 78, 86)
theme.surfaceDeep = Color3.fromRGB(44, 44, 49)
theme.border = Color3.fromRGB(150, 150, 158)
theme.textColor = Color3.fromRGB(236, 236, 240)
theme.mutedText = Color3.fromRGB(170, 170, 178)

theme.variants = {
	red = Color3.fromRGB(206, 84, 84),
	blue = Color3.fromRGB(84, 134, 206),
	green = Color3.fromRGB(84, 184, 116),
	purple = Color3.fromRGB(154, 96, 206),
	yellow = Color3.fromRGB(212, 184, 76),
	white = Color3.fromRGB(210, 210, 216),
	rainbow = Color3.fromRGB(184, 124, 204),
}

function theme.accent(variant: string?): Color3
	return theme.variants[variant or "white"] or theme.variants.white
end

return theme
