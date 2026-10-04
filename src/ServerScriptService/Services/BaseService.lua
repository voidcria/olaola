-- BaseService: cada jogador recebe uma base (como no jogo de referência) com pedestais
-- para colocar pets. Pets na base geram moedas por segundo; pise no botão (pad) para coletar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local BaseConfig = require(Modules.BaseConfig)
local PetConfig = require(Modules.PetConfig)
local RarityConfig = require(Modules.RarityConfig)
local Formulas = require(Modules.Formulas)
local NumberFormat = require(Modules.NumberFormat)
local Remotes = require(Modules.Remotes)
local PetModels = require(Modules.Models.PetModels)

local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local Notify = require(ServerScriptService.Util.Notify)

local BaseService = {}

type Base = {
	Model: Model,
	Id: number,
	Owner: Player?,
	Slots: { [number]: Model },
	PetModels: { [number]: Model },
}

local bases: { Base } = {}
local baseOf: { [Player]: Base } = {}
local limiter = RateLimiter.new(4, 4)
local collectedEvent: RemoteEvent
local padDebounce: { [Instance]: number } = {}

local LOCKED_COLOR = Color3.fromRGB(120, 120, 135)
local PAD_COLOR = Color3.fromRGB(90, 210, 90)

local function slotKey(slot: number): string
	return tostring(slot)
end

local function setTexts(slotModel: Model, title: string, rate: string, stored: string, titleColor: Color3?)
	local gui = slotModel:FindFirstChild("Info", true)
	if not gui then
		return
	end
	local t = gui:FindFirstChild("Title") :: TextLabel?
	local r = gui:FindFirstChild("Rate") :: TextLabel?
	local s = gui:FindFirstChild("Stored") :: TextLabel?
	if t then
		t.Text = title
		t.TextColor3 = titleColor or Color3.new(1, 1, 1)
	end
	if r then
		r.Text = rate
	end
	if s then
		s.Text = stored
	end
end

local function setPrompt(slotModel: Model, action: string, object: string)
	local prompt = slotModel:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		prompt.ActionText = action
		prompt.ObjectText = object
	end
end

local function clearPetModel(base: Base, slot: number)
	local m = base.PetModels[slot]
	if m then
		m:Destroy()
		base.PetModels[slot] = nil
	end
end

-- Atualiza o visual de um slot conforme os dados do dono
function BaseService:RenderSlot(base: Base, slot: number)
	local slotModel = base.Slots[slot]
	if not slotModel then
		return
	end
	clearPetModel(base, slot)
	local pedestal = slotModel:FindFirstChild("Pedestal") :: BasePart?
	local pad = slotModel:FindFirstChild("Pad") :: BasePart?
	local owner = base.Owner
	local data = owner and DataService:Get(owner)

	if not data then
		slotModel:SetAttribute("State", "Free")
		slotModel:SetAttribute("Stored", 0)
		setTexts(slotModel, "", "", "")
		setPrompt(slotModel, "", "")
		if pedestal then
			pedestal.Color = Color3.fromRGB(235, 235, 245)
		end
		if pad then
			pad.Color = LOCKED_COLOR
		end
		return
	end

	if slot > data.Base.Unlocked then
		local cost = BaseConfig.SlotCosts[slot] or 0
		local isNext = slot == data.Base.Unlocked + 1
		slotModel:SetAttribute("State", "Locked")
		slotModel:SetAttribute("Cost", cost)
		setTexts(slotModel, "LOCKED", if isNext then NumberFormat.Abbreviate(cost) .. " Coins" else "Unlock previous slot", "", Color3.fromRGB(255, 200, 90))
		setPrompt(slotModel, if isNext then "Unlock Slot" else "Locked", NumberFormat.Abbreviate(cost) .. " Coins")
		if pedestal then
			pedestal.Color = LOCKED_COLOR
		end
		if pad then
			pad.Color = LOCKED_COLOR
		end
		return
	end

	if pedestal then
		pedestal.Color = Color3.fromRGB(245, 245, 250)
	end
	if pad then
		pad.Color = PAD_COLOR
	end

	local entry = data.Base.Slots[slotKey(slot)]
	local owned = entry and data.Pets[entry.Pet]
	if not owned then
		slotModel:SetAttribute("State", "Empty")
		slotModel:SetAttribute("Stored", 0)
		setTexts(slotModel, "Empty Slot", "Place a pet here!", "")
		setPrompt(slotModel, "Place Pet", "Slot " .. slot)
		return
	end

	local pet = PetConfig.Get(owned.N)
	local rarity = RarityConfig.Get(pet.Rarity).Color
	local rarityColor = Color3.fromRGB(rarity[1], rarity[2], rarity[3])
	slotModel:SetAttribute("State", "Pet")
	slotModel:SetAttribute("Stored", math.floor(entry.Stored))
	setTexts(slotModel, owned.N, "+" .. NumberFormat.Abbreviate(Formulas.PetIncome(data, owned.N)) .. "/s", "$" .. NumberFormat.Abbreviate(entry.Stored), rarityColor)
	setPrompt(slotModel, "Pick Up", owned.N)

	-- Modelo do pet em cima do pedestal, olhando para a entrada
	local anchor = slotModel:FindFirstChild("Anchor") :: BasePart?
	if anchor then
		local model = PetModels.Build(owned.N)
		model:ScaleTo(1.5)
		model:PivotTo(anchor.CFrame * CFrame.new(0, 1.6, 0))
		model.Name = "PetModel"
		model.Parent = slotModel
		base.PetModels[slot] = model
	end
