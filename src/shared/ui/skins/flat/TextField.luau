--!strict
-- Flat TextField: gray box + a TextBox. Controlled when `text` is supplied,
-- uncontrolled (via `defaultText`) otherwise.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local contract = require(ReplicatedStorage.Shared.ui.contract)
local theme = require(script.Parent.theme)

return function(props: contract.TextFieldProps)
	local padding = props.padding or theme.padding

	local boxProps: { [string]: any } = {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = props.text,
		PlaceholderText = props.placeholderText,
		PlaceholderColor3 = props.placeholderColor or theme.mutedText,
		TextColor3 = props.textColor or theme.textColor,
		TextSize = props.textSize or theme.textSize,
		FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", props.weight or Enum.FontWeight.Medium),
		TextXAlignment = props.xAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = props.yAlignment or Enum.TextYAlignment.Center,
		ClearTextOnFocus = if props.clearTextOnFocus ~= nil then props.clearTextOnFocus else false,
		MultiLine = props.multiLine,
		TextWrapped = props.textWrapped,
		ClipsDescendants = true,
	}
	if props.text == nil and props.defaultText ~= nil then
		boxProps.Text = props.defaultText
	end
	if props.maxGraphemes then
		boxProps[React.Change.Text] = function(rbx: TextBox)
			if utf8.len(rbx.Text) and (utf8.len(rbx.Text) :: number) > (props.maxGraphemes :: number) then
				rbx.Text = string.sub(rbx.Text, 1, props.maxGraphemes)
			end
			if props.onTextChanged then
				props.onTextChanged(rbx.Text)
			end
		end
	elseif props.onTextChanged then
		boxProps[React.Change.Text] = function(rbx: TextBox)
			props.onTextChanged(rbx.Text)
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
		BackgroundColor3 = theme.surfaceDeep,
		BackgroundTransparency = props.transparency or 0,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		ZIndex = props.zIndex,
	}, {
		UICorner = React.createElement("UICorner", { CornerRadius = theme.cornerRadius }),
		UIStroke = React.createElement("UIStroke", {
			Thickness = props.strokeThickness or theme.strokeThickness,
			Color = theme.border,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, padding),
			PaddingRight = UDim.new(0, padding),
		}),
		Box = React.createElement("TextBox", boxProps),
	})
end
