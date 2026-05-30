--!nonstrict
-- UI Labs story for the ScrollList primitive. Renders N gem Buttons inside a
-- bordered Panel so the scroll behaviour is obvious.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

local VARIANTS = { "red", "blue", "green", "purple", "yellow", "white", "rainbow" }

return {
	summary = "ScrollingFrame with UIListLayout baked in. Flip direction, drag gap/padding/item count.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		direction = UILabs.Choose({ "vertical", "horizontal" }),
		itemCount = UILabs.Slider(12, 1, 60, 1),
		gap = UILabs.Slider(10, 0, 60, 1),
		padding = UILabs.Slider(10, 0, 40, 1),
		width = UILabs.Slider(400, 100, 1200, 10),
		height = UILabs.Slider(400, 100, 1000, 10),
		showPanel = true,
		fillHorizontal = false,
		fillVertical = false,
	},

	story = function(props)
		local c = props.controls
		local items: { [string]: any } = {}
		for i = 1, c.itemCount do
			local variant = VARIANTS[((i - 1) % #VARIANTS) + 1]
			items[`Item_{i}`] = React.createElement(ui.Button, {
				variant = variant,
				text = tostring(i),
				size = UDim2.fromOffset(120, 60),
				layoutOrder = i,
			})
		end

		local scroll = React.createElement(ui.ScrollList, {
			direction = c.direction,
			gap = c.gap,
			padding = c.padding,
			fillHorizontal = c.fillHorizontal,
			fillVertical = c.fillVertical,
			size = UDim2.fromScale(1, 1),
		}, items)

		if c.showPanel then
			return React.createElement(ui.Panel, {
				size = UDim2.fromOffset(c.width, c.height),
			}, { Scroll = scroll })
		end

		return React.createElement("Frame", {
			Size = UDim2.fromOffset(c.width, c.height),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			BorderSizePixel = 0,
		}, { Scroll = scroll })
	end,
}
