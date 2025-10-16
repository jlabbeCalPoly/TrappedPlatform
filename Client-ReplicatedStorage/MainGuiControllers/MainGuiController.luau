-- This module handles the main gui that's always present on the players screen, as
-- well as displaying any other gui's that can be displayed in the lobby
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Folders
local SharedUtility = ReplicatedStorage.SharedUtility
local Remotes = ReplicatedStorage.Remotes
local TrapIcons = ReplicatedStorage.TrapIcons

-- Modules
local DisconnectAndDestroy = require(SharedUtility.DisconnectAndDestroy)
local UIScaleCategorizer = require(SharedUtility.UIScaleCategorizer)
local TrapData = require(SharedUtility.TrapData)

-- Gui Templates
local MainGuiTemplate = script.MainGui
local ShopGuiTemplate = script.ShopGui
local ExtremeEventsGuiTemplate = script.ExtremeEvents

-- Remotes
local Shop = Remotes.Shop
local TrapDeck = Remotes.TrapDeck
local OpenGui = Remotes.OpenGui
local Earn = Remotes.Earn
local Edit = Remotes.Edit

-- String Templates
--local TIMER_FORMAT_STRING = '<font size="22">%s</font> <font size="30"><i>%ds</i></font>'
local RATIO_FORMAT_STRING = '<i><font size="35">%s</font><font size="25">/%s</font></i>'

local MainGuiController = {}
MainGuiController.__index = MainGuiController

function MainGuiController.new(localPlayer: Player, playerData)
	local mainGui = MainGuiTemplate:Clone()
	mainGui.Parent = localPlayer.PlayerGui
	
	local countdownText = "" -- message that goes next to the countdownTimer
	local countdownTimer = 0 -- number value representing the time left
	local initialPlayerCount = "-" -- string value representing the inital amount of players that started in the round
	local remainingPlayerCount = "-" -- string value representing the remaining amount of players in the game
	local roundCount = "-"; -- string value representing the current round
	
	local shopGui = ShopGuiTemplate:Clone()
	shopGui.Parent = localPlayer.PlayerGui
	
	local extremeEventsGui = ExtremeEventsGuiTemplate:Clone()
	extremeEventsGui.Parent = localPlayer.PlayerGui
	
	local tweenInfo = TweenInfo.new(0.05,Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, true)
	local shakeTween = TweenService:Create(mainGui.CountdownFrame.CountdownTimer, tweenInfo, {Rotation = 3})
	
	local self = {
		mainGui = mainGui,
		shopGui = shopGui,
		extremeEventsGui = extremeEventsGui,
		countdownText = countdownText,
		countdownTimer = countdownTimer,
		initialPlayerCount = initialPlayerCount,
		remainingPlayerCount = remainingPlayerCount,
		roundCount = roundCount,
		shakeTween = shakeTween,
		pendingTransaction = false, -- are we waiting for a reponse from the server for the shop
		connections = {},
		persistentConnections = {}, -- connections that persist across certain actions in shopGui/extremeEventsGui
		temporaryConnections = {},  -- connections that should immediately end after certain actions in shopGui/extremeEventsGui
		inTutorial = true      -- removed when the :joinQueue is called
	}
	setmetatable(self, MainGuiController)
	
	self:initialize()
	self:setupShop(playerData)
	
	return self
end

function MainGuiController:updateRoundCount()
	self.roundCount = workspace:GetAttribute("RoundCount")
	self.mainGui.PlayersFrame.RoundLabel.Text = string.format(RATIO_FORMAT_STRING, self.roundCount, 3)
	
	if self.roundCount == "1" and self.inTutorial == nil then
--		self:disableShop()
--		self:disableExtremeEvents()
		
		-- Also, do checks to see if there are any cells that are still in RemovedCells that weren't moved back by the server (timing issues)
		local RemovedCells = ReplicatedStorage.RemovedCells
		for _, cell in RemovedCells:GetChildren() do
			cell.Parent = workspace
		end
	end
end

function MainGuiController:updateInitialPlayerCount()
	self.initialPlayerCount = workspace:GetAttribute("InitialPlayerCount")
	self.mainGui.PlayersFrame.PlayersLabel.Text = string.format(RATIO_FORMAT_STRING, self.remainingPlayerCount, self.initialPlayerCount)
end

