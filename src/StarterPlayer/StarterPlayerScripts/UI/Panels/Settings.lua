-- Painel Settings: liga/desliga câmera do ovo, música, sons e ovos de outros jogadores.
return function(ctx)
	local UI = ctx.UI
	local T = UI.Theme
	local window, content = ctx.UIController:CreateWindow("Settings", "SETTINGS", "Settings", Color3.fromRGB(130, 140, 170), Vector2.new(560, 400))

	local list = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content })
	UI.list(list, true, 10)

	local defs = {
		{ Key = "EggCamera", Name = "Egg Camera", Desc = "Camera follows your egg after a kick" },
		{ Key = "Sounds", Name = "Sound Effects", Desc = "Kick, coins and UI sounds" },
		{ Key = "Music", Name = "Music", Desc = "Background music" },
		{ Key = "ShowOtherEggs", Name = "Other Players' Eggs", Desc = "Show eggs kicked by other players" },
	}
	local toggles = {}
	for i, def in defs do
		local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 68), BackgroundColor3 = T.PanelLight, LayoutOrder = i, Parent = list })
		UI.corner(row, 12)
		UI.label({
			Text = def.Name,
			Size = UDim2.new(1, -170, 0, 30),
			Position = UDim2.fromOffset(16, 6),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 26,
			Parent = row,
		})
		UI.label({
			Text = def.Desc,
			Size = UDim2.new(1, -170, 0, 22),
			Position = UDim2.fromOffset(16, 38),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.SubText,
			Font = T.BodyFont,
			MaxTextSize = 16,
			NoStroke = true,
			Parent = row,
		})
		local button = UI.button({
			Text = "ON",
			Color = T.Green,
			Size = UDim2.fromOffset(120, 46),
			Position = UDim2.new(1, -14, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Parent = row,
			OnClick = function()
				local data = ctx.Controllers.DataController:Get()
				if data then
					ctx.UIController:Invoke("SetSetting", def.Key, not data.Settings[def.Key])
				end
			end,
		})
		toggles[def.Key] = button
	end

	local panel = { Window = window }
	function panel:Refresh(data)
		for key, button in toggles do
			local on = data.Settings[key] == true
			UI.setButtonText(button, if on then "ON" else "OFF")
			UI.setButtonColor(button, if on then T.Green else T.Gray)
		end
	end
	return panel
end
