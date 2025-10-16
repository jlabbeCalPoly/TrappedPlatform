-- Services
local ServerScriptService = game:GetService("ServerScriptService")

-- Folders
local TypeValidation = ServerScriptService.TypeValidation

-- Modules
local ValidateNumber = require(TypeValidation.ValidateNumber)
local ValidatePlayer = require(TypeValidation.ValidatePlayer)

function ValidateEventDamage(player: Player, timestamp: number, damage: number)
	if not ValidatePlayer(player) then
		return false
	end
	
	if not ValidateNumber(timestamp) then
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
	
	if not ValidateNumber(damage) then
		return false
	end
	
	if damage < 0 then
		return false
	end
	
	return true
end

return ValidateEventDamage