function MainGuiController:updateRemainingPlayerCount()
	local playersLabel = self.mainGui.PlayersFrame.PlayersLabel
	local prevRemainingCount = tonumber(self.remainingPlayerCount)
	self.remainingPlayerCount = workspace:GetAttribute("RemainingPlayerCount")
	playersLabel.Text = string.format(RATIO_FORMAT_STRING, self.remainingPlayerCount, self.initialPlayerCount)
	
	local remainingCount = tonumber(self.remainingPlayerCount)
	if prevRemainingCount and remainingCount and prevRemainingCount > remainingCount then
		local WHITE_COLOR = Color3.fromHex("ffffff")
		local RED_COLOR = Color3.fromHex("ff0000")
		local tweenInfo = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(playersLabel, tweenInfo, { TextColor3 = WHITE_COLOR })
		
		playersLabel.TextColor3 = RED_COLOR
		tween:Play()
	end
end

function MainGuiController:updateCountdownText()
	self.countdownText = workspace:GetAttribute("CountdownText")
	self.mainGui.CountdownFrame.CountdownText.Text = self.countdownText
end

function MainGuiController:updateCountdownTimer()
	self.countdownTimer = workspace:GetAttribute("CountdownTimer")
	self.mainGui.CountdownFrame.Visible = true
	
	-- determine whether you need to stop/start the tween,
	-- as well as updating to the correct gradient
	if self.countdownTimer == 5 then
		local timer = self.mainGui.CountdownFrame.CountdownTimer
		timer.Gradient.Enabled = true
		
		timer.Rotation = -3
		self.shakeTween:Play()
		
		task.spawn(function()
			local audio = ReplicatedStorage.SFX.TimerSFX
			local count = 0
			repeat
				audio:Play()
				count += 1
				task.wait(1)
			until count == 5
		end)
	elseif self.countdownTimer == 0 then
		local timer = self.mainGui.CountdownFrame.CountdownTimer
		timer.Gradient.Enabled = false
		
		self.shakeTween:Cancel()
		timer.Rotation = 0
		
		self.mainGui.CountdownFrame.Visible = false
	end
	
	self.mainGui.CountdownFrame.CountdownTimer.Text = self.countdownTimer.."s"
end

function MainGuiController:updateEventTicketPowerCount()
	local count = workspace:GetAttribute("EventTickets")
	self.extremeEventsGui.Frame.PowerFrame.CountFrame.PowerCount.Text = ""..count
end

function MainGuiController:initialize()
	table.insert(
		self.connections,
		workspace:GetAttributeChangedSignal("RoundCount"):Connect(function()
			self:updateRoundCount()
		end)
	)
	table.insert(
		self.connections,
		workspace:GetAttributeChangedSignal("CountdownText"):Connect(function()
			self:updateCountdownText()
		end)
	)
	table.insert(
		self.connections,
		workspace:GetAttributeChangedSignal("CountdownTimer"):Connect(function()
			self:updateCountdownTimer()
		end)
	)
	table.insert(
		self.connections,
		workspace:GetAttributeChangedSignal("InitialPlayerCount"):Connect(function()
			self:updateInitialPlayerCount()
		end)
	)
	table.insert(
		self.connections,
		workspace:GetAttributeChangedSignal("RemainingPlayerCount"):Connect(function()
			self:updateRemainingPlayerCount()
		end)
	)
	table.insert(
		self.connections,
		workspace:GetAttributeChangedSignal("EventTickets"):Connect(function()
			self:updateEventTicketPowerCount()
		end)
	)
	table.insert(
		self.connections,
		self.mainGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:updateScale(self.mainGui.AbsoluteSize.Y)
		end)
	)
	table.insert(
		self.connections,
		OpenGui.Event:Connect(function(guiId: string)
			if guiId == "shop" then
				if self.shopGui.Enabled then
					self:disableShop()
				else
					self:disableExtremeEvents()
					self:enableShop()
				end
			else
				if self.extremeEventsGui.Enabled then
					self:disableExtremeEvents()
				else
					self:disableShop()
					self:enableExtremeEvents()
				end
			end
		end)
	)
	table.insert(
		self.connections,
		Earn.OnClientEvent:Connect(function(earnings)
			self:onEarn(earnings)
			
			local audio = ReplicatedStorage.SFX.EarnSFX
			audio:Play()
		end)
	)
	table.insert(
		self.connections,
		Edit.OnClientEvent:Connect(function(enable: boolean)
			if enable then
				self:disableShop()
				self:disableExtremeEvents()
			end
		end)
	)
	
	self:updateRoundCount()
	self:updateInitialPlayerCount()
	self:updateRemainingPlayerCount()
	self:updateCountdownText()
	self:updateEventTicketPowerCount()
	self:updateScale(self.mainGui.AbsoluteSize.Y)
