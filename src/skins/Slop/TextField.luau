--!strict
-- Slop TextField: a recessed glass box (lighter than the other glass surfaces so
-- the input reads as sunken) holding a scale-to-fit TextBox with an outlined
-- glyph. Controlled when `text` is supplied, uncontrolled via `defaultText`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Boil = require(ReplicatedStorage.Shared.Boil)
local parts = require(script.Parent.parts)
local theme = require(script.Parent.theme)
-- Shared space-role resolver. Module scope is safe: the skin registry discovers
-- this folder lazily, so requiring the kit here can't re-enter Slop.
local tokens = Boil.ui.tokens

-- Input height as a fraction of the field, leaving room for the glyph outline.
local INPUT_HEIGHT = 0.6

return function(props: Boil.TextFieldProps)
	-- Caps are enforced in absolute pixels, so they need the viewport scale to
	-- mean reference pixels. See parts.capFor.
	local scale = Boil.ui.useScale()
	local strokeThickness = props.strokeThickness or theme.strokeThickness
	-- Horizontal only: the text runs up against the side borders, so those sides
	-- clear the inner-drawn outline. Vertically the box is already inset by
	-- INPUT_HEIGHT, and adding padding on top of that squeezes the text.
	local padding = tokens.resolveSpace(theme.space, props.padding, theme.space.md) + strokeThickness

	local boxProps: { [string]: any } = {
		-- Not full height: under TextScaled the box height *is* the text size, so
		-- a full-height box leaves the glyph outline nowhere to draw and it gets
		-- cut off at the top and bottom.
		Size = UDim2.fromScale(1, INPUT_HEIGHT),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Text = props.text,
		PlaceholderText = props.placeholderText,
		PlaceholderColor3 = props.placeholderColor or theme.placeholderColor,
		TextColor3 = props.textColor or theme.textColor,
		TextScaled = true,
		TextWrapped = props.textWrapped,
		FontFace = theme.font(props.weight),
		TextXAlignment = props.xAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = props.yAlignment or Enum.TextYAlignment.Center,
		ClearTextOnFocus = if props.clearTextOnFocus ~= nil then props.clearTextOnFocus else false,
		MultiLine = props.multiLine,
		ZIndex = 3,
	}

	if props.text == nil and props.defaultText ~= nil then
		boxProps.Text = props.defaultText
	end

	if props.maxGraphemes then
		boxProps[React.Change.Text] = function(rbx: TextBox)
			local length = utf8.len(rbx.Text)
			if length and length > (props.maxGraphemes :: number) then
				rbx.Text = string.sub(rbx.Text, 1, props.maxGraphemes)
			end
			if props.onTextChanged then
				props.onTextChanged(rbx.Text)
			end
		end
	elseif props.onTextChanged then
		boxProps[React.Change.Text] = function(rbx: TextBox)
			(props.onTextChanged :: any)(rbx.Text)
		end
	end

	if props.onFocused then
		boxProps[React.Event.Focused] = props.onFocused
	end

	boxProps[React.Event.FocusLost] = function(rbx: TextBox, enterPressed: boolean)
		if props.onFocusLost then
			props.onFocusLost(rbx.Text, enterPressed)
		end
	end

	return React.createElement("Frame", {
		Size = props.size or theme.textFieldSize,
		Position = props.position,
		AnchorPoint = props.anchorPoint,
		BackgroundColor3 = theme.inputSurface,
		BackgroundTransparency = props.transparency or theme.glassTransparency,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, {
		InnerGlow = parts.innerGlow(),
		Outline = parts.outline(strokeThickness),

		UIPadding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, padding),
			PaddingRight = UDim.new(0, padding),
		}),

		Input = React.createElement("TextBox", boxProps, {
			TextStroke = parts.textStroke(),
			SizeCap = parts.textSizeCap(parts.capFor(props.textSize or props.role, theme.roles.input, scale)),
		}),
	})
end
