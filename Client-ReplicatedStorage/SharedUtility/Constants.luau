local Constants = {
	-- UI scale multipliers
	["UI_SCALE_MINI"] = 0.5,
	["UI_SCALE_SMALL"] = 0.6,
	["UI_SCALE_MEDIUM"] = 1,
	["UI_SCALE_LARGE"] = 1.5,
	-- Screen size dimension cutoffs
	["MINI_CUTOFF"] = 351,
	["SMALL_CUTOFF"] = 601,
	["MEDIUM_CUTOFF"] = 901,
	
	-- Gui button animation tween
	["BUTTON_SMALL_SIZE"] = UDim2.new(0, 96, 0, 80),

	-- Platform location UDim2 values for mapNavigationGui
	["LOW_LAYER"] = UDim2.new(0.5, 0, 0.75, 0),
	["MIDDLE_LAYER"] = UDim2.new(0.5, 0, 0.5, 0),
	["HIGH_LAYER"] = UDim2.new(0.5, 0, 0.25, 0),
	
	-- EditController Hologram constants
	["HOLOGRAM_BLUE_COLOR"] = Color3.fromHex("00fbff"),
	["HOLOGRAM_RED_COLOR"] = Color3.fromHex("ff0000"),
	["HOLOGRAM_NIL_PIVOT"] = CFrame.new(1,1,1), -- TODO: set this to the nil pivot location for traps
	
	-- EditController KeyCode constants
	["SELECT_KEYCODE_1"] = Enum.KeyCode.One,
	["SELECT_KEYCODE_2"] = Enum.KeyCode.Two,
	["SELECT_KEYCODE_3"] = Enum.KeyCode.Three,
	["PLACE_KEYCODE"] = Enum.KeyCode.E,
	["ROTATE_KEYCODE"] = Enum.KeyCode.R,
	["TELEPORT_UP_KEYCODE"] = Enum.KeyCode.F,
	["TELEPORT_DOWN_KEYCODE"] = Enum.KeyCode.V,
	
	-- ActionController KeyCode constants
	["DASH_KEYCODE"] = Enum.KeyCode.E,
	["VECTOR_MULTIPLIER"] = Vector3.new(80,60,80),
	
	-- ActionController cooldown constants
	["DASH_COOLDOWN"] = 5,
	["IMMUNITY_COOLDOWN"] = 5
}

return Constants