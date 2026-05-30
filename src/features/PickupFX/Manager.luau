--!strict
-- Singleton state for the pickup-icon FX. Callable from any client code,
-- React or otherwise. The Overlay component subscribes via the internal
-- `_changed` Signal; external code subscribes to `onArrival`.
--
-- Lifecycle of an icon:
--   spawn(opts)  → push N icons into `active`, _changed fires
--   (Overlay's heartbeat runs the per-frame animation)
--   complete()   → fired by Overlay at end of travel: arrival Signal + flag
--   _remove()    → fired by Overlay after the fade-out: pop from active

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local Constants = require(script.Parent.Constants)
local Types = require(script.Parent.Types)

local Manager = {}

Manager.active = {} :: { Types.ActiveIcon }
Manager.destinations = {} :: { [Types.DestinationId]: Types.DestinationGetter }

-- Fires (destinationId, options) when an icon reaches its destination.
-- `destinationId` is the original string id if one was passed, else nil.
Manager.onArrival = Signal.new()

-- Internal: tells the Overlay to re-render (spawn or remove).
Manager._changed = Signal.new()

local nextId = 0
local function newId(): number
	nextId += 1
	return nextId
end

local function randomBetween(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function randomSign(): number
	return if math.random() < 0.5 then -1 else 1
end

-- Look up the live screen position for a destination id. Returns nil if the
-- id isn't registered or the getter returns nil.
function Manager.resolveDestination(to: Vector2 | Types.DestinationId): Vector2?
	if typeof(to) == "Vector2" then
		return to
	end
	local getter = Manager.destinations[to]
	if not getter then
		return nil
	end
	return getter()
end

function Manager.registerDestination(id: Types.DestinationId, getter: Types.DestinationGetter)
	Manager.destinations[id] = getter
end

function Manager.removeDestination(id: Types.DestinationId)
	Manager.destinations[id] = nil
end

-- Queue one or more icons. Each gets randomized stagger, travel duration, and
-- bezier curve offset so a burst doesn't look like a single rigid swarm.
function Manager.spawn(opts: Types.PickupOptions)
	local count = math.max(1, opts.count or 1)
	local to: Vector2 | Types.DestinationId = opts.to or opts.from
	local size = opts.size or Constants.DEFAULT_SIZE
	local now = os.clock()

	for _ = 1, count do
		local icon: Types.ActiveIcon = {
			id = newId(),
			icon = opts.icon,
			from = opts.from,
			to = to,
			size = size,
			spawnTime = now,
			delay = randomBetween(Constants.STAGGER_MIN, Constants.STAGGER_MAX),
			popDuration = Constants.POP_DURATION,
			travelDuration = randomBetween(Constants.TRAVEL_MIN, Constants.TRAVEL_MAX),
			fadeDuration = Constants.FADE_DURATION,
			curveOffset = randomBetween(Constants.CURVE_OFFSET_MIN, Constants.CURVE_OFFSET_MAX)
				* randomSign(),
			onArrival = opts.onArrival,
			arrived = false,
		}
		table.insert(Manager.active, icon)
	end

	Manager._changed:Fire()
end

-- Called by the Overlay's heartbeat at the end of the travel phase. Fires
-- the external arrival Signal + per-icon callback, then marks the icon so
-- the fade-out phase can run before _remove() drops it from the list.
function Manager._complete(icon: Types.ActiveIcon)
	if icon.arrived then
		return
	end
	icon.arrived = true
	local destinationId: Types.DestinationId? = if typeof(icon.to) == "string"
		then icon.to :: Types.DestinationId
		else nil
	Manager.onArrival:Fire(destinationId)
	if icon.onArrival then
		task.spawn(icon.onArrival)
	end
end

-- Called by the Overlay after the fade-out completes.
function Manager._remove(iconId: number)
	for i, icon in ipairs(Manager.active) do
		if icon.id == iconId then
			table.remove(Manager.active, i)
			Manager._changed:Fire()
			return
		end
	end
end

return Manager
