local Events = {
	require(script.Barrier)
}
local ExtremeEvents = {
	require(script.CherryBomb)
}
local GroundPound = require(script.GroundPound)


local random = Random.new()

local EventHandler = {}
EventHandler.__index = EventHandler

function EventHandler.new()
	
	local self = {
		enabled = false,
		extremeEventsEnabled = false,
		round = 0,
		selectedCells = {}, -- Save a list of cells that have been selected for GroundPound (but haven't been moved to RemovedCells yet)
		roundEvents = {}
	}
	setmetatable(self, EventHandler)
	
	return self
end

-- generates events at a frequency relative to self.rounds
function EventHandler:generateEvents()
	local toggle = 0
	local spawnInterval = 7 - self.round
		
	while self.enabled do
		local event = Events[random:NextInteger(1, #Events)]
		local generatedEvent = event.generateEvent(self.round)
		-- temporarily store the tween so we can stop them all
		-- manually at the end of the round
		table.insert(
			self.roundEvents,
			generatedEvent
		)
		
		if (toggle % 4) == 0 then
			if self.extremeEventsEnabled then
				local event, cellSelected = GroundPound.generateEvent(self.selectedCells)
				self.selectedCells = cellSelected
				table.insert(
					self.roundEvents,
					event
				)
			end
			
			-- add check here to see if the game has extreme events on
--			if self.extremeEventsEnabled then
				local extremeEvent = ExtremeEvents[1]
				local generatedEvent, cellSelected = extremeEvent.generateEvent(self.selectedCells)
				self.selectedCells = cellSelected
				table.insert(
					self.roundEvents,
					generatedEvent
				)
--			end
		end
		toggle += 1
		
		task.wait(spawnInterval)
	end
end

-- prompting the destruction of all the objects
-- clear the table for the following round
function EventHandler:clearEvents()
	-- event represents the cloned event object
	for _, event in self.roundEvents do
--		if event and event.Parent then
			event:SetAttribute("Cleanup", true)
--		end
	end
	table.clear(self.roundEvents)
	table.clear(self.selectedCells)
end

function EventHandler:enableExtremeEvents(enable: boolean)
	self.extremeEventsEnabled = enable
end

function EventHandler:enable(round)
	self.enabled = true
	self.round = round
	
	self:generateEvents()
end

function EventHandler:disable()
	self.enabled = false
	
	self:clearEvents()
end

return EventHandler