function ValidateString(param)
	if typeof(param) ~= "string" then
		return false
	end
	
	return true
end

return ValidateString