--!nonstrict
-- UI Labs story: faithful recreation of a "Rebirth" screen so we can eyeball
-- proportions, sizing, and padding for a rebirth/reset flow. Composes
-- existing shared primitives — no new components shipped.
--
-- Layout overview:
--   - ui.Window with title "Rebirth" — standard chrome, only `size` overridden.
--   - Subtitle ("Rebirth keeps your X!") — joined from the kept-labels list.
--   - Multiplier row: before-cell + ► + after-cell, "after" in gold.
--   - "Requirements" left-aligned heading.
--   - Requirements panel: horizontal row of icon-over-amount cells.
--   - Action row: blue REBIRTH + yellow Skip Rebirth (optional cost badge).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

local theme = ui.theme

-- Gold accent for the "after" multiplier value — matches the reference where
-- the post-rebirth number reads as a positive uplift.
local GOLD_TEXT = Color3.fromRGB(255, 209, 64)

------------------------------------------------------------------------------
-- Layout tokens
------------------------------------------------------------------------------
local SUBTITLE_HEIGHT = 40
local SUBTITLE_TEXT_SIZE = theme.textSizeRegular

local MULTIPLIER_HEIGHT = 70
local MULTIPLIER_ARROW_WIDTH = 48
local MULTIPLIER_TEXT_SIZE = theme.textSizeRegular

local HEADING_HEIGHT = 36
local HEADING_TEXT_SIZE = theme.textSizeRegular

local REQUIREMENTS_PANEL_HEIGHT = 150
local REQ_ICON_SIZE = 80
local REQ_SLOT_WIDTH = 120
local REQUIREMENT_LABEL_SIZE = theme.textSizeSmall

local ACTION_HEIGHT = 60
local ACTION_BUTTON_GAP = 12
local ACTION_BUTTON_TEXT_SIZE = theme.textSizeRegular

local SECTION_GAP = 12

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------
local function formatKeptLine(labels: { string }): string
	local n = #labels
	if n == 0 then
		return "Rebirth keeps your progress!"
	elseif n == 1 then
		return `Rebirth keeps your {labels[1]}!`
	elseif n == 2 then
		return `Rebirth keeps your {labels[1]} and {labels[2]}!`
	end
	local list = ""
	for i = 1, n - 1 do
		list = list .. labels[i] .. ", "
	end
	list = list .. "and " .. labels[n]
	return `Rebirth keeps your {list}!`
end

-- Icon-on-left + value-on-right cell. Used by both multiplier panels.
local function iconValueCell(props: { icon: string?, value: string, valueColor: Color3? }): any
	local children: { [string]: any } = {
		UIPadding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, theme.padding + theme.strokeThickness),
			PaddingRight = UDim.new(0, theme.padding + theme.strokeThickness),
			PaddingTop = UDim.new(0, theme.tightPadding),
			PaddingBottom = UDim.new(0, theme.tightPadding),
		}),
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, theme.itemSpacing),
			HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
		}),
		Value = React.createElement(ui.Text, {
			text = props.value,
			textSize = MULTIPLIER_TEXT_SIZE,
			color = props.valueColor,
			weight = Enum.FontWeight.Heavy,
			shadow = true,
			xAlignment = Enum.TextXAlignment.Right,
			yAlignment = Enum.TextYAlignment.Center,
			size = UDim2.fromOffset(80, 40),
			layoutOrder = 2,
		}),
	}

	if props.icon then
		children.Icon = React.createElement("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = props.icon,
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = 1,
		}, {
			UIAspectRatioConstraint = React.createElement("UIAspectRatioConstraint", {}),
			UIFlexItem = React.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.None }),
		})
	end

	return React.createElement(ui.Panel, {
		size = UDim2.new(1, 0, 1, 0),
	}, children)
end

