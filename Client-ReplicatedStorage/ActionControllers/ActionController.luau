-- Controller for handling the actions of the player during the rounds, such as movement
-- (mid-air dash)
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Folders
local ActionControllers = ReplicatedStorage.ActionControllers
local SharedUtility = ReplicatedStorage.SharedUtility
local Remotes = ReplicatedStorage.Remotes

-- Modules
local Constants = require(SharedUtility.Constants)
local ActionModelController = require(ActionControllers.ActionModelController)
local GuiController = require(ActionControllers.GuiController)
local CameraController = require(ActionControllers.CameraController)
local DisconnectAndDestroy = require(SharedUtility.DisconnectAndDestroy)

-- Remotes
local Action = Remotes.Action
local Immunity = Remotes.Immunity
local Eliminate = Remotes.Eliminate
local CancelDash = Remotes.CancelDash

-- Player Specific
local Camera : Camera = game.Workspace.CurrentCamera

local ActionController = {}
ActionController.__index = ActionController

-- Create a new ActionController
function ActionController.new(player: Player, respawns)
	local actionModelController = ActionModelController.new(player)
	local guiController = GuiController.new(player)
	local cameraController = CameraController.new(player, respawns)
	
	local self = {
		enabled = false,
		actionModelController = actionModelController,
		guiController = guiController,
		cameraController = cameraController,
		dashCooldown = false,
		player = player,
		connections = {}
	}
	setmetatable(self, ActionController)

	self:initialize()
	self:enable()

	return self
end

-- validate dash
function ActionController:checkDash()
	if self.enabled and not self.dashCooldown then
		return true
	else
		return false
	end
end

-- Player ability: Dash
function ActionController:dash(lookDirection: Vector3)
	self.dashCooldown = true
	self.player:SetAttribute("Dashing", true)
	
	RunService:BindToRenderStep(
		"dash",
		Enum.RenderPriority.Camera.Value - 1,
		function(deltaTime)
			self:maintainVelocity(deltaTime, lookDirection * Constants.VECTOR_MULTIPLIER)
		end
	)

	task.spawn(function()
		self.guiController:playDashTween()
	end)
	
	local unbindTask
	local endEarlyConnection

	endEarlyConnection = CancelDash.Event:Connect(function()
		task.cancel(unbindTask)
		endEarlyConnection:Disconnect()
		RunService:UnbindFromRenderStep("dash")
		self.player:SetAttribute("Dashing", false)
	end)

	unbindTask = task.delay(0.3,function()
		endEarlyConnection:Disconnect()
		RunService:UnbindFromRenderStep("dash")
		self.player:SetAttribute("Dashing", false)
	end)
	
	self.actionModelController:playDashAnimation(0.5)
	
	task.wait(Constants.DASH_COOLDOWN)
	self.dashCooldown = false
end

function ActionController:maintainVelocity(deltaTime, lookDirection)
	self.player.Character.HumanoidRootPart.AssemblyLinearVelocity = lookDirection
end

-- Enable the ActionController functionality (round-based part of game)
function ActionController:enable()
	if self.enabled then
		return
	end
	self.enabled = true

	self.actionModelController:enable()
	self.guiController:enable()
end

-- Disable the ActionController functionality (edit-based part of game)
function ActionController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false

	self.actionModelController:disable()
	self.guiController:disable()
end

-- Set up all events and callbacks (in the event the player is using a touchscreen)
function ActionController:initialize()
	table.insert(
		self.connections,
		Action.OnClientEvent:Connect(function(enable: boolean)
			if enable then
				self:enable()
			else
				self:disable()
			end
		end)
	)
	table.insert(
		self.connections,
		Immunity.OnClientEvent:Connect(function()
			self.player:SetAttribute("Immune", true)
		end)
	)
	table.insert(
		self.connections,
		Eliminate.OnClientEvent:Connect(function(debounce: boolean)
			self:disable()
			self:onEliminate(debounce)
		end)
	)
	table.insert(
		self.connections,
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed then
				return
			end
			
			if input.KeyCode == Constants.DASH_KEYCODE then
				if self:checkDash() then
					local lookDirection = Camera.CFrame.LookVector
					self:dash(lookDirection)
				end
			end
		end)
	)
	table.insert(
		self.connections,
		self.player:GetAttributeChangedSignal("Health"):Connect(function()
			local health = self.player:GetAttribute("Health")
			self.guiController:setHealth(health)
		end)
	)
	
	self.guiController:setDashCallback(function()
		if self:checkDash() then
			local lookDirection = Camera.CFrame.LookVector
			self:dash(lookDirection)
		end
	end)
	
	self.cameraController:setDefaultCamera()
end

function ActionController:onEliminate(debounce: boolean)
	self.player.Character.HumanoidRootPart.Anchored = true
	self.player.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
	
	self.cameraController:setDeathCamera(Camera.CFrame, function()
		self:callback()
	end, debounce)
	--callback: re-enable the default camera and reset the action controller/health
end

function ActionController:callback()
	self:enable()
	self.player:SetAttribute("Health", 100)
	self.cameraController:setDefaultCamera()

	self.player.Character.HumanoidRootPart.Anchored = false
end

-- Only to be called when the player is leaving the game
function ActionController:destroy()
	DisconnectAndDestroy(self.connections)
	self:disable()
	
	self.actionModelController:destroy()
	self.guiController:destroy()
end

return ActionController