-- Painel Egg Shop: desbloquear e escolher qual ovo chutar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local NumberFormat = require(Modules.NumberFormat)
local EggConfig = require(Modules.EggConfig)
local EggModels = require(Modules.Models.EggModels)

return function(ctx)
	local UI = ctx.UI
	local T = UI.Theme
	local window, content = ctx.UIController:CreateWindow("EggShop", "EGGS", "Eggs", Color3.fromRGB(255, 196, 64), Vector2.new(820, 480), {
		{ Id = "EggShop", Text = "Kick Eggs" },
		{ Id = "Hatchery", Text = "Hatch Pets" },
	})

	UI.label({
		Text = "Better eggs give more coins per meter. Choose which egg you kick!",
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = T.SubText,
		Font = T.BodyFont,
		NoStroke = true,
		MaxTextSize = 17,
		Parent = content,
	})

	local scroll = UI.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -32),
		Position = UDim2.fromOffset(0, 32),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	UI.list(scroll, false, 12)

	local cards = {}
	for i, id in EggConfig.Order do
		local egg = EggConfig.Get(id)
		local rarityColor = UI.rarityColor(egg.Rarity)
		local card = UI.new("Frame", { Size = UDim2.new(0, 186, 1, -14), BackgroundColor3 = T.PanelLight, LayoutOrder = i, Parent = scroll })
		UI.corner(card, 16)
		local stroke = UI.stroke(card, rarityColor, 3)

		local view
		if egg.Icon ~= "" then
			view = UI.new("ImageLabel", { BackgroundTransparency = 1, Image = egg.Icon, ScaleType = Enum.ScaleType.Fit })
		else
			view = UI.viewport(EggModels.Build(id))
		end
		view.Size = UDim2.new(1, -30, 0, 130)
		view.Position = UDim2.fromOffset(15, 8)
		view.Parent = card

		UI.label({ Text = egg.Name, Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 140), MaxTextSize = 24, Parent = card })
		local chip = UI.new("Frame", { Size = UDim2.new(0.7, 0, 0, 22), Position = UDim2.new(0.5, 0, 0, 170), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = rarityColor, Parent = card })
		UI.corner(chip, UDim.new(1, 0))
		if egg.Rarity == "Secret" then
			UI.rainbow(chip)
		end
		UI.label({ Text = string.upper(egg.Rarity), Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = chip })
		UI.label({
			Text = NumberFormat.Multiplier(egg.CoinMultiplier) .. " Coins",
			Size = UDim2.new(1, -16, 0, 24),
			Position = UDim2.fromOffset(8, 198),
			TextColor3 = T.Gold,
			MaxTextSize = 22,
			Parent = card,
		})
		local req = UI.label({
			Text = "",
			Size = UDim2.new(1, -16, 0, 34),
			Position = UDim2.fromOffset(8, 224),
			TextColor3 = T.SubText,
			Font = T.BodyFont,
			TextWrapped = true,
			NoStroke = true,
			MaxTextSize = 15,
			Parent = card,
		})
		local button = UI.button({
			Text = "",
			Color = T.Green,
			Size = UDim2.new(1, -20, 0, 46),
			Position = UDim2.new(0.5, 0, 1, -10),
			AnchorPoint = Vector2.new(0.5, 1),
			TextSize = 22,
			Parent = card,
			OnClick = function()
				local data = ctx.Controllers.DataController:Get()
				if not data then
					return
				end
				if data.UnlockedEggs[id] then
					local ok = ctx.UIController:Invoke("SelectEgg", id)
					if ok then
						ctx.UIController:Toast(egg.Name .. " selected!", "Success")
					end
				else
					local ok = ctx.UIController:Invoke("UnlockEgg", id)
					if ok then
						ctx.Controllers.SoundController:Play("Reveal")
						UI.pop(card, 1.1)
					end
				end
			end,
		})
		cards[id] = { Stroke = stroke, Req = req, Button = button, Card = card, Color = rarityColor }
	end

	local panel = { Window = window }
	function panel:Refresh(data)
		for id, card in cards do
			local egg = EggConfig.Get(id)
			local unlocked = data.UnlockedEggs[id] == true
			local parts = {}
			if egg.StrengthRequired > 0 then
				table.insert(parts, NumberFormat.Abbreviate(egg.StrengthRequired) .. " Strength")
			end
			if egg.RebirthsRequired > 0 then
				table.insert(parts, egg.RebirthsRequired .. " Rebirths")
			end
			card.Req.Text = if #parts > 0 then "Needs " .. table.concat(parts, " + ") else "Starter egg"
			if unlocked then
				if data.SelectedEgg == id then
					UI.setButtonText(card.Button, "SELECTED")
					UI.setButtonColor(card.Button, T.Blue)
				elseif data.Strength < egg.StrengthRequired then
					UI.setButtonText(card.Button, "TOO HEAVY")
					UI.setButtonColor(card.Button, T.Gray)
				else
					UI.setButtonText(card.Button, "SELECT")
					UI.setButtonColor(card.Button, T.Green)
				end
			else
				local can = data.Strength >= egg.StrengthRequired and data.Rebirths >= egg.RebirthsRequired and data.Coins >= egg.UnlockCost
				UI.setButtonText(card.Button, NumberFormat.Abbreviate(egg.UnlockCost) .. " Coins")
				UI.setButtonColor(card.Button, if can then T.Green else T.Gray)
			end
			card.Card.BackgroundColor3 = if unlocked then T.PanelLight else T.PanelDark
		end
	end
	return panel
end
