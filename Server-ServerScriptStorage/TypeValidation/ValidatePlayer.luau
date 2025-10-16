function ValidatePlayer(param)
	if typeof(param) ~= "Instance" then
		return false
	end

	return param:IsA("Player")
end

return ValidatePlayer