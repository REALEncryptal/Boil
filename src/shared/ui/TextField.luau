--!strict
-- Translucent dark glass text input. Same outer shape as Panel (black +
-- 0.8 transparency + white Miter UIStroke), with a transparent TextBox child
-- using the gem display font and inset by 10px UIPadding.
--
-- Pass `text` to drive it as a controlled input (parent owns state and updates
-- via `onTextChanged`); omit `text` and pass `defaultText` for uncontrolled use.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Assets = require(script.Parent.assets)
local theme = require(script.Parent.theme)

type Props = {
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	layoutOrder: number?,
	zIndex: number?,
	transparency: number?,
	strokeThickness: number?,
	padding: number?,

	text: string?,
	defaultText: string?,
	placeholderText: string?,
	textSize: number?,
	textColor: Color3?,
	placeholderColor: Color3?,
	xAlignment: Enum.TextXAlignment?,
	yAlignment: Enum.TextYAlignment?,
	weight: Enum.FontWeight?,
	clearTextOnFocus: boolean?,
	multiLine: boolean?,
	textWrapped: boolean?,
	maxGraphemes: number?,

	onTextChanged: ((text: string) -> ())?,
	onFocused: (() -> ())?,
	onFocusLost: ((text: string, enterPressed: boolean) -> ())?,
}

local WHITE = Color3.fromRGB(255, 255, 255)

return function(props: Props)
	local padding = props.padding or theme.padding
	local font = Font.new(
		Assets.DISPLAY_FONT_ID,
		props.weight or Enum.FontWeight.Bold,
		Enum.FontStyle.Normal
	)

	local textBoxProps: { [string]: any } = {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		TextColor3 = props.textColor or WHITE,
		PlaceholderColor3 = props.placeholderColor or Color3.fromRGB(180, 180, 180),
		PlaceholderText = props.placeholderText,
		TextSize = props.textSize or theme.inputTextSize,
		FontFace = font,
		TextXAlignment = props.xAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = props.yAlignment or Enum.TextYAlignment.Center,
		ClearTextOnFocus = if props.clearTextOnFocus == nil then false else props.clearTextOnFocus,
		MultiLine = props.multiLine,
		TextWrapped = props.textWrapped,
		ZIndex = 1,
	}

	if props.text ~= nil then
		textBoxProps.Text = props.text
	elseif props.defaultText ~= nil then
		textBoxProps.Text = props.defaultText
	end

	if props.maxGraphemes ~= nil then
		textBoxProps.MaxVisibleGraphemes = props.maxGraphemes
	end

	if props.onTextChanged then
		textBoxProps[React.Change.Text] = function(rbx: TextBox)
			(props.onTextChanged :: any)(rbx.Text)
		end
	end
	if props.onFocused then
		textBoxProps[React.Event.Focused] = props.onFocused
	end
	if props.onFocusLost then
		textBoxProps[React.Event.FocusLost] = function(rbx: TextBox, enterPressed: boolean)
			(props.onFocusLost :: any)(rbx.Text, enterPressed)
		end
	end

	return React.createElement("Frame", {
		Size = props.size or theme.textFieldSize,
		Position = props.position or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = props.transparency or theme.glassTransparency,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, {
		UIStroke = React.createElement("UIStroke", {
			Thickness = props.strokeThickness or theme.strokeThickness,
			LineJoinMode = Enum.LineJoinMode.Miter,
		}),
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, padding),
			PaddingBottom = UDim.new(0, padding),
			PaddingLeft = UDim.new(0, padding),
			PaddingRight = UDim.new(0, padding),
		}),
		TextBox = React.createElement("TextBox", textBoxProps),
	})
end
