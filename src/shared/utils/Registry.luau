--!strict
-- Registry — the generic extension seam. This is the mechanism the whole
-- "features stack like legos" idea runs on.
--
-- The problem it solves: a shared feature that wants to accept contributions
-- from other features used to hand-roll its own discovery loop. PlayerData wrote
-- one, Settings wrote a second, and a third shared feature (Cash, Levels, Pets)
-- would have written a fourth — the same 25 lines of walk-require-pcall-warn
-- each time, with rules that quietly diverged. There was no way to say "any
-- feature may contribute to me" once.
--
-- Now a shared feature declares its seam in a line:
--
--   -- src/features/Cash/init.luau
--   local Cash = {}
--   Cash.currencies = Boil.Registry.define("Cash")
--   return Cash
--
-- and any other feature opts in by dropping a sibling file with the matching
-- name, returning a function that receives the registry:
--
--   -- src/features/Rebirth/Cash.luau
--   return function(cash)
--       cash.add({ id = "gems", label = "Gems", order = 20 })
--   end
--
-- Rebirth names Cash; Cash never names Rebirth. The dependency arrow points one
-- way, which is what lets you delete either folder.
--
-- ---------------------------------------------------------------------------
-- Realms
-- ---------------------------------------------------------------------------
-- Lua state is per-realm, so each realm builds its own copy from the same shared
-- files. Register only from shared code (a sibling `<Name>.luau`, discovered
-- below) — never from server- or client-only code, or the two realms' registries
-- diverge and any server-side validation reads a different list than the client
-- rendered. `seal()` turns that mistake into a loud error instead of silent drift.
--
-- ---------------------------------------------------------------------------
-- Discovery timing
-- ---------------------------------------------------------------------------
-- Discovery is LAZY: it runs on the first `list`/`get`/`count`, not at define
-- time. A registry defined inside a feature's `init.luau` cannot walk the
-- Features tree during its own require without recursing into itself, and UI
-- Labs never runs an entry script at all — so deferring is what makes both work.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)

local FEATURES_CONTAINER = "Features"

export type Entry = {
	id: string,
	-- Sort position, low to high. Unset sorts last, then by id.
	order: number?,
	[string]: any,
}

export type Registry<T> = {
	name: string,
	-- Fires whenever an entry is added, so a UI can re-read without a remount.
	Changed: any,
	add: (entry: T) -> (),
	get: (id: string) -> T?,
	list: () -> { T },
	count: () -> number,
	has: (id: string) -> boolean,
	seal: () -> (),
	-- Force the discovery pass now. Only needed when a caller must observe
	-- registrations before any read — normal code just calls `list()`.
	discover: () -> (),
}

local Registry = {}

-- Every registry defined this session, keyed by name. Defining the same name
-- twice returns the existing one rather than silently creating a second, private
-- registry that no contributor can reach.
local defined: { [string]: any } = {}

local function sortEntries(a: Entry, b: Entry): boolean
	local ao = a.order or math.huge
	local bo = b.order or math.huge
	if ao ~= bo then
		return ao < bo
	end
	return tostring(a.id) < tostring(b.id)
end

-- Walk the Features container for a child ModuleScript named `name`, require it,
-- and call the function it returns with the registry API.
--
-- The container is read GENERICALLY — iterate children, look for a name match —
-- so no framework code ever names a feature. That is the framework-boundary rule
-- (docs/game/framework-boundary.md), and it's checked by
-- `lune run tools/check-framework-boundary`.
local function runDiscovery(name: string, api: any, owner: Instance?)
	local features = ReplicatedStorage:FindFirstChild(FEATURES_CONTAINER)
	if features == nil then
		-- The framework boots with zero features. Not an error.
		return
	end

	for _, feature in features:GetChildren() do
		-- A feature never registers into its own seam; that's just the owner's
		-- module requiring itself.
		if owner ~= nil and feature == owner then
			continue
		end

		local module = feature:FindFirstChild(name)
		if module == nil or not module:IsA("ModuleScript") then
			continue
		end

		local ok, result = pcall(require, module)
		if not ok then
			warn(`[Registry:{name}] failed to require {module:GetFullName()}: {result}`)
			continue
		end
		if typeof(result) ~= "function" then
			warn(
				`[Registry:{name}] {module:GetFullName()} must return `
					.. `function({name}) … end; got {typeof(result)}`
			)
			continue
		end

		-- One bad contributor must not stop the rest from registering, or a typo
		-- in a new feature would take the whole game's UI down with it.
		local okCall, err = pcall(result, api)
		if not okCall then
			warn(`[Registry:{name}] registration error in {module:GetFullName()}: {err}`)
		end
	end
end

-- Declare an extension seam named `name`.
--
-- `owner` is the defining feature's own instance (pass `script` from an
-- `init.luau`) so discovery skips it. Optional — omit it and a same-named module
-- inside the owner is treated like any other contributor.
function Registry.define<T>(name: string, owner: Instance?): Registry<T>
	local existing = defined[name]
	if existing then
		return existing
	end

	local entries: { [string]: any } = {}
	local sealed = false
	local discovered = false

	local api: any = {}
	api.name = name
	api.Changed = Signal.new()

	local function ensureDiscovered()
		if discovered then
			return
		end
		-- Set before running so a contributor that reads `list()` during its own
		-- registration sees a partial list instead of recursing forever.
		discovered = true
		runDiscovery(name, api, owner)
	end

	function api.add(entry: T)
		local record = entry :: any
		if typeof(record) ~= "table" or typeof(record.id) ~= "string" then
			error(`[Registry:{name}] add() expects a table with a string \`id\``, 2)
		end
		if sealed then
			error(
				`[Registry:{name}] "{record.id}" registered after the registry was sealed. `
					.. `Register only from shared code (a sibling {name}.luau picked up by `
					.. `discovery), never from server- or client-only code — otherwise the two `
					.. `realms' registries diverge.`,
				2
			)
		end
		if entries[record.id] ~= nil then
			warn(`[Registry:{name}] "{record.id}" already registered; overwriting`)
		end
		entries[record.id] = record
		api.Changed:Fire()
	end

	function api.get(id: string): T?
		ensureDiscovered()
		return entries[id]
	end

	function api.has(id: string): boolean
		ensureDiscovered()
		return entries[id] ~= nil
	end

	function api.list(): { T }
		ensureDiscovered()
		local out: { any } = {}
		for _, entry in entries do
			table.insert(out, entry)
		end
		table.sort(out, sortEntries)
		return out
	end

	function api.count(): number
		ensureDiscovered()
		local n = 0
		for _ in entries do
			n += 1
		end
		return n
	end

	function api.discover()
		ensureDiscovered()
	end

	function api.seal()
		ensureDiscovered()
		sealed = true
	end

	defined[name] = api
	return api
end

-- Names of every registry defined so far. Diagnostic — used by the Cmdr
-- `registries` command and worth printing when a registration silently no-ops.
function Registry.names(): { string }
	local out: { string } = {}
	for name in defined do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

return Registry
