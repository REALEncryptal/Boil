--!nonstrict
-- UI Labs story for the Grid layout primitive. Children are skinned Badges
-- mounted as direct grid children (UIGridLayout only sizes direct children).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.Packages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

local VARIANTS = { "red", "blue", "green", "purple", "yellow", "white" }

return {
	summary = "Structure-only grid. Tune cell size / padding / columns; cells are skinned Buttons.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		cell = UILabs.Slider(120, 40, 240, 1),
		padding = UILabs.Slider(8, 0, 40, 1),
		columns = UILabs.Slider(3, 1, 6, 1),
		count = UILabs.Slider(6, 1, 12, 1),
	},

	story = function(props)
		local c = props.controls
		local cells = {}
		for i = 1, c.count do
			cells[`Cell{i}`] = React.createElement(ui.Button, {
				variant = VARIANTS[((i - 1) % #VARIANTS) + 1],
				text = tostring(i),
				size = UDim2.fromScale(1, 1),
				layoutOrder = i,
			})
		end
		return React.createElement(ui.Grid, {
			cellSize = UDim2.fromOffset(c.cell, c.cell),
			cellPadding = UDim2.fromOffset(c.padding, c.padding),
			fillDirectionMaxCells = c.columns,
			size = UDim2.fromOffset(520, 520),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
		}, cells)
	end,
}
