-- Stateful container that wires the pure SettingsUI to live data:
--   • useReplica(PlayerDataController, "Settings") for current values
--   • Registry.Changed signal so newly-registered settings appear without remount
--   • SettingsController.LinkRequested for transient row highlights
--
-- The HUD mounts this from the client entry script (`client/init.client.luau`)
-- and passes it to UIShowcase.HUD's frameContents so the Settings sidebar
-- entry opens a real settings panel instead of placeholder rows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local Boil = require(ReplicatedStorage.Shared.Boil)

local Constants = require(ReplicatedStorage.Features.Settings.Constants)
local Registry = require(ReplicatedStorage.Features.Settings.Registry)
local SettingsUI = require(ReplicatedStorage.Features.Settings.SettingsUI)

-- Client-realm siblings (StarterPlayerScripts.Features tree).
local SettingsController = require(script.Parent.SettingsController)
local PlayerDataController = require(script.Parent.Parent.PlayerData.PlayerDataController)

-- Subscribes to the Registry's Changed signal and returns its current `list()`.
-- Forces a re-render via a version counter on each change.
local function useRegistrySections(): { Registry.Section }
	local _, setVersion = React.useState(0)
	React.useEffect(function()
		local conn = Registry.Changed:Connect(function()
			setVersion(function(v: number): number
				return v + 1
			end)
		end)
		return function()
			conn:Disconnect()
		end
	end, {})
	return Registry.list()
end

return function()
	local sections = useRegistrySections()
	local values = Boil.useReplica(PlayerDataController, Constants.PROFILE_KEY) or {}

	local focusedId, setFocusedId = React.useState(nil :: string?)

	React.useEffect(function()
		local conn = SettingsController.LinkRequested:Connect(function(id: string)
			setFocusedId(id)
			-- Clear the highlight after the timeout, but only if the same id
			-- is still focused (don't stomp a newer linkTo with our timer).
			task.delay(Constants.LINK_HIGHLIGHT_SECONDS, function()
				setFocusedId(function(current: string?): string?
					if current == id then
						return nil
					end
					return current
				end)
			end)
		end)
		return function()
			conn:Disconnect()
		end
	end, {})

	return React.createElement(SettingsUI, {
		sections = sections,
		values = values,
		onToggle = SettingsController.setToggle,
		focusedId = focusedId,
	})
end
