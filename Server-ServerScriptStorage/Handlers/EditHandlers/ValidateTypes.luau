-- Services
local ServerScriptService = game:GetService("ServerScriptService")

-- Folders
local TypeValidation = ServerScriptService.TypeValidation

-- Modules
local ValidateString = require(TypeValidation.ValidateString)
local ValidateNumber = require(TypeValidation.ValidateNumber)

function ValidateTypes(spotRequested, trapID, rotation)
	if not ValidateString(spotRequested) then
		return false
	end
	
	if not ValidateString(trapID) then
		return false
	end
	
	if not ValidateNumber(rotation) then
		return false
	end
	
	return true
end

return ValidateTypes