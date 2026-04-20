local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cmdr = require(ReplicatedStorage.Packages.Cmdr)
local Constants = require(ReplicatedStorage.Features.Cmdr.Constants)

local CmdrService = {}

-- After PlayerData (Priority=1) but before gameplay services.
CmdrService.Priority = 2

local function isAllowed(player: Player): boolean
	for _, name in Constants.AllowedUsernames do
		if player.Name == name then
			return true
		end
	end
	return false
end

function CmdrService.IsAllowed(player: Player): boolean
	return isAllowed(player)
end

function CmdrService.Start()
	Cmdr:RegisterDefaultCommands()

	-- Gate every command on the server. Cmdr runs the hook before dispatch;
	-- returning a string blocks execution and surfaces the message to the user.
	Cmdr.Registry:RegisterHook("BeforeRun", function(context)
		if not isAllowed(context.Executor) then
			return "You don't have permission to run this command."
		end
		return nil
	end)
end

return CmdrService
