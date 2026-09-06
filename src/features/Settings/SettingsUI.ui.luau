--!strict
-- Renders the Settings registry: a category header per section, then one row per
-- setting. Pure and dumb — it takes the already-grouped `sections`, the current
-- `values` map, an `onToggle` intent, and an optional `focusedId` to highlight
-- one row (set by SettingsController.linkTo).
--
-- SettingsView.client.luau wires it to real data; SettingsUI.story.luau feeds it
-- mock sections so it renders in UI Labs without a live replica.
--
-- Every size here comes from the CONTRACT tokens — `theme.type` and
-- `theme.space` — and nothing else.
--
-- That restriction is the point. This file used to open with ten local constants
-- (ROW_HEIGHT = 76, LABEL_TEXT_SIZE = 32 …) that existed in no theme, so the
-- screen never matched the rest of the UI. The first fix swapped them for
-- `theme.rowHeight` and `theme.checkboxSize`, which was still wrong: those are
-- skin-PRIVATE tokens. Gem spells `checkboxSize` as a number and slop spells it
-- as a UDim2, so `theme.checkboxSize + theme.space.md` threw
-- "UDim2 expected, got number" the moment the default skin changed — and slop has
-- no `rowHeight` at all.
--
-- A feature is written against the contract, never against one skin's tokens.
--
-- The row therefore DERIVES one control size from the type and space scales and
-- uses it for both the row's height and the checkbox's square. Letting the
-- checkbox size itself was the previous attempt and it was worse: slop's default
-- checkbox is 66px against a 55px row, so the control hung out of its own row,
-- and the label — boxed to the same short height — scaled down to something
-- unreadable under a scale-to-fit skin. Deriving both from one number means they
-- cannot disagree, whatever the skin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ui = require(ReplicatedStorage.Shared.Boil).ui
local Registry = require(script.Parent.Registry)

type Props = {
	sections: { Registry.Section },
	values: { [string]: any },
	onToggle: (id: string, value: boolean) -> (),
	focusedId: string?,
}

-- The interactive control's square, and the height of the label beside it. Built
-- from `heading` rather than `body` so the control is a comfortable tap target
-- and the label has room to render at its full role size under a scale-to-fit
-- skin. The primitives still floor this at the real-pixel minimum tap target.
local function controlSize(theme: any): number
	return theme.type.heading + theme.space.md * 2
end

-- Row height: the control, plus even breathing room above and below it.
local function rowHeight(theme: any): number
	return controlSize(theme) + theme.space.md * 2
end

-- One setting: a glass row with its label on the left and its control on the
-- right. The Panel's own `padding` prop supplies the inset — no hand-built
-- UIPadding at the call site.
local function settingRow(theme: any, layoutOrder: number, label: string, control: any, focused: boolean): any
	return React.createElement(ui.Panel, {
		size = UDim2.new(1, 0, 0, rowHeight(theme)),
		layoutOrder = layoutOrder,
		padding = "md",
		-- Lift the glass when this row is the link target so it visibly pulses
		-- out of the list.
		transparency = if focused then 0.5 else nil,
	}, {
		Label = React.createElement(ui.Text, {
			text = label,
			role = "body",
			xAlignment = Enum.TextXAlignment.Left,
			truncate = true,
			-- Reserve the control's square plus a gap; take the full row height so
			-- a scale-to-fit skin has vertical room to render the label at its
			-- role size instead of shrinking it to a sliver.
			size = UDim2.new(1, -(controlSize(theme) + theme.space.md), 1, 0),
			position = UDim2.new(0, 0, 0.5, 0),
			anchorPoint = Vector2.new(0, 0.5),
		}),
		Control = control,
	})
end

-- A category heading: the title, then a rule filling the remaining width.
local function categoryHeader(theme: any, layoutOrder: number, title: string, isFirst: boolean): any
	return React.createElement(ui.Row, {
		gap = "md",
		-- Extra breathing room above every heading but the first, so categories
		-- read as groups rather than one long list.
		size = UDim2.new(1, 0, 0, theme.type.heading + (if isFirst then theme.space.sm else theme.space.xl)),
		layoutOrder = layoutOrder,
		verticalAlignment = Enum.VerticalAlignment.Bottom,
		horizontalAlignment = Enum.HorizontalAlignment.Left,
	}, {
		Title = React.createElement(ui.Text, {
			text = title,
			role = "heading",
			xAlignment = Enum.TextXAlignment.Left,
			yAlignment = Enum.TextYAlignment.Bottom,
			automaticSize = Enum.AutomaticSize.X,
			size = UDim2.new(0, 0, 0, theme.type.heading + theme.space.xs),
			layoutOrder = 1,
		}, {
			-- Opt the title out of flex distribution so the rule takes exactly
			-- the leftover width instead of splitting it.
			UIFlexItem = React.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.None }),
		}),
		Rule = React.createElement("Frame", {
			-- A hairline, derived from the smallest space step rather than from a
			-- skin-private stroke token that not every skin defines.
			Size = UDim2.new(0, 0, 0, math.max(1, math.floor(theme.space.xs / 2))),
			BackgroundColor3 = theme.textColor,
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			LayoutOrder = 2,
		}, {
			UIFlexItem = React.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		}),
	})
end

return function(props: Props)
	local theme = ui.useSkin().theme

	local children: { [string]: any } = {}
	local hasAny = false
	local order = 0
	local seenCategory = false

	for _, section in props.sections do
		-- Skip empty categories rather than leaving an orphaned heading and rule
		-- floating above nothing.
		if #section.settings == 0 then
			continue
		end
		hasAny = true
		order += 1
		children[`Cat_{section.category.id}`] =
			categoryHeader(theme, order, section.category.title, not seenCategory)
		seenCategory = true

		for _, def in section.settings do
			if def.kind ~= "toggle" then
				continue
			end
			order += 1

			local toggle = def :: Registry.ToggleSetting
			local current: any = props.values[toggle.id]
			if current == nil then
				current = toggle.default
			end

			children[`Setting_{toggle.id}`] = settingRow(
				theme,
				order,
				toggle.label,
				React.createElement(ui.Checkbox, {
					variant = toggle.variant or "secondary",
					checked = current,
					onToggle = function(next: boolean)
						props.onToggle(toggle.id, next)
					end,
					-- Square, matching the height the row reserved for it. Explicit
					-- because a skin's own default can be taller than the row.
					size = UDim2.fromOffset(controlSize(theme), controlSize(theme)),
					position = UDim2.new(1, 0, 0.5, 0),
					anchorPoint = Vector2.new(1, 0.5),
				}),
				props.focusedId == toggle.id
			)
		end
	end

	if not hasAny then
		children.Empty = React.createElement(ui.Text, {
			text = "No settings registered yet. A feature adds one by dropping a Settings.luau beside its init.",
			role = "body",
			color = theme.mutedText,
			wrap = true,
			size = UDim2.new(1, 0, 0, theme.type.body * 4),
			layoutOrder = 1,
		})
	end

	return React.createElement(ui.Stack, {
		gap = "sm",
		size = UDim2.new(1, 0, 0, 0),
		automaticSize = Enum.AutomaticSize.Y,
		fillHorizontal = true,
	}, children)
end
