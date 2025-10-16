-- Folders
local Handlers = script.Parent.Parent

-- Modules
local PlayerHandler = require(Handlers.PlayerHandler)
local ValidateSpot = require(script.ValidateSpot)
local ValidateTrap = require(script.ValidateTrap)

function ValidateArguments(player, spotRequested, trapID)
	if PlayerHandler.getPlayerStatus(player) == nil then
		return false
	end
	
	if not ValidateSpot(spotRequested) then
		return false
	end
	
	if not ValidateTrap(player, trapID) then
		return false
	end
	
	return true
end

return ValidateArguments