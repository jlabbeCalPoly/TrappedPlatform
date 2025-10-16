-- Controller for handling placing traps, along with functionality (rotating, opening up trap
-- hotbar, etc.)
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Folders
local EditControllers = ReplicatedStorage.EditControllers
local SharedUtility = ReplicatedStorage.SharedUtility
local TrapHolograms = ReplicatedStorage.TrapHolograms
local Remotes = ReplicatedStorage.Remotes

-- Modules
local TeleportController = require(script.TeleportController)
local EditModelController = require(EditControllers.EditModelController)
local InventoryController = require(EditControllers.InventoryController)
local GuiController = require(EditControllers.GuiController)
local DisconnectAndDestroy = require(SharedUtility.DisconnectAndDestroy)
local Constants = require(SharedUtility.Constants)

-- Remotes
local Place = Remotes.Place -- Fired by Server/Client
local Inventory = Remotes.Inventory -- Fired by Server, adds traps to the player's inventory
local Edit = Remotes.Edit -- Enable/Disable editController

-- Player Specific
local Camera : Camera = game.Workspace.CurrentCamera

local EditController = {}
EditController.__index = EditController

function EditController.new(localPlayer: Player)
	local teleportController = TeleportController.new(localPlayer)
	local editModelController = EditModelController.new(localPlayer)
	local inventoryController = InventoryController.new()
	local guiController = GuiController.new(localPlayer)
	
	local self = {
		enabled = false,
		teleportController = teleportController,
		editModelController = editModelController,
		inventoryController = inventoryController,
		guiController = guiController,
		
		processingRequest = false, -- make sure the server receieved/sends back info to player (for placing)
		                           -- before moving on

		spot = nil, -- the spot being hovered over by the player
		trap = nil, -- the selected trap that the player is trying to place
		rotation = 0,  -- save the rotation data if the player decides to rotate the model
		rotationCFrame = CFrame.fromEulerAngles(0,0,0), -- the rotation to be applied to the model
		
		currentLevel = 1, -- Save the current level the player is on
		
		connections = {},
	}
	
	setmetatable(self, EditController)
	self:initialize()

	return self
end

-- check the validity of the request (processingRequest -> are we waiting for a response from the server?)
function EditController:checkValidity()
	return (self.enabled and not self.processingRequest)
end

function EditController:checkSelect(index: number)
	if self:checkValidity() then
		-- only run deselect() if there actually is a selection to be deselected
		if self.inventoryController:getIndexSelection() ~= 0 then
			self:deselect()
		end

		-- do checks to see if 1) there is a selectable trap in the specified slot and 2) if the
		-- player currently has a trap selected
		if self.inventoryController:checkSelect(index) then
			self.guiController:tweenSlot(index)
			self:select(index)
		end
	end
end

function EditController:select(index: number)
	local trapInfo = self.inventoryController:select(index)
	local trapID = trapInfo[1]
--	local level = trapInfo[2]

--	local trap = TrapHolograms[trapID][level]:Clone()
	local trap = TrapHolograms[trapID]:Clone()
	self.trap = trap
	trap.Parent =workspace

	local raycastParams = RaycastParams.new()
	raycastParams.CollisionGroup = "Cells"
	
	self.editModelController:playSelectAnimation(0.1, trapID)

	-- determine if the selection is the bomb (has different logic than other traps)
	if trapID == "Bomb" then
		RunService:BindToRenderStep(
			"select",
			Enum.RenderPriority.Camera.Value + 1,
			function(deltaTime)
				self:updateBombModel(deltaTime, raycastParams)
			end
		)
	else
		RunService:BindToRenderStep(
			"select",
			Enum.RenderPriority.Camera.Value + 1,
			function(deltaTime)
				self:updateTrapModel(deltaTime, raycastParams)
			end
		)
	end
	
	local audio = ReplicatedStorage.SFX.SelectSFX
	audio:Play()
end

