--!strict
-- Shared settings registry. Holds the list of categories + settings other
-- features have declared, and a Changed signal the UI listens to so newly
-- registered entries appear without a remount.
--
-- Each realm has its own copy (Lua state is per-realm). Register from shared
-- code — an `init.luau` top-level call, or a sibling `Settings.luau` file
-- picked up by the Settings feature's auto-discovery — so both realms see
-- the same set. Server-only or client-only registration would let the two
-- sides drift, and the server uses the registry to validate writes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

export type ToggleSetting = {
	kind: "toggle",
	id: string,
	label: string,
	-- Optional helper text; not yet shown in the default UI but kept on the
	-- record so future variants (tooltips, accessibility) can read it.
	description: string?,
	-- Category id this setting belongs to. The UI groups + sorts by this.
	category: string,
	-- Initial value if the player has nothing persisted yet.
	default: boolean,
	-- Sort order inside the category (low → high). Ties break by label.
	order: number?,
	-- Checkbox palette ("white" | "red" | "blue" | "green" | "purple" |
	-- "yellow" | "rainbow"). Falls back to "white".
	variant: string?,
}

-- Add new shapes here (slider, dropdown, etc.) once more setting kinds exist.
-- The union flows through validation, packet routing, and UI rendering.
export type Setting = ToggleSetting

export type Category = {
	id: string,
	title: string,
	-- Sort order across categories (low → high). Ties break by title.
	order: number?,
}

export type Section = {
	category: Category,
	settings: { Setting },
}

local Registry = {}

-- Fires whenever a setting or category is registered. The UI subscribes to
-- this and re-reads the list so late registrations show up live.
Registry.Changed = Signal.new()

local settings: { [string]: Setting } = {}
local categories: { [string]: Category } = {}

-- Once the shared auto-discovery pass finishes, the registry is sealed. Any
-- later register* call is a realm-specific registration (server- or client-only
-- code reaching in after load) — exactly the thing that would let the two
-- realms' registries diverge and break server-side write validation. We turn
-- that into a hard error at the call site rather than silent drift.
local sealed = false

function Registry.seal()
	sealed = true
end

local function assertUnsealed(what: string, id: string)
	if not sealed then
		return
	end
	error(
		`[Settings] {what} "{id}" registered after the registry was sealed. `
			.. `Register only from shared code (a sibling Settings.luau picked up by `
			.. `auto-discovery), never from server- or client-only code — otherwise the `
			.. `two realms' registries diverge.`,
		2
	)
end

function Registry.registerSetting(def: Setting)
	assertUnsealed("setting", def.id)
	if settings[def.id] ~= nil then
		warn(`[Settings] setting "{def.id}" already registered; overwriting`)
	end
	settings[def.id] = def
	Registry.Changed:Fire()
end

function Registry.registerCategory(def: Category)
	assertUnsealed("category", def.id)
	if categories[def.id] ~= nil then
		warn(`[Settings] category "{def.id}" already registered; overwriting`)
	end
	categories[def.id] = def
	Registry.Changed:Fire()
end

function Registry.getSetting(id: string): Setting?
	return settings[id]
end

function Registry.getCategory(id: string): Category?
	return categories[id]
end

local function sortKey(a: { order: number?, label: string? }, b: { order: number?, label: string? }): boolean
	local ao = a.order or math.huge
	local bo = b.order or math.huge
	if ao ~= bo then
		return ao < bo
	end
	return (a.label or "") < (b.label or "")
end

-- Returns the registry as a list of { category, settings } sections, sorted
-- by category order then title, and per section settings sorted by order
-- then label. Settings whose category isn't registered are dropped (with a
-- warning) — they can't be displayed without a header.
function Registry.list(): { Section }
	local catList: { Category } = {}
	for _, c in categories do
		table.insert(catList, c)
	end
	table.sort(catList, function(a, b)
		local ao = a.order or math.huge
		local bo = b.order or math.huge
		if ao ~= bo then
			return ao < bo
		end
		return a.title < b.title
	end)

	-- Group settings by category for one O(n) pass.
	local grouped: { [string]: { Setting } } = {}
	for _, def in settings do
		if categories[def.category] == nil then
			warn(`[Settings] setting "{def.id}" references unknown category "{def.category}"`)
			continue
		end
		local bucket = grouped[def.category]
		if bucket == nil then
			bucket = {}
			grouped[def.category] = bucket
		end
		table.insert(bucket, def)
	end

	local result: { Section } = {}
	for _, cat in catList do
		local bucket = grouped[cat.id] or {}
		table.sort(bucket, sortKey :: any)
		table.insert(result, { category = cat, settings = bucket })
	end
	return result
end

return Registry