end

function BaseService:RenderBase(base: Base)
	local sign = base.Model:FindFirstChild("Sign", true)
	local owner = base.Owner
	local data = owner and DataService:Get(owner)
	if sign then
		local ownerLabel = sign:FindFirstChild("Owner", true) :: TextLabel?
		local incomeLabel = sign:FindFirstChild("Income", true) :: TextLabel?
		if ownerLabel then
			ownerLabel.Text = if owner then owner.DisplayName .. "'s Base" else "FREE BASE"
		end
		if incomeLabel then
			incomeLabel.Text = if data then "+" .. NumberFormat.Abbreviate(Formulas.BaseIncome(data)) .. " Coins/s" else ""
		end
	end
	for slot = 1, BaseConfig.SlotCount do
		self:RenderSlot(base, slot)
	end
end

function BaseService:GetBase(player: Player)
	return baseOf[player]
end

local function nearBase(player: Player, base: Base): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local center = base.Model:GetPivot().Position
	local d = root.Position - center
	return Vector3.new(d.X, 0, d.Z).Magnitude < 60 and math.abs(d.Y) < 30
end

local function teleportToBase(player: Player)
	local base = baseOf[player]
	local character = player.Character
	local spawnPart = base and base.Model:FindFirstChild("SpawnPoint") :: BasePart?
	if character and spawnPart then
		character:PivotTo(spawnPart.CFrame * CFrame.new(0, 4, 0))
	end
end

local function collect(player: Player, base: Base, slot: number): number
	local data = DataService:Get(player)
	local entry = data and data.Base.Slots[slotKey(slot)]
	if not entry then
		return 0
	end
	local amount = math.floor(entry.Stored)
	if amount < 1 then
		return 0
	end
	entry.Stored -= amount
	data.Coins += amount
	data.TotalCoinsEarned += amount
	data.TotalBaseCollected += amount
	DataService:MarkDirty(player)
	collectedEvent:FireClient(player, amount, slot)
	local slotModel = base.Slots[slot]
	slotModel:SetAttribute("Stored", 0)
	local gui = slotModel:FindFirstChild("Info", true)
	local label = gui and gui:FindFirstChild("Stored") :: TextLabel?
	if label then
		label.Text = "$0"
	end
	return amount
end

local function assign(player: Player)
	if baseOf[player] then
		return
	end
	for _, base in bases do
		if not base.Owner then
			base.Owner = player
			baseOf[player] = base
			base.Model:SetAttribute("OwnerId", player.UserId)
			BaseService:RenderBase(base)
			return
		end
	end
	Notify(player, "All bases are taken on this server - your pets are safe in your inventory.", "Info")
end

local function release(player: Player)
	local base = baseOf[player]
	if not base then
		return
	end
	baseOf[player] = nil
	base.Owner = nil
	base.Model:SetAttribute("OwnerId", nil)
	BaseService:RenderBase(base)
end

local actions = {}

function actions.Place(player: Player, base: Base, data, slot: number, petId: any)
	if type(petId) ~= "string" or not data.Pets[petId] then
		return false, "Pet not found"
	end
	if slot > data.Base.Unlocked then
		return false, "This slot is locked"
	end
	if data.Base.Slots[slotKey(slot)] then
		return false, "This slot already has a pet"
	end
	if Formulas.PlacedSlot(data, petId) then
		return false, "This pet is already on your base"
	end
	local index = table.find(data.Equipped, petId)
	if index then
		table.remove(data.Equipped, index)
		PetService:UpdateEquippedAttribute(player)
	end
	data.Base.Slots[slotKey(slot)] = { Pet = petId, Stored = 0 }
	BaseService:RenderBase(base)
	return true
