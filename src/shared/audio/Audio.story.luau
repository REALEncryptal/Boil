--!nonstrict
-- UI Labs story for the shared audio module. Mounts a button per UI sound and
-- per music track so you can audition the registry in Studio without writing
-- any wiring code. Music is mutually exclusive — clicking a track swaps the
-- active looping Sound.
--
-- Volume sliders cover the typical mix range (UI fairly loud, music quiet
-- because it loops underneath everything else).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local audio = require(ReplicatedStorage.Shared.audio)
local ui = require(ReplicatedStorage.Shared.ui)

-- Stable ordering for the buttons so the layout doesn't shuffle between
-- renders (table iteration over a Luau table is not ordered).
local UI_ORDER = {
	"click", "click2", "purchase", "hoverIn", "hoverOut",
	"levelUp", "swipe", "select", "reward", "tick", "money",
}

local MUSIC_ORDER = {
	"lobby", "lobby2", "lobby3", "fastMusic", "phonk", "phonk2", "xmas",
}

return {
	summary = "Audition every UI sound and music track from the shared audio registry. Each button plays its sound; music buttons swap the looping track.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		uiVolume = UILabs.Slider(1, 0, 1, 0.05),
		musicVolume = UILabs.Slider(0.2, 0, 1, 0.05),
	},

	story = function(props)
		local c = props.controls

		local children: { [string]: any } = {}

		children.UISection = React.createElement(ui.Badge, {
			variant = "blue",
			text = "UI Sounds",
			size = UDim2.fromOffset(360, 64),
			layoutOrder = 0,
		})

		for i, key in ipairs(UI_ORDER) do
			children[`UI_{key}`] = React.createElement(ui.Button, {
				variant = "blue",
				text = key,
				textSize = 28,
				size = UDim2.fromOffset(360, 56),
				layoutOrder = i,
				onClick = function()
					audio.playUI(key, c.uiVolume)
				end,
			})
		end

		children.MusicSection = React.createElement(ui.Badge, {
			variant = "purple",
			text = "Music",
			size = UDim2.fromOffset(360, 64),
			layoutOrder = 100,
		})

		for i, key in ipairs(MUSIC_ORDER) do
			children[`Music_{key}`] = React.createElement(ui.Button, {
				variant = "purple",
				text = key,
				textSize = 28,
				size = UDim2.fromOffset(360, 56),
				layoutOrder = 100 + i,
				onClick = function()
					audio.playMusic(key, c.musicVolume)
				end,
			})
		end

		children.StopMusic = React.createElement(ui.Button, {
			variant = "red",
			text = "Stop music",
			textSize = 28,
			size = UDim2.fromOffset(360, 56),
			layoutOrder = 999,
			onClick = function()
				audio.stopMusic()
			end,
		})

		return React.createElement(ui.Window, {
			title = "Audio",
			icon = ui.assets.Icons.questionMark,
			titleVariant = "blue",
			size = UDim2.fromOffset(440, 600),
			onClose = function()
				audio.stopMusic()
			end,
		}, children)
	end,
}
