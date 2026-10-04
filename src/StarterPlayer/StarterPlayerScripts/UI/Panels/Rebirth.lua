-- Painel Rebirth: requisitos, bônus do próximo rebirth e marcos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local NumberFormat = require(Modules.NumberFormat)
local RebirthConfig = require(Modules.RebirthConfig)

return function(ctx)
	local UI = ctx.UI
	local T = UI.Theme
	local window, content = ctx.UIController:CreateWindow("Rebirth", "REBIRTH", "Rebirth", Color3.fromRGB(180, 100, 255), Vector2.new(720, 470))

	-- Esquerda: bônus + requisitos + botão
	local left = UI.new("Frame", { Size = UDim2.new(0.58, -8, 1, 0), BackgroundColor3 = T.PanelLight, Parent = content })
	UI.corner(left, 14)
	UI.padding(left, 14)
	local count = UI.label({ Text = "", Size = UDim2.new(1, 0, 0, 34), MaxTextSize = 30, TextColor3 = Color3.fromRGB(220, 180, 255), Parent = left })

	local bonus = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 104), Position = UDim2.fromOffset(0, 40), BackgroundColor3 = T.PanelDark, Parent = left })
	UI.corner(bonus, 12)
	UI.padding(bonus, 8)
	UI.list(bonus, true, 2)
	local bonusLines = {}
	for i, key in { "Strength", "Coins", "Kick" } do
		bonusLines[key] = UI.label({
			Text = "",
			Size = UDim2.new(1, 0, 0, 28),
			LayoutOrder = i,
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 22,
			Parent = bonus,
		})
	end

	UI.label({ Text = "Requirements", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 152), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.SubText, MaxTextSize = 20, Parent = left })
	local strengthBar = UI.progressBar(left, T.Strength, UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 180))
	local coinsBar = UI.progressBar(left, T.Gold, UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, 218))
	UI.label({
		Text = "Resets your Coins and Strength. Keeps pets, eggs, upgrades and areas.",
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 254),
		TextColor3 = T.SubText,
		Font = T.BodyFont,
		TextWrapped = true,
		MaxTextSize = 15,
		NoStroke = true,
		Parent = left,
	})

	local confirming = false
	local rebirthButton
	rebirthButton = UI.button({
		Text = "REBIRTH",
		Color = T.Purple,
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		TextSize = 30,
		Parent = left,
		OnClick = function()
			if not confirming then
				confirming = true
				UI.setButtonText(rebirthButton, "TAP AGAIN TO CONFIRM")
				task.delay(3, function()
					confirming = false
					UI.setButtonText(rebirthButton, "REBIRTH")
				end)
				return
			end
			confirming = false
			UI.setButtonText(rebirthButton, "REBIRTH")
			local ok = ctx.UIController:Invoke("Rebirth")
			if ok then
				ctx.UIController:ClosePanel()
			end
		end,
	})

	-- Direita: marcos
	local right = UI.new("Frame", { Size = UDim2.new(0.42, -8, 1, 0), Position = UDim2.new(0.58, 8, 0, 0), BackgroundColor3 = T.PanelLight, Parent = content })
	UI.corner(right, 14)
	UI.padding(right, 12)
	UI.label({ Text = "Milestones", Size = UDim2.new(1, 0, 0, 30), MaxTextSize = 26, Parent = right })
	local milestoneList = UI.new("Frame", { Size = UDim2.new(1, 0, 1, -38), Position = UDim2.fromOffset(0, 38), BackgroundTransparency = 1, Parent = right })
	UI.list(milestoneList, true, 8)
	local milestoneRows = {}
	for i, m in RebirthConfig.Milestones do
		local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = T.PanelDark, LayoutOrder = i, Parent = milestoneList })
		UI.corner(row, 10)
		local stroke = UI.stroke(row, T.Gray, 2)
		UI.label({ Text = m.Rebirths .. " Rebirth" .. (if m.Rebirths > 1 then "s" else ""), Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 4), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Gold, MaxTextSize = 18, Parent = row })
		UI.label({ Text = m.Text, Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 27), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 16, Font = T.BodyFont, NoStroke = true, Parent = row })
		milestoneRows[i] = stroke
	end

	local panel = { Window = window }
	function panel:Refresh(data)
		local r = data.Rebirths
		count.Text = "Rebirths: " .. NumberFormat.Abbreviate(r)
		local now = RebirthConfig.Multipliers(r)
		local nextM = RebirthConfig.Multipliers(r + 1)
		bonusLines.Strength.Text = "Strength Gain  " .. NumberFormat.Multiplier(now.Strength) .. "  >  " .. NumberFormat.Multiplier(nextM.Strength)
		bonusLines.Coins.Text = "Coin Gain  " .. NumberFormat.Multiplier(now.Coins) .. "  >  " .. NumberFormat.Multiplier(nextM.Coins)
		bonusLines.Kick.Text = "Kick Power  " .. NumberFormat.Multiplier(now.Kick) .. "  >  " .. NumberFormat.Multiplier(nextM.Kick)
		local needStrength = RebirthConfig.StrengthRequired(r)
		local needCoins = RebirthConfig.CoinCost(r)
		strengthBar:Set(data.Strength / needStrength, "Strength " .. NumberFormat.Abbreviate(data.Strength) .. " / " .. NumberFormat.Abbreviate(needStrength))
		coinsBar:Set(data.Coins / needCoins, "Coins " .. NumberFormat.Abbreviate(data.Coins) .. " / " .. NumberFormat.Abbreviate(needCoins))
		local can = data.Strength >= needStrength and data.Coins >= needCoins
		UI.setButtonColor(rebirthButton, if can then T.Purple else T.Gray)
		for i, m in RebirthConfig.Milestones do
			milestoneRows[i].Color = if r >= m.Rebirths then T.Green else T.Gray
		end
	end
	return panel
end
