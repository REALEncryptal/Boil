--!strict
-- Game HUD demo: Sidebar of icon + label entries that open Window frames via
-- the UIShell system. Assumes FrameProvider context is mounted higher in the
-- tree (see src/client/init.client.luau for the production mount, or the
-- HUD.story.luau wrapper for the UI Labs preview).
--
-- Extend by appending entries to `SIDEBAR_ENTRIES` — the same row drives
-- the Sidebar item and its corresponding Frame, so adding a window is a
-- one-line change.
--
-- The caller supplies real window contents via the `frameContents` prop —
-- a map keyed by entry id to a React element. Any entry without a supplied
-- content falls back to a row of placeholder labels (handy for entries that
-- don't have a real implementation yet, and for the UI Labs preview).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Features = ReplicatedStorage:WaitForChild("Features")

local React = require(ReplicatedStorage.Packages.React)
local ui = require(ReplicatedStorage.Shared.ui)
local UIShell = require(Features:WaitForChild("UIShell"))
local Sidebar = require(Features:WaitForChild("Sidebar"))

local REBIRTH_ICON = "rbxassetid://137349421699691"

type SidebarEntry = {
	id: string,
	label: string,
	icon: string,
	-- titleVariant only colors the Window's title badge; the Sidebar itself
	-- no longer has a gem background, so this doesn't affect the icon column.
	titleVariant: string,
}

local SIDEBAR_ENTRIES: { SidebarEntry } = {
	{ id = "Inventory", label = "Inventory", icon = REBIRTH_ICON, titleVariant = "green"  },
	{ id = "Shop",      label = "Shop",      icon = REBIRTH_ICON, titleVariant = "yellow" },
	{ id = "Notes",     label = "Notes",     icon = REBIRTH_ICON, titleVariant = "blue"   },
	{ id = "Settings",  label = "Settings",  icon = REBIRTH_ICON, titleVariant = "purple" },
}

-- Outer container = icon box + two paddings.
local SIDEBAR_WIDTH = Sidebar.Constants.DEFAULT_ICON_SIZE + Sidebar.Constants.PADDING * 2

-- Placeholder window content. Used for any entry that the caller hasn't
-- supplied a real React element for via `props.frameContents`.
local function placeholderRows(label: string): { [string]: any }
	local rows: { [string]: any } = {}
	for i = 1, 6 do
		rows[`Row{i}`] = React.createElement("TextLabel", {
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.85,
			BorderSizePixel = 0,
			Text = `{label} row {i}`,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 18,
			LayoutOrder = i,
		})
	end
	return rows
end

type Props = {
	frameContents: { [string]: any }?,
}

return function(props: Props)
	local frames = UIShell.useFrame()
	local frameContents = props.frameContents

	-- Build the Sidebar items list. One entry → one item + one Frame.
	local sidebarItems: { Sidebar.Item } = {}
	for _, entry in ipairs(SIDEBAR_ENTRIES) do
		table.insert(sidebarItems, {
			id = entry.id,
			icon = entry.icon,
			label = entry.label,
			onClick = function()
				frames.toggle(entry.id)
			end,
		})
	end

	local rootChildren: { [string]: any } = {
		SideBar = React.createElement(UIShell.HideWhenFrameOpen, {
			direction = "left",
			basePosition = UDim2.new(0, 20, 0.5, 0),
			anchorPoint = Vector2.new(0, 0.5),
			size = UDim2.fromOffset(SIDEBAR_WIDTH, 480),
		}, {
			Column = React.createElement(Sidebar.UI, {
				items = sidebarItems,
			}),
		}),
	}

	for _, entry in ipairs(SIDEBAR_ENTRIES) do
		local supplied = if frameContents then frameContents[entry.id] else nil

		local windowChildren: { [string]: any }
		if supplied ~= nil then
			windowChildren = { Content = supplied }
		else
			windowChildren = placeholderRows(entry.id)
		end

		rootChildren[`{entry.id}Frame`] = React.createElement(UIShell.Frame, {
			id = entry.id,
		}, {
			Window = React.createElement(ui.Window, {
				size = UDim2.fromOffset(600, 500),
				title = entry.id,
				icon = REBIRTH_ICON,
				titleVariant = entry.titleVariant :: any,
				onClose = frames.close,
			}, windowChildren),
		})
	end

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, rootChildren)
end
