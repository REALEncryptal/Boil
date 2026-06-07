-- Settings — shared registry, server validation, client UI, and persistence
-- through PlayerData. Features add their categories + settings either by
-- requiring this module and calling registerSetting/registerCategory, or by
-- dropping a sibling `Settings.luau` file (returning `function(Settings) … end`)
-- that the auto-discovery loop below picks up at load time.
--
-- See docs/game/Settings.md for the full integration guide.

local Settings = {}

Settings.Constants = require(script.Constants)
Settings.Registry = require(script.Registry)
Settings.UI = require(script.SettingsUI)

-- The UIShell frame id used by the HUD. Other features can call
-- `UIShell.useFrame().open(Settings.FRAME_ID)` from React, or compose this
-- with their own UI shell, to navigate users to the Settings window.
Settings.FRAME_ID = "Settings"

Settings.registerSetting = Settings.Registry.registerSetting
Settings.registerCategory = Settings.Registry.registerCategory

------------------------------------------------------------------------------
-- Auto-discovery
------------------------------------------------------------------------------
-- Walk the Features tree and require any sibling feature's `Settings.luau`
-- module. That module is expected to return `function(Settings) ... end` —
-- when called, it receives this Settings table and uses the register* API
-- to declare its categories and settings.
--
-- This convention avoids a circular require (a feature's Settings.luau never
-- requires Features.Settings itself) and works identically on client and
-- server (both realms load this module and run the loop independently).
do
	local Features = script.Parent
	for _, featureModule in Features:GetChildren() do
		if featureModule == script then
			continue
		end
		local mod = featureModule:FindFirstChild("Settings")
		if mod == nil or not mod:IsA("ModuleScript") then
			continue
		end

		local ok, result = pcall(require, mod)
		if not ok then
			warn(`[Settings] failed to require {mod:GetFullName()}: {result}`)
			continue
		end
		if typeof(result) ~= "function" then
			warn(
				`[Settings] {mod:GetFullName()} must return function(Settings); `
					.. `got {typeof(result)}`
			)
			continue
		end

		local okCall, err = pcall(result, Settings)
		if not okCall then
			warn(`[Settings] registration error in {mod:GetFullName()}: {err}`)
		end
	end

	-- Discovery is the only sanctioned registration window. Seal so any later
	-- register* call (from server- or client-only code) errors instead of
	-- silently drifting the two realms' registries apart.
	Settings.Registry.seal()
end

return Settings
