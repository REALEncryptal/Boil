--!strict
-- The HUD itself: a sidebar of registered nav entries, the corner widget
-- clusters, and one UIShell Frame per nav entry holding that feature's screen.
--
-- Dumb by construction (docs/game/headless-core.md): it reads the HUD registries
-- and renders them. No networking, no validation, no persistence — a nav entry's
-- `onOpen` intent is the feature's own, routed through UIShell.
--
-- Opening any frame slides the sidebar and every widget cluster off-screen via
-- UIShell's HideWhenFrameOpen, so the open window is never competing with the
-- HUD behind it. Each cluster hides toward its own edge.
--
-- Everything is authored in REFERENCE pixels inside `ui.Surface`, so the HUD is
-- correct on a phone without a second layout — the one place it *branches* by
-- device is window size, where a phone gets a near-fullscreen window instead of
-- a small floating one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Features = ReplicatedStorage:WaitForChild("Features")

local React = require(ReplicatedStorage.Packages.React)
local Boil = require(ReplicatedStorage.Shared.Boil)
local ui = Boil.ui

local Constants = require(script.Parent.Constants)
local Registries = require(script.Parent.Registries)
local UIShell = require(Features:WaitForChild("UIShell"))
local Sidebar = require(Features:WaitForChild("Sidebar"))

-- Where each corner cluster anchors, and which way it slides out. One table so
-- adding a corner is a row here rather than another branch in the render body.
local CORNERS: {
	[string]: { anchor: Vector2, position: (number) -> UDim2, direction: string, horizontal: boolean },
} = {
	topLeft = {
		anchor = Vector2.new(0, 0),
		position = function(inset) return UDim2.fromOffset(inset, inset) end,
		direction = "top",
		horizontal = false,
	},
	topRight = {
		anchor = Vector2.new(1, 0),
		position = function(inset) return UDim2.new(1, -inset, 0, inset) end,
		direction = "top",
		horizontal = false,
	},
	bottomLeft = {
		anchor = Vector2.new(0, 1),
		position = function(inset) return UDim2.new(0, inset, 1, -inset) end,
		direction = "bottom",
		horizontal = false,
	},
	bottomRight = {
		anchor = Vector2.new(1, 1),
		position = function(inset) return UDim2.new(1, -inset, 1, -inset) end,
		direction = "bottom",
		horizontal = false,
	},
	bottomCenter = {
		anchor = Vector2.new(0.5, 1),
		position = function(inset) return UDim2.new(0.5, 0, 1, -inset) end,
		direction = "bottom",
		horizontal = true,
	},
}

type Props = {
	-- Story hook: render these nav entries instead of the live registry.
	entries: { any }?,
	-- Story hook: frameId → element, instead of the registered screens.
	screens: { [string]: any }?,
	-- Story hook: corner → { widget }, instead of the registered widgets.
	widgets: { [string]: any }?,
}

