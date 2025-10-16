-- Services
local ServerScriptService = game:GetService("ServerScriptService")

-- Folders
local TypeValidation = ServerScriptService.TypeValidation

-- Modules
local ValidateNumber = require(TypeValidation.ValidateNumber)
local ValidateString = require(TypeValidation.ValidateString)
local ValidatePlayer = require(TypeValidation.ValidatePlayer)

function ValidateTypes(player: Player, 
					   timestamp: number, 
					   cellID: string, 
					   trapName: string, 
					   value: number)
					   
	if not ValidatePlayer(player) then
		return false
	end
					   
	if not ValidateNumber(timestamp) then
		return false
	end

	if not ValidateString(cellID) then
		return false
	end
	
	if not ValidateString(trapName) then
		return false
	end

	if not ValidateNumber(value) then
		return false
	end
	
	return true
end

return ValidateTypes