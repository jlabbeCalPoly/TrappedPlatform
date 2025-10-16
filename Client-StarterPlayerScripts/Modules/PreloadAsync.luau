local ContentProvider = game:GetService("ContentProvider")

function PreloadAsync(loadingText: TextLabel)
	loadingText.Text = "Loading Animations..."
	ContentProvider:PreloadAsync({
		"rbxassetid://139531816201241",
		"rbxassetid://85056295073742",
		"rbxassetid://127098681737601",
		"rbxassetid://111176502819829",
		"rbxassetid://103252962437369",
		"rbxassetid://94391207154268"
		
	})
	
	loadingText.Text = "Loading Traps..."
	ContentProvider:PreloadAsync({
		"rbxassetid://118993720920150",
		"rbxassetid://127337431196071",
		"rbxassetid://71029314738039",
		"rbxassetid://82455453917819"
	})
	
	loadingText.Text = "Loading ZapSplat Audio..."
	ContentProvider:PreloadAsync({
		"rbxassetid://122437923866277", -- TimerSFX
		"rbxassetid://93050764712203", -- ZapSFX
		"rbxassetid://112701462495811", -- SelectSFX
		"rbxassetid://77094331238268", -- FireSFX
		"rbxassetid://135243926834023", -- DamageSFX
		"rbxassetid://91553034771261", -- Thud SFX
		"rbxassetid://129995162664253", -- Explosion SFX
		"rbxassetid://103773081621895" -- Earn SFX
--		"rbxassetid://81790609187681" -- Dash SFX
	})
	
	task.wait(0.6)
end

return PreloadAsync