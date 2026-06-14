-- Root presentation for UIShowcase: registers the HUD host (sidebar + window
-- frames) as a top-level element. The HUD reads its window contents from the
-- UIRegistry itself, so this passes no frameContents prop — features supply
-- those via their own *Presentation modules.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIRegistry = require(ReplicatedStorage.Shared.Boil).UIRegistry
local UIShowcase = require(ReplicatedStorage.Features.UIShowcase)

UIRegistry.registerRoot("HUD", React.createElement(UIShowcase.HUD))

return {}
