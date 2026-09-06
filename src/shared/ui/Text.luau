--!strict
-- Gem text primitive.
--
-- Call sites name a ROLE, not a size:
--
--   React.createElement(ui.Text, { text = "Rebirth", role = "title" })
--
-- `role` resolves against the active skin's `theme.type`, so the same call renders
-- at gem's 36 and flat's 32 without the caller knowing either number. `textSize`
-- still overrides for the rare value a scale can't express.
--
-- Two behaviours changed from the pre-scale version, both because they made small
-- text unreadable:
--
--   * The Miter stroke is no longer unconditional. Headline roles (display /
--     title / heading) keep it — they usually sit over busy gem artwork and need
--     the separation. Body, label and caption render clean, because a 2px outline
--     on 14px text eats the counters and is most of why small copy looked muddy.
--     Pass `strokeThickness` to force it either way.
--   * `wrap` and `truncate` exist. Text that can outgrow its box must set one;
--     silently clipping a label is a bug, and it used to be the only option.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Assets = require(script.Parent.assets)
local theme = require(script.Parent.theme)
local tokens = require(script.Parent.tokens)

type Props = {
	text: string,
	role: string?,
	textSize: number?,
	weight: Enum.FontWeight?,
	color: Color3?,
	xAlignment: Enum.TextXAlignment?,
	yAlignment: Enum.TextYAlignment?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	automaticSize: Enum.AutomaticSize?,
	wrap: boolean?,
	truncate: boolean?,
	richText: boolean?,
	lineHeight: number?,
	shadow: boolean?,
	shadowColor: Color3?,
	strokeThickness: number?,
	foregroundOffset: number?,
}

local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(0, 0, 0)

-- Roles that carry an outline by default: they're display type, usually over
-- gem artwork. Everything smaller renders clean.
local STROKED_ROLES: { [string]: boolean } = {
	display = true,
	title = true,
	heading = true,
}

return function(props: Props)
	local role = props.role or theme.roles.default
	local textSize = props.textSize or tokens.resolveType(theme.type, role, theme.type.body)

	local strokeThickness = props.strokeThickness
	if strokeThickness == nil then
		strokeThickness = if STROKED_ROLES[role] then theme.thinStrokeThickness else 0
	end

	local font = Font.new(Assets.DISPLAY_FONT_ID, props.weight or Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	local xAlign = props.xAlignment or Enum.TextXAlignment.Center
	local yAlign = props.yAlignment or Enum.TextYAlignment.Center
	local color = props.color or WHITE

	-- Shared across both layers of the shadow variant so they never drift.
	local common = {
		Text = props.text,
		TextSize = textSize,
		FontFace = font,
		TextXAlignment = xAlign,
		TextYAlignment = yAlign,
		TextWrapped = props.wrap,
		TextTruncate = if props.truncate then Enum.TextTruncate.AtEnd else nil,
		RichText = props.richText,
		LineHeight = props.lineHeight,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}

	local function stroke()
		if (strokeThickness :: number) <= 0 then
			return nil
		end
		return React.createElement("UIStroke", {
			Thickness = strokeThickness,
			LineJoinMode = Enum.LineJoinMode.Miter,
		})
	end

	if not props.shadow then
		local flat = table.clone(common)
		flat.Size = props.size or UDim2.fromScale(1, 1)
		flat.Position = props.position
		flat.AnchorPoint = props.anchorPoint
		flat.TextColor3 = color
		flat.LayoutOrder = props.layoutOrder
		flat.ZIndex = props.zIndex
		flat.AutomaticSize = props.automaticSize
		return React.createElement("TextLabel", flat, { UIStroke = stroke() })
	end

	-- Shadow variant: an outer label painted in `shadowColor` with an inner copy
	-- in `color` lifted a couple of pixels, both carrying the same stroke.
	local outer = table.clone(common)
	outer.Size = props.size or UDim2.fromScale(1, 1)
	outer.Position = props.position
	outer.AnchorPoint = props.anchorPoint
	outer.TextColor3 = props.shadowColor or BLACK
	outer.LayoutOrder = props.layoutOrder
	outer.ZIndex = props.zIndex
	outer.AutomaticSize = props.automaticSize

	local inner = table.clone(common)
	inner.Size = UDim2.fromScale(1, 1)
	inner.Position = UDim2.fromOffset(0, props.foregroundOffset or theme.textForegroundOffset)
	inner.TextColor3 = color

	return React.createElement("TextLabel", outer, {
		UIStroke = stroke(),
		FgTextLabel = React.createElement("TextLabel", inner, { UIStroke = stroke() }),
	})
end
