-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Folders
local SharedUtility = ReplicatedStorage.SharedUtility

-- Module
local DisconnectAndDestroy = require(SharedUtility.DisconnectAndDestroy)
local InputCategorizer = require(SharedUtility.InputCategorizer)

-- GuiTemplates
local NonTouchTemplate = script.NonTouchGui
local TouchTemplate = script.TouchGui

local InputUIController = {}
InputUIController.__index = InputUIController

function InputUIController.new(player: Player)
	local touchGui = TouchTemplate:Clone()
	touchGui.Parent = player.PlayerGui
	
	local nonTouchGui = NonTouchTemplate:Clone()
	nonTouchGui.Parent = player.PlayerGui

	local self = {
		enabled = false,
		touchGui = touchGui,
		nonTouchGui = nonTouchGui,
		connections = {},
	}
	setmetatable(self, InputUIController)
	
	InputCategorizer.initialize()

	return self
end

function InputUIController:updateScale(scale: number)
	self.touchGui.UIScale.Scale = scale
	self.nonTouchGui.UIScale.Scale = scale
end

function InputUIController:enableTouch()
	self.nonTouchGui.Enabled = false
	self.touchGui.Enabled = true
end

function InputUIController:enableNonTouch()
	self.touchGui.Enabled = false
	self.nonTouchGui.Enabled = true
end

function InputUIController:lastInputCategoryChanged(inputCategory: string)
	if inputCategory == InputCategorizer.inputCategory.Touch then
		self:enableTouch()
		
		if self.updateMobileAlignment then
			self.updateMobileAlignment()
		end
	else
		self:enableNonTouch()
		
		if self.updateOtherAlignment then
			self.updateOtherAlignment()
		end
	end
end

function InputUIController:enable()
	if self.enabled then
		return
	end
	self.enabled = true
	
	table.insert(
		self.connections,
		InputCategorizer.lastInputCategory.Changed:Connect(function()
			self:lastInputCategoryChanged(InputCategorizer.lastInputCategory.Value)
		end)
	)
	-- Selection callbacks
	table.insert(
		self.connections,
		self.touchGui.InventoryFrame.Slot_1.InputBegan:Connect(function(inputObject: InputObject)
			if inputObject.UserInputState == Enum.UserInputState.Change then
				return
			end

			if self.selectCallback and self.enabled then
				self.selectCallback(1)
			end
		end)
	)
	table.insert(
		self.connections,
		self.touchGui.InventoryFrame.Slot_2.InputBegan:Connect(function(inputObject: InputObject)
			if inputObject.UserInputState == Enum.UserInputState.Change then
				return
			end

			if self.selectCallback and self.enabled then
				self.selectCallback(2)
			end
		end)
	)
	table.insert(
		self.connections,
		self.touchGui.InventoryFrame.Slot_3.InputBegan:Connect(function(inputObject: InputObject)
			if inputObject.UserInputState == Enum.UserInputState.Change then
				return
			end

			if self.selectCallback and self.enabled then
				self.selectCallback(3)
			end
		end)
	)
	-- Teleport callbacks
	table.insert(
		self.connections,
		self.touchGui.MapNavigationFrame.Teleport_1.InputBegan:Connect(function(inputObject: InputObject)
			if inputObject.UserInputState == Enum.UserInputState.Change then
				return
			end

			if self.teleportCallback and self.enabled then
				self.teleportCallback(1)
			end
		end)
	)
	table.insert(
		self.connections,
		self.touchGui.MapNavigationFrame.Teleport_2.InputBegan:Connect(function(inputObject: InputObject)
			if inputObject.UserInputState == Enum.UserInputState.Change then
				return
			end

			if self.teleportCallback and self.enabled then
				self.teleportCallback(2)
			end
		end)
	)
	table.insert(
		self.connections,
		self.touchGui.MapNavigationFrame.Teleport_3.InputBegan:Connect(function(inputObject: InputObject)
			if inputObject.UserInputState == Enum.UserInputState.Change then
				return
			end

			if self.teleportCallback and self.enabled then
				self.teleportCallback(3)
			end
		end)
	)
	-- Rotate callback
	table.insert(
		self.connections,
		self.touchGui.ButtonFrame.Rotate.InputBegan:Connect(function(inputObject: InputObject)
			if inputObject.UserInputState == Enum.UserInputState.Change then
				return
			end

			if self.rotateCallback and self.enabled then
				self.rotateCallback()
			end
		end)
	)
	-- Place callback
	table.insert(
		self.connections,
		self.touchGui.ButtonFrame.Place.InputBegan:Connect(function(inputObject: InputObject)
			if inputObject.UserInputState == Enum.UserInputState.Change then
				return
			end

			if self.placeCallback and self.enabled then
				self.placeCallback()
			end
		end)
	)
	
	self:lastInputCategoryChanged(InputCategorizer.lastInputCategory.Value)
end

function InputUIController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false
	
	self.touchGui.Enabled = false
	self.nonTouchGui.Enabled = false
	
	DisconnectAndDestroy(self.connections)
end

function InputUIController:destroy()
	self.nonTouchGui.Destroy()
	self.touchGui.Destroy()
end

-- set up callbacks
function InputUIController:setSelectCallback(Callback: () -> any)
	self.selectCallback = Callback
end
function InputUIController:setTeleportCallback(Callback: () -> any)
	self.teleportCallback = Callback
end
function InputUIController:setRotateCallback(Callback: () -> any)
	self.rotateCallback = Callback
end
function InputUIController:setPlaceCallback(Callback: () -> any)
	self.placeCallback = Callback
end
function InputUIController:setUpdateMobileAlignment(Callback: () -> any)
	self.updateMobileAlignment = Callback
end
function InputUIController:setUpdateOtherAlignment(Callback: () -> any)
	self.updateOtherAlignment = Callback
end

return InputUIController