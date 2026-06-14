--!nonstrict
-- UI Labs story: faithful recreation of a "Brainrot Index" screen so we can
-- eyeball proportions, sizing, and padding for a collection/codex layout.
-- Composes existing shared primitives — no new components shipped.
--
-- Layout overview:
--   - Sidebar of rarity pills, anchored outside the window's left edge.
--   - ui.Window with title "Index" — standard chrome, only `size` overridden.
--     Holds a 5-column grid of brainrot cards (first revealed, rest "???").
--   - Below the window (outside): cash-bonus caption + collection ProgressBar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.Boil).ui

local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(0, 0, 0)
local LIME = Color3.fromRGB(170, 255, 0)

-- Sidebar entries: label + gem variant. Order matches the screenshot.
local RARITIES = {
	{ label = "Normal",  variant = "white",   notify = false },
	{ label = "Gold",    variant = "yellow",  notify = false },
	{ label = "Diamond", variant = "white",   notify = false },
	{ label = "Lava",    variant = "yellow",  notify = false },
	{ label = "Galaxy",  variant = "purple",  notify = true  },
	{ label = "Rainbow", variant = "rainbow", notify = false },
}

-- 15 grid slots: one revealed ("Common — Lirili Larila"), the rest locked.
local GRID_SLOTS = 15

local function buildSidebar(): { [string]: any }
	local entries: { [string]: any } = {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			-- Matches the 20-pixel bbox gap between the sidebar and the
			-- window (see Sidebar Position offset). Buttons and the window
			-- are both stroked, so visual gap = bbox gap − 2·stroke on both
			-- axes; equal bbox gaps → equal visual gaps.
			Padding = UDim.new(0, 20),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	}

	for i, entry in ipairs(RARITIES) do
		local children: { [string]: any } = {}
		if entry.notify then
			-- Small red "!" notification badge floating off the top-right corner.
			children.Notify = React.createElement(ui.Button, {
				variant = "red",
				text = "!",
				size = UDim2.fromOffset(31, 31),
				position = UDim2.new(1, -4, 0, 4),
				anchorPoint = Vector2.new(0.5, 0.5),
				zIndex = 5,
			})
		end
		entries["Tab_" .. entry.label] = React.createElement(ui.Button, {
			variant = entry.variant,
			text = entry.label,
			textSize = ui.theme.textSizeRegular,
			textWeight = Enum.FontWeight.Heavy,
			size = UDim2.fromOffset(169, 45),
			layoutOrder = i,
		}, children)
	end

	return entries
end

local function revealedCard(layoutOrder: number, rarityLabel: string, brainrotIcon: string, brainrotName: string)
	-- Image fills the full cell (under the labels) so the brainrot art reads
	-- as large as possible. Rarity label sits top-left, name bottom-right —
	-- same overlay pattern as the locked card's "???" corners, so both card
	-- types share the same internal geometry.
	local rowHeight = ui.theme.textSizeRegular + 4
	return React.createElement(ui.Panel, {
		variant = "green",
		hasShine = false,
		layoutOrder = layoutOrder,
		-- UIGridLayout overrides Size on direct children to its CellSize, but
		-- pass an explicit 1,1 here so Panel doesn't fall back to its giant
		-- `theme.windowSize` default if UIGridLayout ever can't reach it.
		size = UDim2.fromScale(1, 1),
	}, {
		Icon = React.createElement("ImageLabel", {
			-- ~85% of the cell so there's visible green border around the
			-- art, matching the reference screenshot. ZIndex 1 keeps it
			-- below the rarity/name overlay text.
			Size = UDim2.fromScale(0.85, 0.85),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = brainrotIcon,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 1,
		}),
		Rarity = React.createElement(ui.Text, {
			text = rarityLabel,
			textSize = ui.theme.textSizeRegular,
			weight = Enum.FontWeight.Heavy,
			xAlignment = Enum.TextXAlignment.Left,
			yAlignment = Enum.TextYAlignment.Top,
			size = UDim2.new(1, -16, 0, rowHeight),
			position = UDim2.new(0, 8, 0, 2),
			shadow = true,
			zIndex = 2,
		}),
		Name = React.createElement(ui.Text, {
			text = brainrotName,
			textSize = ui.theme.textSizeRegular,
			weight = Enum.FontWeight.Heavy,
			xAlignment = Enum.TextXAlignment.Right,
			yAlignment = Enum.TextYAlignment.Bottom,
			size = UDim2.new(1, -16, 0, rowHeight),
			position = UDim2.new(0, 8, 1, -rowHeight - 2),
			shadow = true,
			zIndex = 2,
		}),
	})
