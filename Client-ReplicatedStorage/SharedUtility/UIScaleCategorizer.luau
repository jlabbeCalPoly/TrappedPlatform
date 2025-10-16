-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Folders
local SharedUtility = ReplicatedStorage.SharedUtility

-- Modules
local Constants = require(SharedUtility.Constants)

function UIScaleCategorizer(dimensions: number) 
	local scale
	
	-- determine which category the dimension falls into
	if dimensions < Constants.MINI_CUTOFF then
		scale = Constants.UI_SCALE_MINI
	elseif dimensions < Constants.SMALL_CUTOFF then
		scale = Constants.UI_SCALE_SMALL
	elseif dimensions < Constants.MEDIUM_CUTOFF then
		scale = Constants.UI_SCALE_MEDIUM
	else
		scale = Constants.UI_SCALE_LARGE
	end
	
	return scale
end

return UIScaleCategorizer