end

function MainGuiController:onEarn(earnings)
	local earnFrame = script.EarnStuff.EarnFrame:Clone()
	for currency, value in earnings do
		if currency == "Cash" then
			self:updateCashLabels(self.cash + value)

			local cashLabel = script.EarnStuff.CashLabel:Clone()
			cashLabel:WaitForChild("AmountLabel").Text = "+$"..value
			cashLabel.Parent = earnFrame
		elseif currency == "Tickets" then
			self:updateTicketLabels(self.tickets + value)

			local ticketsLabel = script.EarnStuff.TicketsLabel:Clone()
			ticketsLabel:WaitForChild("AmountLabel").Text = "+"..value
			ticketsLabel.Parent = earnFrame
		elseif currency == "2xCash" then
			self:updatePassInfo("2xCash")
		end
	end

	local tweenInfo = TweenInfo.new(0.7,Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(earnFrame, tweenInfo, { Position = UDim2.new(0,0,0.4,0)})

	local tweenCompletedConnection
	tweenCompletedConnection = tween.Completed:Connect(function()
		tweenCompletedConnection:Disconnect()
		task.wait(1.5)
		earnFrame:Destroy()
	end)

	earnFrame.Parent = self.mainGui
	tween:Play()
end

-- upgrade button logic
function MainGuiController:upgrade(trapId, levelUpgradeTo)
	self.pendingTransaction = true
	local serverResponseConnection
			
	serverResponseConnection = Shop.OnClientEvent:Connect(function(success: boolean, currencyType: string, remainingCash: number)
		serverResponseConnection:Disconnect()
		if success and currencyType == "Cash" then
			self:updateCashLabels(remainingCash)
			self:updateTrapButton(trapId, levelUpgradeTo)
			self:updateMainFrame(trapId, levelUpgradeTo)
		end
				
		self.pendingTransaction = false
	end)

	Shop:FireServer("Cash", trapId, levelUpgradeTo)
end

function MainGuiController:useEventTicket()
	self.pendingTransaction = true
	local serverResponseConnection

	serverResponseConnection = Shop.OnClientEvent:Connect(function(success: boolean, currencyType: string, remainingTickets: number)
		serverResponseConnection:Disconnect()
		if success and currencyType == "Tickets" then
			self:updateTicketLabels(remainingTickets)
		end

		self.pendingTransaction = false
	end)

	Shop:FireServer("Tickets")
end

-- update the MainFrame in the shop
function MainGuiController:updateMainFrame(trapId: string, level: number)
	-- retrieve the trap information for the trap
	--     level : {<Cost to unlock/upgrade>, <Upgraded stat>, <CurrentValue>, <NextValue>}
	local trapInfo = TrapData.retrieveTrapInformation(trapId, level)
	local trapDescription = TrapData.retrieveTrapDescription(trapId)

	self.trapId = trapId
	self.level = level
	self.costToUpgrade = tonumber(trapInfo[1])

	local mainFrame = self.shopGui.ShopFrame.MainFrame
	mainFrame.TrapIcon.Image = TrapIcons[trapId].Value
	mainFrame.TrapName.Text = trapId

	-- self.costToUpgrade will be nil if the trap is at max level
	if self.costToUpgrade then
		mainFrame.CostFrame.Visible = true
		mainFrame.CostFrame.CostLabel.Text = "$"..self.costToUpgrade
	else
		mainFrame.CostFrame.Visible = false
	end
	
	local currentMultiplier = 0
	local nextMultiplier = 0
	local upgradeButton = mainFrame.UpgradeButton
	if level == 0 then
		upgradeButton.LabelText.Text = "Unlock"
		mainFrame.EquipButton.Visible = false
		nextMultiplier = 2
	elseif level == 6 then
		upgradeButton.LabelText.Text = "Max"
		mainFrame.EquipButton.Visible = true
		currentMultiplier = level
	else
		upgradeButton.LabelText.Text = "Upgrade"
		mainFrame.EquipButton.Visible = true
		currentMultiplier = level
		nextMultiplier = currentMultiplier + 1
	end
	local currentLevel = mainFrame.ProgressBar.CurrentLevel
	local nextLevel = mainFrame.ProgressBar.NextLevel
	currentLevel.Size = UDim2.new(0, 65*currentMultiplier, 0, 14)
	nextLevel.Size = UDim2.new(0, 65*nextMultiplier, 0, 14)

	if self.nextLevelTween then
		self.nextLevelTween:Cancel()
	end
	if nextMultiplier ~= 0 then
		nextLevel.BackgroundTransparency = 0
		local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, true, 0.5)
		self.nextLevelTween = TweenService:Create(nextLevel, tweenInfo, {BackgroundTransparency = 1})
		self.nextLevelTween:Play()
	end
	
	mainFrame.Description.DescriptionText.Text = trapDescription
	
	local upgradeInfo = mainFrame.UpgradeInfo
	upgradeInfo.UpgradeType.Text = trapInfo[2]
	
	local UPGRADE_FORMAT_STRING = `<font size="20">%s </font><i><font color="#A9FF70"><font size="25">+%s</font></font></i>`
	upgradeInfo.UpgradeAmount.Text = string.format(UPGRADE_FORMAT_STRING, trapInfo[3], trapInfo[4])
