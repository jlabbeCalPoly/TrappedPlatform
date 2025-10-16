-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Folders
local Cells = workspace.Cells
local Traps = workspace.Traps
local FloorDividers = workspace.FloorDividers
local TrapModels = ServerStorage.TrapModels
local Remotes = ReplicatedStorage.Remotes
local Handlers = script.Parent

-- Modules
local ValidateTypes = require(script.ValidateTypes)
local ValidateArguments = require(script.ValidateArguments)
local TrapDataHandler = require(Handlers.TrapDataHandler)
local InventoryHandler = require(Handlers.InventoryHandler)
local PlayerHandler = require(Handlers.PlayerHandler)
local PlayerDataHandler = require(Handlers.PlayerDataHandler)

-- Remotes
local Place = Remotes.Place
local Inventory = Remotes.Inventory
local Teleport = Remotes.Teleport
local Edit = Remotes.Edit

local EditHandler = {}
EditHandler.__index = EditHandler

function EditHandler.new()
	
	local self = {
		enabled = false, -- determines whether or not EditHandler should consider client events, protection against exploiters
		connections = {}
	}
	setmetatable(self, EditHandler)
	self:initialize()
	
	return self
end

function EditHandler:updateFloorDividers(enable: boolean)
	for _, divider : Part in FloorDividers:GetChildren() do
		if not enable and divider.Name == "FloorLow" then
			task.delay(5, function()
				divider.CanCollide = enable
			end)
		else
			divider.CanCollide = enable
		end
	end
end

function EditHandler:validatePlace(player, spotRequested, trapID, rotation)
	-- check to make sure the types of the received information are valid
	if not ValidateTypes(spotRequested, trapID, rotation) then
		return
	end
	
	-- check to make sure that the data within the arguments is valid
	-- this ONLY checks if the data is potentially valid, NOT if the trap can actually be placed there
	if not ValidateArguments(player, spotRequested, trapID) then
		return
	end
	
	-- If validation checks pass, check to see if the spot has already been taken yet
	-- if not, create a trap and parent it to the folder "Traps" in workspace
	local spotTaken = Traps:FindFirstChild(spotRequested)
	local result
	
	if trapID == "Bomb" then
		result = self:placeBombLogic(player, spotTaken, spotRequested, trapID, rotation)
	else
		result = self:placeTrapLogic(player, spotTaken, spotRequested, trapID, rotation)
	end
	
	Place:FireClient(player, result)
end

-- Logic for validating trap placement
function EditHandler:placeTrapLogic(player, spotTaken, spotRequested, trapID, rotation)
	local result 
	
	if spotTaken then
		result = false
	else
		local trapLevel = PlayerDataHandler.getPlayerTrapLevel(player, trapID)
		local trap : Model = TrapModels[trapID][""..trapLevel]:Clone()
		-- roaster needs a random offset attribute
		if trapID == "Roaster" then
			trap:SetAttribute("offset", Random.new():NextInteger(7,14))
		end
		trap.Name = spotRequested
		trap.Parent = Traps

		local cell : Model = Cells[spotRequested]
		cell.Connector.IsConnected.Value = true

		local pivot = cell.Connector.CFrame * CFrame.fromEulerAngles(0, rotation, 0)
		trap:PivotTo(pivot)
		
		-- add a new entry for our trap into TrapDataHandler
		TrapDataHandler.addTrapData(spotRequested, player, trap:GetAttribute("TrapType"))

		-- remove the trap from the players inventory
		InventoryHandler.removeFromInventory(player, trapID)
		
		result = true
	end
	
	return result
end

-- logic for validating bomb placement
function EditHandler:placeBombLogic(player, spotTaken, spotRequested, trapID, rotation)
	local result 

	if spotTaken then
		-- spotTaken represents the trap at that location, spotRequested is the cellID
		-- save the data from the trap, then destroy it
		TrapDataHandler.saveDataImmediate(spotRequested)
		spotTaken:Destroy()

		-- remove the bomb from the players inventory 
		InventoryHandler.removeFromInventory(player, trapID)
		
		result = true
	else
		result = false
	end
	
	return result
end

-- Main function call that handles the chronological sequence
-- of the edit phase
function EditHandler:beginEditPhase(trapCount: number)
	self:updateFloorDividers(true)
	
	local players = PlayerHandler.getPlayers()
	for player, _ in players do
		-- Enable edit for the players
		Edit:FireClient(player, true)
	end
	
	self:fillInventories(players, trapCount)
end

-- for all the players still in the game, fill their inventories
-- then, send the players their inventory information
function EditHandler:fillInventories(players, trapCount: number)
	InventoryHandler.fillInventories(players, trapCount)
	
	for player, _ in players do
		local inventory = InventoryHandler.getInventory(player)
		Inventory:FireClient(player, inventory)
	end
end

function EditHandler:endEditPhase()
	for player, _ in PlayerHandler.getPlayers() do
		-- Disable edit for the players
		Edit:FireClient(player, false)
	end
end

-- At the end of each edit phase, checks if there are
-- not enough traps on the map. If so, adds some
function EditHandler:placeAdditionalTraps(round: number)
	local trapsNeeded = 0
	local needsExtraTraps = false
	if round == 1 then
		trapsNeeded = (10 - #Traps:GetChildren()) 
	elseif round == 2 then
		trapsNeeded = (30 - #Traps:GetChildren()) 
	end
	
	if trapsNeeded > 0 then
		needsExtraTraps = true
	end
	
	local cells = Cells:GetChildren() 
	local random = Random.new()
	while trapsNeeded > 0 do
		local attempts = 10
		local spot = nil
		while attempts > 0 do
			local spotRequested = cells[random:NextInteger(1, #cells)].Name
			-- if there is already a trap there, simply continue onto the next iteration
			if Traps:FindFirstChild(spotRequested) then
				attempts -= 1
			else
				spot = spotRequested
				attempts = 0
			end
		end
		
		if spot then
			local trap : Model = TrapModels["Spikes"]["1"]:Clone()

			trap.Name = spot
			trap.Parent = Traps

			local cell : Model = Cells[spot]
			cell.Connector.IsConnected.Value = true

			local pivot = cell.Connector.CFrame
			trap:PivotTo(pivot)

			-- add a new entry for our trap into TrapDataHandler
			TrapDataHandler.addTrapData(spot, nil, trap:GetAttribute("TrapType"))

		end
		trapsNeeded -= 1
	end
	
	return needsExtraTraps
end

function EditHandler:enable()
	self.enabled = true
end

function EditHandler:disable()
	self.enabled = false
end

function EditHandler:initialize()
	table.insert(
		self.connections,
		Place.OnServerEvent:Connect(function(player, spotRequested, trapID, rotation)
			if self.enabled then
				self:validatePlace(player, spotRequested, trapID, rotation)
			end
		end)
	)
end

return EditHandler