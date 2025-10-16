-- Services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

-- Folders
local Handlers = ServerScriptService.Handlers
local TrapModels = ServerStorage.TrapModels
local Traps = Workspace.Traps

-- Modules
local PlayerHandler = require(Handlers.PlayerHandler)

function ValidateArguments(player: Player, 
						   timestamp: number, 
						   cellID: string,
						   trapName: string, 
						   value: number)
						   
	-- validate player
	if PlayerHandler.getPlayerStatus(player) == nil then
		return false
	end
	
	-- validate timestamp
	local now = workspace:GetServerTimeNow()
	if timestamp > now then
		return false
	end
	if timestamp < now - 1 then
		return false
	end
	
	-- validate cellID
	if Traps[cellID] == nil then
		return false
	end
	
	-- validate trapName
	if TrapModels[trapName] == nil then
		return false
	end

	-- validate value
	local trapType = Traps[cellID]:GetAttribute("TrapType")	
	if trapType == "Damage" then
		if value < 0 then
			return false
		end
	elseif trapType == "Utility" then
		if value ~= 1 then
			return false
		end
	end
	
	return true
end

return ValidateArguments