end

-- update all the cash labels across all the gui's
function MainGuiController:updateCashLabels(cash: number)
	self.cash = cash
	
	local formatedCash = "$"..cash
	self.shopGui.ShopFrame.Header.CashFrame.Balance.Text = formatedCash
	self.shopGui.CurrencyFrame.Header.CashFrame.Balance.Text = formatedCash
end

-- update all the ticket labels across all the gui's
function MainGuiController:updateTicketLabels(tickets: number)
	self.tickets = tickets
	
	local formatedTickets = ""..tickets
	self.shopGui.ShopFrame.Header.TicketsFrame.Balance.Text = formatedTickets
	self.shopGui.CurrencyFrame.Header.TicketsFrame.Balance.Text = formatedTickets
	self.extremeEventsGui.Frame.Header.TicketsFrame.Balance.Text = formatedTickets
end

-- update the provided trap button with the specified trapId and corresponding level
function MainGuiController:updateTrapButton(trapId: string, level: number)
	local trapFrame = self.shopGui.ShopFrame.TrapFrame
	local button
	if trapFrame["Damage"]:findFirstChild(trapId) then
		button = trapFrame["Damage"][trapId]
	else
		button = trapFrame["Utility"][trapId]
	end
		
	local prevLevel = button:GetAttribute("Level")
	-- if the prevLevel was 0, remove the lock icon and recenter the level text
	if prevLevel == 0 then
		button.LockIcon:Destroy()
		button.LevelText.Position = UDim2.new(0.5,0,1,0)
	end		
	button.LevelText.Text = "Level "..level
	button:SetAttribute("Level", level)
end

-- update the provided slot in the trap deck with the specified trapId
function MainGuiController:updateTrapDeck(trapId: string, slotSelected: number)
	local slots = self.shopGui.ShopFrame.TrapDeck.Slots
	local slot = slots[""..slotSelected]
	slot.TrapName.Text = trapId
	slot.TrapIcon.Image = TrapIcons[trapId].Value
end

