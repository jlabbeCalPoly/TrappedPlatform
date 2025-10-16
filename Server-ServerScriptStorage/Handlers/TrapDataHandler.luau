-- Store all the functions for trap data handling
local TrapDataHandler = {}

-- Trap data format: (Stores the trap data for each INDIVIDUAL trap on the map)
-- [CellID] =        {
--                   player,
--                   trapType: "Damage" OR "Utility",
--                   data
--                   }
local TrapData = {}

-- Stores the grand total of trap data for each player, with the following format:
-- [player] = {
--                   ["Damage"] = damageData,
--                   ["Utility"] = utilityData,
--                   }
local SaveData = {}

-- add and entry to TrapDataHandler
function TrapDataHandler.addTrapData(cellID, player, trapType)
	TrapData[cellID] = {player, trapType, 0}
end

-- update an existing entry in TrapDataHandler, only if it
-- was placed by a user
function TrapDataHandler.updateTrapData(cellID, data)
	if TrapData[cellID][1] then
		TrapData[cellID][3] += data
	end
end

-- purpose of this function is to save data from traps being destroyed from bombs.
-- the information they store in TrapDataHandler may be overridden by another trap
-- taking their cell, thus we need to save the data immediately
function TrapDataHandler.saveDataImmediate(cellID)
	local trapData = TrapData[cellID]
	TrapDataHandler.saveData(cellID, trapData)
end

-- save ALL the remaining trap data in TrapDataHandler
-- only to be done at the very end of the game
function TrapDataHandler.saveDataAndClearAll()
	for cellID, trapData in TrapData do
		TrapDataHandler.saveData(cellID, trapData)
	end 
end

function TrapDataHandler.saveData(cellID, trapData)
	local player = trapData[1]        -- Player who placed the trap
	local trapType = trapData[2]      -- The type of the trap (Damage/Utility)
	local data = trapData[3]          -- The data stored for the trap
	
	-- don't save the data if the trap was auto-placed by the game (player will be nil)
	if player then
		-- check if the player doesn't have any trap data saved yet
		if SaveData[player] == nil then
			SaveData[player] = {
				["Damage"] = 0,
				["Utility"] = 0,
			}
		end

		-- Now we know for sure that the player has trap data entered in TrapData,
		-- therefore add to the appropriate key
		SaveData[player][trapType] += data
	end
	
	-- Finally, set the entry in TrapDataHandler to nil to clear the data
	TrapData[cellID] = nil
end

-- retrieve all the saved data
function TrapDataHandler.getSavedData()
	return SaveData
end

-- after saved data is retrieved, clear all the saved data before the next game
function TrapDataHandler.clearSavedData()
	table.clear(SaveData)
end

return TrapDataHandler