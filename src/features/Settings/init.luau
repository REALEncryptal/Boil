-- Settings — shared registry, server validation, client UI, and persistence
-- through PlayerData. A feature declares its own settings by dropping a sibling
-- `Settings.luau` returning `function(Settings) … end`; Settings never names it.
--
-- The discovery loop that used to live here by hand is now `Boil.Registry` — the
-- same mechanism PlayerData and the HUD's Nav use. Settings keeps its own data
-- model (categories and settings are two collections with their own sorting, not
-- one flat list), and lets the shared registry own discovery and sealing.
--
-- See docs/game/Settings.md for why it is built this way.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Boil = require(ReplicatedStorage.Shared.Boil)

local Settings = {}

Settings.Constants = require(script.Constants)
Settings.Registry = require(script.Registry)
Settings.UI = require(script.SettingsUI)

-- The UIShell frame id, also the HUD nav id (see Nav.luau). Other features can
-- call `UIShell.useFrame().open(Settings.FRAME_ID)` to navigate here.
Settings.FRAME_ID = Settings.Constants.FRAME_ID

Settings.registerSetting = Settings.Registry.registerSetting
Settings.registerCategory = Settings.Registry.registerCategory

------------------------------------------------------------------------------
-- Discovery
------------------------------------------------------------------------------
-- The shared registry finds every feature's sibling `Settings.luau` and calls it
-- with `seam`. Attaching the register* methods to `seam` BEFORE the first read is
-- what makes them visible to contributors — discovery is lazy, so nothing has run
-- yet at this point.
local seam = Boil.Registry.define("Settings", script)
seam.registerCategory = Settings.registerCategory
seam.registerSetting = Settings.registerSetting

-- Eager, unlike most registries: the server validates inbound writes against this
-- list, so it must be complete before the first packet arrives rather than on the
-- first read.
seam.discover()

-- Discovery is the only sanctioned registration window. Seal so any later
-- register* call (from server- or client-only code) errors instead of silently
-- drifting the two realms' registries apart.
Settings.Registry.seal()
seam.seal()

return Settings
