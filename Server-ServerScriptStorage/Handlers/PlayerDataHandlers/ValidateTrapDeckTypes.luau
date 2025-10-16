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

function ValidateTypes(player, trapType, slot)
	if not ValidatePlayer(player) then
		return false
	end
	
	if not ValidateString(trapType) and TrapModels[trapType] then
		return false
	end

	if not ValidateNumber(slot) and slot >= 1 and slot <= 3 then
		return false
	end

	return true
end

return ValidateTypes