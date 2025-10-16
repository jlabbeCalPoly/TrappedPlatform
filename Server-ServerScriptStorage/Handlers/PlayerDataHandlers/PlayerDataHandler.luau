-- Services
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Folders
local Handlers = ServerScriptService.Handlers
local Remotes = ReplicatedStorage.Remotes
local Events = ServerScriptService.Events

-- Modules
local PlayerHandler = require(Handlers.PlayerHandler)
local TrapData = require(ReplicatedStorage.SharedUtility.TrapData)
local ValidateShopTypes = require(script.ValidateShopTypes)
local ValidateTrapDeckTypes = require(script.ValidateTrapDeckTypes)

-- DataStore
local playerData = DataStoreService:GetDataStore("playerData")

-- HitboxModel
local HitboxModel = ServerStorage.HitboxModel.Hitbox

-- Remotes
local GetData = Remotes.GetData -- (fired from client when they need their initial shop info to get updated)
local Shop = Remotes.Shop
local TrapDeck = Remotes.TrapDeck
local ConcurrentPlayer = Remotes.ConcurrentPlayer

-- Contains all the functions of PlayerDataHandler
local PlayerDataHandler = {}

-- PlayerSessionData serves as the session data, storing the current game data of all the players 
-- until they leave the game, then saving that data in our playerData data store
local PlayerSessionData = {}

-- Saves the number of players that have completely loaded into the game and are ready to play
local ConcurrentPlayers = {}

function PlayerDataHandler.getPlayerTrapDeck(player: Player)
	return PlayerSessionData[player.UserId].TrapDeck
end

function PlayerDataHandler.getPlayerTrapLevel(player: Player, trapID: string)
	return PlayerSessionData[player.UserId].TrapsUnlocked[trapID]
end

function PlayerDataHandler.onPlayerAdded(player: Player)
	local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
	while humanoidRootPart == nil do
		task.wait(0.1)
		humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
	end
		
	local hitbox = HitboxModel:Clone()
	local weld = Instance.new("WeldConstraint")
	hitbox.Name = tostring(player.UserId)
	hitbox.CFrame = humanoidRootPart.CFrame
	hitbox.Parent = workspace
	weld.Part0 = humanoidRootPart
	weld.Part1 = hitbox
	weld.Parent = hitbox
	
	hitbox:SetNetworkOwner(player)
	
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = 0
	wins.Parent = leaderstats
	
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 0
	cash.Parent = leaderstats

	local success = nil
	local data = nil
	local attempt = 1

	repeat
		success, data = pcall(function()
			return playerData:GetAsync(player.UserId)
		end)
		attempt += 1
		if not success then
			warn(data)
			task.wait(3)
		end
	until success or attempt == 5

	if success then
		if not data then
			data = {
				["Wins"] = 0,
				["Cash"] = 0,
				["EventTickets"] = 0,
				["TrapsUnlocked"] = {
					["Spikes"] = 1, 
					["Bouncer"] = 1, 
					["Roaster"] = 1
				},
				["TrapDeck"] = {"Spikes", "Bouncer", "Roaster"},
				["Cosmetics"] = {},
				
				-- Also have an additional "EventCurrency" for if you ever want to do a
				-- special event where players can get exclusive items
				["EventCurrency"] = {
					["Name"] = "",
					["Value"] = 0
				},
			}
		end
		if data["EventTickets"] == nil then
			data["EventTickets"] = 0
		end
		
		PlayerSessionData[player.UserId] = data
	else
		warn("Unable to get data for "..player.UserId)
		player:Kick("Unable to load your data, try again later")
	end
	
	local winChangeConnection
	local cashChangeConnection
	
	-- set up basic data updates for wins and parts. Data structures like tables
	-- need to be updated manually into PlayerDataHandler
	wins.Value = data.Wins
	winChangeConnection = wins.Changed:Connect(function()
		PlayerSessionData[player.UserId].Wins = wins.Value
	end)
	
	cash.Value = data.Cash
	cashChangeConnection = cash.Changed:Connect(function()
		PlayerSessionData[player.UserId].Cash = cash.Value
	end)
	
	local playerDestroyingConnection
	playerDestroyingConnection = player.Destroying:Connect(function()
		playerDestroyingConnection:Disconnect()
		winChangeConnection:Disconnect()
		cashChangeConnection:Disconnect()
	end)
end

function PlayerDataHandler.updateWins(player)
	player.leaderstats.Wins.Value += 1
end

function PlayerDataHandler.updateCash(player, amount)
	player.leaderstats.Cash.Value += amount
end

function PlayerDataHandler.updateTickets(player, amount)
	PlayerSessionData[player.UserId]["EventTickets"] += amount
