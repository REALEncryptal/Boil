--!nonstrict
-- UI Labs story: prototype of an "Upgrades" screen — a stack of upgrade rows
-- (Dash, Speed, Storage, Luck), each showing its current level, a before ► after
-- stat preview, and an UPGRADE button with a cost badge. Clicking UPGRADE is
-- live: the level ticks up, the stat preview advances, and the cost grows by
-- the multiplier — so the purchase loop can be felt directly in UI Labs.
-- Composes existing shared primitives — no new components shipped.
--
-- Layout overview (per row):
--   [icon | name over "Lv. N"]      [now ► next]      [$cost button]
--   The level is a muted text label under the name — deliberately not a gem
--   surface so nothing on the left reads as clickable. Maxed rows swap the
--   preview for a gold "MAX" and the button for a white MAXED no-op.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.Boil).ui

local theme = ui.theme

-- Gold accent for the "after" stat value and the MAX marker — same uplift
-- reading as the Rebirth story's post-rebirth multiplier.
local GOLD_TEXT = Color3.fromRGB(255, 209, 64)

------------------------------------------------------------------------------
-- Layout tokens
------------------------------------------------------------------------------
local ROW_HEIGHT = 84
local ROW_ICON_SIZE = 56

local NAME_ZONE_WIDTH = 260
local NAME_TEXT_WIDTH = 190
local NAME_TEXT_SIZE = theme.textSizeLarge
local NAME_TEXT_HEIGHT = 46

local LEVEL_TEXT_SIZE = theme.textSizeSmall
local LEVEL_TEXT_HEIGHT = 26
local LEVEL_TEXT_COLOR = Color3.fromRGB(185, 195, 215)

local STAT_VALUE_WIDTH = 52
local STAT_ARROW_WIDTH = 24
local STAT_TEXT_SIZE = theme.textSizeRegular

local BUTTON_ZONE_WIDTH = 150
local BUTTON_HEIGHT = 56
local BUTTON_TEXT_SIZE = theme.textSizeRegular

------------------------------------------------------------------------------
-- Upgrade definitions (prototype data — a real feature would own these in
-- its Constants/Registry, not in the story)
------------------------------------------------------------------------------
local UPGRADES = {
	{ id = "Dash", name = "Dash", icon = ui.assets.Icons.rocket, variant = "blue", baseCost = 50, baseStat = 1, statStep = 1 },
	{ id = "Speed", name = "Speed", icon = ui.assets.Icons.wheel, variant = "yellow", baseCost = 75, baseStat = 16, statStep = 2 },
	{ id = "Storage", name = "Storage", icon = ui.assets.Icons.shoppingBasket, variant = "green", baseCost = 100, baseStat = 10, statStep = 5 },
	{ id = "Luck", name = "Luck", icon = ui.assets.Icons.questionMark, variant = "purple", baseCost = 150, baseStat = 1, statStep = 1 },
}

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------
local function costFor(baseCost: number, multiplier: number, level: number): number
	return math.floor(baseCost * multiplier ^ (level - 1) + 0.5)
end

local function statAt(upgrade, level: number): number
	return upgrade.baseStat + upgrade.statStep * (level - 1)
end

------------------------------------------------------------------------------
-- Row zones
------------------------------------------------------------------------------
-- Left: icon + a two-line label block (name over a muted "Lv. N").
local function nameZone(upgrade, level: number): any
	return React.createElement(ui.Row, {
		gap = theme.itemSpacing,
		horizontalAlignment = Enum.HorizontalAlignment.Left,
		size = UDim2.new(0, NAME_ZONE_WIDTH, 1, 0),
		layoutOrder = 1,
	}, {
		Icon = React.createElement("ImageLabel", {
			Size = UDim2.fromOffset(ROW_ICON_SIZE, ROW_ICON_SIZE),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = upgrade.icon,
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = 1,
		}),
		Labels = React.createElement(ui.Stack, {
			horizontalAlignment = Enum.HorizontalAlignment.Left,
			verticalAlignment = Enum.VerticalAlignment.Center,
			size = UDim2.new(0, NAME_TEXT_WIDTH, 1, 0),
			layoutOrder = 2,
		}, {
			Name = React.createElement(ui.Text, {
				text = upgrade.name,
				textSize = NAME_TEXT_SIZE,
				weight = Enum.FontWeight.Heavy,
				shadow = true,
				xAlignment = Enum.TextXAlignment.Left,
				size = UDim2.new(1, 0, 0, NAME_TEXT_HEIGHT),
				layoutOrder = 1,
			}),
			Level = React.createElement(ui.Text, {
				text = `Lv. {level}`,
				textSize = LEVEL_TEXT_SIZE,
				color = LEVEL_TEXT_COLOR,
				weight = Enum.FontWeight.Heavy,
				xAlignment = Enum.TextXAlignment.Left,
				size = UDim2.new(1, 0, 0, LEVEL_TEXT_HEIGHT),
				layoutOrder = 2,
			}),
		}),
	})
end

-- Middle: "now ► next" stat preview, or a gold MAX when capped. The zone
-- flex-fills the space between the name and the button; its content hugs
-- the zone's left edge so it reads as a column, not as floating chrome.
local statPreview

