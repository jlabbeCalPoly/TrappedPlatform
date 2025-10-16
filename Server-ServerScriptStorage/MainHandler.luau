-- Services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Folders
local Handlers = ServerScriptService.Handlers
local Remotes = ReplicatedStorage.Remotes

-- Modules
local EditHandler = require(Handlers.EditHandler)
local ActionHandler = require(Handlers.ActionHandler)
local EventHandler = require(Handlers.EventHandler)
local PlayerHandler = require(Handlers.PlayerHandler)
local PlayerDataHandler = require(Handlers.PlayerDataHandler)
local TrapDataHandler = require(Handlers.TrapDataHandler)
local GameEarningsHandler = require(Handlers.GameEarningsHandler)

local MainHandler = {}
MainHandler.__index = MainHandler

function MainHandler.setup()
	local editHandler = EditHandler.new()
	local actionHandler = ActionHandler.new()
	local eventHandler = EventHandler.new()
	
	local self = {
		editHandler = editHandler,
		actionHandler = actionHandler,
		eventHandler = eventHandler,
		connections = {}
	}
	setmetatable(self, MainHandler)

	self:intermission()
end

function MainHandler:intermission()
	self:disableAll()
	
	local timer = 30
	workspace:SetAttribute("CountdownText", "Game starting in:")
	
	while timer >= 0 do
		workspace:SetAttribute("CountdownTimer", timer)
		timer -= 1
		task.wait(1)
	end
	
	-- add all the players into the next game
	for player, _ in PlayerDataHandler.getConcurrentPlayers() do
		PlayerHandler.addPlayer(player)
	end
	
	-- check to make sure the number of players is >= 2
	-- if so, begin the rounds
	local playerCount = PlayerHandler.playerCount.Value
	if playerCount >= 1 then
		local numInString = tostring(playerCount)
		workspace:SetAttribute("InitialPlayerCount", numInString)
		workspace:SetAttribute("RemainingPlayerCount", numInString)
		self:handleRounds()
	
	-- otherwise, clear playerHandler and restart the intermission period
	else
		PlayerHandler.clearPlayers()
		self:intermission()
	end
end

function MainHandler:handleRounds()
	local round = 1
	local endRoundEarly = false
	PlayerHandler.setEndEarlyCallback(function()
		endRoundEarly = true
	end)
	
	-- since all players join the game with action enabled,
	-- we need to disable it
	self.actionHandler:endActionPhase()
	
	local eventPower = workspace:GetAttribute("EventTickets")
	if eventPower > 0 then
		self.eventHandler:enableExtremeEvents(true)
		workspace:SetAttribute("EventTickets", eventPower - 1)
	else
		self.eventHandler:enableExtremeEvents(false)
	end
	
	-- outermost loop, runs each "subround" for a total of 3 for the whole match
	while round <= 3 and not endRoundEarly do	
		workspace:SetAttribute("RoundCount", tostring(round))
		
		local timer = 20
		workspace:SetAttribute("CountdownText", "Place your traps!")
		
		-- Phase 1: Edit phase
		-- Begin the phase, passing in the round # (representing the amount of traps the players recieve)
		self:enableEdit()
		self.editHandler:beginEditPhase(round)
		while timer >= 0 and not endRoundEarly do
			workspace:SetAttribute("CountdownTimer", timer)
			timer -= 1
			task.wait(1)
		end
		self.editHandler:endEditPhase()
		
		local needsExtraTraps = self.editHandler:placeAdditionalTraps(round)
		if needsExtraTraps then
			local timer = 3
			workspace:SetAttribute("CountdownText", "Adding extra traps")
			while timer >= 0 and not endRoundEarly do
				workspace:SetAttribute("CountdownTimer", timer)
				timer -= 1
				task.wait(1)
			end
		end
		
		local initialPlayerCount = PlayerHandler.playerCount.Value
		if initialPlayerCount > 0 and round ~= 3 then
			for player, _ in PlayerDataHandler.getConcurrentPlayers() do
				PlayerHandler.addMidgame(player)
			end
			local newPlayerCount = PlayerHandler.playerCount.Value
			local numInString = tostring(newPlayerCount)
			workspace:SetAttribute("RemainingPlayerCount", numInString)
			if newPlayerCount > initialPlayerCount then
				workspace:SetAttribute("InitialPlayerCount", numInString)
			end
		end
		
		self.editHandler:updateFloorDividers(false)
		
		local timer = 5
		workspace:SetAttribute("CountdownText", "Immunity ends in:")
		-- Phase 2: Action phase
		-- Begin the phase
		self:enableAction()
		self.actionHandler.beginActionPhase(round)
		
		while timer >= 0 and not endRoundEarly do
			workspace:SetAttribute("CountdownTimer", timer)
			timer -= 1
			task.wait(1)
		end
		
		local timer = 59
		workspace:SetAttribute("CountdownText", "Survive the round!")
		task.spawn(function()
			self.eventHandler:enable(round)
		end)
		
		while timer >= 0 and not endRoundEarly do
			workspace:SetAttribute("CountdownTimer", timer)
			timer -= 1
			task.wait(1)
		end
		
		local initialPlayerCount = PlayerHandler.playerCount.Value
		if initialPlayerCount > 0 and round ~= 3 then
			for player, _ in PlayerDataHandler.getConcurrentPlayers() do
				PlayerHandler.addMidgame(player)
			end
			local newPlayerCount = PlayerHandler.playerCount.Value
			local numInString = tostring(newPlayerCount)
			workspace:SetAttribute("RemainingPlayerCount", numInString)
			if newPlayerCount > initialPlayerCount then
				workspace:SetAttribute("InitialPlayerCount", numInString)
			end
		end
		
		self.actionHandler:endActionPhase()
		
		self.eventHandler:disable()
		
		if round ~= 3 then
			task.spawn(function()
				GameEarningsHandler.grantRoundEarnings()
			end)
		end
		
		-- increment round
		round += 1
	end

	self:onGameEnd()
	self:intermission()