end

local function lockedCard(layoutOrder: number)
	return React.createElement(ui.Panel, {
		layoutOrder = layoutOrder,
		transparency = 0.45,
		-- No strokeThickness override: matches the revealed card's stroke
		-- footprint (theme.strokeThickness = 4) so both cells occupy the
		-- same visual size in the grid.
		size = UDim2.fromScale(1, 1),
	}, {
		-- "???" floats top-left; the silhouette would sit centered but we
		-- have no brainrot silhouette art, so a darkened brainrot stands in.
		QuestionTop = React.createElement(ui.Text, {
			text = "???",
			textSize = ui.theme.textSizeRegular,
			weight = Enum.FontWeight.Heavy,
			color = WHITE,
			xAlignment = Enum.TextXAlignment.Left,
			yAlignment = Enum.TextYAlignment.Top,
			size = UDim2.new(1, -16, 0, ui.theme.textSizeRegular + 4),
			position = UDim2.new(0, 8, 0, 2),
			shadow = true,
		}),
		Silhouette = React.createElement("ImageLabel", {
			Size = UDim2.fromScale(0.7, 0.7),
			Position = UDim2.fromScale(0.5, 0.55),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = ui.assets.Brainrots.liriliLarila,
			ImageColor3 = BLACK,
			ScaleType = Enum.ScaleType.Fit,
		}),
		QuestionBottom = React.createElement(ui.Text, {
			text = "???",
			textSize = ui.theme.textSizeRegular,
			weight = Enum.FontWeight.Heavy,
			color = WHITE,
			xAlignment = Enum.TextXAlignment.Right,
			yAlignment = Enum.TextYAlignment.Bottom,
			size = UDim2.new(1, -16, 0, ui.theme.textSizeRegular + 4),
			position = UDim2.new(0, 8, 1, -(ui.theme.textSizeRegular + 4) - 2),
			shadow = true,
		}),
	})
end

-- Wrapper component: drives a UIScale via useHoverScale and overlays an
-- invisible TextButton at high ZIndex to capture pointer events. Wrapping is
-- needed because revealedCard / lockedCard are plain functions (not React
-- components), so they can't call hooks directly — and because UIGridLayout
-- only sizes its direct child, the UIScale has to live in that direct child
-- so the whole card scales together with the GemBackground around it.
local function HoverableCard(props: {
	layoutOrder: number,
	children: { [string]: any },
})
	local hover = ui.useHoverScale({ triggerKind = "button" })

	local kids: { [string]: any } = {
		UIScale = React.createElement("UIScale", {
			Scale = 1,
			ref = hover.scaleRef,
		}),
		Trigger = React.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Text = "",
			TextColor3 = Color3.fromRGB(0, 0, 0),
			TextSize = 14,
			FontFace = Font.new(
				"rbxasset://fonts/families/SourceSansPro.json",
				Enum.FontWeight.Regular,
				Enum.FontStyle.Normal
			),
			ZIndex = 10,
			[React.Event.MouseEnter] = hover.onEnter,
			[React.Event.MouseLeave] = hover.onLeave,
			[React.Event.MouseButton1Down] = hover.onPress,
			[React.Event.MouseButton1Up] = hover.onRelease,
		}),
	}
	for k, v in pairs(props.children) do
		kids[k] = v
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
	}, kids)
end

