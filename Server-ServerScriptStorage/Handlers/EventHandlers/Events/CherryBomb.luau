-- Services
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Folders
local CherryBombTemplate = ServerStorage.EventObjects.CherryBomb
local Cells = workspace.Cells

-- Random
local random = Random.new()

local CherryBomb = {}

-- start the event, connect to the tween end event to
-- do disconnects and destroy the cloned event
function CherryBomb.generateEvent(selectedCells)
	local event = CherryBombTemplate:Clone()
	local cells = Cells:GetChildren() 
		
	local attempts = 10
	local spot = nil
	while attempts > 0 do
		local spotRequested = cells[random:NextInteger(1, #cells)].Name
		-- if there is already a trap there, simply continue onto the next iteration
		if selectedCells[spotRequested] then
			attempts -= 1
		else
			spot = spotRequested
			selectedCells[spot] = true
			attempts = 0
		end
	end

	event:PivotTo(Cells[spot].PrimaryPart.CFrame)
	event:SetAttribute("CellId", spot)
	event.Parent = workspace

	local destructionTask
	local roundEndConnection -- called when all the remaining barriers need to be 
	-- automatically destroyed at the end of the round

	local function handleCleanup()
		-- give the SetAttribute adequate time to replicate to the player (if needed)
		task.wait(3)
		event:Destroy()
	end

	destructionTask = task.delay(7.5, function()
		roundEndConnection:Disconnect()
		event:SetAttribute("Cleanup", true)
		handleCleanup()
	end)

	-- only to be called in the event that the GroundPound is destroyed prematurely
	roundEndConnection = event:GetAttributeChangedSignal("Cleanup"):Connect(function()
		task.cancel(destructionTask)
		roundEndConnection:Disconnect()
		handleCleanup()
	end)

	return event, selectedCells
end

return CherryBomb