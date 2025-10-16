local InventoryController = {}
InventoryController.__index = InventoryController

function InventoryController.new()
	
	local self = {
		enabled = false,
		inventory = {},
		indexSelection = 0, -- the slot that is currently selected, initially 0 since no selected value
	}
	setmetatable(self, InventoryController)
	
	return self
end

-- fills the given index of the inventory with the trap
function InventoryController:addToInventory(index: number, trapID: string, level: number)
	self.inventory[index] = {trapID, tostring(level)}
end

-- return the index of the current selection
function InventoryController:getIndexSelection()
	return self.indexSelection
end

-- checks if the slot trying to be selected is valid
function InventoryController:checkSelect(index: number)
	-- check to see if the provided slot is not nil and that the user isn't trying to select the same trap twice
	-- otherwise, we know that there isn't a trap in that slot OR that the player is actually trying to deselect the trap
	if self.inventory[index] and index ~= self.indexSelection then
		return true
	else
		self.indexSelection = 0
		return false
	end
end

function InventoryController:getInventoryEntry(index: number)
	return self.inventory[index]
end

-- if checks are successful, select the trap and return the info
function InventoryController:select(index: number)
	self.indexSelection = index
	return self.inventory[index]
end

-- if the trap is placed, remove the trap from the inventory
-- since we are no longer holding onto a trap, reset the indexSelection to 0
function InventoryController:place()
	self.inventory[self.indexSelection] = nil
	self.indexSelection = 0
end

-- enable the InventoryController
function InventoryController:enable()
	if self.enabled then
		return
	end
	self.enabled = true
	
end

-- disable the InventoryController, wiping its previous selection data
function InventoryController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false
	
	-- clear the previous inventory and sets the current selection back to 0
	table.clear(self.inventory)
	self.indexSelection = 0
end

return InventoryController