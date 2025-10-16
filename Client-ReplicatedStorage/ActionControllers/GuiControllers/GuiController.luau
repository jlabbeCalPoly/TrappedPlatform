-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Folders
local SharedUtility = ReplicatedStorage.SharedUtility

-- Module
local InputUIController = require(script.InputUIController)
local DisconnectAndDestroy = require(SharedUtility.DisconnectAndDestroy)
local UIScaleCategorizer = require(SharedUtility.UIScaleCategorizer)
local Constants = require(SharedUtility.Constants)

-- Gui templates
local GuiTemplate = script.GuiTemplate

-- Local constants
local HEALTH_FORMAT_STRING = '<font size="50">%d</font><font size="27">%%</font>'
local HEALTH_TWEEN_TIME = 1
local HEALTH_WHITE_COLOR = Color3.fromHex("ffffff")
local HEALTH_RED_COLOR = Color3.fromHex("ff0000")

local GuiController = {}
GuiController.__index = GuiController

function GuiController.new(player: Player)
	local inputUIController = InputUIController.new(player)

	local gui = GuiTemplate:Clone()
	gui.Parent = player.PlayerGui
	
	local tweenInfo = TweenInfo.new(HEALTH_TWEEN_TIME, 
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out)
	local healthTween = TweenService:Create(gui.HealthFrame.Health.HealthLabel,
		tweenInfo,
		{ TextColor3 =  HEALTH_WHITE_COLOR})
	
	local self = {
		enabled = false,
		player = player,
		inputUIController = inputUIController,
		gui = gui,
		healthTween = healthTween,
		connections = {}
	}
	setmetatable(self, GuiController)
	
	self:initialize()
	
	self.inputUIController:setUpdateMobileAlignment(function()
		self:updateAlignment("Mobile")
	end)
	self.inputUIController:setUpdateOtherAlignment(function()
		self:updateAlignment("")
	end)
	
	return self
end

-- update the health label and does effects if needed
function GuiController:setHealth(health: number)
	local healthLabel = self.gui.HealthFrame.Health.HealthLabel
	local prevHealth = healthLabel.Health.Value
	healthLabel.Health.Value = health
	
	-- if the health is less than the previous health, do the effects
	-- otherwise, simply change the value in the healthLabel
	if health < prevHealth then
		local loopRepetitions = prevHealth - health
		local interval = HEALTH_TWEEN_TIME / loopRepetitions
		
		healthLabel.TextColor3 = HEALTH_RED_COLOR
		self.healthTween:Play()
		local waitOffset = 0
		
		local audio = ReplicatedStorage.SFX.DamageSFX
		audio:Play()

		while loopRepetitions > 0 do
			prevHealth -= 1
			loopRepetitions -= 1
			healthLabel.Text = string.format(HEALTH_FORMAT_STRING, prevHealth)
			
			-- adjust wait interval to account for discrepencies in 
			-- actual wait times vs. our interval time
			local elapsed = task.wait(interval + waitOffset)
			waitOffset -= (elapsed - interval)
		end
	else
		healthLabel.Text = string.format(HEALTH_FORMAT_STRING, health)
	end
end

function GuiController:playDashTween()
	self.inputUIController:playDashTween()
end

function GuiController:updateScale(dimensions: number)
	local scale = UIScaleCategorizer(dimensions)

	self.inputUIController:updateScale(scale)
	self.gui.UIScale.Scale = scale
end

function GuiController:updateAlignment(deviceType: string)
	local anchorPoint
	local position

	if deviceType == "Mobile" then
		anchorPoint = Vector2.new(0.5,1)
		position = UDim2.new(0.5,0,1,0)
	else
		anchorPoint = Vector2.new(0,1)
		position = UDim2.new(0,0,1,0)
	end

	self.gui.HealthFrame.AnchorPoint = anchorPoint
	self.gui.HealthFrame.Position = position
end

function GuiController:initialize()
	table.insert(
		self.connections,
		self.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:updateScale(self.gui.AbsoluteSize.Y)
		end)
	)
	table.insert(
		self.connections,
		self.player:GetAttributeChangedSignal("Immune"):Connect(function()
			if self.player:GetAttribute("Immune") then
				self.gui.Effects.Immunity.Visible = true
				local endImmunityTask
				local endEarlyConnection
				
				endImmunityTask = task.delay(Constants.IMMUNITY_COOLDOWN, function()
					endEarlyConnection:Disconnect()
					self.player:SetAttribute("Immune", false)
				end)
				
				endEarlyConnection = self.player:GetAttributeChangedSignal("Immune"):Connect(function()
					endEarlyConnection:Disconnect()
					task.cancel(endImmunityTask)
				end)
			else
				self.gui.Effects.Immunity.Visible = false
			end
		end)
	)
end

-- enabled the overall functionality of GuiController
function GuiController:enable()
	if self.enabled then
		return
	end
	self.enabled = true

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

	self.inputUIController:disable()
	
	-- temporarily do this
	self.gui.Effects.Immunity.Visible = false
end

-- set up callbacks
function GuiController:setDashCallback(Callback: () -> any)
	self.inputUIController:setDashCallback(Callback)
end

function GuiController:destroy()
	self:disable()
	DisconnectAndDestroy(self.connections)
	
	-- destroy the guiTemplate we cloned
	self.gui:Destroy()
end

return GuiController