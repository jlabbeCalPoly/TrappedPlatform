-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Folders
local VFX = script.Parent
local Remotes = ReplicatedStorage.Remotes

-- Events
local Particles = Remotes.Particles

Particles.Event:Connect(function(VFX_Id: string, Cframe: CFrame)
	local particles = VFX[VFX_Id]:Clone()
	particles.CFrame = Cframe
	particles.Parent = workspace
	
	for _, emitter in particles:GetChildren() do
		emitter:Emit(emitter:GetAttribute("emitCount"))
	end
	
	task.wait(particles:GetAttribute("lifetime"))
	particles:Destroy()
end)