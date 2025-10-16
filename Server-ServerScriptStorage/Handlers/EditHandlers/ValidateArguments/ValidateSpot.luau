-- Folders
local Cells = workspace.Cells

-- The purpose of validate spot is to verify that the spot requested
-- is an actual location in the map
function ValidateSpot(spotRequested: string)
	local cell = Cells:FindFirstChild(spotRequested)
	if cell then
		return true
	end

	return false
end

return ValidateSpot