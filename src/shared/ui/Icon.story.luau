--!nonstrict
-- UI Labs story for the Icon primitive (bare, unskinned image).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

return {
	summary = "Bare image, no surface. Fit keeps a non-square source undistorted; Stretch fills the box.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		icon = UILabs.Choose({
			"bandOfCash", "rebirth", "shoppingBasket", "questionMark",
			"friends", "wheel", "rocket", "book", "settings", "flyingShoe", "pet",
			"trailShop", "trailPreview", "eggStatus", "sparkle", "exclamationMark",
		}),
		scaleType = UILabs.Choose({ "Fit", "Stretch", "Slice" }),
		width = UILabs.Slider(96, 16, 400, 4),
		height = UILabs.Slider(96, 16, 400, 4),
		lockSquare = false,
	},

	story = function(props)
		local c = props.controls
		return React.createElement(ui.Icon, {
			image = ui.assets.Icons[c.icon],
			scaleType = Enum.ScaleType[c.scaleType],
			size = UDim2.fromOffset(c.width, c.height),
			aspectRatio = if c.lockSquare then 1 else nil,
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
		})
	end,
}
