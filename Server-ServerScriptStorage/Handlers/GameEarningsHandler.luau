-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")

-- Folders
local Remotes = ReplicatedStorage.Remotes
local Handlers = ServerScriptService.Handlers
local Events = ServerScriptService.Events

-- Modules
local PlayerDataHandler = require(Handlers.PlayerDataHandler)
local PlayerHandler = require(Handlers.PlayerHandler)

-- Remotes/Events
local Earn = Remotes.Earn
local RespawnBE = Events.RespawnBE
local AddRespawn = Events.AddRespawn

-- Constants
local CASHPOOL = 1000

local GameEarningsHandler = {}

-- send the player their earnings
-- if damageData and utlityData are nil, means that the earning came from a purchase, etc. 
-- (to be handled accordingly on client's end)
function GameEarningsHandler.grantEarnings(player, 
										   earnings, 	
										   damageData, 
										   utilityData)
	-- check to make sure the player is still in the game
	if player.Parent then
		for currency, value in earnings do
			if currency == "Cash" then
				PlayerDataHandler.updateCash(player, value)
			elseif currency == "Tickets" then
				PlayerDataHandler.updateTickets(player, value)
			elseif currency == "Respawns" then
				PlayerDataHandler.addRespawn(player, value)
			end
		end
		-- On the client side, Earn will also pull up a screen gui displaying the data
		-- in the event that damageData and utilityData aren't nil
		Earn:FireClient(player, earnings, damageData, utilityData)
	end
end

-- Calculate the earnings for each player based on their
-- trap data and if they survived all the rounds
function GameEarningsHandler.calculateEarnings(survivedData, saveData)
	local earnings = {}
	local random = Random.new()
	local cashEarning
	
	-- calculate cashpool earnings
	-- first, determine how the earnings should be split between players
	local split = 0
	for player, _ in survivedData do
		split += 1
	end
	
	-- check if there were any players that survived
	if split ~= 0 then
		cashEarning = math.round(CASHPOOL/split)

		for player, _ in survivedData do
			earnings[player] = {
				["Earnings"] = {["Cash"] = cashEarning},
				["DamageData"] = 0,
				["UtilityData"] = 0
			}
			PlayerDataHandler.updateWins(player)
			
			local chanceForTicket = random:NextNumber()
			if chanceForTicket < 0.2 then
				earnings[player]["Earnings"]["Tickets"] = 1
			end
			
		end
	end

	-- calculate trap data earnings
	for player, trapData in saveData do
		-- if there isn't an entry for the player yet, create one
		if earnings[player] == nil then
			earnings[player] = {
				["Earnings"] = {["Cash"] = 0},
				["DamageData"] = 0,
				["UtilityData"] = 0
			}
		end

		cashEarning = (trapData.Damage * 3) + (trapData.Utility * 2)
		
		earnings[player]["Earnings"]["Cash"] += cashEarning
		earnings[player].DamageData += trapData.Damage
		earnings[player].UtilityData += trapData.Utility
	end
	
	-- now, grant each player their respective earnings
	for player, earningsData in earnings do
		if PlayerDataHandler.hasPass(player, "2xCash") then
			earningsData.Earnings["Cash"] *= 2
		end
		GameEarningsHandler.grantEarnings(player, 
										  earningsData.Earnings, 
										  earningsData.DamageData, 
										  earningsData.UtilityData)
	end
end

-- grants the players who survived the round a bit of earnings
function GameEarningsHandler:grantRoundEarnings()
	for player, _ in PlayerHandler.getPlayers() do
		local cash = 40
		if PlayerDataHandler.hasPass(player, "2xCash") then
			cash *= 2
		end
		GameEarningsHandler.grantEarnings(player, {["Cash"] = cash})
	end
end

-- Handle product purchases from the player
-- for purchasing Wad of Cash
GameEarningsHandler[2708141046] = function(receiptInfo)
	local player = game.Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player then
		GameEarningsHandler.grantEarnings(player, {["Cash"] = 300})
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- for purchasing Bag of Cash
GameEarningsHandler[2708141367] = function(receiptInfo)
	local player = game.Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player then
		GameEarningsHandler.grantEarnings(player, {["Cash"] = 1800})
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- for purchasing Vault of Cash
GameEarningsHandler[2708141535] = function(receiptInfo)
	local player = game.Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player then
		GameEarningsHandler.grantEarnings(player, {["Cash"] = 6000})
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- for purchasing x1 Event Tickets
GameEarningsHandler[2781947113] = function(receiptInfo)
	local player = game.Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player then
		GameEarningsHandler.grantEarnings(player, {["Tickets"] = 1})
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- for purchasing x5 Event Tickets
GameEarningsHandler[2781960049] = function(receiptInfo)
	local player = game.Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player then
		GameEarningsHandler.grantEarnings(player, {["Tickets"] = 5})
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- for purchasing x20 Event Tickets
GameEarningsHandler[2781981995] = function(receiptInfo)
	local player = game.Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player then
		GameEarningsHandler.grantEarnings(player, {["Tickets"] = 20})
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

GameEarningsHandler[2838378635] = function(receiptInfo)
	local player = game.Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player then
		RespawnBE:Fire(player.UserId)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Process the receipt
local function processReceipt(receiptInfo)
	local handler = GameEarningsHandler[receiptInfo.ProductId]
	if handler then
		return handler(receiptInfo)
	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

local function onPassPromptFinished(player: Player, id, success) 
	if success and id == 1056174367 then
		PlayerDataHandler.addPass(player, "2xCash")
		GameEarningsHandler.grantEarnings(player, {["2xCash"] = true})
	end
end

MarketplaceService.ProcessReceipt = processReceipt

MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPromptFinished)

AddRespawn.Event:Connect(function(player, removeRespawn: boolean)
	-- if removeRespawn, then we are decreasing the amount of respawns the player has
	local value
	if removeRespawn then
		value = -1
	else
		value = 1
	end
	GameEarningsHandler.grantEarnings(player, {["Respawns"] = value})
end)

return GameEarningsHandler