-- Services
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Folders
local TrapModels = ServerStorage.TrapModels
local Handlers = ServerScriptService.Handlers

-- Modules
local InventoryHandler = require(Handlers.InventoryHandler)

function ValidateTrap(player: Player, trapID: string)
	-- check to see if the trap is an actual valid trap
	local trap = TrapModels:FindFirstChild(trapID)
	if trap == nil then
		return false
	end
	
	-- check to see if the player has an inventory to begin with,
	-- then check if the player has the trap in their inventory
	local inventory = InventoryHandler.getInventory(player)
	if inventory == nil then
		return false
	end

	for _, trapInfo in inventory do
		if trapInfo[1] == trapID then
			return true
		end
	end
	
	return false
end

return ValidateTrap