------------------------------------------------------------------------------
-- Sections
------------------------------------------------------------------------------
local function subtitleSection(layoutOrder: number, labels: { string }): any
	return React.createElement(ui.Text, {
		text = formatKeptLine(labels),
		textSize = SUBTITLE_TEXT_SIZE,
		weight = Enum.FontWeight.Heavy,
		shadow = true,
		size = UDim2.new(1, 0, 0, SUBTITLE_HEIGHT),
		layoutOrder = layoutOrder,
	})
end

local function multiplierSection(
	layoutOrder: number,
	rewardIcon: string?,
	beforeText: string,
	afterText: string
): any
	-- Half-width cells; the arrow and its 2 × itemSpacing flanks subtract
	-- equally from each so the row stays symmetric.
	local halfMinus = (MULTIPLIER_ARROW_WIDTH + theme.itemSpacing * 2) / 2

	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, MULTIPLIER_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, theme.itemSpacing),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Before = React.createElement("Frame", {
			Size = UDim2.new(0.5, -halfMinus, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
		}, {
			Panel = iconValueCell({ icon = rewardIcon, value = beforeText }),
		}),
		Arrow = React.createElement(ui.Text, {
			text = "►",
			textSize = MULTIPLIER_TEXT_SIZE,
			weight = Enum.FontWeight.Heavy,
			shadow = true,
			size = UDim2.fromOffset(MULTIPLIER_ARROW_WIDTH, MULTIPLIER_HEIGHT),
			layoutOrder = 2,
		}),
		After = React.createElement("Frame", {
			Size = UDim2.new(0.5, -halfMinus, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 3,
		}, {
			Panel = iconValueCell({ icon = rewardIcon, value = afterText, valueColor = GOLD_TEXT }),
		}),
	})
end

local function requirementsHeading(layoutOrder: number): any
	return React.createElement(ui.Text, {
		text = "Requirements",
		textSize = HEADING_TEXT_SIZE,
		weight = Enum.FontWeight.Heavy,
		shadow = true,
		size = UDim2.new(1, 0, 0, HEADING_HEIGHT),
		xAlignment = Enum.TextXAlignment.Left,
		yAlignment = Enum.TextYAlignment.Bottom,
		layoutOrder = layoutOrder,
	})
end

local function requirementsPanel(layoutOrder: number, requirements: { any }): any
	local children: { [string]: any } = {
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, theme.padding + theme.strokeThickness),
			PaddingBottom = UDim.new(0, theme.padding),
			PaddingLeft = UDim.new(0, theme.padding + theme.strokeThickness),
			PaddingRight = UDim.new(0, theme.padding + theme.strokeThickness),
		}),
	}

	if #requirements == 0 then
		children.Empty = React.createElement(ui.Text, {
			text = "No requirements!",
			textSize = REQUIREMENT_LABEL_SIZE,
			weight = Enum.FontWeight.Heavy,
			shadow = true,
			size = UDim2.fromScale(1, 1),
		})
	else
		children.UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, theme.contentSpacing),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})

		for i, req in ipairs(requirements) do
			children[req.id] = React.createElement("Frame", {
				Size = UDim2.fromOffset(
					REQ_SLOT_WIDTH,
					REQUIREMENTS_PANEL_HEIGHT - (theme.padding + theme.strokeThickness) * 2
				),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = i,
			}, {
				UIListLayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, theme.tightPadding),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Icon = req.icon and React.createElement("ImageLabel", {
					Size = UDim2.fromOffset(REQ_ICON_SIZE, REQ_ICON_SIZE),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Image = req.icon,
					ScaleType = Enum.ScaleType.Fit,
					LayoutOrder = 1,
				}),
				Amount = React.createElement(ui.Text, {
					text = req.amount,
					textSize = REQUIREMENT_LABEL_SIZE,
					weight = Enum.FontWeight.Heavy,
					shadow = true,
					size = UDim2.new(1, 0, 0, REQUIREMENT_LABEL_SIZE + 8),
					layoutOrder = 2,
				}),
			})
		end
	end

	return React.createElement(ui.Panel, {
		size = UDim2.new(1, 0, 0, REQUIREMENTS_PANEL_HEIGHT),
		layoutOrder = layoutOrder,
	}, children)
