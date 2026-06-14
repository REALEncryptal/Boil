--!strict
-- Boil — the framework's single public surface.
--
-- This is the *contract* between the framework and the features built on it.
-- A feature consumes the framework through here and nowhere else:
--
--   local Boil = require(ReplicatedStorage.Shared.Boil)
--   React.createElement(Boil.ui.Button, { variant = "red", text = "X" })
--   Boil.UIRegistry.registerScreen("Notes", element)
--
-- Why the indirection: features depend on this stable re-export, never on deep
-- framework paths (`Shared.ui.skins.gem`, `Shared.utils.LoadOrdered`, …). That
-- lets the framework refactor its internals freely — only this surface has to
-- stay stable — which is what makes "update the framework without touching the
-- features" a version bump instead of a merge. Enforced both ways by
-- tools/check-framework-boundary. See docs/game/framework-boundary.md.
--
-- What belongs here: the framework's OWN modules (the UI kit, the load helpers,
-- the presentation registry, the replica hook, the audio system). What does NOT:
-- third-party Wally packages (React, ByteNet, ReplicaService — features require
-- those directly) and anything owned by a feature (PlayerData templates, Settings
-- categories). The framework ships with zero features; this surface names none.
--
-- Members load lazily on first access and cache, so requiring Boil is cheap and
-- realm-safe: a server Service that only touches `Boil.LoadOrdered` never pulls in
-- the React UI kit behind `Boil.ui`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Boil = {
	ui: typeof(require(ReplicatedStorage.Shared.ui)),
	audio: typeof(require(ReplicatedStorage.Shared.audio)),
	Loader: typeof(require(ReplicatedStorage.Packages.Loader)),
	LoadOrdered: typeof(require(ReplicatedStorage.Shared.utils.LoadOrdered)),
	UIRegistry: typeof(require(ReplicatedStorage.Shared.utils.UIRegistry)),
	useReplica: typeof(require(ReplicatedStorage.Shared.utils.useReplica)),
}

-- Lazy loaders, resolved once and cached by the metatable below.
local loaders: { [string]: () -> any } = {
	ui = function()
		return require(ReplicatedStorage.Shared.ui)
	end,
	audio = function()
		return require(ReplicatedStorage.Shared.audio)
	end,
	Loader = function()
		return require(ReplicatedStorage.Packages.Loader)
	end,
	LoadOrdered = function()
		return require(ReplicatedStorage.Shared.utils.LoadOrdered)
	end,
	UIRegistry = function()
		return require(ReplicatedStorage.Shared.utils.UIRegistry)
	end,
	useReplica = function()
		return require(ReplicatedStorage.Shared.utils.useReplica)
	end,
}

local cache: { [string]: any } = {}

local Boil = setmetatable({}, {
	__index = function(_, key: string): any
		if cache[key] == nil then
			local loader = loaders[key]
			if not loader then
				error(`[Boil] unknown member "{key}" — not part of the public surface`, 2)
			end
			cache[key] = loader()
		end
		return cache[key]
	end,
})

return (Boil :: any) :: Boil
