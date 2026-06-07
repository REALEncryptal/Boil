--!nonstrict
-- UI Labs story for the skin seam. Flip the `skin` control between "gem" and
-- "flat" and watch every primitive below re-skin — the whole showcase is wrapped
-- in a single <SkinProvider>, so nothing in the showcase mentions a skin.
--
-- This is the verifiable proof of the swap: the gem skin is the polished look,
-- the flat skin is plain gray boxes with accent borders, and the same prop set
-- drives both.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

local REBIRTH_ICON = "rbxassetid://137349421699691"

local function Showcase(props)
	local variant = props.variant
	return React.createElement(ui.Window, {
		title = "Skin Showcase",
		icon = REBIRTH_ICON,
		titleVariant = variant,
		size = UDim2.fromOffset(720, 560),
		onClose = function() end,
	}, {
		Button = React.createElement(ui.Button, {
			variant = variant,
			text = "Button",
			size = UDim2.fromOffset(240, 64),
			layoutOrder = 1,
		}),
		Badge = React.createElement(ui.Badge, {
			variant = variant,
			text = "Badge",
			icon = REBIRTH_ICON,
			size = UDim2.fromOffset(360, 72),
			layoutOrder = 2,
		}),
		Progress = React.createElement(ui.ProgressBar, {
			variant = variant,
			progress = props.progress,
			size = UDim2.fromOffset(420, 44),
			layoutOrder = 3,
		}),
		Field = React.createElement(ui.TextField, {
			placeholderText = "Type here…",
			defaultText = "Editable",
			size = UDim2.fromOffset(420, 64),
			layoutOrder = 4,
		}),
		CheckRow = React.createElement(ui.Checkbox, {
			variant = variant,
			checked = props.checked,
			size = UDim2.fromOffset(56, 56),
			layoutOrder = 5,
		}),
		Text = React.createElement(ui.Text, {
			text = "Text primitive",
			shadow = true,
			size = UDim2.fromOffset(420, 56),
			layoutOrder = 6,
		}),
	})
end

return {
	summary = "Flip `skin` between gem and flat — the whole showcase re-skins. Same props, two looks.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		skin = UILabs.Choose({ "gem", "flat" }),
		variant = UILabs.Choose({ "red", "blue", "green", "purple", "yellow", "white", "rainbow" }),
		progress = UILabs.Slider(0.6, 0, 1, 0.01),
		checked = true,
	},

	story = function(props)
		local c = props.controls
		return React.createElement(ui.SkinProvider, { skin = c.skin }, {
			Showcase = React.createElement(Showcase, {
				variant = c.variant,
				progress = c.progress,
				checked = c.checked,
			}),
		})
	end,
}
