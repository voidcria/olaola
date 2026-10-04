-- Painel Stats: estatísticas detalhadas (fora do HUD principal).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local NumberFormat = require(Modules.NumberFormat)
local Formulas = require(Modules.Formulas)

return function(ctx)
	local UI = ctx.UI
	local T = UI.Theme
	local window, content = ctx.UIController:CreateWindow("Stats", "STATS", "Stats", Color3.fromRGB(90, 200, 150), Vector2.new(640, 430))

	local grid = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = content })
	UI.new("UIGridLayout", {
		CellSize = UDim2.new(0.5, -6, 0.25, -8),
		CellPadding = UDim2.fromOffset(12, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local rows = {}
	local defs = {
		{ Key = "BestKick", Name = "Best Kick", Icon = "Trophy", Color = T.Gold },
		{ Key = "TotalDistance", Name = "Total Distance", Icon = "Areas", Color = T.Orange },
		{ Key = "TotalKicks", Name = "Total Kicks", Icon = "Kick", Color = T.Orange },
		{ Key = "Strength", Name = "Strength", Icon = "Strength", Color = T.Strength },
		{ Key = "Coins", Name = "Coins", Icon = "Coins", Color = T.Gold },
		{ Key = "Rebirths", Name = "Rebirths", Icon = "Rebirth", Color = T.Purple },
		{ Key = "Pets", Name = "Pets Discovered", Icon = "Pets", Color = Color3.fromRGB(255, 130, 170) },
		{ Key = "Playtime", Name = "Playtime", Icon = "Stats", Color = T.Blue },
	}
	for i, def in defs do
		local tile = UI.new("Frame", { BackgroundColor3 = T.PanelLight, LayoutOrder = i, Parent = grid })
		UI.corner(tile, 12)
		UI.stroke(tile, def.Color, 2, 0.3)
		local icon = UI.icon(def.Icon, 40)
		icon.Position = UDim2.new(0, 10, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Parent = tile
		UI.label({
			Text = def.Name,
			Size = UDim2.new(1, -66, 0.42, 0),
			Position = UDim2.new(0, 58, 0.1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = T.SubText,
			MaxTextSize = 18,
			Parent = tile,
		})
		rows[def.Key] = UI.label({
			Text = "-",
			Size = UDim2.new(1, -66, 0.46, 0),
			Position = UDim2.new(0, 58, 0.48, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			MaxTextSize = 26,
			Parent = tile,
		})
	end

	local panel = { Window = window }
	local open = false

	function panel:Refresh(data)
		rows.BestKick.Text = NumberFormat.Distance(data.BestDistance)
		rows.TotalDistance.Text = NumberFormat.Distance(data.TotalDistance)
		rows.TotalKicks.Text = NumberFormat.Commas(data.TotalKicks)
		rows.Strength.Text = NumberFormat.Abbreviate(data.Strength)
		rows.Coins.Text = NumberFormat.Abbreviate(data.Coins)
		rows.Rebirths.Text = NumberFormat.Abbreviate(data.Rebirths)
		rows.Pets.Text = Formulas.DiscoveredCount(data) .. " / " .. Formulas.TotalPetTypes()
		rows.Playtime.Text = NumberFormat.Time(ctx.Controllers.DataController:GetPlaytime())
	end

	function panel:OnOpen()
		if open then
			return
		end
		open = true
		task.spawn(function()
			while open do
				rows.Playtime.Text = NumberFormat.Time(ctx.Controllers.DataController:GetPlaytime())
				task.wait(1)
			end
		end)
	end

	function panel:OnClose()
		open = false
	end

	return panel
end
