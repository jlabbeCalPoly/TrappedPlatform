-- Handle the players that are still in the game
-- Services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Folders
local Remotes = ReplicatedStorage.Remotes
local Events = ServerScriptService.Events

-- Remotes
local Eliminate = Remotes.Eliminate
local RespawnBE = Events.RespawnBE
local AddRespawn = Events.AddRespawn

-- PlayerHandler represents all the functions, as well as the playerCount data (stores the number of remaining players in the game)
local PlayerHandler = {
	playerCount = Instance.new("IntValue")
}

-- Represents all the PLAYERS IN THE ROUND
local Players = {}
-- Represents all the eliminated players who shouldn't be considered between rounds
local EliminatePlayers = {}

-- get all the players that are still in the game
function PlayerHandler.getPlayers()
	return Players
end

-- check if the player is still in the game or not
-- if the player is in the game, this value won't be nil
function PlayerHandler.getPlayerStatus(player: Player)
	return Players[player]
end

-- update the health
function PlayerHandler.removeHealth(player: Player, healthAmount: number)
	local remainingHealth = Players[player] - healthAmount
	
	if remainingHealth <= 0 then
		remainingHealth = 0
		PlayerHandler.removePlayer(player)
	else
		Players[player] = remainingHealth
	end
	
	player:SetAttribute("Health", remainingHealth)
end

-- initalizes the health data of each player
function PlayerHandler.addPlayer(player: Player)
	Players[player] = 100
	PlayerHandler.playerCount.Value += 1
end

-- function that's ONLY used when a player is eliminated from the round
function PlayerHandler.removePlayer(player: Player)
	Players[player] = nil
	EliminatePlayers[player] = true
	
	if workspace:GetAttribute("CountdownTimer") >= 7 and workspace:GetAttribute("CountdownText") ~= "Game starting in:" then
		local respawn = Remotes.Respawn
		local osTime = Remotes.OsTime
		local promptStartTime = 0

		local osTimeConnection
		local removalTask
		local removeAllTask
		local freeRespawnConnection
		local respawnConnection
		
		-- get the initial time when the respawn prompt appeared for the client
		osTimeConnection = osTime.OnServerEvent:Connect(function(p: Player, timestamp)
			if p.UserId == player.UserId and timestamp < workspace:GetServerTimeNow() then
				osTimeConnection:Disconnect()
				promptStartTime = timestamp
			end
		end)

		-- When the remove the player from the game (disconnect all listeners for immediately respawning in the game)
		removalTask = task.delay(5.5, function()
			osTimeConnection:Disconnect()
			PlayerHandler.playerCount.Value -= 1
			workspace:SetAttribute("RemainingPlayerCount", tostring(PlayerHandler.playerCount.Value))
		end)
		
		-- When to disconnect all listening events (meaning that if the player purchases after this time, the free respawns won't be added)
		removeAllTask = task.delay(20, function()
			respawnConnection:Disconnect()
			freeRespawnConnection:Disconnect()
		end)
		
		local function validateRespawn(playerId, freeRespawn: boolean)
			local now = workspace:GetServerTimeNow()
			if playerId == player.UserId then
				-- check for the validity of the input
				if now - promptStartTime <= 4.8 then
					task.cancel(removalTask)
					respawn:FireClient(player)
					Players[player] = 100
					EliminatePlayers[player] = nil
					-- need to remove a respawn
					if freeRespawn then
						AddRespawn:Fire(player, true)
					end
				else
					-- don't fire respawn, instead add a free ticket to the player's data
					-- IF the player had just purchased a respawn
					if not freeRespawn then
						AddRespawn:Fire(player)
					end
				end
				task.cancel(removeAllTask)
				freeRespawnConnection:Disconnect()
				respawnConnection:Disconnect()
			end
		end
		
		-- listener for immediately respawning in the game
		freeRespawnConnection = respawn.OnServerEvent:Connect(function(p: Player)
			validateRespawn(p.UserId, true)
		end)

		respawnConnection = RespawnBE.Event:Connect(function(playerId)
			validateRespawn(playerId, false)
		end)
	else
		PlayerHandler.playerCount.Value -= 1
		workspace:SetAttribute("RemainingPlayerCount", tostring(PlayerHandler.playerCount.Value))
	end
	
	Eliminate:FireClient(player)
end

-- Add any players still in the lobby into the game between rounds
function PlayerHandler.addMidgame(player)
	-- Make sure the player isn't currently in the game or has already been eliminated
	if Players[player] == nil and EliminatePlayers[player] == nil then
		PlayerHandler.addPlayer(player)
	end
end

-- Clear the table of players at the end of the game
function PlayerHandler.clearPlayers()
	table.clear(Players)
	table.clear(EliminatePlayers)
	PlayerHandler.playerCount.Value = 0
end

function PlayerHandler.setEndEarlyCallback(Callback: () -> any)
	local endEarlyConnection
	-- determine if the match has no more players playing in it
	endEarlyConnection = PlayerHandler.playerCount.Changed:Connect(function(value: number)  
		if value == 0 then
			endEarlyConnection:Disconnect()
			Callback()
		end
	end)
end

return PlayerHandler