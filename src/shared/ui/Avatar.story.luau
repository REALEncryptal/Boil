--!nonstrict
-- UI Labs story for Avatar — a player's headshot in a ring.
--
-- `userId` takes any real id (1 is Roblox, 156 is builderman); the thumbnail is
-- fetched live through rbxthumb, so a real face shows in edit mode. Flip
-- `accent` to see the ring in a colour instead of black — how a feature marks
-- "this one is you". `strokeThickness` at 0 means the skin's own outline weight.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local ui = require(ReplicatedStorage.Shared.ui)

return {
	summary = "Headshot in a rounded ring. Change `userId` for another player; `accent` recolours the ring; 0 thickness is the skin's own.",
	react = React,
	reactRoblox = ReactRoblox,

	controls = {
		userId = 156,
		size = UILabs.Slider(120, 24, 400, 4),
		strokeThickness = UILabs.Slider(0, 0, 12, 0.5),
		accent = false,
		square = false,
		skin = UILabs.Choose({ "default", "slop", "gem", "flat" }),
	},

	story = function(props)
		local c = props.controls
		return React.createElement(ui.SkinProvider, {
			skin = if c.skin == "default" then nil else c.skin,
		}, {
			Avatar = React.createElement(ui.Avatar, {
				userId = c.userId,
				size = UDim2.fromOffset(c.size, c.size),
				position = UDim2.fromScale(0.5, 0.5),
				anchorPoint = Vector2.new(0.5, 0.5),
				strokeThickness = if c.strokeThickness > 0 then c.strokeThickness else nil,
				strokeColor = if c.accent then Color3.fromRGB(14, 70, 160) else nil,
				cornerRadius = if c.square then UDim.new(0, 8) else nil,
			}),
		})
	end,
}
