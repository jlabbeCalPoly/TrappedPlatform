-- Services
--local TweenService = game:GetService("TweenService")
local ServerStorage = game:GetService("ServerStorage")

-- Folders
local Barrier = ServerStorage.EventObjects.Barrier
local EventSpawns = workspace.EventSpawns

-- Specific event object(s) for this script
local Events = {
	Barrier.SmallLow,
	Barrier.SmallMiddle,
	Barrier.LowSplit,
	Barrier.MediumLow,
	Barrier.MediumHigh,
	Barrier.Large,
}

-- Random
local random = Random.new()

local Barrier = {}

-- start the event, connect to the tween end event to
-- do disconnects and destroy the cloned event
function Barrier.generateEvent(round: number)
	local event : Model = Events[random:NextInteger(1, #Events)]:Clone()

	local spawnPoint = random:NextInteger(1,6)
	local toSpawn = spawnPoint - 2
	if toSpawn <= 0 then
		-- since toSpawn is negative, add instead of subtract
		toSpawn = 6 + toSpawn
	end
	
	event.Start.Value = spawnPoint
	event.End.Value = toSpawn
	
	local startLocation : CFrame = EventSpawns[""..spawnPoint].CFrame
	
	event:PivotTo(startLocation)
	event.Parent = workspace
	
	local destructionTask
	local roundEndConnection -- called when all the remaining barriers need to be 
							 -- automatically destroyed at the end of the round
							 
	local function handleCleanup()
		-- give the SetAttribute adequate time to replicate to the player (if needed)
		task.wait(3)
		event:Destroy()
	end
	
	destructionTask = task.delay(20, function()
		roundEndConnection:Disconnect()
		event:SetAttribute("Cleanup", true)
		handleCleanup()
	end)
	
	roundEndConnection = event:GetAttributeChangedSignal("Cleanup"):Connect(function()
		task.cancel(destructionTask)
		roundEndConnection:Disconnect()
		handleCleanup()
	end)

	return event
end

return Barrier