--!strict
-- Pure/dumb React component that renders the Settings registry. Takes the
-- already-grouped + sorted `sections` list, the current `values` map (from
-- PlayerData.Settings), an `onToggle` callback, and an optional `focusedId`
-- that briefly visually highlights one row (set by SettingsController.linkTo).
--
-- The container that wires this up to real data is SettingsView.client.luau.
-- A separate story file (SettingsUI.story.luau) feeds it mock sections so the
-- panel renders in UI Labs without a live PlayerData replica.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ui = require(ReplicatedStorage.Shared.Boil).ui
local Registry = require(script.Parent.Registry)

-- Layout tokens. Mirror the look of the original UIShowcase demo so swapping
-- the real Settings feature in doesn't visually drift.
local ROW_HEIGHT = 76
local ROW_INNER_PADDING = 14
local LABEL_TEXT_SIZE = 32
local CHECKBOX_SIZE = 44
local ROW_GAP = 12

local CATEGORY_ROW_HEIGHT = 50
local CATEGORY_TEXT_SIZE = 36
local CATEGORY_LINE_THICKNESS = 3
local CATEGORY_GAP = 14
local CATEGORY_TOP_MARGIN = 8

local EMPTY_TEXT_SIZE = 26

type Props = {
	sections: { Registry.Section },
	values: { [string]: any },
	onToggle: (id: string, value: boolean) -> (),
	focusedId: string?,
}

local function entryPanel(
	layoutOrder: number,
	label: string,
	control: any,
	focused: boolean
): any
	return React.createElement(ui.Panel, {
		size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		layoutOrder = layoutOrder,
		-- Lift the glass background a bit when this row is the link target so
		-- it visibly pulses out of the list.
		transparency = if focused then 0.5 else nil,
	}, {
		UIPadding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, ROW_INNER_PADDING),
			PaddingRight = UDim.new(0, ROW_INNER_PADDING),
		}),
		Label = React.createElement(ui.Text, {
			text = label,
			textSize = LABEL_TEXT_SIZE,
			xAlignment = Enum.TextXAlignment.Left,
			yAlignment = Enum.TextYAlignment.Center,
			size = UDim2.new(1, -CHECKBOX_SIZE - 20, 1, 0),
			position = UDim2.new(0, 0, 0.5, 0),
			anchorPoint = Vector2.new(0, 0.5),
		}),
		Control = control,
	})
end

local function categoryHeader(layoutOrder: number, title: string, isFirst: boolean): any
	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, CATEGORY_ROW_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
	}, {
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, if isFirst then 0 else CATEGORY_TOP_MARGIN),
		}),
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, CATEGORY_GAP),
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		}),
		-- Title wrapped in a Frame with UIFlexItem(None) so it opts out of
		-- flex distribution and the line takes only the remaining width.
		Title = React.createElement("Frame", {
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 0,
		}, {
			UIFlexItem = React.createElement("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.None,
			}),
			Label = React.createElement(ui.Text, {
				text = title,
				textSize = CATEGORY_TEXT_SIZE,
				xAlignment = Enum.TextXAlignment.Left,
				yAlignment = Enum.TextYAlignment.Center,
				automaticSize = Enum.AutomaticSize.X,
				size = UDim2.new(0, 0, 1, 0),
			}),
		}),
		Line = React.createElement("Frame", {
			Size = UDim2.new(0, 0, 0, CATEGORY_LINE_THICKNESS),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			LayoutOrder = 1,
		}, {
			UIFlexItem = React.createElement("UIFlexItem", {
				FlexMode = Enum.UIFlexMode.Fill,
			}),
		}),
	})
end

local function emptyState(): any
	return React.createElement(ui.Text, {
		text = "No settings registered yet.",
		textSize = EMPTY_TEXT_SIZE,
		xAlignment = Enum.TextXAlignment.Center,
		yAlignment = Enum.TextYAlignment.Center,
		size = UDim2.new(1, 0, 0, 80),
		layoutOrder = 1,
	})
end

return function(props: Props)
	local children: { [string]: any } = {
		UIListLayout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, ROW_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		}),
	}

	local hasAny = false
	local order = 0
	local seenCategory = false

	for _, section in props.sections do
		if #section.settings == 0 then
			-- Skip categories with no settings rather than leaving an
			-- orphaned heading + line floating above empty space.
			continue
		end
		hasAny = true
		order += 1
		children[`Cat_{section.category.id}`] =
			categoryHeader(order, section.category.title, not seenCategory)
		seenCategory = true

		for _, def in section.settings do
			order += 1
			if def.kind == "toggle" then
				local toggleDef = def :: Registry.ToggleSetting
				local current: any = props.values[toggleDef.id]
				if current == nil then
					current = toggleDef.default
				end
				children[`Setting_{toggleDef.id}`] = entryPanel(
					order,
					toggleDef.label,
					React.createElement(ui.Checkbox, {
						variant = (toggleDef.variant or "white") :: any,
						checked = current,
						onToggle = function(next: boolean)
							props.onToggle(toggleDef.id, next)
						end,
						size = UDim2.fromOffset(CHECKBOX_SIZE, CHECKBOX_SIZE),
						position = UDim2.new(1, 0, 0.5, 0),
						anchorPoint = Vector2.new(1, 0.5),
					}),
					props.focusedId == toggleDef.id
				)
			end
		end
	end

	if not hasAny then
		children.Empty = emptyState()
	end

	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, children)
end
