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
-- features" a version bump instead of a merge. See docs/game/framework-boundary.md.
--
-- What belongs here: the framework's OWN modules (the UI kit, the load helpers,
-- the presentation registry, the replica hook). What does NOT: third-party Wally
-- packages (React, ByteNet, ReplicaService) — features require those directly —
-- and anything owned by a feature (PlayerData templates, Settings categories).
-- The framework ships with zero features; this surface names none.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boil = {}

-- UI seam (skin / layout / primitives). See Shared.ui.
Boil.ui = require(ReplicatedStorage.Shared.ui)

-- Load orchestration. `Loader` is the third-party module loader the entry
-- scripts drive; `LoadOrdered` is the framework's dependency-order helper.
Boil.Loader = require(ReplicatedStorage.Packages.Loader)
Boil.LoadOrdered = require(ReplicatedStorage.Shared.utils.LoadOrdered)

-- Presentation registry — features register screens / roots / providers here so
-- the client entry names no feature.
Boil.UIRegistry = require(ReplicatedStorage.Shared.utils.UIRegistry)

-- Replica state hook for views.
Boil.useReplica = require(ReplicatedStorage.Shared.utils.useReplica)

return Boil
