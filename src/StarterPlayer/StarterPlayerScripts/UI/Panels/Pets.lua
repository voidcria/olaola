-- Painel Pets: inventário com cards, filtros por raridade, equipar, bloquear, excluir e Equip Best.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local NumberFormat = require(Modules.NumberFormat)
local PetConfig = require(Modules.PetConfig)
local RarityConfig = require(Modules.RarityConfig)
local Formulas = require(Modules.Formulas)
local Config = require(Modules.Config)
local PetModels = require(Modules.Models.PetModels)

return function(ctx)
	local UI = ctx.UI
	local T = UI.Theme
	local window, content = ctx.UIController:CreateWindow("Pets", "PETS", "Pets", Color3.fromRGB(255, 130, 170), Vector2.new(860, 500))

	local filter = "All"
	local selectedId: string? = nil
	local currentData = nil

	-- Barra superior
	local top = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = content })
	local countLabel = UI.label({ Text = "", Size = UDim2.new(0.34, 0, 1, -8), Position = UDim2.fromOffset(0, 4), TextXAlignment = Enum.TextXAlignment.Left, MaxTextSize = 24, Parent = top })
	UI.button({
		Text = "Equip Best",
		Color = T.Green,
		Size = UDim2.fromOffset(150, 42),
		Position = UDim2.new(1, -160, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = 22,
		Parent = top,
		OnClick = function()
			if ctx.UIController:Invoke("PetAction", "EquipBest") then
				ctx.UIController:Toast("Best pets equipped!", "Success")
			end
		end,
	})
	UI.button({
		Text = "Unequip All",
		Color = T.Gray,
		Size = UDim2.fromOffset(150, 42),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = 20,
		Parent = top,
		OnClick = function()
			ctx.UIController:Invoke("PetAction", "UnequipAll")
		end,
	})

	-- Filtros
	local filters = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 50), BackgroundTransparency = 1, Parent = content })
	UI.list(filters, false, 6)
	local filterButtons = {}
	local filterNames = { "All" }
	for _, r in RarityConfig.Order do
		table.insert(filterNames, r)
	end

	-- Grade de cards (esquerda)
	local scroll = UI.new("ScrollingFrame", {
		Size = UDim2.new(1, -250, 1, -94),
		Position = UDim2.fromOffset(0, 94),
		BackgroundColor3 = T.PanelDark,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = content,
	})
	UI.corner(scroll, 14)
	UI.padding(scroll, 8)
	UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(102, 124),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	local emptyLabel = UI.label({
		Text = "No pets yet! Hatch eggs at the Hatchery.",
		Size = UDim2.new(1, -250, 0, 40),
		Position = UDim2.fromOffset(0, 200),
		TextColor3 = T.SubText,
		MaxTextSize = 22,
		Visible = false,
		Parent = content,
	})

	-- Detalhes (direita)
	local detail = UI.new("Frame", { Size = UDim2.new(0, 238, 1, -94), Position = UDim2.new(1, 0, 0, 94), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = T.PanelLight, Parent = content })
	UI.corner(detail, 14)
	local detailStroke = UI.stroke(detail, T.Gray, 3)
	local detailView = UI.viewport(nil)
	detailView.Size = UDim2.new(1, -20, 0, 120)
	detailView.Position = UDim2.fromOffset(10, 6)
	detailView.Parent = detail
	local detailName = UI.label({ Text = "Select a pet", Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 128), MaxTextSize = 24, Parent = detail })
	local detailRarity = UI.label({ Text = "", Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 156), MaxTextSize = 18, Parent = detail })
	local detailStats = UI.label({
		Text = "",
		Size = UDim2.new(1, -20, 0, 70),
		Position = UDim2.fromOffset(10, 180),
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = T.Font,
		MaxTextSize = 19,
		TextWrapped = true,
		Parent = detail,
	})
	local function actionButton(text: string, color: Color3, y: number, onClick)
		return UI.button({
			Text = text,
			Color = color,
			Size = UDim2.new(1, -20, 0, 34),
			Position = UDim2.new(0.5, 0, 1, y),
			AnchorPoint = Vector2.new(0.5, 1),
			TextSize = 20,
			Parent = detail,
			OnClick = onClick,
		})
	end
	local deleteArmed = false
	local equipButton = actionButton("Equip", T.Green, -88, function()
		if not selectedId or not currentData then
			return
		end
		local action = if table.find(currentData.Equipped, selectedId) then "Unequip" else "Equip"
		ctx.UIController:Invoke("PetAction", action, selectedId)
	end)
	local lockButton = actionButton("Lock", T.Blue, -48, function()
		if selectedId then
			ctx.UIController:Invoke("PetAction", "Lock", selectedId)
		end
	end)
	local deleteButton
	deleteButton = actionButton("Delete", T.Red, -8, function()
		if not selectedId then
			return
		end
		if not deleteArmed then
			deleteArmed = true
			UI.setButtonText(deleteButton, "Confirm?")
			task.delay(2.5, function()
				deleteArmed = false
				UI.setButtonText(deleteButton, "Delete")
			end)
			return
		end
		deleteArmed = false
		UI.setButtonText(deleteButton, "Delete")
		local ok = ctx.UIController:Invoke("PetAction", "Delete", selectedId)
		if ok then
			selectedId = nil
		end
	end)

	local cards: { [string]: any } = {}

	local function setDetail(data)
		local owned = selectedId and data.Pets[selectedId]
		local visible = owned ~= nil
		equipButton.Visible = visible
		lockButton.Visible = visible
		deleteButton.Visible = visible
		if not owned then
			detailName.Text = "Select a pet"
			detailRarity.Text = ""
			detailStats.Text = ""
			detailStroke.Color = T.Gray
			for _, c in detailView:GetChildren() do
				c:Destroy()
			end
			detailView:SetAttribute("Pet", nil)
			return
		end
		local pet = PetConfig.Get(owned.N)
		local color = UI.rarityColor(pet.Rarity)
		detailStroke.Color = color
		detailName.Text = owned.N
		detailRarity.Text = string.upper(pet.Rarity)
		detailRarity.TextColor3 = color
		detailStats.Text = string.format(
			"Coins %s\nStrength %s\nKick Power %s",
			NumberFormat.Multiplier(pet.Coins),
			NumberFormat.Multiplier(pet.Strength),
			NumberFormat.Multiplier(pet.Kick)
		)
		if detailView:GetAttribute("Pet") ~= owned.N then
			detailView:SetAttribute("Pet", owned.N)
			UI.setViewportModel(detailView, PetModels.Build(owned.N))
		end
		local equipped = table.find(data.Equipped, selectedId) ~= nil
		UI.setButtonText(equipButton, if equipped then "Unequip" else "Equip")
		UI.setButtonColor(equipButton, if equipped then T.Orange else T.Green)
		UI.setButtonText(lockButton, if owned.L then "Unlock" else "Lock")
		deleteButton.Visible = not owned.L
	end

	local function makeCard(petId: string, petName: string)
		local pet = PetConfig.Get(petName)
		local color = UI.rarityColor(pet.Rarity)
		local card = UI.new("TextButton", { BackgroundColor3 = T.PanelLight, AutoButtonColor = false, Text = "", Parent = scroll })
		UI.corner(card, 12)
		local stroke = UI.stroke(card, color, 2.5)
		if pet.Rarity == "Secret" then
			local g = UI.rainbow(stroke)
			g.Rotation = 45
		end
		local view
		if pet.Icon ~= "" then
			view = UI.new("ImageLabel", { BackgroundTransparency = 1, Image = pet.Icon, ScaleType = Enum.ScaleType.Fit })
		else
			view = UI.viewport(PetModels.Build(petName))
		end
		view.Size = UDim2.new(1, -12, 0, 66)
		view.Position = UDim2.fromOffset(6, 4)
		view.Parent = card
		UI.label({ Text = petName, Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 70), MaxTextSize = 16, Parent = card })
		UI.label({ Text = NumberFormat.Multiplier(pet.Coins), Size = UDim2.new(1, -8, 0, 22), Position = UDim2.fromOffset(4, 92), TextColor3 = T.Gold, MaxTextSize = 19, Parent = card })
		local equippedBadge = UI.new("Frame", { Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = T.Green, Visible = false, Parent = card })
		UI.corner(equippedBadge, UDim.new(1, 0))
		UI.stroke(equippedBadge, Color3.fromRGB(20, 90, 40), 2)
		UI.label({ Text = "E", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = equippedBadge })
		local lockBadge = UI.icon("Lock", 22)
		lockBadge.Position = UDim2.new(1, -26, 0, 4)
		lockBadge.Visible = false
		lockBadge.Parent = card
		UI.interactive(card, function()
			selectedId = petId
			deleteArmed = false
			if currentData then
				setDetail(currentData)
			end
		end)
		return { Card = card, Equipped = equippedBadge, Lock = lockBadge, Stroke = stroke, Name = petName }
	end

	for i, name in filterNames do
		local color = if name == "All" then T.Blue else UI.rarityColor(name)
		local b = UI.new("TextButton", { Size = UDim2.fromOffset(if name == "Legendary" then 108 else 88, 32), BackgroundColor3 = color, AutoButtonColor = false, Text = "", LayoutOrder = i, Parent = filters })
		UI.corner(b, UDim.new(1, 0))
		local stroke = UI.stroke(b, Color3.new(1, 1, 1), 0)
		if name == "Secret" then
			UI.rainbow(b)
		end
		UI.label({ Text = name, Size = UDim2.new(1, -10, 1, -8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), MaxTextSize = 17, Parent = b })
		UI.interactive(b, function()
			filter = name
			if currentData then
				ctx.UIController.Panels.Pets:Refresh(currentData)
			end
		end)
		filterButtons[name] = stroke
	end

	local panel = { Window = window }
	function panel:Refresh(data)
		currentData = data
		local total = Formulas.PetCount(data)
		countLabel.Text = string.format("%d/%d Pets   |   %d/%d Equipped", total, Config.Pets.MaxInventory, #data.Equipped, Formulas.MaxEquipped(data))
		for name, stroke in filterButtons do
			stroke.Thickness = if name == filter then 3 else 0
		end

		-- Remove cards de pets que não existem mais
		for petId, card in cards do
			if not data.Pets[petId] then
				card.Card:Destroy()
				cards[petId] = nil
			end
		end
		-- Ordena: equipados primeiro, depois raridade/força
		local ids = {}
		for petId in data.Pets do
			table.insert(ids, petId)
		end
		table.sort(ids, function(a, b)
			local ea = table.find(data.Equipped, a) ~= nil
			local eb = table.find(data.Equipped, b) ~= nil
			if ea ~= eb then
				return ea
			end
			local sa, sb = PetConfig.Score(data.Pets[a].N), PetConfig.Score(data.Pets[b].N)
			if sa ~= sb then
				return sa > sb
			end
			return a < b
		end)
		local shown = 0
		for order, petId in ids do
			local owned = data.Pets[petId]
			local card = cards[petId]
			if not card then
				card = makeCard(petId, owned.N)
				cards[petId] = card
			end
			local pet = PetConfig.Get(owned.N)
			local visible = filter == "All" or pet.Rarity == filter
			card.Card.Visible = visible
			card.Card.LayoutOrder = order
			card.Equipped.Visible = table.find(data.Equipped, petId) ~= nil
			card.Lock.Visible = owned.L == true
			card.Card.BackgroundColor3 = if petId == selectedId then T.PanelLight:Lerp(Color3.new(1, 1, 1), 0.2) else T.PanelLight
			if visible then
				shown += 1
			end
		end
		emptyLabel.Visible = shown == 0
		emptyLabel.Text = if total == 0 then "No pets yet! Hatch eggs at the Hatchery." else "No " .. filter .. " pets"
		setDetail(data)
	end

	return panel
end