-- function called when the equip button is pressed
function MainGuiController:enableTrapDeckConnections()
	-- do checks beforehand to assess the validity of the equip button event
	local trapId = self.trapId
	local trapFrame = self.shopGui.ShopFrame.TrapFrame
	if trapFrame["Damage"]:findFirstChild(trapId) then
		if trapFrame["Damage"][trapId]:GetAttribute("Level") == 0 then
			return
		end
	else
		if trapFrame["Utility"][trapId]:GetAttribute("Level") == 0 then
			return
		end
	end
	
	local trapDeck = self.shopGui.ShopFrame.TrapDeck
	local slots = trapDeck.Slots
	for _, slot in slots:GetChildren() do
		if trapId == slot.TrapName.Text then
			return
		end
	end
	
	-- all checks have passed, disable the current connections
	-- then, enable the selectionFrame, create tween for the slots,
	-- and create specific connections
	DisconnectAndDestroy(self.persistentConnections)
	DisconnectAndDestroy(self.temporaryConnections)
	
	local selectionFrame = self.shopGui.ShopFrame.SelectionFrame
	local PURPLE_COLOR = Color3.fromHex("8474ff")
	local WHITE_COLOR = Color3.fromHex("ffffff")
	local slot1 = trapDeck.UIStuff["1"]
	local slot2 = trapDeck.UIStuff["2"]
	local slot3 = trapDeck.UIStuff["3"]
	local tweenInfo = TweenInfo.new(0.8,Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, true, 0.5)
	local tweenSlot1 = TweenService:Create(slot1, tweenInfo, { BackgroundColor3 = PURPLE_COLOR })
	local tweenSlot2 = TweenService:Create(slot2, tweenInfo, { BackgroundColor3 = PURPLE_COLOR })
	local tweenSlot3 = TweenService:Create(slot3, tweenInfo, { BackgroundColor3 = PURPLE_COLOR })
	
	local function cancelTweens()
		tweenSlot1:Cancel()
		tweenSlot2:Cancel()
		tweenSlot3:Cancel()
		slot1.BackgroundColor3 = WHITE_COLOR
		slot2.BackgroundColor3 = WHITE_COLOR
		slot3.BackgroundColor3 = WHITE_COLOR
	end
	
	local function restoreOriginalConnections()
		DisconnectAndDestroy(self.persistentConnections)
		cancelTweens()
		selectionFrame.Visible = false
		
		self:enablePersistentShopConnections()
		self:enableTemporaryShopConnections()
	end
	
	table.insert(
		self.persistentConnections,
		selectionFrame.Header.CancelButton.Button.Activated:Connect(function()
			restoreOriginalConnections()
		end)
	)
	for _, slot in slots:GetChildren() do
		table.insert(
			self.persistentConnections,
			slot.Activated:Connect(function()
				restoreOriginalConnections()
				TrapDeck:FireServer(trapId, tonumber(slot.Name))
				slot.TrapIcon.Image = TrapIcons[trapId].Value
				slot.TrapName.Text = trapId
			end)
		)
	end
	table.insert(
		self.persistentConnections,
		workspace:GetAttributeChangedSignal("RoundCount"):Connect(function()
			if workspace:GetAttribute("RoundCount") == "1" then
				-- other areas in our code should already disable all connections/reset the guis,
				-- so only cancel the tweens
				cancelTweens()
			end
		end)
	)
	selectionFrame.Visible = true
	tweenSlot1:Play()
	tweenSlot2:Play()
	tweenSlot3:Play()
end

-- create connections specifically for the left trap button navigation
function MainGuiController:enableTemporaryShopConnections(trapType: string)
	local trapButtons
	local selectedTab
	local otherTab
	local trapFrame = self.shopGui.ShopFrame.TrapFrame
	if trapType == "Damage" then
		trapButtons = trapFrame.Damage
		trapFrame.Utility.Visible = false
		trapFrame.Damage.Visible = true
		selectedTab = self.shopGui.ShopFrame.Header.TabsFrame.Damage
		otherTab = self.shopGui.ShopFrame.Header.TabsFrame.Utility
		
	else
		trapButtons = trapFrame.Utility
		trapFrame.Damage.Visible = false
		trapFrame.Utility.Visible = true
		selectedTab = self.shopGui.ShopFrame.Header.TabsFrame.Utility
		otherTab = self.shopGui.ShopFrame.Header.TabsFrame.Damage
	end

	local TALL_ANCHOR = Vector2.new(0.5,0.9)
	local SMALL_ANCHOR = Vector2.new(0.5,0.75)
	selectedTab.AnchorPoint = TALL_ANCHOR
	otherTab.AnchorPoint = SMALL_ANCHOR
	
	for _, button in trapButtons:GetChildren() do
		table.insert(
			self.temporaryConnections,
			button.Activated:Connect(function()
				self:updateMainFrame(button.Name, button:GetAttribute("Level"))
			end)
		)
	end
	table.insert(
		self.temporaryConnections,
		otherTab.Activated:Connect(function()
			DisconnectAndDestroy(self.temporaryConnections)
			self:enableTemporaryShopConnections(otherTab.Name)
		end)
	)	
end

function MainGuiController:enablePersistentShopConnections()
	local header = self.shopGui.ShopFrame.Header
	local mainFrame = self.shopGui.ShopFrame.MainFrame
	table.insert(
		self.persistentConnections,
		header.CashFrame.Button.Activated:Connect(function()
			self:disableShop()
			self:enableCurrency()
		end)
	)
	table.insert(
		self.persistentConnections,
		header.TicketsFrame.Button.Activated:Connect(function()
			self:disableShop()
			self:enableCurrency()
		end)
	)
	table.insert(
		self.persistentConnections,
		header.ExitButton.Button.Activated:Connect(function()
			self:disableShop()
		end)
	)
	table.insert(
		self.persistentConnections,
		mainFrame.UpgradeButton.Activated:Connect(function()
			local trapId = self.trapId
			local levelUpgradeTo =  self.level + 1

			if self.costToUpgrade and not self.pendingTransaction then
				if self.cash >= self.costToUpgrade then
					self:upgrade(trapId, levelUpgradeTo)
				else
					self:disableShop()
					self:enableCurrency()
				end
			end
		end)
	)
	table.insert(
		self.persistentConnections,
		mainFrame.EquipButton.Activated:Connect(function()
			self:enableTrapDeckConnections()
		end)
	)
