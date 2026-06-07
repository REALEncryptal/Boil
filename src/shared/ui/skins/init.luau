--!strict
-- Skin registry — name → skin table. Add a new skin by dropping a sibling
-- module (single file or folder) and listing it here. Each entry must satisfy
-- contract.Skin: { name, theme, components = { Button = …, Window = …, … } }.

local gem = require(script.gem)
local flat = require(script.flat)

return {
	gem = gem,
	flat = flat,
}
