-- Services
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

-- Folders
local TypeValidation = ServerScriptService.TypeValidation
local TrapModels = ServerStorage.TrapModels

-- Modules
local ValidateNumber = require(TypeValidation.ValidateNumber)
local ValidateString = require(TypeValidation.ValidateString)
local ValidatePlayer = require(TypeValidation.ValidatePlayer)

function ValidateTypes(player, currencyType: string, trapType, levelUpgradingTo)
	if not ValidatePlayer(player) then
		return false
	end
	
	if not ValidateString(currencyType) or (currencyType ~= "Cash" and currencyType ~= "Tickets") then
		return false
	end
	
	if currencyType == "Cash" then
		if not ValidateString(trapType) or TrapModels:FindFirstChild(trapType) == nil then
			return false
		end

		if not ValidateNumber(levelUpgradingTo) or levelUpgradingTo > 6 then
			return false
		end
	end

	return true
end

return ValidateTypes