local function statZone(upgrade, level: number, isMaxed: boolean): any
	local content
	if isMaxed then
		content = React.createElement(ui.Text, {
			text = "MAX",
			textSize = STAT_TEXT_SIZE,
			color = GOLD_TEXT,
			weight = Enum.FontWeight.Heavy,
			shadow = true,
			xAlignment = Enum.TextXAlignment.Left,
			size = UDim2.fromScale(1, 1),
		})
	else
		content = statPreview(upgrade, level)
	end

	return React.createElement("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 2,
	}, {
		UIFlexItem = React.createElement("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }),
		Content = content,
	})
end

-- The "now ► next" cluster itself, hugging the left edge of the flex zone
-- (right after the name column) rather than drifting toward the button.
function statPreview(upgrade, level: number): any
	return React.createElement(ui.Row, {
		gap = theme.itemSpacing,
		horizontalAlignment = Enum.HorizontalAlignment.Left,
		size = UDim2.fromScale(1, 1),
	}, {
		Now = React.createElement(ui.Text, {
			text = tostring(statAt(upgrade, level)),
			textSize = STAT_TEXT_SIZE,
			weight = Enum.FontWeight.Heavy,
			shadow = true,
			xAlignment = Enum.TextXAlignment.Right,
			size = UDim2.new(0, STAT_VALUE_WIDTH, 1, 0),
			layoutOrder = 1,
		}),
		Arrow = React.createElement(ui.Text, {
			text = "►",
			textSize = theme.textSizeSmall,
			weight = Enum.FontWeight.Heavy,
			shadow = true,
			size = UDim2.new(0, STAT_ARROW_WIDTH, 1, 0),
			layoutOrder = 2,
		}),
		Next = React.createElement(ui.Text, {
			text = tostring(statAt(upgrade, level + 1)),
			textSize = STAT_TEXT_SIZE,
			color = GOLD_TEXT,
			weight = Enum.FontWeight.Heavy,
			shadow = true,
			xAlignment = Enum.TextXAlignment.Left,
			size = UDim2.new(0, STAT_VALUE_WIDTH, 1, 0),
			layoutOrder = 3,
		}),
	})
end

-- Right: green buy button labeled with the price. Maxed rows keep the same
-- button but flip to MAXED + the Button primitive's disabled dim.
local function buttonZone(cost: number, isMaxed: boolean, onUpgrade: () -> ()): any
	return React.createElement("Frame", {
		Size = UDim2.new(0, BUTTON_ZONE_WIDTH, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = 3,
	}, {
		Button = React.createElement(ui.Button, {
			variant = "green",
			text = if isMaxed then "MAXED" else `${cost}`,
			textSize = BUTTON_TEXT_SIZE,
			textWeight = Enum.FontWeight.Heavy,
			size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
			position = UDim2.fromScale(0, 0.5),
			anchorPoint = Vector2.new(0, 0.5),
			disabled = isMaxed,
			onClick = onUpgrade,
		}),
	})
end

------------------------------------------------------------------------------
-- Row
------------------------------------------------------------------------------
local function upgradeRow(props: {
	upgrade: any,
	level: number,
	maxLevel: number,
	costMultiplier: number,
	layoutOrder: number,
	onUpgrade: () -> (),
}): any
	local upgrade = props.upgrade
	local isMaxed = props.level >= props.maxLevel
	local cost = costFor(upgrade.baseCost, props.costMultiplier, props.level)

	return React.createElement(ui.Panel, {
		size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		layoutOrder = props.layoutOrder,
	}, {
		UIPadding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, theme.padding + theme.strokeThickness),
			PaddingRight = UDim.new(0, theme.padding + theme.strokeThickness),
		}),
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		NameZone = nameZone(upgrade, props.level),
		StatZone = statZone(upgrade, props.level, isMaxed),
		ButtonZone = buttonZone(cost, isMaxed, props.onUpgrade),
	})
end

------------------------------------------------------------------------------
-- Story
------------------------------------------------------------------------------
return {
	summary = "Upgrades screen prototype. One row per upgrade: name over a muted Lv. label, now ► next stat preview, and a buy button labeled with the price. Clicks are live — level, preview, and price all advance; rows cap at maxLevel and flip to MAXED.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		windowWidth = UILabs.Slider(620, 440, 1100, 10),
		windowHeight = UILabs.Slider(560, 360, 800, 10),
		costMultiplier = UILabs.Slider(1.6, 1.1, 3, 0.1),
		maxLevel = UILabs.Slider(5, 2, 20, 1),
	},

	story = function(props)
		local c = props.controls
		local levels, setLevels = React.useState({})

		local function levelOf(id: string): number
			return levels[id] or 1
		end

		local function upgradeOne(id: string)
			setLevels(function(prev)
				local updated = table.clone(prev)
				updated[id] = math.min((prev[id] or 1) + 1, c.maxLevel)
				return updated
			end)
		end

		local rows: { [string]: any } = {}
		for i, upgrade in ipairs(UPGRADES) do
			rows[upgrade.id] = upgradeRow({
				upgrade = upgrade,
				level = levelOf(upgrade.id),
				maxLevel = c.maxLevel,
				costMultiplier = c.costMultiplier,
				layoutOrder = i,
				onUpgrade = function()
					upgradeOne(upgrade.id)
				end,
			})
		end

		return React.createElement(ui.Window, {
			size = UDim2.fromOffset(c.windowWidth, c.windowHeight),
			title = "Upgrades",
			icon = ui.assets.Icons.rebirth,
			titleVariant = "blue",
			onClose = function()
				print("[UpgradesUI.story] close")
			end,
		}, rows)
	end,
}
