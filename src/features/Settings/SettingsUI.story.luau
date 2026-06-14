--!nonstrict
-- UI Labs story for the Settings UI. Feeds mock sections so the panel
-- renders without a live PlayerData replica or any real registry entries.
-- Toggle the `useMockData` control off to see the empty-state placeholder
-- the production UI shows when nothing is registered.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Features = ReplicatedStorage:WaitForChild("Features")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.Boil).ui

local SettingsUI = require(Features:WaitForChild("Settings"):WaitForChild("SettingsUI"))

local REBIRTH_ICON = "rbxassetid://137349421699691"

-- Hardcoded sections that match the Registry.Section shape. We don't go
-- through Registry.register here so the story doesn't pollute the live
-- registry for other UI Labs scenes.
local MOCK_SECTIONS = {
	{
		category = { id = "audio", title = "Audio", order = 1 },
		settings = {
			{ kind = "toggle", id = "audio.music",     label = "Music",          category = "audio", default = true,  variant = "blue" },
			{ kind = "toggle", id = "audio.sfx",       label = "Sound Effects",  category = "audio", default = true,  variant = "blue" },
		},
	},
	{
		category = { id = "display", title = "Display", order = 2 },
		settings = {
			{ kind = "toggle", id = "display.fps",     label = "Show FPS",       category = "display", default = false, variant = "green" },
			{ kind = "toggle", id = "display.motion",  label = "Reduced Motion", category = "display", default = false, variant = "green" },
		},
	},
	{
		category = { id = "gameplay", title = "Gameplay", order = 3 },
		settings = {
			{ kind = "toggle", id = "gameplay.autopickup", label = "Auto-Pickup",    category = "gameplay", default = true, variant = "yellow" },
			{ kind = "toggle", id = "gameplay.notify",     label = "Notifications", category = "gameplay", default = true, variant = "yellow" },
		},
	},
}

return {
	summary = "Settings UI driven by mock sections + a local state map. Flip useMockData off to verify the empty state. focusedId mimics what SettingsController.linkTo() triggers.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		width = UILabs.Slider(600, 320, 1000, 10),
		height = UILabs.Slider(500, 200, 900, 10),
		useMockData = true,
		focusedId = UILabs.Choose({
			"<none>",
			"audio.music",
			"audio.sfx",
			"display.fps",
			"display.motion",
			"gameplay.autopickup",
			"gameplay.notify",
		}),
	},

	story = function(props)
		local c = props.controls

		-- Local state map keyed by setting id. Lets clicks in the story
		-- actually flip the checkbox without needing a real replica.
		local values, setValues = React.useState({} :: { [string]: boolean })

		local sections = if c.useMockData then MOCK_SECTIONS else {}
		local focusedId = if c.focusedId == "<none>" then nil else c.focusedId

		return React.createElement(ui.Window, {
			size = UDim2.fromOffset(c.width, c.height),
			title = "Settings",
			icon = REBIRTH_ICON,
			titleVariant = "purple",
			onClose = function()
				print("[SettingsUI.story] close")
			end,
		}, {
			Settings = React.createElement(SettingsUI, {
				sections = sections,
				values = values,
				focusedId = focusedId,
				onToggle = function(id: string, next: boolean)
					setValues(function(prev)
						local copy = table.clone(prev)
						copy[id] = next
						return copy
					end)
				end,
			}),
		})
	end,
}
