-- Orders a list of required modules by their `.Priority` field (ascending).
-- Modules with no numeric `.Priority` sort to the end.
-- Intended to be piped between Loader.LoadDescendants and Loader.SpawnAll.

local function LoadOrdered<T>(modules: { T }): { T }
	table.sort(modules, function(a, b)
		local pa = (type(a) == "table" and tonumber((a :: any).Priority)) or math.huge
		local pb = (type(b) == "table" and tonumber((b :: any).Priority)) or math.huge
		return pa < pb
	end)
	return modules
end

return LoadOrdered
