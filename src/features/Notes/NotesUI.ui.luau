--!strict
-- Pure/dumb React component for the Notes feature. Takes the current saved
-- note + a save callback; owns no data fetching or networking. The container
-- (NotesView) wires it up to the PlayerData replica and the SetNote packet.
--
-- Renders the *contents* of a Notes window — a saved-value Panel on top
-- (shows what's currently persisted), a TextField for the draft, and a
-- centered Save button. The HUD wraps this in a `ui.Window` via
-- UIShowcase.HUD's `frameContents` map. A separate story (NotesUI.story.luau)
-- drives it with local state for UI Labs preview.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ui = require(ReplicatedStorage.Shared.ui)
local Constants = require(script.Parent.Constants)

-- Row sizing — tuned to fit a 600×500 Window without engaging the scrollbar.
--
--   Window 500 tall − topBarHeight 60                         = 440 scroll
--   ScrollingFrame UIPadding (14 top + 10 bottom)             =  24
--   ────────────────────────────────────────────────────────
--   Budget for NotesUI children                               = 416
--
-- Tally below:
--   Saved section  HEADING_HEIGHT 60 + HEADING_GAP 4 + PANEL 76 = 140
--   SECTION_GAP                                                =  16
--   Draft section  HEADING_HEIGHT 60 + HEADING_GAP 4 + INPUT 88 = 152
--   SECTION_GAP                                                =  16
--   SaveRow                                                    =  72
--   ───────────────────────────────────────────────────────────
--   Total                                                      = 396  ✓ (20px slack)
--
-- Heading text is the largest tier (theme.textSize) so the section labels
-- pop against the value rows; values and input land just below at 44 for
-- balance. Bump these together if you change the Window size — keep
-- `Total + 24 ≤ ScrollingFrame.AbsoluteSize.Y` or scroll engages.
local HEADING_TEXT_SIZE = 50
local VALUE_TEXT_SIZE = 44
local INPUT_TEXT_SIZE = 44
local HEADING_HEIGHT = HEADING_TEXT_SIZE + 10
local SAVED_PANEL_HEIGHT = 76
local INPUT_HEIGHT = 88
local SAVE_BUTTON_SIZE = UDim2.fromOffset(280, 72)
local HEADING_GAP = 4
local SECTION_GAP = 16

type Props = {
	note: string,
	onSave: (text: string) -> (),
}

-- Wrap a heading + its content row in a single layout block so the Window's
-- outer UIListLayout treats them as one unit (no surprise extra gap between
-- a heading and its panel when SECTION_GAP changes).
local function section(layoutOrder: number, heading: string, content: any): any
	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, HEADING_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		}),
		Heading = React.createElement(ui.Text, {
			text = heading,
			textSize = HEADING_TEXT_SIZE,
			weight = Enum.FontWeight.Heavy,
			shadow = true,
			xAlignment = Enum.TextXAlignment.Center,
			yAlignment = Enum.TextYAlignment.Bottom,
			size = UDim2.new(1, 0, 0, HEADING_HEIGHT),
			layoutOrder = 1,
		}),
		Content = React.cloneElement(content, { layoutOrder = 2 }),
	})
end

return function(props: Props)
	local draft, setDraft = React.useState(props.note)

	-- Re-sync the draft when the saved note changes from the server. The
	-- dependency array makes this fire only when `props.note` actually
	-- changes, so local typing isn't stomped by every re-render.
	React.useEffect(function()
		setDraft(props.note)
		return nil
	end, { props.note } :: { any })

	local savedLabel = if props.note == "" then "<empty>" else props.note

	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, SECTION_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		}),

		Saved = section(
			1,
			"Saved",
			React.createElement(ui.Panel, {
				size = UDim2.new(1, 0, 0, SAVED_PANEL_HEIGHT),
			}, {
				UIPadding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 14),
					PaddingRight = UDim.new(0, 14),
				}),
				Label = React.createElement(ui.Text, {
					text = savedLabel,
					textSize = VALUE_TEXT_SIZE,
					xAlignment = Enum.TextXAlignment.Center,
					yAlignment = Enum.TextYAlignment.Center,
					size = UDim2.fromScale(1, 1),
				}),
			})
		),

		Draft = section(
			2,
			"Draft",
			React.createElement(ui.TextField, {
				text = draft,
				placeholderText = "Type something…",
				size = UDim2.new(1, 0, 0, INPUT_HEIGHT),
				textSize = INPUT_TEXT_SIZE,
				xAlignment = Enum.TextXAlignment.Center,
				-- Server clamps the inbound packet too, but we mirror the cap
				-- here so the controlled text snaps back if a paste exceeds it.
				onTextChanged = function(text: string)
					if #text > Constants.MAX_LENGTH then
						text = string.sub(text, 1, Constants.MAX_LENGTH)
					end
					setDraft(text)
				end,
			})
		),

		-- Wrapper Frame so the Save Button can center independently of the
		-- enclosing UIListLayout's HorizontalFlex.Fill (which would otherwise
		-- stretch a bare Button across the full width).
		SaveRow = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, SAVE_BUTTON_SIZE.Y.Offset),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 3,
		}, {
			Save = React.createElement(ui.Button, {
				variant = "blue",
				text = "Save",
				size = SAVE_BUTTON_SIZE,
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				onClick = function()
					props.onSave(draft)
				end,
			}),
		}),
	})
end
