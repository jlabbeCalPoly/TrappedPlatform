-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Folders
local ViewModels = ReplicatedStorage.ViewModels
local SharedUtility = ReplicatedStorage.SharedUtility

-- Utility
local Lerp = require(SharedUtility.Lerp)
local DisconnectAndDestroy = require(SharedUtility.DisconnectAndDestroy)

-- Player Specific
local Camera = game.Workspace.CurrentCamera

local ActionModelController = {}
ActionModelController.__index = ActionModelController

-- Create a new ViewModel controller
function ActionModelController.new(localPlayer: Player)	
	local viewModel = ViewModels["ActionViewModel"]:Clone() -- the ActionViewModel
	viewModel.Parent = ReplicatedStorage

	local emitter = viewModel.Model.Emitter.ParticleAttachment -- where particles will emit from
	
	local animator = viewModel.AnimationController.Animator
	local animationsFolder = viewModel.Animations
	
	local animations = {}
	for _, animation in animationsFolder:GetChildren() do
		local animationTrack = animator:LoadAnimation(animation)
		animations[animation.Name] = animationTrack
		
		-- TODO: bind sounds to animation events
	end
	
	local self ={
		enabled = false,
		inAnimation = false,
		primaryPart = localPlayer.Character.PrimaryPart,
		viewModel = viewModel,
		emitter = emitter,
		animations = animations,
		hideInstances = {},
		connections = {},
		stride = 0,
		bobbing = 0
	}
	setmetatable(self, ActionModelController)
	
	return self
end

-- Update the position/location of the ViewModel
function ActionModelController:update(deltaTime: number)
	local moveSpeed = (self.primaryPart.AssemblyLinearVelocity * Vector3.new(1,0,1)).Magnitude
	if moveSpeed > 32 then
		moveSpeed = 32
	end
	
	local bobbingSpeed = moveSpeed * 0.4 -- TODO: constants for BOBBING_SPEED
	local bobbing = math.min(bobbingSpeed, 1)

	self.stride = (self.stride + bobbingSpeed * deltaTime) % (math.pi * 2)
	self.bobbing = Lerp(self.bobbing, bobbing, math.min(deltaTime * 0.4, 1)) -- TODO: constants for BOBBING SPEED

	local x = math.sin(self.stride)
	local y = math.sin(self.stride * 2)

	local bobbingOffset = Vector3.new(x, y, 0) * 0.1 * self.bobbing -- TODO: constants for BOBBING AMOUNT
	local bobbingCFrame = CFrame.new(bobbingOffset)

	self.viewModel:PivotTo(Camera.CFrame * bobbingCFrame * CFrame.new(0.7, -1.3,-2.5)) -- TODO: constants for VIEWMODEL OFFSET
end

function ActionModelController:playDashAnimation(duration: number)
	self.animations.Idle:Stop(0)

	local endedConnection
	local speed = self.animations.Dash.length / duration
	self.animations.Dash:Play(0.1,1,speed)
	
	table.insert(
		self.connections,
		self.animations.Dash:GetMarkerReachedSignal("Particles"):Once(function()
			local particleEmitter = self.emitter.ParticleEmitter
			local emitCount = 3
			repeat
				particleEmitter:Emit(1)
				emitCount -= 1
				task.wait(0.1)
			until emitCount == 0
		end)
	)
	
	table.insert(
		self.connections,
		self.animations.Dash.Stopped:Once(function()
			DisconnectAndDestroy(self.connections)
			if self.enabled then
				self.animations.Idle:play()
			end
		end)
	)
	
--	local audio = ReplicatedStorage.SFX.DashSFX
--	audio:Play()
end

-- enable the ViewModel
function ActionModelController:enable()
	if self.enabled then
		return
	end
	self.enabled = true
	
	RunService:BindToRenderStep(
		"Action",
		Enum.RenderPriority.Camera.Value + 1,
		function(deltaTime: number)
			self:update(deltaTime)
		end
	)
	
	self.viewModel.Parent = workspace
	-- TODO: self:hideInstances()
	
	self.animations.Idle:play()
end

-- disable the ViewModel
function ActionModelController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false
	
	RunService:UnbindFromRenderStep(
		"Action"
	)
	
	self.viewModel.Parent = nil
	-- TODO: self:unhideInstances

	for _, animation in self.animations do
		animation:Stop(0)
	end
end

-- destroy the ViewModel, only done when the player leaves the game
function ActionModelController:destroy()
	self.viewModel:Destroy()
end

return ActionModelController