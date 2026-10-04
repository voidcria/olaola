-- Painel Weight Shop (aberto pela barraca): comprar e equipar pesos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local NumberFormat = require(Modules.NumberFormat)
local Formulas = require(Modules.Formulas)
local WeightConfig = require(Modules.WeightConfig)
local WeightModels = require(Modules.Models.WeightModels)

return function(ctx)
	local UI = ctx.UI
	local T = UI.Theme
	local window, content = ctx.UIController:CreateWindow("Weights", "WEIGHT SHOP", "Strength", Color3.fromRGB(255, 140, 60), Vector2.new(820, 500))

	UI.label({
		Text = "Hold your weight and click (or tap TRAIN) to lift. Better weights = more Strength per lift!",
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = T.SubText,
		Font = T.BodyFont,
		NoStroke = true,
		MaxTextSize = 17,
		Parent = content,
	})

	local grid = UI.new("Frame", { Size = UDim2.new(1, 0, 1, -32), Position = UDim2.fromOffset(0, 32), BackgroundTransparency = 1, Parent = content })
	UI.new("UIGridLayout", {
		CellSize = UDim2.new(0.25, -9, 0.5, -6),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local cards = {}
	for i, id in WeightConfig.Order do
		local weight = WeightConfig.Get(id)
		local color = UI.rarityColor(weight.Rarity)
		local card = UI.new("Frame", { BackgroundColor3 = T.PanelLight, LayoutOrder = i, Parent = grid })
		UI.corner(card, 14)
		local stroke = UI.stroke(card, color, 2.5)
		if weight.Rarity == "Secret" then
			UI.rainbow(stroke)
		end
		local view
		if weight.Icon ~= "" then
			view = UI.new("ImageLabel", { BackgroundTransparency = 1, Image = weight.Icon, ScaleType = Enum.ScaleType.Fit })
		else
			view = UI.viewport(WeightModels.Build(id))
		end
		view.Size = UDim2.new(1, -16, 0.38, 0)
		view.Position = UDim2.new(0, 8, 0, 4)
		view.Parent = card
		UI.label({ Text = weight.Name, Size = UDim2.new(1, -10, 0.13, 0), Position = UDim2.new(0, 5, 0.4, 0), MaxTextSize = 20, Parent = card })
		UI.label({
			Text = "+" .. NumberFormat.Abbreviate(weight.Gain) .. " Strength",
			Size = UDim2.new(1, -10, 0.12, 0),
			Position = UDim2.new(0, 5, 0.54, 0),
			TextColor3 = T.Strength:Lerp(Color3.new(1, 1, 1), 0.3),
			MaxTextSize = 18,
			Parent = card,
		})
		local req = UI.label({
			Text = "",
			Size = UDim2.new(1, -10, 0.1, 0),
			Position = UDim2.new(0, 5, 0.66, 0),
			TextColor3 = T.SubText,
			Font = T.BodyFont,
			NoStroke = true,
			MaxTextSize = 14,
			Parent = card,
		})
		local button = UI.button({
			Text = "",
			Color = T.Green,
			Size = UDim2.new(1, -16, 0.2, 0),
			Position = UDim2.new(0.5, 0, 1, -8),
			AnchorPoint = Vector2.new(0.5, 1),
			TextSize = 20,
			Parent = card,
			OnClick = function()
				local data = ctx.Controllers.DataController:Get()
				if not data then
					return
				end
				if data.OwnedWeights[id] then
					if data.EquippedWeight ~= id then
						ctx.UIController:Invoke("EquipWeight", id)
					end
				else
					local ok = ctx.UIController:Invoke("BuyWeight", id)
					if ok then
						ctx.Controllers.SoundController:Play("Reveal")
						ctx.Controllers.EffectsController:Banner("NEW WEIGHT!", weight.Name, color, "Strength", 2)
						UI.pop(card, 1.1)
					end
				end
			end,
		})
		cards[id] = { Button = button, Req = req, Card = card }
	end

	local panel = { Window = window }
	function panel:Refresh(data)
		local nextId = Formulas.NextWeight(data)
		for id, card in cards do
			local weight = WeightConfig.Get(id)
			local owned = data.OwnedWeights[id] == true
			if owned then
				card.Req.Text = "Owned"
				if data.EquippedWeight == id then
					UI.setButtonText(card.Button, "EQUIPPED")
					UI.setButtonColor(card.Button, T.Blue)
				else
					UI.setButtonText(card.Button, "EQUIP")
					UI.setButtonColor(card.Button, T.Green)
				end
			elseif data.Rebirths < weight.RebirthsRequired then
				card.Req.Text = "Needs " .. weight.RebirthsRequired .. " Rebirth" .. (if weight.RebirthsRequired > 1 then "s" else "")
				UI.setButtonText(card.Button, "LOCKED")
				UI.setButtonColor(card.Button, T.Gray)
			else
				card.Req.Text = if id == nextId then "Next upgrade!" else ""
				UI.setButtonText(card.Button, NumberFormat.Abbreviate(weight.Cost) .. " Coins")
				UI.setButtonColor(card.Button, if data.Coins >= weight.Cost then T.Green else T.Gray)
			end
			card.Card.BackgroundColor3 = if owned then T.PanelLight else T.PanelDark
		end
	end
	return panel
end
