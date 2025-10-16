function ValidateNumber(param)
	if typeof(param) ~= "number" then
		return false
	end
	
	-- check for NaN values
	if param ~= param then
		return false
	end
	
	return true
end

return ValidateNumber
