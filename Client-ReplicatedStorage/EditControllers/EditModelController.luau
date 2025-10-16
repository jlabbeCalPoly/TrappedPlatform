-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

-- Folders
local ViewModels = ReplicatedStorage.ViewModels
local SharedUtility = ReplicatedStorage.SharedUtility
local VFX = ReplicatedStorage.VFX

-- Utility
local Lerp = require(SharedUtility.Lerp)
local DisconnectAndClear = require(SharedUtility.DisconnectAndDestroy)

-- VFX Templates
local EditBeamTemplate = VFX.EditBeam

-- Player Specific
local Camera = game.Workspace.CurrentCamera

local EditModelController = {}
EditModelController.__index = EditModelController

function EditModelController.new(localPlayer: Player)
	local viewModel = ViewModels["EditViewModel"]:Clone()
	viewModel.Parent = ReplicatedStorage
	
	local emitterAttachment = viewModel.Model.Emitter.EmitterAttachment -- where particles will emit from
	
	local animator = viewModel.AnimationController.Animator
	local animationsFolder = viewModel.Animations

	local animations = {}
	for _, animation in animationsFolder:GetChildren() do
		local animationTrack = animator:LoadAnimation(animation)
		animations[animation.Name] = animationTrack

		-- TODO: bind sounds to animation events
	end
	
	local self = {
		enabled = false,
		primaryPart = localPlayer.Character.PrimaryPart,
		viewModel = viewModel,
		hologram = nil, 
		emitterAttachment = emitterAttachment,
		animations = animations,
		hideInstances = {},
		connections = {},
		stride = 0,
		bobbing = 0
	}
	setmetatable(self, EditModelController)

	return self
end

-- Update the position/location of the ViewModel
function EditModelController:update(deltaTime: number)
	local moveSpeed = (self.primaryPart.AssemblyLinearVelocity * Vector3.new(1,0,1)).Magnitude
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

-- Play the Select animation
function EditModelController:playSelectAnimation(duration: number, hologramID: string)
	self.animations.Idle:Stop(0)
	
	local markerReachedConnection
	local selectCanceledConnection
	
	local speed = self.animations.Select.length / duration
	self.animations.Select:Play(0,1,speed)

	local hologram = self.viewModel.Holograms[hologramID]
	local doRotation = true
	self.hologram = hologram
	self.hologram.Transparency = 0
	
	markerReachedConnection = self.animations.Select:GetMarkerReachedSignal("StartLooping"):Connect(function()
		selectCanceledConnection:Disconnect()
		local selectLoopingCanceledConnection
		self.animations.SelectLooping:Play()
		
		selectLoopingCanceledConnection = self.animations.SelectLooping.Stopped:Connect(function()
			selectLoopingCanceledConnection:Disconnect()
			doRotation = false
		end)
	end)

	selectCanceledConnection = self.animations.Select.Stopped:Connect(function()
		markerReachedConnection:Disconnect()
		doRotation = false
	end)	
	
	task.spawn(function()
		while doRotation do
			hologram.Motor6D.C1 *= CFrame.fromEulerAngles(0,math.rad(1),0)
			task.wait(0.05)
		end
	end)
end

function EditModelController:stopSelectAnimation()
	self.animations.Select:Stop(0)
	self.animations.SelectLooping:Stop(0)
	self.animations.Idle:Play()
	
	self.hologram.Transparency = 1
end

function EditModelController:playPlaceAnimation(duration: number, beamLocation: Part)
	self.animations.Idle:Stop(0)
	
	local animationEndedConnection
	local vfxConnection
	
	local speed = self.animations.Place.length / duration
	self.animations.Place:Play(0.1,1,speed)
	
	vfxConnection = self.animations.Place:GetMarkerReachedSignal("PlacingEvent"):Connect(function()
		local editBeam = EditBeamTemplate:Clone()
		editBeam.CFrame = beamLocation.CFrame
		editBeam.Beam.Attachment0 = self.emitterAttachment
		editBeam.Parent = workspace

		local emitter : ParticleEmitter = self.emitterAttachment.ParticleEmitter
		local emissionCount = 0
		
		local audio = ReplicatedStorage.SFX.ZapSFX
		audio:Play()
		
		repeat
			emitter:Emit(2)
			emissionCount += 1
			task.wait(0.1)
		until emissionCount >= 5
		
		editBeam:Destroy()
	end)
	
	animationEndedConnection = self.animations.Place.Stopped:Connect(function()
		animationEndedConnection:Disconnect()
		vfxConnection:Disconnect()
		self.animations.Idle:play()
	end)
end

-- enable the ViewModel
function EditModelController:enable()
	if self.enabled then
		return
	end
	self.enabled = true

	RunService:BindToRenderStep(
		"Edit",
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
function EditModelController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false

	RunService:UnbindFromRenderStep(
		"Edit"
	)

	self.viewModel.Parent = nil
	-- TODO: self:unhideInstances

	for _, animation in self.animations do
		animation:Stop(0)
	end
end

-- destroy the ViewModel, only done when the player leaves the game
function EditModelController:destroy()
	DisconnectAndClear(self.connections)
	self:disable()
	self.viewModel:Destroy()
end

return EditModelController