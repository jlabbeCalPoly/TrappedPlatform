-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Folders
local Remotes = ReplicatedStorage.Remotes
local Traps = workspace.Traps

-- Remotes
local Trap = Remotes.Trap

-- Constants
local TIMESTAMP_BUFFER = 0.1

local function replicateCooldown(cellID: string)
	local trap : Model = Traps[cellID]
	if trap then
		
		if not trap:GetAttribute("Cooldown") then
			trap:SetAttribute("Cooldown", true)
		-- if the trap is already on cooldown for the client, check if
		-- the activation time is within the buffer (to account for server replication)
		-- if so, activate the trap
		else
			local replicateTimestamp = workspace:GetServerTimeNow()
			local attributeChangedConnection
			local timeoutConnection
			
			attributeChangedConnection = trap:GetAttributeChangedSignal("Cooldown"):Connect(function()
				-- since it's possible for this attribute to possibly return "true",
				-- make sure we debouce if that is the case
				if not trap:GetAttribute("Cooldown") then
					local timestamp = workspace:GetServerTimeNow()
					task.cancel(timeoutConnection)
					attributeChangedConnection:Disconnect()

					if timestamp - replicateTimestamp <= TIMESTAMP_BUFFER then
						trap:SetAttribute("Cooldown", true)
					end
				end
			end)
			
			-- in the event that the countdown attribute never gets updated
			-- (ex. at the end of a game when all the traps are destroyed),
			-- have a timeoutConnection to make sure all connections are cleaned up
			timeoutConnection = task.delay(10, function()
				attributeChangedConnection:Disconnect()
			end)
		end
		
	end
end

-- Replicate cooldowns across 
Trap.OnClientEvent:Connect(function(cellID: string)
	replicateCooldown(cellID)
end)