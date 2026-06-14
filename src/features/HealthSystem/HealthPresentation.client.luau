-- Root presentation for HealthSystem: registers the always-mounted health
-- widget as a top-level element of the client tree. The root client file no
-- longer names HealthSystem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UIRegistry = require(ReplicatedStorage.Shared.Boil).UIRegistry
local HealthSystem = require(ReplicatedStorage.Features.HealthSystem)

-- hp = 100 is the demo value the root previously passed inline; real health
-- would come from a hook reading replicated state.
UIRegistry.registerRoot("Health", React.createElement(HealthSystem.UI, { hp = 100 }))

return {}
