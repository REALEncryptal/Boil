local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Features.Cmdr.Constants)

local CmdrController = {}

function CmdrController.Start()
	-- CmdrClient is inserted into ReplicatedStorage by the server Cmdr bootstrap,
	-- so we must WaitForChild rather than require it statically.
	local CmdrClient = require(ReplicatedStorage:WaitForChild("CmdrClient"))
	CmdrClient:SetActivationKeys(Constants.ActivationKeys)
end

return CmdrController
