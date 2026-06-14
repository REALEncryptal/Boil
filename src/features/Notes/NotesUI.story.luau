--!nonstrict
-- UI Labs story for the Notes UI. Holds local "saved" state so clicking Save
-- updates the `saved:` label without needing a live PlayerData replica or any
-- packet wiring. Wrapped in a ui.Window so the chrome matches how the HUD
-- mounts NotesUI in production.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Features = ReplicatedStorage:WaitForChild("Features")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.Boil).ui

local NotesUI = require(Features:WaitForChild("Notes"):WaitForChild("NotesUI"))

return {
	summary = "Notes UI driven by local state. Type, hit Save, the saved label updates. No replica or packet traffic — for that, Play-test the game.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		width = UILabs.Slider(600, 320, 1000, 10),
		height = UILabs.Slider(420, 200, 800, 10),
		initialNote = "Hello world",
	},

	story = function(props)
		local c = props.controls
		local saved, setSaved = React.useState(c.initialNote)

		return React.createElement(ui.Window, {
			size = UDim2.fromOffset(c.width, c.height),
			title = "Notes",
			icon = ui.assets.Icons.questionMark,
			titleVariant = "blue",
			onClose = function()
				print("[NotesUI.story] close")
			end,
		}, {
			Notes = React.createElement(NotesUI, {
				note = saved,
				onSave = function(text)
					setSaved(text)
				end,
			}),
		})
	end,
}