local function buildGrid(cellSize: number, gap: number): { [string]: any }
	local children: { [string]: any } = {
		UIGridLayout = React.createElement("UIGridLayout", {
			CellSize = UDim2.fromOffset(cellSize, cellSize),
			CellPadding = UDim2.fromOffset(gap, gap),
			FillDirectionMaxCells = 5,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	}

	for i = 1, GRID_SLOTS do
		local key = string.format("Card_%02d", i)
		local card = if i == 1
			then revealedCard(0, "Common", ui.assets.Brainrots.liriliLarila, "Lirili Larila")
			else lockedCard(0)
		children[key] = React.createElement(HoverableCard, {
			layoutOrder = i,
		}, { Card = card })
	end

	return children
end

return {
	summary = "Brainrot Index recreation. Window uses the standard ui.Window chrome; only width/height are overridden. Caption + ProgressBar sit outside, below the window.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		windowWidth = UILabs.Slider(847, 462, 1232, 10),
		windowHeight = UILabs.Slider(493, 308, 693, 10),
		discovered = UILabs.Slider(2, 0, 517, 1),
		total = UILabs.Slider(517, 1, 1000, 1),
		collected = UILabs.Slider(1, 0, 92, 1),
		collectionMax = UILabs.Slider(92, 1, 200, 1),
	},

	story = function(props)
		local c = props.controls

		-- Single spacing value drives both: (a) inset between the window
		-- stroke and the grid on all four sides, and (b) the gap between
		-- adjacent cells. Pulled from the theme (`contentSpacing` — the
		-- token reserved for spacing between stacked content rows inside a
		-- Window's scroll body) so a live theme edit flows through here.
		local cols = 5
		local gap = ui.theme.contentSpacing
		-- Inset around the grid matches the cell gap so the padding between
		-- the window edge and the cards reads identical to the gap between
		-- adjacent cards. (Skips the +stroke compensation from CLAUDE.md;
		-- the user wants flat-equal visual gaps here.)
		local inset = gap
		local horizontalChrome = inset * 2
		local available = math.max(0, c.windowWidth - horizontalChrome)
		local cellSize = math.max(40, math.floor((available - gap * (cols - 1)) / cols))

		-- Grid mounted as a single child of Window so its own UIListLayout
		-- treats the whole grid as one row. The host Frame carries the
		-- UIGridLayout and grows vertically to fit its cells.
		local gridHost = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, buildGrid(cellSize, gap))

		-- Stats column rendered into Window's topBarExtra slot, left of the
		-- close button. Two right-aligned lines: "% complete" (lime, Regular)
		-- and "N / total discovered" (white, Small). Heights derive from the
		-- ladder tokens so the rows scale with the theme.
		local percent = if c.total > 0 then math.floor((c.discovered / c.total) * 100) else 0
		-- Two right-aligned lines anchored to the top and bottom edges of
		-- the bar. Each label is one ladder tier minus 5 — slightly trimmed
		-- so the pair reads tight against the 60px topbar.
		local percentSize = ui.theme.textSizeLarge - 5
		local counterSize = ui.theme.textSizeRegular - 5
		local statsColumn = React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			UIPadding = React.createElement("UIPadding", {
				PaddingRight = UDim.new(0, ui.theme.padding),
			}),

			Percent = React.createElement(ui.Text, {
				text = string.format("%d%% complete", percent),
				textSize = percentSize,
				weight = Enum.FontWeight.Heavy,
				color = LIME,
				xAlignment = Enum.TextXAlignment.Right,
				yAlignment = Enum.TextYAlignment.Top,
				size = UDim2.new(1, 0, 0, percentSize),
				position = UDim2.new(0, 0, 0, 0),
				anchorPoint = Vector2.new(0, 0),
				shadow = true,
			}),

			Counter = React.createElement(ui.Text, {
				text = string.format("%d / %d discovered", c.discovered, c.total),
				textSize = counterSize,
				weight = Enum.FontWeight.Heavy,
				color = WHITE,
				xAlignment = Enum.TextXAlignment.Right,
				yAlignment = Enum.TextYAlignment.Bottom,
				size = UDim2.new(1, 0, 0, counterSize),
				position = UDim2.new(0, 0, 1, 0),
				anchorPoint = Vector2.new(0, 1),
				shadow = true,
			}),
		})

		local window = React.createElement(ui.Window, {
			size = UDim2.fromOffset(c.windowWidth, c.windowHeight),
			title = "Index",
			icon = ui.assets.Icons.book,
			titleVariant = "blue",
			-- Override Window's per-side defaults so all four insets match
			-- the cell gap (visually equal spacing all around).
			contentPadding = {
				top = inset,
				bottom = inset,
				left = inset,
				right = inset,
			},
			topBarExtra = statsColumn,
			topBarExtraSize = UDim2.new(0, 323, 1, 0),
			onClose = function()
				print("[IndexUI.story] close")
			end,
		}, {
			Grid = gridHost,
		})

		-- Caption + progress bar live OUTSIDE the window, stacked below it.
		-- Width matches the window so the bar tracks the window's footprint
		-- as the size sliders move. Heights pulled from theme tokens so the
		-- below-strip auto-resizes when the ladder is retuned.
		local progressHeight = 46
		local captionHeight = ui.theme.textSizeRegular + 6
		local innerGap = 6
		local belowStripHeight = captionHeight + innerGap + progressHeight
		-- Gap between window and the strip below — generous so the strip
		-- reads as a separate UI element rather than welded to the window.
		local windowToStripGap = ui.theme.contentSpacing * 2

		local belowStrip = React.createElement("Frame", {
			Size = UDim2.fromOffset(c.windowWidth, belowStripHeight),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, innerGap),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			Caption = React.createElement(ui.Text, {
				text = "Collect 75% of Normal Brainrots for +0.5x Cash",
				textSize = ui.theme.textSizeRegular,
				weight = Enum.FontWeight.Heavy,
				size = UDim2.new(1, 0, 0, captionHeight),
				layoutOrder = 0,
				shadow = true,
			}),

			Progress = React.createElement(ui.ProgressBar, {
				progress = if c.collectionMax > 0 then c.collected / c.collectionMax else 0,
				variant = "green",
				text = string.format("%d / %d", c.collected, c.collectionMax),
				textSize = ui.theme.textSizeRegular,
				size = UDim2.new(1, 0, 0, progressHeight),
				layoutOrder = 1,
			}),
		})

		-- Center container stacks the Window and the below-strip vertically
		-- with `windowToStripGap` between them; the whole stack is centered.
		local stackHeight = c.windowHeight + windowToStripGap + belowStripHeight
		local centerStack = React.createElement("Frame", {
			Size = UDim2.fromOffset(c.windowWidth, stackHeight),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, windowToStripGap),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Window = React.createElement("Frame", {
				Size = UDim2.fromOffset(c.windowWidth, c.windowHeight),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = 0,
			}, { Inner = window }),
			Below = belowStrip,
		})

		-- Sidebar is positioned absolutely so its vertical center aligns with
		-- the window itself (not the window+below stack).
		return React.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, {
			Stack = centerStack,

			Sidebar = React.createElement("Frame", {
				-- Top-anchored alongside the content panel: the first sidebar
				-- button lines up with the top of the content area (i.e. the
				-- bottom of the Window top bar). Height covers the content
				-- area only so we don't overlap the below-strip.
				Size = UDim2.fromOffset(169, c.windowHeight - ui.theme.topBarHeight),
				-- Stack is centered with anchor (0.5, 0.5); the window's top
				-- edge sits at `0.5 - stackHeight/2` from screen center, then
				-- the content area starts `topBarHeight` below that.
				Position = UDim2.new(
					0.5,
					-(c.windowWidth / 2) - 189,
					0.5,
					-stackHeight / 2 + ui.theme.topBarHeight
				),
				AnchorPoint = Vector2.new(0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
			}, buildSidebar()),
		})
	end,
}