end

function MainHandler:onGameEnd()
	-- teleport all remaining players on the map back to the lobby,
	-- as well as reactivating their action
	self.actionHandler:onGameEnd()
	
	-- disable both ActionHandler and EditHandler on the server-side
	self:disableAll()
	
	-- save the trap data and get the players who survived to calculate earnings
	local survivedData = PlayerHandler.getPlayers()
	TrapDataHandler.saveDataAndClearAll()
	local savedData = TrapDataHandler.getSavedData()
	
	-- determine how many players survived the rounds
	-- calculate cashpool earnings and grant players their earnings
	GameEarningsHandler.calculateEarnings(survivedData, savedData)
	
	-- clear all the player entries in PlayerHandler
	PlayerHandler.clearPlayers()
	
	-- clear trap data
	TrapDataHandler.clearSavedData()
	
	-- move all the cells from RemovedCells back into Cells
	local cells = workspace.Cells
	local removedCells = ReplicatedStorage.RemovedCells
	for _, cell in removedCells:GetChildren() do
		cell.Parent = cells
	end
	
	-- clear all the traps in the workspace (Will prompt disconnections and cleanup on client)
	local traps = workspace.Traps
	for _, trap in ipairs(traps:GetChildren()) do
		-- reset the connector
		local cellID = trap.Name
		cells[cellID].Connector.IsConnected.Value = false
		trap:SetAttribute("Cleanup", true)
	end
	
	-- destroy the traps on the server afterwards, hopefully giving client's enough time to handle
	-- the cleanup on their devices beforehand
	task.delay(3, function()
		for _, trap in ipairs(traps:GetChildren()) do
			trap:Destroy()
		end
	end)
	
	workspace:SetAttribute("RoundCount", "-")
	workspace:SetAttribute("InitialPlayerCount", "-")
	workspace:SetAttribute("RemainingPlayerCount", "-")
end
	
function MainHandler:enableEdit()
	self.actionHandler:disable()
	self.editHandler:enable()
end

function MainHandler:enableAction()
	self.editHandler:disable()
	self.actionHandler:enable()
end

-- During the time of intermission/spawn selection, disable both the editHandler and actionHandler
function MainHandler:disableAll()
	self.editHandler:disable()
	self.actionHandler:disable()
end

MainHandler.setup()