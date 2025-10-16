-- Handles the teleporting aspect within/out of the game
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")

-- Folders
local Remotes = ReplicatedStorage.Remotes
local SharedUtility = ReplicatedStorage.SharedUtility
local Spawns = workspace.Spawns

-- Modules
local DisconnectAndDestroy = SharedUtility.DisconnectAndDestroy

-- Remotes
local Teleport = Remotes.Teleport

local TeleportController = {}
TeleportController.__index = TeleportController

function TeleportController.new(localPlayer)
	
	local self = {
		enabled = false,
		localPlayer = localPlayer,
		connections = {}
	}
	setmetatable(self, TeleportController)
	
	self:initialize()
	
	return self
end

function TeleportController:teleport(teleportID: string, fromServer: boolean)
	if self.enabled or fromServer then
		local teleport = Spawns:FindFirstChild(teleportID)
		if teleport then
			self.localPlayer.Character:PivotTo(teleport.CFrame)
		else
			if teleportID == "GameSpawn" then
				-- in the event the gamespawn isn't available, teleport them to the hardcoded gamespawn cFrame
				local hardcodedGameSpawn = CFrame.new(364.992, 55.712, 14.979)
				self.localPlayer.Character:PivotTo(hardcodedGameSpawn)
			else
				warn("teleport failed")
			end
		end
	end
end

function TeleportController:initialize()
	table.insert(
		self.connections,
		Teleport.OnClientEvent:Connect(function(teleportID: string)
			self:teleport(teleportID, true)
		end)
	)
end

function TeleportController:enable()
	if self.enabled then
		return
	end
	self.enabled = true
end

function TeleportController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false
end

function TeleportController:destroy()
	DisconnectAndDestroy(self.connections)
end

return TeleportController