end

function actions.PickUp(player: Player, base: Base, data, slot: number)
	if not data.Base.Slots[slotKey(slot)] then
		return false, "No pet here"
	end
	collect(player, base, slot)
	data.Base.Slots[slotKey(slot)] = nil
	BaseService:RenderBase(base)
	return true
end

function actions.Unlock(_player: Player, base: Base, data, slot: number)
	if slot ~= data.Base.Unlocked + 1 or slot > BaseConfig.SlotCount then
		return false, "Unlock the previous slot first"
	end
	local cost = BaseConfig.SlotCosts[slot] or 0
	if data.Coins < cost then
		return false, "Not enough coins"
	end
	data.Coins -= cost
	data.Base.Unlocked = slot
	BaseService:RenderBase(base)
	return true
end

function BaseService:Init()
	collectedEvent = Remotes.Event("BaseCollected")
	local folder = workspace:WaitForChild("Map"):WaitForChild("Bases")
	for _, model in folder:GetChildren() do
		local id = model:GetAttribute("BaseId")
		if model:IsA("Model") and type(id) == "number" then
			local base: Base = { Model = model, Id = id, Owner = nil, Slots = {}, PetModels = {} }
			local slots = model:FindFirstChild("Slots")
			for _, slotModel in (slots and slots:GetChildren()) or {} do
				local n = slotModel:GetAttribute("Slot")
				if type(n) == "number" and slotModel:IsA("Model") then
					base.Slots[n] = slotModel
				end
			end
			table.insert(bases, base)
		end
	end
	table.sort(bases, function(a, b)
		return a.Id < b.Id
	end)
end

function BaseService:Start()
	for _, base in bases do
		self:RenderBase(base)
		-- Botões de coletar
		for slot, slotModel in base.Slots do
			local pad = slotModel:FindFirstChild("Pad") :: BasePart?
			if pad then
				pad.Touched:Connect(function(hit)
					local player = Players:GetPlayerFromCharacter(hit.Parent)
					if not player or base.Owner ~= player then
						return
					end
					local now = os.clock()
					if (padDebounce[pad] or 0) > now then
						return
					end
					padDebounce[pad] = now + 0.5
					if collect(player, base, slot) > 0 then
						pad.Color = Color3.fromRGB(255, 230, 90)
						task.delay(0.25, function()
							pad.Color = PAD_COLOR
						end)
					end
				end)
			end
		end
	end

	Remotes.Function("BaseAction").OnServerInvoke = function(player, action, slot, arg)
		if type(action) ~= "string" or type(slot) ~= "number" or not limiter:Check(player) then
			return false, "Slow down!"
		end
		local handler = actions[action]
		local data = DataService:Get(player)
		local base = baseOf[player]
		slot = math.floor(slot)
		if not handler or not data or not base or slot < 1 or slot > BaseConfig.SlotCount then
			return false, "Invalid action"
		end
		if not nearBase(player, base) then
			return false, "Go to your base first"
		end
		local ok, err = handler(player, base, data, slot, arg)
		if ok then
			DataService:ReplicateNow(player)
		end
		return ok, err
	end

	DataService:OnPlayerLoaded(function(player)
		assign(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.1)
			teleportToBase(player)
		end)
		if player.Character then
			teleportToBase(player)
		end
	end)
	DataService.PlayerRemoving:Connect(release)

	-- Renda dos pets (um loop para todas as bases)
	task.spawn(function()
		while true do
			task.wait(BaseConfig.IncomeInterval)
			for _, base in bases do
				local owner = base.Owner
				local data = owner and DataService:Get(owner)
				if data then
					for key, entry in data.Base.Slots do
						local owned = data.Pets[entry.Pet]
						if owned then
							entry.Stored += Formulas.PetIncome(data, owned.N) * BaseConfig.IncomeInterval
							local slotModel = base.Slots[tonumber(key) :: number]
							if slotModel then
								local stored = math.floor(entry.Stored)
								slotModel:SetAttribute("Stored", stored)
								local gui = slotModel:FindFirstChild("Info", true)
								local label = gui and gui:FindFirstChild("Stored") :: TextLabel?
								if label then
									label.Text = "$" .. NumberFormat.Abbreviate(stored)
								end
							end
						end
					end
				end
			end
		end
	end)
end

-- Redesenha a base de um jogador (ex.: depois de um rebirth a renda muda)
function BaseService:Refresh(player: Player)
	local base = baseOf[player]
	if base then
		self:RenderBase(base)
	end
end

return BaseService