function EditController:deselect()
	RunService:UnbindFromRenderStep(
		"select"
	)
	self.trap:Destroy()
	
	self.editModelController:stopSelectAnimation()
	
	self.spot = nil
	self.trap = nil
end

-- For all traps other than bombs
function EditController:updateTrapModel(deltaTime: number, raycastParams)
	local rayOrigin = Camera.CFrame.Position
	local rayDirection = Camera.CFrame.LookVector * 30 -- create a raycast with a length of 30 studs
	
	local pivot
	local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	
	if rayResult then
		local cell = rayResult.Instance
		local connector = cell.Parent.Connector
		
		-- determine if the cell already has a trap connected to it
		if not connector.IsConnected.Value then
			self.spot = cell
			self.trap.Trap.Color = Constants.HOLOGRAM_BLUE_COLOR
		else
			self.spot = nil
			self.trap.Trap.Color = Constants.HOLOGRAM_RED_COLOR
		end
		
		pivot = connector.CFrame * self.rotationCFrame
	else
		self.spot = nil
		pivot = Constants.HOLOGRAM_NIL_PIVOT
	end

	self.trap:PivotTo(pivot)
end

-- Specific update function for bombs since they work differently that other traps
function EditController:updateBombModel(deltaTime:number, raycastParams)
	local rayOrigin = Camera.CFrame.Position
	local rayDirection = Camera.CFrame.LookVector * 30 -- create a raycast with a length of 30 studs

	local pivot
	local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if rayResult then
		local cell = rayResult.Instance
		local connector = cell.Parent.Connector

		-- determine if the cell already has a trap connected to it
		-- if so, mark the spot as placeable since we're holding onto a bomb
		if connector.IsConnected.Value then
			self.spot = cell
			self.trap.Trap.Color = Constants.HOLOGRAM_BLUE_COLOR
		else
			self.spot = nil
			self.trap.Trap.Color = Constants.HOLOGRAM_RED_COLOR
		end

		pivot = connector.CFrame * self.rotationCFrame
	else
		self.spot = nil
		pivot = Constants.HOLOGRAM_NIL_PIVOT
	end

	self.trap:PivotTo(pivot)
end

-- update the rotation of the trap
function EditController:rotate()
	self.rotation = (self.rotation + math.rad(60)) % math.rad(360)
	self.rotationCFrame = CFrame.fromEulerAngles(0, self.rotation, 0)
end

-- Check the valididty of the arguments that could be passed into the place function
function EditController:checkPlace(currentSpot, currentTrap)
	if self:checkValidity() then
		if currentSpot and currentTrap then
			self.processingRequest = true
			self:place(currentSpot)
		end
	end
end

function EditController:place(currentSpot)
	local serverResponseConnection
	local index = self.inventoryController:getIndexSelection()
	local trapInfo = self.inventoryController:getInventoryEntry(index)
	
	self:deselect()
	self.editModelController:playPlaceAnimation(0.7, currentSpot.Parent.Connector)
	self.guiController:emptySlot(index)
	self.inventoryController:place()

	serverResponseConnection = Place.OnClientEvent:Connect(function(success: boolean)
		self.connections[serverResponseConnection] = nil
		serverResponseConnection:Disconnect()
		
		-- determine if the trap was successfully placed or not
		-- if not successful, readd the trap back into the players inventory
		if not success then
			self.inventoryController:addToInventory(index, trapInfo[1], trapInfo[2])
		end

		self.processingRequest = false
	end)
	
	table.insert(
		self.connections,
		serverResponseConnection
	)
	
	Place:FireServer(currentSpot.Name, trapInfo[1], self.rotation)
end

function EditController:checkUpTeleport()
	if self.enabled then
		local teleportTo = self.currentLevel + 1
		if teleportTo <= 3 then
			self.currentLevel = teleportTo
			self:teleport(""..self.currentLevel)
		end
	end
end

function EditController:checkDownTeleport()
	if self.enabled then
		local teleportTo = self.currentLevel - 1
		if teleportTo >= 1 then
			self.currentLevel = teleportTo
			self:teleport(""..self.currentLevel)
		end
	end
