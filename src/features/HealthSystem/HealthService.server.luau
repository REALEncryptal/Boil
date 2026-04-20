local HealthService = {}

-- Lower priority runs earlier. Unset = runs last.
HealthService.Priority = 10

function HealthService.Start()
	print(`[HealthService] started (priority={HealthService.Priority})`)
end

return HealthService
