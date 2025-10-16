-- Takes a table of connections, disconnects each one and then clears the table
function DisconnectAndDestroy(connections)
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

return DisconnectAndDestroy