end

function EditController:teleport(teleportID: string)
	self.teleportController:teleport(teleportID)
	self.guiController:updateMapPlayerIcon(teleportID)
end

-- Enable the EditController functionality (edit-based part of game)
function EditController:enable()
	if self.enabled then
		return
	end
	self.enabled = true
	
	self.teleportController:enable()
	self.editModelController:enable()
	self.inventoryController:enable()
	self.guiController:enable()
end

-- Disable the EditController functionality (round-based part of game)
function EditController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false
	
	-- check to see if the player had a trap currently selected 
	if self.inventoryController:getIndexSelection() ~= 0 then
		self:deselect()
	end
	
	self.teleportController:disable()
	self.editModelController:disable()
	self.inventoryController:disable()
	self.guiController:disable()
	
	-- reset constants for the next time editController is enabled
	self.processingRequest = false
	self.currentLevel = 1
end

-- Set up all events and callbacks (in the event the player is using a touchscreen)
function EditController:initialize()
	table.insert(
		self.connections,
		Inventory.OnClientEvent:Connect(function(traps)
			-- trapInfo format: (trapID, level)
			for index, trapInfo in traps do
				self.inventoryController:addToInventory(index, trapInfo[1], trapInfo[2])
				self.guiController:fillSlot(index, trapInfo[1])
			end
		end)
	)
	table.insert(
		self.connections,
		Edit.OnClientEvent:Connect(function(enable: boolean)
			if enable then
				self:enable()
				self.teleportController:teleport("GameSpawn")
			else
				self:disable()
			end
		end)
	)
	table.insert( -- "Select" user input
		self.connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed then
				return
			end
			
			if input.KeyCode == Constants.SELECT_KEYCODE_1 then
				self:checkSelect(1)
			elseif input.KeyCode == Constants.SELECT_KEYCODE_2 then
				self:checkSelect(2)
			elseif input.KeyCode == Constants.SELECT_KEYCODE_3 then
				self:checkSelect(3)
			end			
		end)
	)
	table.insert( -- "Place" user input
		self.connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed then
				return
			end
			
			if input.KeyCode == Constants.PLACE_KEYCODE then
				-- since self.spot and self.trap could potentially change
				-- create variables to save the information for the spot
				local currentSpot = self.spot
				local currentTrap = self.trap
				self:checkPlace(currentSpot, currentTrap)
			end
		end)
	)
	table.insert( -- "Rotate" user input
		self.connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed then
				return
			end
			
			if input.KeyCode == Constants.ROTATE_KEYCODE then
				self:rotate()
			end
		end)
	)
	table.insert( -- "Teleport up" user input
		self.connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed then
				return
			end

			if input.KeyCode == Constants.TELEPORT_UP_KEYCODE then
				self:checkUpTeleport()
			end
		end)
	)
	table.insert( -- "Teleport down" user input
		self.connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed then
				return
			end

			if input.KeyCode == Constants.TELEPORT_DOWN_KEYCODE then
				self:checkDownTeleport()
			end
		end)
	)
	
	-- set up callbacks
	self.guiController:setSelectCallback(function(slot: number)
		self:checkSelect(slot)
	end)
	self.guiController:setTeleportCallback(function(teleportTo: number)
		if self.enabled then
			self.currentLevel = teleportTo
			self:teleport(""..self.currentLevel)
		end
	end)
	self.guiController:setRotateCallback(function()
		self:rotate()
	end)
	self.guiController:setPlaceCallback(function()
		local currentSpot = self.spot
		local currentTrap = self.trap
		self:checkPlace(currentSpot, currentTrap)
	end)
end

-- Only to be called when the player is leaving the game
function EditController:destroy()
	self:disable()
	DisconnectAndDestroy(self.connections)
	
	self.teleportController:destroy()
	self.editModelController:destroy()
	self.guiController:destroy()
end

return EditController