end

local function actionRow(
	layoutOrder: number,
	showSkip: boolean,
	skipCost: string?,
	skipCostIcon: string?
): any
	local children: { [string]: any } = {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, ACTION_BUTTON_GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill,
		}),

		Rebirth = React.createElement(ui.Button, {
			variant = "blue",
			text = "REBIRTH",
			textSize = ACTION_BUTTON_TEXT_SIZE,
			textWeight = Enum.FontWeight.Heavy,
			size = UDim2.new(0, 0, 1, 0),
			layoutOrder = 1,
			onClick = function()
				print("[RebirthUI.story] rebirth")
			end,
		}),
	}

	if showSkip then
		-- Wrap so the cost badge can sit on top via ZIndex (per the
		-- overlay-via-zindex memory) without joining the row's UIListLayout.
		local skipChildren: { [string]: any } = {
			Button = React.createElement(ui.Button, {
				variant = "yellow",
				text = "Skip Rebirth",
				textSize = ACTION_BUTTON_TEXT_SIZE,
				textWeight = Enum.FontWeight.Heavy,
				size = UDim2.fromScale(1, 1),
				zIndex = 1,
				onClick = function()
					print("[RebirthUI.story] skip rebirth")
				end,
			}),
		}

		if skipCost ~= nil then
			skipChildren.CostBadge = React.createElement(ui.Badge, {
				variant = "yellow",
				text = skipCost,
				textSize = theme.textSizeSmall,
				icon = skipCostIcon,
				size = UDim2.fromOffset(80, 32),
				position = UDim2.new(1, 6, 0, -6),
				anchorPoint = Vector2.new(1, 0),
				zIndex = 5,
			})
		end

		children.SkipWrapper = React.createElement("Frame", {
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 2,
		}, skipChildren)
	end

	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 0, ACTION_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,
	}, children)
end

------------------------------------------------------------------------------
-- Story
------------------------------------------------------------------------------
return {
	summary = "Rebirth screen recreation. Subtitle + before/after multiplier + requirements + REBIRTH/Skip Rebirth buttons. Tweak the controls to preview empty / no-skip variants.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		windowWidth = UILabs.Slider(560, 360, 900, 10),
		windowHeight = UILabs.Slider(490, 320, 700, 10),
		keptLabel = "rockets",
		showSkipButton = true,
		skipCost = "39",
		emptyRequirements = false,
	},

	story = function(props)
		local c = props.controls

		local keptLabels: { string } = if c.keptLabel == "" then {} else { c.keptLabel }

		local requirements
		if c.emptyRequirements then
			requirements = {}
		else
			requirements = {
				{ id = "brainrot", icon = ui.assets.Brainrots.tralaleroTralala, amount = "1x" },
				{ id = "cash-1", icon = ui.assets.Icons.bandOfCash, amount = "$200" },
				{ id = "cash-2", icon = ui.assets.Icons.bandOfCash, amount = "$200" },
			}
		end

		local content = React.createElement("Frame", {
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

			Subtitle = subtitleSection(1, keptLabels),
			Multiplier = multiplierSection(2, ui.assets.Icons.bandOfCash, "1x", "2x"),
			RequirementsHeading = requirementsHeading(3),
			Requirements = requirementsPanel(4, requirements),
			Actions = actionRow(
				5,
				c.showSkipButton,
				if c.skipCost == "" then nil else c.skipCost,
				ui.assets.Icons.wheel
			),
		})

		return React.createElement(ui.Window, {
			size = UDim2.fromOffset(c.windowWidth, c.windowHeight),
			title = "Rebirth",
			icon = ui.assets.Icons.rebirth,
			titleVariant = "red",
			onClose = function()
				print("[RebirthUI.story] close")
			end,
		}, {
			Content = content,
		})
	end,
}
