-- Folders
local Handlers = script.Parent

-- Modules
local PlayerDataHandler = require(Handlers.PlayerDataHandler)

local InventoryHandler = {}

-- Store the inventory data for the players
local Inventories = {}

-- fills the InventoryHandler table from a list of players
-- trapCount determines the amount of traps selected for each player
function InventoryHandler.fillInventories(players, trapCount)
	for player, _ in players do
		-- get the player's "trapDeck", or 3 possible traps the player has selected to bring into the round
		local trapDeck = PlayerDataHandler.getPlayerTrapDeck(player)
		local traps = {}
		
		-- give "trapCount" number of traps to the players inventory
		for index = 1, trapCount, 1 do
			local randomIndex = math.random(1,3)
			local trapID = trapDeck[randomIndex]
			local trapLevel = PlayerDataHandler.getPlayerTrapLevel(player, trapID)
			table.insert(traps, {trapID, trapLevel})
		end
		
		Inventories[player.UserId] = traps
	end
end

-- returns a list representing the traps in the player's inventory (strings) and their levels
function InventoryHandler.getInventory(player: Player)
	return Inventories[player.UserId]
end

-- removes the first occurence of the specified trap from the player's inventory
function InventoryHandler.removeFromInventory(player: Player, trapID)
	local inventory = InventoryHandler.getInventory(player)
	
	for index, trapInfo in inventory do
		if trapInfo[1] == trapID then
			table.remove(Inventories[player.UserId], index)
			return
		end
	end
end

-- sets all the keys in InventoryHandler to nil, wiping all the previous data
function InventoryHandler.resetInventories()
	table.clear(Inventories)
end

return InventoryHandler