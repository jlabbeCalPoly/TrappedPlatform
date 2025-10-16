local player = game:GetService("Players").LocalPlayer

local function onCharacterAdded()
	local character = player.Character

	-- Services
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	-- Folder
	local StarterCharacterScripts = script.Parent:WaitForChild("Modules")
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")

	local EditControllers = ReplicatedStorage.EditControllers
	local ActionControllers = ReplicatedStorage.ActionControllers
	local MainGuiController = ReplicatedStorage.MainGuiController
	local ViewModels = ReplicatedStorage.ViewModels

	-- Modules
	local PreloadAsnc = require(StarterCharacterScripts:WaitForChild("PreloadAsync"))
	local CoreCall = require(StarterCharacterScripts:WaitForChild("CoreCall"))
	
	-- Remotes
	local GetData = Remotes:WaitForChild("GetData")

	local EditController = require(EditControllers.EditController)
	local ActionController = require(ActionControllers.ActionController)
	local MainGuiController = require(MainGuiController.MainGuiController)
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	while humanoidRootPart == nil do
		task.wait(0.1)
		humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	end
	

	local TweenService = game:GetService("TweenService")
	local loadingScreen = player.PlayerGui:WaitForChild("LoadingScreen")
	local background = loadingScreen:WaitForChild("Background")
	local logo = loadingScreen:WaitForChild("Logo")
	local loadingText = logo:WaitForChild("LoadingText")

	CoreCall('SetCore', 'ResetButtonCallback', false)
	PreloadAsnc(loadingText)
	
	EditController.new(player)
	
	-- get the player's data from the server, needed for MainGuiController and setting
	-- up the shop and extreme events gui
	loadingText.Text = "Loading player data..."
	local playerData
	while playerData == nil do
		-- get the playerData from the server
		local data = GetData:InvokeServer()
		
		if data then
			playerData = data
		else
			task.wait(3)
		end
	end
	-- Remote function is no longer needed, remove from RS
	GetData:Destroy()

	ActionController.new(player, playerData.Respawns)
	local mainGuiController = MainGuiController.new(player, playerData)

	player:SetAttribute("Health", 100)
	player:SetAttribute("Dashing", false)
	
	local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	local backgroundTween = TweenService:Create(background, tweenInfo, { BackgroundTransparency = 1 })
	local logoTween = TweenService:Create(logo, tweenInfo, { ImageTransparency = 1 })
	local completedConnection
	
	-- connection for cleanup
	completedConnection = logoTween.Completed:Connect(function() 
		completedConnection:Disconnect()
		loadingScreen:Destroy()
	end)
	
	loadingText:Destroy()
	backgroundTween:Play()
	logoTween:Play()
	
	-- check if the player has already played before (LastJoin data should be initialized)
	if playerData.LastJoin == nil then
		mainGuiController:playTutorial(player)
	else
		mainGuiController:joinQueue()
	end
end

onCharacterAdded()