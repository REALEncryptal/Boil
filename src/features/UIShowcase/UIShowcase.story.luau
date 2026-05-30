--!nonstrict
-- UI Labs story: full recreation of the Studio gem-button template.
-- Use this to visually compare the React-built layout against your reference.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local UIShowcase = require(ReplicatedStorage.Features.UIShowcase.UIShowcase)

return {
	summary = "Full template recreation: dark glass panel + Rebirth badge + close button + colored gem column.",
	react = React,
	reactRoblox = ReactRoblox,

	story = function()
		return React.createElement(UIShowcase)
	end,
}