end

function MainGuiController:enablePersistentCurrencyConnections()
	local currencyFrame = self.shopGui.CurrencyFrame
	for _, bundle in currencyFrame.Bundles:GetChildren() do
		local button = bundle.PurchaseButton.Button
		table.insert(
			self.persistentConnections,
			button.Activated:Connect(function()
				local MarketplaceService = game:GetService("MarketplaceService")
				local Players = game:GetService("Players")

				local productId = button:GetAttribute("ProductId")
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
			end)
		)
	end
	
	local cashPassButton = currencyFrame.CashPass:findFirstChild("PurchaseButton")
	if cashPassButton then
		local button = cashPassButton.Button
		table.insert(
			self.persistentConnections,
			button.Activated:Connect(function()
				local MarketplaceService = game:GetService("MarketplaceService")
				local Players = game:GetService("Players")
				
				local productId = button:GetAttribute("ProductId")
				MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, productId)
			end)
		)
	end
	
	local returnButton = currencyFrame.Header.ReturnButton.Button
	table.insert(
		self.persistentConnections,
		returnButton.Activated:Connect(function()
			self:disableCurrency()
			if self.lastGui == "Shop" then
				self:enableShop()
			else
				self:enableExtremeEvents()
			end
		end)
	)
end

-- enable the currency frame in shopGui
function MainGuiController:enableCurrency()
	self:enablePersistentCurrencyConnections()
	
	self.shopGui.CurrencyFrame.Visible = true
	self.shopGui.Enabled = true
end

function MainGuiController:disableCurrency()
	DisconnectAndDestroy(self.persistentConnections)
	
	self.shopGui.CurrencyFrame.Visible = false
	self.shopGui.Enabled = false
end

-- enable the inital connections for the shop
function MainGuiController:enableShop()
	self.lastGui = "Shop"
	self:enablePersistentShopConnections()
	self:enableTemporaryShopConnections("Damage")
	
	self.shopGui.ShopFrame.Visible = true
	
	-- automatically open the shop up with the spikes in the MainFrame
	local spikesLevel = self.shopGui.ShopFrame.TrapFrame.Damage.Spikes:GetAttribute("Level")
	self:updateMainFrame("Spikes", spikesLevel)
	self.shopGui.Enabled = true
end

-- disable the shop, disconnecting all connections and
-- resetting all elements back to their original state
function MainGuiController:disableShop()
	DisconnectAndDestroy(self.persistentConnections)
	DisconnectAndDestroy(self.temporaryConnections)
	
	self.shopGui.ShopFrame.Visible = false
	self.shopGui.ShopFrame.SelectionFrame.Visible = false
	
	if self.nextLevelTween then
		self.nextLevelTween:Cancel()
		self.nextLevelTween = nil
	end
	self.shopGui.Enabled = false
end

-- setup the initial information for the shop
function MainGuiController:setupShop(playerData)
	self:updateCashLabels(playerData.Cash)
	self:updateTicketLabels(playerData.EventTickets)
	
	for trapId, level in playerData.TrapsUnlocked do
		self:updateTrapButton(trapId, level)
	end

	for index, trapId in playerData.TrapDeck do
		self:updateTrapDeck(trapId, index)
	end
	
	if playerData["2xCash"] then
		self:updatePassInfo("2xCash")
	end
end

function MainGuiController:updatePassInfo(pass: string)
	if pass == "2xCash" then
		self.shopGui.CurrencyFrame.CashPass.PurchaseButton:Destroy()
	end
end

function MainGuiController:enableExtremeEventsConnections()
	local header = self.extremeEventsGui.Frame.Header
	local powerFrame = self.extremeEventsGui.Frame.PowerFrame
	table.insert(
		self.persistentConnections,
		header.TicketsFrame.Button.Activated:Connect(function()
			self:disableExtremeEvents()
			self:enableCurrency()
		end)
	)
	table.insert(
		self.persistentConnections,
		header.ExitButton.Button.Activated:Connect(function()
			self:disableExtremeEvents()
		end)
	)
	table.insert(
		self.persistentConnections,
		powerFrame.CountFrame.PurchaseButton.Button.Activated:Connect(function()
			if self.tickets > 0 and not self.pendingTransaction then
				self:useEventTicket()
			elseif self.tickets == 0 then
				self:disableExtremeEvents()
				self:enableCurrency()
			end
		end)
	)
