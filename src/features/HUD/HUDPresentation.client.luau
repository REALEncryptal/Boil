-- Root presentation for HUD: mounts the heads-up display as a top-level element
-- of the client tree.
--
-- The client entry never names HUD — it renders whatever registered — so the
-- framework still boots with `src/features/` empty. Discovered and required
-- before mount by init.client.luau's presentation loop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIRegistry = require(ReplicatedStorage.Shared.Boil).UIRegistry
local HUD = require(ReplicatedStorage.Features.HUD)

if HUD.Constants.Presentations.root then
	UIRegistry.registerRoot("HUD", React.createElement(HUD.UI))
end

return {}
