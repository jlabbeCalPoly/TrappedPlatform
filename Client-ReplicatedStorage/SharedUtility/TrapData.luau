-- Contains all the trap information used by the client/server
-- to update the shop/validate purchases

-- Format:
-- [<TrapName>] = {
--     level : {<Cost to unlock/upgrade>, <Upgraded stat>, <CurrentValue>, <NextValue>}
--}
local TrapInformation = {
	["Spikes"] = {
		{nil, nil, nil, nil},
		{"100", "Damage", "10", "1"},
		{"200", "Damage", "11", "1"},
		{"800", "Damage", "12", "1"},
		{"2000", "Damage", "13", "1"},
		{"5000", "Damage", "14", "1"},
		{"-", "Damage", "15", "Max"}
	},
	["Bouncer"] = {
		{nil, nil, nil, nil},
		{"100", "Power", "100%", "10%"},
		{"200", "Power", "110%", "10%"},
		{"800", "Power", "120%", "10%"},
		{"2000", "Power", "130%", "10%"},
		{"5000", "Power", "140%", "10%"},
		{"-", "Power", "150%", "Max"}
	},
	["Roaster"] = {
		{nil, nil, nil, nil},
		{"200", "Damage", "20", "2"},
		{"400", "Range", "1", "1"},
		{"800", "Damage", "22", "2"},
		{"2000", "Damage", "24", "2"},
		{"10000", "Range", "2", "1"},
		{"-", "Damage", "26", "Max"}
	},
	["Springtrap"] = {
		{"100", "Power", "", "100%"},
		{"200", "Power", "100%", "10%"},
		{"400", "Power", "110%", "10%"},
		{"800", "Power", "120%", "10%"},
		{"2000", "Power", "130%", "10%"},
		{"5000", "Power", "140%", "10%"},
		{"-", "Power", "150%", "Max"}
	},
	["Tall-Wall"] = {
		{"100", "Damage", "", "15"},
		{"200", "Damage", "15", "1"},
		{"400", "Damage", "16", "1"},
		{"1000", "Damage", "17", "1"},
		{"3000", "Damage", "18", "1"},
		{"8000", "Damage", "19", "1"},
		{"-", "Damage", "20", "Max"}
	},
	
}

local TrapDescriptions = {
	["Spikes"] =     "Deals damage to players when stepped on. Who knew bamboo could be so dangerous...",
	["Bouncer"] =    "Boosts players upwards when activated, used to access higher platforms. 8-second cooldown.",
	["Roaster"] =    "Occasionally shoots fire, dealing massive damage. Next time, turn off the oven...",
	["Springtrap"] = "Boosts players in the direction it's facing when activated. 4-second cooldown.",
	["Tall-Wall"] =  "Tall, thin wall that deals damage to players when touched. Place them side by side to form an extra large wall"
}

local TrapData = {}
TrapData.__index = TrapData

function TrapData.retrieveTrapInformation(trapType: string, level: number)
	-- level + 1 because our levels start at 0, but luau arrays start from 1
	return TrapInformation[trapType][level+1]
end

function TrapData.retrieveTrapDescription(trapType: string)
	return TrapDescriptions[trapType]
end

return TrapData