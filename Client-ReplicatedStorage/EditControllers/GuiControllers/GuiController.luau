-- TouchController is specifically to handle touchscreen inputs
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

-- Folders
local SharedUtility = ReplicatedStorage.SharedUtility
local TrapIcons = ReplicatedStorage.TrapIcons

-- Module
local InputUIController = require(script.InputUIController)
local DisconnectAndDestroy = require(SharedUtility.DisconnectAndDestroy)
local UIScaleCategorizer = require(SharedUtility.UIScaleCategorizer)
local Constants = require(SharedUtility.Constants)

-- Gui templates
local GuiTemplate = script.GuiTemplate

local GuiController = {}
GuiController.__index = GuiController

function GuiController.new(player: Player)
	local inputUIController = InputUIController.new(player)
	
	local gui = GuiTemplate:Clone()
	gui.Parent = player.PlayerGui
	
	local tweenInfo = TweenInfo.new(0.2, 
									Enum.EasingStyle.Quad,
									Enum.EasingDirection.Out,
									0,
									true)
	local slot_1Tween = TweenService:Create(gui.InventoryFrame.Slot_1,
											tweenInfo,
											{ Size = Constants.BUTTON_SMALL_SIZE })
	local slot_2Tween = TweenService:Create(gui.InventoryFrame.Slot_2,
											tweenInfo,
											{ Size = Constants.BUTTON_SMALL_SIZE })
	local slot_3Tween = TweenService:Create(gui.InventoryFrame.Slot_3,
											tweenInfo,
											{ Size = Constants.BUTTON_SMALL_SIZE })
	
	local self = {
		enabled = false,
		player = player,
		inputUIController = inputUIController,
		gui = gui,
		tweens = {slot_1Tween, slot_2Tween, slot_3Tween},
		connections = {}
	}
	setmetatable(self, GuiController)
	
	self:getPlayerIcon(player)
	
	self.inputUIController:setUpdateMobileAlignment(function()
		self:updateAlignment("Mobile")
	end)
	self.inputUIController:setUpdateOtherAlignment(function()
		self:updateAlignment("")
	end)

	return self
end

function GuiController:getPlayerIcon(player)
	local userId = player.UserId
	local thumbnailType = Enum.ThumbnailType.HeadShot
	local thumbnailSize = Enum.ThumbnailSize.Size100x100
	local content, isReady = Players:GetUserThumbnailAsync(userId, thumbnailType, thumbnailSize)
	
	if isReady then
		self.player = nil
		self.gui.MapNavigationFrame.Icon.Image = content
	end
end

function GuiController:fillSlot(slot: number, trapID: string)
	-- get the assetID for the trap icon
	local trapIconID = TrapIcons[trapID].Value
	local slotString = "Slot_"..slot
	
	self.gui.InventoryFrame[slotString].Icon.Image = trapIconID
end

function GuiController:tweenSlot(slot: number)
	self.tweens[slot]:Play()
end

function GuiController:emptySlot(slot: number)
	local slotString = "Slot_"..slot
	
	self.gui.InventoryFrame[slotString].Icon.Image = ""
end

function GuiController:resetSlots()
	local slotIndex = 1
	while slotIndex <= 3 do
		self:emptySlot(slotIndex)
		slotIndex += 1
	end
end

function GuiController:updateMapPlayerIcon(layerID: string)
	local icon = self.gui.MapNavigationFrame.Icon
	if layerID == "1" then
	    icon.Position = Constants.LOW_LAYER
	elseif layerID == "2" then
		icon.Position = Constants.MIDDLE_LAYER
	else
		icon.Position = Constants.HIGH_LAYER
	end
end

function GuiController:resetMapPlayerIcon()
	local icon = self.gui.MapNavigationFrame.Icon
	
	icon.Position = Constants.LOW_LAYER
end

function GuiController:updateScale(dimensions: number)
	local scale = UIScaleCategorizer(dimensions)
	
	self.inputUIController:updateScale(scale)
	self.gui.UIScale.Scale = scale
end

function GuiController:updateAlignment(deviceType: string)
	local anchorPoint
	local position
	local mapAnchorPoint
	local mapPosition
	
	if deviceType == "Mobile" then
		anchorPoint = Vector2.new(0.5,1)
		position = UDim2.new(0.5,0,1,0)
		mapAnchorPoint = Vector2.new(1,0)
		mapPosition = UDim2.new(1,0,0,0)
	else
		anchorPoint = Vector2.new(0,1)
		position = UDim2.new(0,0,1,0)
		mapAnchorPoint = Vector2.new(1,0.5)
		mapPosition = UDim2.new(1,0,0.5,0)
	end
	
	self.gui.InventoryFrame.AnchorPoint = anchorPoint
	self.gui.InventoryFrame.Position = position
	self.gui.MapNavigationFrame.AnchorPoint = mapAnchorPoint
	self.gui.MapNavigationFrame.Position = mapPosition
end

-- enabled the overall functionality of GuiController
function GuiController:enable()
	if self.enabled then
		return
	end
	self.enabled = true
	
	table.insert(
		self.connections,
		self.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:updateScale(self.gui.AbsoluteSize.Y)
		end)
	)
	
	-- if self.player ~= nil, means that the thumbnail hasn't loaded in yet
	-- retry the load
	if self.player then
		self:getPlayerIcon(self.player)
	end
	self.gui.Enabled = true
	self.inputUIController:enable()
	self:updateScale(self.gui.AbsoluteSize.Y)
end

-- disable the overall functionality of GuiController
function GuiController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false
	
	-- disable our gui
	self.gui.Enabled = false
	
	-- reset our mapPlayerIcon and slots
	self:resetMapPlayerIcon()
	self:resetSlots()
	
	self.inputUIController:disable()
	DisconnectAndDestroy(self.connections)
end

-- set up callbacks
function GuiController:setSelectCallback(Callback: () -> any)
	self.inputUIController:setSelectCallback(Callback)
end
function GuiController:setTeleportCallback(Callback: () -> any)
	self.inputUIController:setTeleportCallback(Callback)
end
function GuiController:setRotateCallback(Callback: () -> any)
	self.inputUIController:setRotateCallback(Callback)
end
function GuiController:setPlaceCallback(Callback: () -> any)
	self.inputUIController:setPlaceCallback(Callback)
end


function GuiController:destroy()
	self:disable()

	-- destroy the guiTemplate we cloned
	self.gui:Destroy()
end

return GuiController