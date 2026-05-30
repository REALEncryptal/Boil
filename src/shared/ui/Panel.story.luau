--!nonstrict
-- UI Labs story for the Panel primitive. Switch `variant` from "glass" to a
-- gem palette key to flip the surface from translucent dark glass to the
-- gem stud background used by Button / Badge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

return {
	summary = "Panel surface — translucent dark glass or gem stud background.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		variant = UILabs.Choose({
			"glass", "red", "blue", "green", "purple", "yellow", "white", "rainbow",
		}),
		hasShine = false,
		width = UILabs.Slider(400, 100, 1200, 10),
		height = UILabs.Slider(300, 100, 1000, 10),
		transparency = UILabs.Slider(0.8, 0, 1, 0.05),
		strokeThickness = UILabs.Slider(4, 0, 12, 1),
	},

	story = function(props)
		local c = props.controls
		local font = Font.new(
			ui.assets.DISPLAY_FONT_ID,
			Enum.FontWeight.Bold,
			Enum.FontStyle.Normal
		)
		local panelProps: { [string]: any } = {
			size = UDim2.fromOffset(c.width, c.height),
		}
		if c.variant == "glass" then
			panelProps.transparency = c.transparency
			panelProps.strokeThickness = c.strokeThickness
		else
			panelProps.variant = c.variant
			panelProps.hasShine = c.hasShine
		end

		return React.createElement(ui.Panel, panelProps, {
			Label = React.createElement("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Text = "Panel content",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 28,
				FontFace = font,
			}),
		})
	end,
}
