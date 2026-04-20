-- Pure/dumb React component. Takes the current note + a save callback;
-- owns no data fetching or networking. The container (NotesView) wires it up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Constants = require(script.Parent.Constants)

type Props = {
	note: string,
	onSave: (text: string) -> (),
}

return function(props: Props)
	local draft, setDraft = React.useState(props.note)

	-- Keep draft in sync when the saved note changes from the server.
	React.useEffect(function()
		setDraft(props.note)
	end, { props.note } :: { any })

	return React.createElement("Frame", {
		Size = UDim2.fromOffset(360, 200),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(32, 32, 40),
		BorderSizePixel = 0,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
		Padding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, 12),
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),

		Title = React.createElement("TextLabel", {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "Your note (persists across sessions)",
			Font = Enum.Font.GothamMedium,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		Saved = React.createElement("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(180, 180, 190),
			Text = `saved: {if props.note == "" then "<empty>" else props.note}`,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		Input = React.createElement("TextBox", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 36),
			BackgroundColor3 = Color3.fromRGB(52, 52, 62),
			BorderSizePixel = 0,
			TextColor3 = Color3.new(1, 1, 1),
			PlaceholderText = "Type something…",
			Text = draft,
			ClearTextOnFocus = false,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			[React.Change.Text] = function(rbx)
				local t = rbx.Text
				if #t > Constants.MAX_LENGTH then
					t = string.sub(t, 1, Constants.MAX_LENGTH)
					rbx.Text = t
				end
				setDraft(t)
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		}),

		Save = React.createElement("TextButton", {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = Color3.fromRGB(70, 130, 230),
			BorderSizePixel = 0,
			TextColor3 = Color3.new(1, 1, 1),
			Text = "Save",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			AutoButtonColor = true,
			[React.Event.Activated] = function()
				props.onSave(draft)
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),
		}),
	})
end
