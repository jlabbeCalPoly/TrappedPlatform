-- Services
local UserInputService = game:GetService("UserInputService")

local InputCategory = {
	KeyboardAndMouse = "KeyboardAndMouse",
	Touch = "Touch",
	Unknown = "Unknown"
}

local InputCategorizer = {
	initialized = false,
	inputCategory = InputCategory,
	lastInputCategory = Instance.new("StringValue"), -- Fires an RBXScriptSignal whenever the value changes
}

function InputCategorizer.getCategoryOfInput(inputType: Enum.UserInputType)
	if inputType == Enum.UserInputType.Keyboard or string.find(inputType.Name, "Mouse") then
		return InputCategory.KeyboardAndMouse
	elseif inputType == Enum.UserInputType.Touch then
		return InputCategory.Touch
	else
		return InputCategory.Unknown
	end
end

function InputCategorizer.setLastInputCategory(inputCategory: string)
	if inputCategory ~= InputCategorizer.lastInputCategory.Value then
		InputCategorizer.lastInputCategory.Value = inputCategory
	end
end

function InputCategorizer.onInputTypeChanged(inputType: Enum.UserInputType)
	local inputCategory = InputCategorizer.getCategoryOfInput(inputType)
	
	if inputCategory ~= InputCategory.Unknown then
		InputCategorizer.setLastInputCategory(inputCategory)
	end
end

function InputCategorizer.getDefaultInputCategory()
	local lastInputType = UserInputService:GetLastInputType()
	local lastInputCategory = InputCategorizer.getCategoryOfInput(lastInputType)

	if lastInputCategory ~= InputCategory.Unknown then
		return lastInputCategory
	end

	if UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
		return InputCategory.KeyboardAndMouse
	elseif UserInputService.TouchEnabled then
		return InputCategory.Touch
	else
		return InputCategory.Unknown
	end
end

-- make sure InputCategorizer is only initialized once since it's used
-- by both EditController and ActionController
function InputCategorizer.initialize()
	if InputCategorizer.initialized then
		return
	end
	InputCategorizer.initialized = true
	InputCategorizer.lastInputCategory.Value = InputCategory.Unknown
	
	UserInputService.LastInputTypeChanged:Connect(InputCategorizer.onInputTypeChanged)
	
	local defaultCategory = InputCategorizer.getDefaultInputCategory()
	InputCategorizer.setLastInputCategory(defaultCategory)
end

return InputCategorizer