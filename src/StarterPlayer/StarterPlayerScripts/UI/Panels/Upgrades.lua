-- Painel Upgrades: Kick Power, Strength Gain, Coin Gain, Walk Speed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local NumberFormat = require(Modules.NumberFormat)
local UpgradeConfig = require(Modules.UpgradeConfig)

return function(ctx)
	local UI = ctx.UI
	local T = UI.Theme
	local window, content = ctx.UIController:CreateWindow("Upgrades", "UPGRADES", "Upgrades", Color3.fromRGB(80, 170, 255), Vector2.new(720, 440))

	local list = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content })
	UI.list(list, true, 10)

	local function formatValue(id: string, value: number): string
		if UpgradeConfig.Get(id).Format == "Speed" then
			return string.format("%.1f", value)
		end
		return NumberFormat.Multiplier(value)
	end

	local rows = {}
	for i, id in UpgradeConfig.Order do
		local def = UpgradeConfig.Get(id)
		local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0.25, -8), BackgroundColor3 = T.PanelLight, LayoutOrder = i, Parent = list })
		UI.corner(row, 14)
		local icon = UI.icon(def.Icon, 52)
		icon.Position = UDim2.new(0, 12, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Parent = row
		UI.label({
			Text = def.Name,
			Size = UDim2.new(0.45, 0, 0.45, 0),
			Position = UDim2.new(0, 76, 0.08, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 26,
			Parent = row,
		})
		local effect = UI.label({
			Text = "",
			Size = UDim2.new(0.45, 0, 0.36, 0),
			Position = UDim2.new(0, 76, 0.55, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.SubText,
			MaxTextSize = 20,
			Parent = row,
		})
		local level = UI.label({
			Text = "",
			Size = UDim2.new(0.14, 0, 0.5, 0),
			Position = UDim2.new(0.6, 0, 0.25, 0),
			TextColor3 = T.Gold,
			MaxTextSize = 22,
			Parent = row,
		})
		local buy = UI.button({
			Text = "",
			Icon = "Coins",
			Color = T.Green,
			Size = UDim2.new(0.24, 0, 0.72, 0),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextSize = 24,
			Parent = row,
			OnClick = function()
				local ok = ctx.UIController:Invoke("BuyUpgrade", id)
				if ok then
					ctx.Controllers.SoundController:Play("Coins", 0.1)
					UI.pop(row, 1.04)
				end
			end,
		})
		rows[id] = { Effect = effect, Level = level, Buy = buy }
	end

	local panel = { Window = window }
	function panel:Refresh(data)
		for id, row in rows do
			local def = UpgradeConfig.Get(id)
			local lvl = data.Upgrades[id] or 0
			row.Level.Text = "Lv " .. lvl .. "/" .. def.MaxLevel
			local current = UpgradeConfig.Value(id, lvl)
			if lvl >= def.MaxLevel then
				row.Effect.Text = def.Description .. "  " .. formatValue(id, current)
				UI.setButtonText(row.Buy, "MAX")
				UI.setButtonColor(row.Buy, T.Gray)
			else
				local nextValue = UpgradeConfig.Value(id, lvl + 1)
				row.Effect.Text = formatValue(id, current) .. "  >  " .. formatValue(id, nextValue)
				local cost = UpgradeConfig.Cost(id, lvl)
				UI.setButtonText(row.Buy, NumberFormat.Abbreviate(cost))
				UI.setButtonColor(row.Buy, if data.Coins >= cost then T.Green else T.Gray)
			end
		end
	end
	return panel
end