return function(props: Props)
	local frames = UIShell.useFrame()
	local vp = ui.useViewport()
	local device = vp.device
	local theme = ui.useSkin().theme

	local inset = Constants.SCREEN_INSET
	local entries = props.entries or Registries.Nav.list()
	local widgetsByCorner = props.widgets or Registries.widgetsByCorner()

	local children: { [string]: any } = {}

	----------------------------------------------------------------------------
	-- Sidebar
	----------------------------------------------------------------------------
	if #entries > 0 then
		local items: { any } = {}
		for _, entry in entries do
			table.insert(items, {
				id = entry.id,
				icon = entry.icon or Constants.FALLBACK_ICON,
				label = entry.label or entry.id,
				-- The nav entry's variant now paints the button's gem surface, so
				-- the field a feature already declares does visible work.
				variant = entry.variant,
				badge = entry.badge,
				badgeVariant = entry.badgeVariant,
				onClick = function()
					frames.toggle(entry.id)
				end,
			})
		end

		-- One item wide. The Sidebar adds its own padding step inside this.
		local sidebarWidth = Sidebar.Constants.DEFAULT_ICON_SIZE

		children.Sidebar = React.createElement(UIShell.HideWhenFrameOpen, {
			direction = "left",
			basePosition = UDim2.new(0, inset, 0.5, 0),
			anchorPoint = Vector2.new(0, 0.5),
			size = UDim2.fromScale(0, 0),
		}, {
			Scaled = React.createElement(ui.Surface, {
				name = "Sidebar",
				size = UDim2.fromOffset(sidebarWidth, 0),
				automaticSize = Enum.AutomaticSize.Y,
				anchorPoint = Vector2.new(0, 0.5),
				position = UDim2.fromScale(0, 0.5),
			}, {
				Column = React.createElement(Sidebar.UI, { items = items }),
			}),
		})
	end

	----------------------------------------------------------------------------
	-- Widget clusters
	----------------------------------------------------------------------------
	for cornerName, corner in CORNERS do
		local bucket = widgetsByCorner[cornerName]
		if bucket == nil or #bucket == 0 then
			continue
		end

		local contents: { [string]: any } = {}
		for index, widget in bucket do
			contents[widget.id] = React.createElement("Frame", {
				Size = UDim2.fromScale(0, 0),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = index,
			}, { Content = widget.element })
		end

		children[`Widgets_{cornerName}`] = React.createElement(UIShell.HideWhenFrameOpen, {
			direction = corner.direction,
			basePosition = corner.position(inset),
			anchorPoint = corner.anchor,
			size = UDim2.fromScale(0, 0),
		}, {
			Scaled = React.createElement(ui.Surface, {
				name = `Widgets_{cornerName}`,
				size = UDim2.fromScale(0, 0),
				automaticSize = Enum.AutomaticSize.XY,
				anchorPoint = corner.anchor,
				position = UDim2.fromScale(corner.anchor.X, corner.anchor.Y),
			}, {
				Cluster = React.createElement(ui.Stack, {
					direction = if corner.horizontal then "horizontal" else "vertical",
					gap = "md",
					size = UDim2.fromScale(0, 0),
					automaticSize = Enum.AutomaticSize.XY,
					horizontalAlignment = if corner.anchor.X == 1
						then Enum.HorizontalAlignment.Right
						elseif corner.anchor.X == 0 then Enum.HorizontalAlignment.Left
						else Enum.HorizontalAlignment.Center,
				}, contents),
			}),
		})
	end

	----------------------------------------------------------------------------
	-- Frames
	----------------------------------------------------------------------------
	-- Window sizing, in reference pixels (the Window's own Surface scales them).
	--
	-- The largest window that still fits the screen with its margins. Computed
	-- from the LIVE viewport, because "fits the screen" is a real-pixel fact:
	-- dividing by the scale converts it back into the reference space the Window
	-- is authored in. A fixed reference constant can't do this — the phone boost
	-- scales it up and it overflows.
	local maxReference = Vector2.new(
		(vp.size.X - inset * 2) / vp.scale,
		(vp.size.Y - inset * 2) / vp.scale
	)

	-- A phone fills that budget: a small float wastes the screen and cramps its
	-- own content. Everything else takes the tuned default. Both are then clamped,
	-- so no device can ever render a window larger than its screen.
	local desired = if device == "phone" then maxReference else Vector2.new(
		Constants.DEFAULT_WINDOW_SIZE.X.Offset,
		Constants.DEFAULT_WINDOW_SIZE.Y.Offset
	)
	local defaultWindowSize = UDim2.fromOffset(
		math.floor(math.min(desired.X, maxReference.X)),
		math.floor(math.min(desired.Y, maxReference.Y))
	)

	for _, entry in entries do
		local screen = if props.screens then props.screens[entry.id] else Registries.getScreen(entry.id)

		children[`Frame_{entry.id}`] = React.createElement(UIShell.Frame, {
			id = entry.id,
		}, {
			Window = React.createElement(ui.Window, {
				-- A per-entry size is clamped too, so one feature asking for a big
				-- window can't push it off a small screen.
				size = if entry.windowSize
					then UDim2.fromOffset(
						math.floor(math.min(entry.windowSize.X.Offset, maxReference.X)),
						math.floor(math.min(entry.windowSize.Y.Offset, maxReference.Y))
					)
					else defaultWindowSize,
				title = entry.title or entry.label or entry.id,
				icon = entry.icon,
				titleVariant = entry.variant or "primary",
				onClose = frames.close,
				-- No contentPadding: where a window's chrome sits is the skin's
				-- business, not the HUD's, and every skin already has a tuned
				-- default. Passing one here is what put slop's floating title badge
				-- on top of the first row.
			}, {
				-- A nav entry with no screen yet is a real state during
				-- development, so say so on screen instead of rendering an empty
				-- window that looks broken.
				Content = screen
					or React.createElement(ui.Text, {
						text = `No screen registered for "{entry.id}".`,
						role = "body",
						color = theme.mutedText,
						wrap = true,
						size = UDim2.new(1, 0, 0, theme.type.body * 3),
					}),
			}),
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, children)
end
