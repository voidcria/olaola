-- Painel Hatchery: escolher um ovo, ver as chances e chocar (roleta).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local NumberFormat = require(Modules.NumberFormat)
local Formulas = require(Modules.Formulas)
local EggConfig = require(Modules.EggConfig)
local PetConfig = require(Modules.PetConfig)
local EggModels = require(Modules.Models.EggModels)
local PetModels = require(Modules.Models.PetModels)

return function(ctx)
	local UI = ctx.UI
	local T = UI.Theme
	local window, content = ctx.UIController:CreateWindow("Hatchery", "EGGS", "Eggs", Color3.fromRGB(255, 196, 64), Vector2.new(820, 480), {
		{ Id = "EggShop", Text = "Kick Eggs" },
		{ Id = "Hatchery", Text = "Hatch Pets" },
	})

	local selected = "Basic"
	local busy = false

	-- Lista de ovos (esquerda)
	local eggList = UI.new("ScrollingFrame", {
		Size = UDim2.new(0, 200, 1, 0),
		BackgroundColor3 = T.PanelDark,
		ScrollBarThickness = 5,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	UI.corner(eggList, 14)
	UI.padding(eggList, 8)
	UI.list(eggList, true, 8)

	-- Detalhes (direita)
	local right = UI.new("Frame", { Size = UDim2.new(1, -214, 1, 0), Position = UDim2.fromOffset(214, 0), BackgroundTransparency = 1, Parent = content })
	local title = UI.label({ Text = "", Size = UDim2.new(0.6, 0, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 32, Parent = right })
	local hint = UI.label({
		Text = "",
		Size = UDim2.new(0.6, 0, 0, 20),
		Position = UDim2.fromOffset(0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = T.SubText,
		Font = T.BodyFont,
		NoStroke = true,
		MaxTextSize = 15,
		Parent = right,
	})

	local grid = UI.new("Frame", { Size = UDim2.new(1, 0, 1, -140), Position = UDim2.fromOffset(0, 64), BackgroundTransparency = 1, Parent = right })
	UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(110, 140),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local hatchButton
	hatchButton = UI.button({
		Text = "HATCH",
		Icon = "Coins",
		Color = T.Green,
		Size = UDim2.new(0.6, 0, 0, 60),
		Position = UDim2.new(0.5, 0, 1, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		TextSize = 30,
		Parent = right,
		OnClick = function()
			if busy then
				return
			end
			busy = true
			local ok, result = ctx.UIController:Invoke("HatchEgg", selected)
			if ok and type(result) == "table" then
				ctx.UIController:ClosePanel()
				ctx.Controllers.HatchController:Play(result)
				task.wait(1.5)
			end
			busy = false
		end,
	})

	local eggButtons = {}
	for i, id in EggConfig.Order do
		local egg = EggConfig.Get(id)
		local b = UI.new("TextButton", {
			Size = UDim2.new(1, 0, 0, 64),
			BackgroundColor3 = T.PanelLight,
			AutoButtonColor = false,
			Text = "",
			LayoutOrder = i,
			Parent = eggList,
		})
		UI.corner(b, 12)
		local stroke = UI.stroke(b, UI.rarityColor(egg.Rarity), 2)
		local view = UI.viewport(EggModels.Build(id))
		view.Size = UDim2.fromOffset(52, 52)
		view.Position = UDim2.new(0, 6, 0.5, 0)
		view.AnchorPoint = Vector2.new(0, 0.5)
		view.Parent = b
		UI.label({ Text = egg.Name, Size = UDim2.new(1, -66, 0.6, 0), Position = UDim2.new(0, 62, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 20, Parent = b })
		UI.interactive(b, function()
			selected = id
			local data = ctx.Controllers.DataController:Get()
			if data then
				ctx.UIController.Panels.Hatchery:Refresh(data)
			end
		end)
		eggButtons[id] = { Button = b, Stroke = stroke }
	end

	local panel = { Window = window }

	local function buildPetGrid(eggId: string, data)
		for _, child in grid:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local egg = EggConfig.Get(eggId)
		for i, entry in egg.Pets do
			local pet = PetConfig.Get(entry.Pet)
			local color = UI.rarityColor(pet.Rarity)
			local cell = UI.new("Frame", { BackgroundColor3 = T.PanelLight, LayoutOrder = i, Parent = grid })
			UI.corner(cell, 12)
			UI.stroke(cell, color, 2.5)
			local discovered = data.Discovered[entry.Pet] == true
			local view
			if pet.Icon ~= "" then
				view = UI.new("ImageLabel", { BackgroundTransparency = 1, Image = pet.Icon, ScaleType = Enum.ScaleType.Fit })
			else
				view = UI.viewport(PetModels.Build(entry.Pet))
			end
			view.Size = UDim2.new(1, -16, 0, 70)
			view.Position = UDim2.fromOffset(8, 4)
			if not discovered then
				if view:IsA("ViewportFrame") then
					view.ImageColor3 = Color3.fromRGB(20, 20, 30)
				else
					(view :: ImageLabel).ImageColor3 = Color3.fromRGB(20, 20, 30)
				end
			end
			view.Parent = cell
			UI.label({ Text = if discovered then entry.Pet else "???", Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 76), MaxTextSize = 17, Parent = cell })
			UI.label({ Text = string.upper(pet.Rarity), Size = UDim2.new(1, -8, 0, 16), Position = UDim2.fromOffset(4, 97), TextColor3 = color, MaxTextSize = 14, Parent = cell })
			UI.label({ Text = NumberFormat.Percent(entry.Chance), Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 115), TextColor3 = T.Gold, MaxTextSize = 18, Parent = cell })
		end
	end

	local lastBuilt = nil
	function panel:Refresh(data)
		local egg = EggConfig.Get(selected)
		local unlocked = data.UnlockedEggs[selected] == true
		title.Text = egg.Name
		hint.Text = if unlocked then "Pets give bonus Coins, Strength and Kick Power!" else "Unlock this egg at the Egg Shop first"
		UI.setButtonText(hatchButton, "HATCH  " .. NumberFormat.Abbreviate(egg.HatchCost))
		UI.setButtonColor(hatchButton, if unlocked and data.Coins >= egg.HatchCost then T.Green else T.Gray)
		for id, entry in eggButtons do
			entry.Button.BackgroundColor3 = if id == selected then T.PanelLight:Lerp(Color3.new(1, 1, 1), 0.15) else T.PanelLight
			entry.Stroke.Thickness = if id == selected then 4 else 2
			entry.Button.Visible = data.UnlockedEggs[id] == true or id == "Basic" or EggConfig.IndexOf(id) <= 2
		end
		-- Só reconstrói a grade quando muda o ovo ou a quantidade de pets descobertos
		local key = selected .. "|" .. Formulas.DiscoveredCount(data)
		if lastBuilt ~= key then
			lastBuilt = key
			buildPetGrid(selected, data)
		end
	end

	function panel:OnOpen()
		local data = ctx.Controllers.DataController:Get()
		if data then
			-- Abre no melhor ovo desbloqueado
			for _, id in EggConfig.Order do
				if data.UnlockedEggs[id] then
					selected = id
				end
			end
			lastBuilt = nil
			self:Refresh(data)
		end
	end

	return panel
end
