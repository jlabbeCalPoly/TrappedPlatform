-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

-- Folders
local Remotes = ReplicatedStorage.Remotes
local TrapModels = ServerStorage.TrapModels
local Handlers = script.Parent
local Traps = workspace.Traps

-- Modules
local PlayerHandler = require(Handlers.PlayerHandler)
local TrapDataHandler = require(Handlers.TrapDataHandler)
local ValidateTypes = require(script.ValidateTypes)
local ValidateArguments = require(script.ValidateArguments)
local ValidateEventDamage = require(script.ValidateEventDamage)

-- Remotes
local Trap = Remotes.Trap      -- handle damage/events dealt by traps
local Damage = Remotes.Damage  -- handle damage dealt by events (barriers, etc.)
local Teleport = Remotes.Teleport
local Action = Remotes.Action
local Immunity = Remotes.Immunity
local Eliminate = Remotes.Eliminate

local ActionHandler = {}
ActionHandler.__index = ActionHandler

function ActionHandler.new()
	
	local self = {
		enabled = false,
		connections = {}
	}
	setmetatable(self, ActionHandler)
	
	self:initialize()
	
	return self
end

function ActionHandler:validateEventDamage(player: Player,
	timestamp: number,
	damage: number)
						
	if not ValidateEventDamage(player, timestamp, damage) then
		return
	end
	-- check to make sure the player is still alive in the game
	-- (in the event they touch the insta-death part more than once)
	if PlayerHandler.getPlayerStatus(player) then
		PlayerHandler.removeHealth(player, damage)
	end
end

function ActionHandler:validateTrap(player: Player, 
									timestamp: number, 
									cellID: string,
									trapName: string,
									value: number)
	-- validate the types
	if not ValidateTypes(player, timestamp, cellID, trapName, value) then
		return
	end
	
	-- validate the data within the args
	if not ValidateArguments(player, timestamp, cellID, trapName, value) then
		return
	end
	
	local trapType = Traps[cellID]:GetAttribute("TrapType")
	
	if trapType == "Damage" then
		PlayerHandler.removeHealth(player, value)
	end
	
	TrapDataHandler.updateTrapData(cellID, value)
	
	-- if all checks pass, fire this information to all the other clients
	-- if the trap has a cooldown/animations/particles
	if Traps[cellID]:GetAttribute("Replication") then
		for _, p in Players:GetChildren() do
			if p ~= player then
				Trap:FireClient(p, cellID)
			end
		end
	end
end

-- begin the action phase
-- round level determines how many events there are
function ActionHandler:beginActionPhase(round: number)
	local players = PlayerHandler.getPlayers()
	for player, _ in players do
		-- teleport the players to the spawn on the map
		Teleport:FireClient(player, "GameSpawn")
		-- Enable action for the players
		Action:FireClient(player, true)
		-- Grant initial immunity to the player
		Immunity:FireClient(player)
	end
end

function ActionHandler:endActionPhase()
	local players = PlayerHandler.getPlayers()
	for player, _ in players do
		-- disable action for all the players
		Action:FireClient(player, false)
	end
end

function ActionHandler:onGameEnd()
	local players = PlayerHandler.getPlayers()
	for player, _ in players do
		-- teleport players back to the lobby
		Eliminate:FireClient(player)	
	end
end

function ActionHandler:initialize()
	table.insert(
		self.connections,
		Trap.OnServerEvent:Connect(function(player: Player, timestamp: number, trapID: string, trapType: string, value: number)
			if self.enabled then
				self:validateTrap(player, timestamp, trapID, trapType, value)
			end
		end)
	)
	table.insert(
		self.connections,
		Damage.OnServerEvent:Connect(function(player: Player, timestamp: number, value: number)
			if self.enabled then
				self:validateEventDamage(player, timestamp, value)
			end
		end)
	)
end

function ActionHandler:enable()
	self.enabled = true
end

function ActionHandler:disable()
	self.enabled = false
end

return ActionHandler