end

function PlayerDataHandler.addRespawn(player, value)
	local playerData = PlayerSessionData[player.UserId]
	if playerData then
		if playerData["Respawns"] then
			playerData["Respawns"] += value
		else
			playerData["Respawns"] = 1
		end
	end
end

function PlayerDataHandler.addPass(player, pass)
	local playerData = PlayerSessionData[player.UserId]
	if playerData then
		playerData[pass] = true
		PlayerSessionData[player.UserId] = playerData
	end
end

function PlayerDataHandler.hasPass(player, pass)
	local hasPass = nil
	local playerData = PlayerSessionData[player.UserId]
	if playerData then
		hasPass = playerData[pass]
	end
	
	return hasPass
end

function PlayerDataHandler.onPlayerRemoving(player: Player)	
	-- First, check if the player was in an ongoing game
	if PlayerHandler.getPlayerStatus(player) then
		PlayerHandler.removePlayer(player)
	end
	if ConcurrentPlayers[player] then
		ConcurrentPlayers[player] = nil
	end
	
	if PlayerSessionData[player.UserId] then
		PlayerSessionData[player.UserId]["LastJoin"] = os.date("!*t")
--		PlayerSessionData[player.UserId]["LastJoin"] = nil
		local success = nil
		local error_message = nil
		local attempt = 1
		
		repeat success, error_message = pcall(function()
--				playerData:RemoveAsync(player.UserId)
				playerData:SetAsync(player.UserId, PlayerSessionData[player.UserId])
			end)
			attempt += 1
			if not success then
				warn(error_message)
				task.wait(3)
			end
		until success or attempt == 5
		
		PlayerSessionData[player.UserId] = nil
	end
	
	player:Destroy()
end

function PlayerDataHandler.getConcurrentPlayers()
	return ConcurrentPlayers
end

function PlayerDataHandler.setCollisionGroup(model)
	-- Apply collision group to all existing parts in the model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = "Player"
		end
	end
end

TrapDeck.OnServerEvent:Connect(function(player: Player, trapType: string, slot: number)
	if not ValidateTrapDeckTypes(player, trapType, slot) then
		return
	end
	
	-- check and make sure the player doesn't already have the
	-- trap in their trapdeck
	local trapDeck = PlayerSessionData[player.UserId].TrapDeck
	for _, trap in trapDeck do
		if trapType == trap then
			return
		end
	end

	trapDeck[slot] = trapType
	PlayerSessionData[player.UserId].TrapDeck = trapDeck
end)

-- Can either be a call from client to get their data or a purchase request
Shop.OnServerEvent:Connect(function(player: Player, currencyType: string, trapType: string, levelUpgradeTo: number)
	local success = false
	local value = nil
	if ValidateShopTypes(player, currencyType, trapType, levelUpgradeTo) then
		local playerData = PlayerSessionData[player.UserId]
		if playerData then
			if currencyType == "Cash" then
				value = playerData.Cash
				local cost = tonumber(TrapData.retrieveTrapInformation(trapType, levelUpgradeTo - 1)[1])
				if value - cost >= 0 then
					value -= cost
					PlayerDataHandler.updateCash(player, -cost)
					PlayerSessionData[player.UserId]["TrapsUnlocked"][trapType] = levelUpgradeTo
					success = true
				end
			else
				value = playerData.EventTickets
				if value - 1 >= 0 then
					value -= 1
					PlayerDataHandler.updateTickets(player, -1)
					success = true
					local currentTickets = workspace:GetAttribute("EventTickets")
					workspace:SetAttribute("EventTickets", currentTickets + 1)					
				end
			end
		end
	end

	Shop:FireClient(player, success, currencyType, value)
end)

GetData.OnServerInvoke = function(player: Player)
	local playerData = PlayerSessionData[player.UserId]
	
	if playerData then
		return playerData
		-- if no session data, send nil info back to client so client can try again
	else
		return nil
	end
end

ConcurrentPlayer.OnServerEvent:Connect(function(player: Player)
	if typeof(player) ~= "Instance" then
		return
	end

	if not player:IsA("Player") then
		return
	end
	
	if ConcurrentPlayers[player] then
		return
	end
	
	ConcurrentPlayers[player] = true
end)

Players.PlayerAdded:Connect(function(player: Player)
	local initialConnection
	
	initialConnection = player.CharacterAdded:Connect(function(character: Model)
		initialConnection:Disconnect()
		PlayerDataHandler.onPlayerAdded(player)
		PlayerDataHandler.setCollisionGroup(character)
	end)
end)

Players.PlayerRemoving:Connect(PlayerDataHandler.onPlayerRemoving)

return PlayerDataHandler