function CoreCall(func, functionality, enabled) 
	local StarterGui = game:GetService("StarterGui")
	local RunService = game:GetService("RunService")
	
	local success, result
	repeat
		success, result = pcall(function()
		   return StarterGui:SetCore("ResetButtonCallback", false)
		end)
		if not success then
			warn(result)
		end
		RunService.Stepped:Wait()
	until success
	
end

return CoreCall