end

function MainGuiController:disableExtremeEvents()
	DisconnectAndDestroy(self.persistentConnections)
	
	self.extremeEventsGui.Frame.Visible = false
	self.extremeEventsGui.Enabled = false
end

function MainGuiController:enableExtremeEvents()
	self.lastGui = "Events"
	self:enableExtremeEventsConnections()
	
	self.extremeEventsGui.Frame.Visible = true
	self.extremeEventsGui.Enabled = true
end

function MainGuiController:updateScale(dimensions: number)
	local scale = UIScaleCategorizer(dimensions)

	self.mainGui.UIScale.Scale = scale
	self.shopGui.UIScale.Scale = scale
	self.extremeEventsGui.UIScale.Scale = scale
end

function MainGuiController:disable()
	self.mainGui:Destroy()
	self.shopGui:Destroy()
	self.extremeEventsGui:Destroy()
	DisconnectAndDestroy(self.connections)
end

function MainGuiController:joinQueue()
	script.TutorialGui:Destroy()
	local ConcurrentPlayer = Remotes.ConcurrentPlayer
	ConcurrentPlayer:FireServer()
	self.inTutorial = nil
end

function MainGuiController:playTutorial(localPlayer: Player)
	local tutorialGui = script.TutorialGui
	local guiFrame = tutorialGui.GuiFrame
	
	local highlight = tutorialGui.Highlight
	local description = guiFrame.Description
	local nextButton = description.NextButton
	local skipButton = tutorialGui.Header.SkipButton.Button
	
	-- Format: [index] = {
	--	[1] = {<parent>, <anchor>, <position>, <text>, <nextConnection>}, -- for the description
	--	[2] = {<parent>, <anchor>, <position>, <size>}                    -- for the highlight
	--	}
	local tutorialStepData = {
		{
			{guiFrame, Vector2.new(0.5,0), UDim2.new(0.5,0,0,0), "Welcome to \"Trapped Platform\"! Read the game description below to get started!"},
			{tutorialGui, Vector2.new(0,0), UDim2.new(0,0,0,0), UDim2.new(0,0,0,0)}
		},
		{
			{guiFrame, Vector2.new(0.5,0), UDim2.new(0.5,0,0,0), "Make your way to the shop and hold down on the \"Open Shop\" button!", workspace:WaitForChild("Lobby"):WaitForChild("ShopProxPrompt"):WaitForChild("ProximityPrompt")},
			{tutorialGui, Vector2.new(0,0), UDim2.new(0,0,0,0), UDim2.new(0,0,0,0)}
		},
		{
			{guiFrame, Vector2.new(0.5,0), UDim2.new(0.5,0,0.3,0), "These are the traps you can place during the game! Toggle between \"Damage\" and \"Utility\" to see more!"},
			{guiFrame, Vector2.new(0,0), UDim2.new(0,0,0,0), UDim2.new(0.25,0,1,0)}
		},
		{
			{guiFrame, Vector2.new(0,0), UDim2.new(0,0,0.3,0), "This is where the information for equipping/unlocking/upgrading the selected trap is displayed!"},
			{guiFrame, Vector2.new(0.5,0), UDim2.new(0.5,0,0,0), UDim2.new(0.5,0,1,0)}
		},
		{
			{guiFrame, Vector2.new(0.5,0), UDim2.new(0.5,0,0.3,0), "You can only bring 3 traps of your choice into each game! Choose wisely, some traps work better together than others!"},
			{guiFrame, Vector2.new(1,0), UDim2.new(1,0,0,0), UDim2.new(0.25,0,1,0)}
		},
		{
			{guiFrame, Vector2.new(0.5,0), UDim2.new(0.5,0,0,0), "Exit out of the shop and make your way to the Extreme Events generator, hold down on the \"Open Events\" button!",  workspace:WaitForChild("Lobby"):WaitForChild("EventsProxPrompt"):WaitForChild("ProximityPrompt")},
			{tutorialGui, Vector2.new(0,0), UDim2.new(0,0,0,0), UDim2.new(0,0,0,0)}
		},
		{
			{guiFrame, Vector2.new(1,0.5), UDim2.new(1,20,0.5,0), "You can power Extreme Events using \"Event Tickets\"! You can view the current power of the generator here!"},
			{guiFrame, Vector2.new(0.5,0.5), UDim2.new(0.275,0,0.5,0), UDim2.new(0.57,0,1.04,0)}
		},
		{
			{guiFrame, Vector2.new(0.5,0.5), UDim2.new(0.275,0,0.5,0), "You can view all the possible Extreme Events that can occur here! More events will be added soon!"},
			{guiFrame, Vector2.new(0.5,0.5), UDim2.new(0.8,0,0.5,0), UDim2.new(0.47,0,1.04,0)}
		},
		{
			{guiFrame, Vector2.new(0.5,0), UDim2.new(0.5,0,0,0), "That's all you need to get started! Feel free to complete the obby while you wait for the next game to begin! Have fun!"},
			{tutorialGui, Vector2.new(0,0), UDim2.new(0,0,0,0), UDim2.new(0,0,0,0)}
		},
	}
	local connections = {}
	local toDestroy = {}
	
	local function cleanup()
		DisconnectAndDestroy(connections)
		for _, obj in toDestroy do
			obj:Destroy()
		end
		table.clear(toDestroy)
	end
	
	local function changeStep(step: number)
		-- check for special steps
		if step == 1 then
			guiFrame.LeftInfo.Visible = true
			guiFrame.MiddleInfo.Visible = true
			guiFrame.RightInfo.Visible = true
		elseif step == 2 then
			nextButton.Visible = false
			guiFrame.LeftInfo.Visible = false
			guiFrame.MiddleInfo.Visible = false
			guiFrame.RightInfo.Visible = false
		elseif step == 3 then
			nextButton.Visible = true
		elseif step == 6 then
			nextButton.Visible = false
		elseif step == 7 then
			nextButton.Visible = true
		elseif step == 9 then
			if self.extremeEventsGui.Enabled then
				self:disableExtremeEvents()
			end
			-- last step
		elseif step == 10 then
			tutorialGui.Parent = script
			self:joinQueue()
			return
		end
		local stepData = tutorialStepData[step]
		description.Parent = stepData[1][1]
		description.AnchorPoint = stepData[1][2]
		description.Position = stepData[1][3]
		description.DescriptionText.Text = stepData[1][4]
		
		highlight.Parent = stepData[2][1]
		highlight.AnchorPoint = stepData[2][2]
		highlight.Position = stepData[2][3]
		highlight.Size = stepData[2][4]
	
		-- initalize connection, next step
		if stepData[1][5] then
			-- create attachments with beam
			local playerAttachment = Instance.new("Attachment")
			playerAttachment.Parent = localPlayer.Character.HumanoidRootPart
			local proximityAttachment = Instance.new("Attachment")
			if step == 2 then
				proximityAttachment.Parent = workspace.Lobby.ShopProxPrompt
			elseif step == 6 then
				proximityAttachment.Parent = workspace.Lobby.EventsProxPrompt
			end
			
			local beam = Instance.new("Beam")
			beam.Attachment0 = playerAttachment
			beam.Attachment1 = proximityAttachment
			beam.FaceCamera = true
			beam.Texture = "rbxassetid://115282734926108"
			beam.TextureMode = Enum.TextureMode.Static
			beam.TextureSpeed = 3
			beam.LightEmission = 0.5
			beam.Parent = workspace
			
			toDestroy = {beam, proximityAttachment, playerAttachment}
			
			table.insert(
				connections,
				stepData[1][5].Triggered:Connect(function()
					cleanup()
					changeStep(step + 1)
				end)
			)
		else
			table.insert(
				connections,
				nextButton.Activated:Connect(function()
					cleanup()
					changeStep(step + 1)
				end)
			)
		end
		-- initalize connection, skip tutorial
		table.insert(
			connections,
			skipButton.Activated:Connect(function()
				cleanup()
				--update to be the last step in the tutorial
				changeStep(10)
			end)
		)
		table.insert(
			connections,
			self.mainGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				local scale = UIScaleCategorizer(self.mainGui.AbsoluteSize.Y)
				tutorialGui.UIScale.Scale = scale
			end)
		)
	end
	
	tutorialGui.UIScale.Scale = self.mainGui.UIScale.Scale
	tutorialGui.Parent = localPlayer.PlayerGui
	tutorialGui.Enabled = true
	changeStep(1)
end

return MainGuiController