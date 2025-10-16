-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Folders
local SharedUtility = ReplicatedStorage.SharedUtility

-- Module
local DisconnectAndDestroy = require(SharedUtility.DisconnectAndDestroy)
local InputCategorizer = require(SharedUtility.InputCategorizer)
local Constants = require(SharedUtility.Constants)

-- GuiTemplates
local NonTouchTemplate = script.NonTouchGui
local TouchTemplate = script.TouchGui

-- Local constants (for CooldownFill)
local ORIGINAL_SIZE = UDim2.new(0,0,0,0)
local FINAL_SIZE = UDim2.new(1,0,1,0)
local BUTTON_SMALL_SIZE_OVERRIDE = UDim2.new(0, 144, 0, 120)

local InputUIController = {}
InputUIController.__index = InputUIController

function InputUIController.new(player: Player)
	local nonTouchGui = NonTouchTemplate:Clone()
	nonTouchGui.Parent = player.PlayerGui
	
	local touchGui = TouchTemplate:Clone()
	touchGui.Parent = player.PlayerGui

	local tweenInfo = TweenInfo.new(
		Constants.DASH_COOLDOWN,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out
	)
	local dashTweenNonTouch = TweenService:Create(nonTouchGui.HealthFrame.Dash.CooldownFill,
												  tweenInfo,
											      { Size = FINAL_SIZE })
	local dashTweenTouch = TweenService:Create(touchGui.ButtonFrame.Dash.CooldownFill,
											   tweenInfo,
											   { Size = FINAL_SIZE })
	
	-- tween information for button animation tweens
	tweenInfo = TweenInfo.new(0.2, 
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out,
		0,
	    true)
	local dashButtonTweenNonTouch = TweenService:Create(nonTouchGui.HealthFrame.Dash,
														tweenInfo,
														{ Size = Constants.BUTTON_SMALL_SIZE })
	local dashButtonTweenTouch = TweenService:Create(touchGui.ButtonFrame.Dash,
													 tweenInfo,
												     { Size = BUTTON_SMALL_SIZE_OVERRIDE })
	
	local self = {
		enabled = false,
		touchGui = touchGui,
		nonTouchGui = nonTouchGui,
		dashTweenNonTouch = dashTweenNonTouch,
		dashTweenTouch = dashTweenTouch,
		dashButtonTweenNonTouch = dashButtonTweenNonTouch,
		dashButtonTweenTouch = dashButtonTweenTouch,
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

function InputUIController:playDashTween()
	local tween : Tween
	local buttonTween: Tween
	local tweenCompletedConnection
	local cooldownFill
	local countdownLabel
	
	if self.touchGui.Enabled then
		tween = self.dashTweenTouch
		buttonTween = self.dashButtonTweenTouch
		cooldownFill = self.touchGui.ButtonFrame.Dash.CooldownFill
		countdownLabel = self.touchGui.ButtonFrame.Dash.CountdownLabel
	else
		tween =  self.dashTweenNonTouch
		buttonTween = self.dashButtonTweenNonTouch
		cooldownFill = self.nonTouchGui.HealthFrame.Dash.CooldownFill
		countdownLabel = self.nonTouchGui.HealthFrame.Dash.CountdownLabel
	end
	
	tween:Play()
	buttonTween:Play()
	tweenCompletedConnection = tween.Completed:Connect(function(playbackState: Enum.PlaybackState)
		tweenCompletedConnection:Disconnect()
		if playbackState ~= Enum.PlaybackState.Cancelled then
			cooldownFill.Size = ORIGINAL_SIZE
			countdownLabel.Text = ""
		end
	end)
	
	local timer = Constants.DASH_COOLDOWN
	while timer > 0 do
		countdownLabel.Text = string.format("%d", timer)
		timer -= 1
		task.wait(1)
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
	-- Dash callback
	table.insert(
		self.connections,
		self.touchGui.ButtonFrame.Dash.InputBegan:Connect(function(inputObject: InputObject)
			if inputObject.UserInputState == Enum.UserInputState.Change then
				return
			end

			if self.dashCallback and self.enabled then
				self.dashCallback()
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
function InputUIController:setDashCallback(Callback: () -> any)
	self.dashCallback = Callback
end
function InputUIController:setUpdateMobileAlignment(Callback: () -> any)
	self.updateMobileAlignment = Callback
end
function InputUIController:setUpdateOtherAlignment(Callback: () -> any)
	self.updateOtherAlignment = Callback
end

return InputUIController