--!strict
-- Row — a horizontal Stack. Thin convenience wrapper so call sites read clearly
-- (`Row` vs `Stack`); it forwards every prop to Stack with direction forced to
-- "horizontal". Same transparent, structure-only behavior.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Stack = require(script.Parent.Stack)

export type RowProps = Stack.StackProps

return function(props: RowProps)
	local merged = table.clone(props)
	merged.direction = "horizontal"
	return React.createElement(Stack, merged)
end
