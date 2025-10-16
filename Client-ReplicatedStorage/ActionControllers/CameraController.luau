-- Controls the camera for entire game
-- reason it's in action controller is because we need to disable
-- actionViewModel when doing the animation
-- Services
local TweenService = game:GetService("TweenService")
local workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- Folders
local Spawns = workspace.Spawns
local SharedUtility = ReplicatedStorage.SharedUtility
local Remotes = ReplicatedStorage.Remotes
local VFX = ReplicatedStorage.VFX

-- Remotes
local Respawn = Remotes.Respawn
local osTime = Remotes.OsTime
local Earn = Remotes.Earn

-- Modules
local DisconnectAndDestroy = require(SharedUtility.DisconnectAndDestroy)

-- GuiTemplates
local RespawnGuiTemplate = script.RespawnTemplate

local CameraController = {}
CameraController.__index = CameraController

function CameraController.new(player: Player, respawns)
	local camera = game.Workspace.CurrentCamera
	local respawnGui = RespawnGuiTemplate:Clone()
	respawnGui.Parent = player.PlayerGui
	
	local self = {
		camera = camera,
		respawnGui = respawnGui,
		player = player,
		cachedParts = {}
	}
	setmetatable(self, CameraController)
	
	self:initialize(respawns)
	
	return self
end

-- Used from Roblox's TransparencyController in CameraModule
function CameraController:IsValidPartToModify(part: BasePart)
	if part:IsA('BasePart') or part:IsA('Decal') then
		return true
	end
	return false
end

-- Used from Roblox's TransparencyController in CameraModule
function CameraController:CachePartsRecursive(object)
	if object then
		if self:IsValidPartToModify(object) then
			self.cachedParts[object] = true
		end
		for _, child in pairs(object:GetChildren()) do
			self:CachePartsRecursive(child)
		end
	end
end

function CameraController:initialize(respawns)
	self:setDefaultCamera()
	for _, child in pairs(self.player.Character:GetChildren()) do
		self:CachePartsRecursive(child)
	end
	
	self:updateFreeRespawns(respawns)
end

-- reset the camera to the default first-person view
function CameraController:setDefaultCamera()
	self.player.CameraMode = Enum.CameraMode.LockFirstPerson
end

-- play the death camera animation
function CameraController:setDeathCamera(cFrame: CFrame, callback, debounce)
	self.camera.CameraType = Enum.CameraType.Custom
	self.camera.CameraType = Enum.CameraType.Scriptable
	
	for child, _ in pairs(self.cachedParts) do
		child.LocalTransparencyModifier = 0
	end
	
	local originalPosition =cFrame.Position
	local newDirection = self.player.Character.HumanoidRootPart.CFrame.LookVector * -10
	local yOffset = Vector3.new(0, 6, 0)
	local targetCFrame = CFrame.new(originalPosition + newDirection + yOffset, originalPosition)
	
	local tweenInfo = TweenInfo.new(0.5,
									Enum.EasingStyle.Quad,
									Enum.EasingDirection.Out
	)
	local tween = TweenService:Create(self.camera, tweenInfo, {CFrame = targetCFrame})
	tween:Play()
	
	local eliminationTask
	
	-- if there is enough time for a respawn, prompt the player
	if workspace:GetAttribute("CountdownTimer") >= 7 and workspace:GetAttribute("CountdownText") ~= "Game starting in:" then
		local now = workspace:GetServerTimeNow()
		osTime:FireServer(now)
		
		local earnTask
		local earnConnection
		
		eliminationTask = task.delay(7, function()
			-- CFrame for the LobbySpawn
			self.player.Character:PivotTo(CFrame.new(125, 131, 15))
			self.camera.CameraType = Enum.CameraType.Custom
			callback()
		end)
		
		earnTask = task.delay(20, function()
			earnConnection:Disconnect()
		end)
		
		earnConnection = Earn.OnClientEvent:Connect(function(earnings)
			for currency, value in earnings do
				if currency == "Respawns" then
					task.cancel(earnTask)
					earnConnection:Disconnect()
					local purchaseButton = self.respawnGui.RespawnFrame.PurchaseButton.Button
					local count = purchaseButton:GetAttribute("Respawns")
					self:updateFreeRespawns(count + value)
				end
			end
		end)
		
		local progressBar = self.respawnGui.RespawnFrame.ProgressBar.CurrentLevel
		local purchaseButton = self.respawnGui.RespawnFrame.PurchaseButton.Button
		local respawnCount = self.respawnGui.RespawnFrame.RespawnCount
		local awaitingServerResponse = false
		local connections = {}
		
		local barTweenInfo = TweenInfo.new(5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
		local barTween = TweenService:Create(progressBar, barTweenInfo, { Size = UDim2.new(0,0,0.7,0) })
		
		local function countdown()
			respawnCount.Text = "5"
			progressBar.Size = UDim2.new(0,390,0.7,0)

			self.respawnGui.Enabled = true
			barTween:Play()

			local countdown = 5
			while countdown > 0 do
				respawnCount.Text = ""..countdown
				task.wait(1)
				countdown -= 1
			end
		end
		
		-- Connection for eliminating the player
		table.insert(
			connections,
			barTween.Completed:Connect(function()
				DisconnectAndDestroy(connections)
				local eliminationVFX = VFX["Elimination"]:Clone()
				eliminationVFX.Parent = workspace
				eliminationVFX.CFrame = self.player.Character.HumanoidRootPart.CFrame
				self.respawnGui.Enabled = false

				task.wait(1.5)
				eliminationVFX:Destroy()
			end)
		)
		
		-- Will fire if the server validates the client's respawn request
		table.insert(
			connections,
			Respawn.OnClientEvent:Connect(function(count)
				DisconnectAndDestroy(connections)
				task.cancel(eliminationTask)
				-- CFrame for the GameSpawn
                self.player.Character:PivotTo(CFrame.new(365, 56, 15))
				self.camera.CameraType = Enum.CameraType.Custom
				self.respawnGui.Enabled = false
				callback()
			end)
		)

		-- handle the purchase button logic
		table.insert(
			connections,
			purchaseButton.Activated:Connect(function()
				if not awaitingServerResponse then 
					local freeRespawns = purchaseButton:GetAttribute("Respawns")
					if freeRespawns > 0 then
						awaitingServerResponse = true
--						self:updateFreeRespawns(freeRespawns - 1)
						-- immediately send respawn event to server
						Respawn:FireServer()
					else
						local MarketplaceService = game:GetService("MarketplaceService")
						local productId = purchaseButton:GetAttribute("ProductId")
						MarketplaceService:PromptProductPurchase(self.player, productId)
					end
				end
			end)
		)
		
		countdown()
	else
		eliminationTask = task.delay(2, function()
			-- CFrame for the LobbySpawn
			self.player.Character:PivotTo(CFrame.new(125, 131, 15))
			self.camera.CameraType = Enum.CameraType.Custom
			callback()
		end)
		
		local eliminationVFX = VFX["Elimination"]:Clone()
		eliminationVFX.Parent = workspace
		eliminationVFX.CFrame = self.player.Character.HumanoidRootPart.CFrame

		task.wait(1.5)
		eliminationVFX:Destroy()
	end
end

function CameraController:updateFreeRespawns(count)
	local purchaseButton = self.respawnGui.RespawnFrame.PurchaseButton.Button
	if count then
		purchaseButton:SetAttribute("Respawns", count)
		self.respawnGui.RespawnFrame.FreeText.Text = "Free respawns: "..count
	end
end

return CameraController
