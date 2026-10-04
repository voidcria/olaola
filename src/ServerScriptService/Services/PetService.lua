-- PetService: inventário de pets (equipar, desequipar, excluir, bloquear, Equip Best).
-- Os nomes dos pets equipados vão num atributo do Player para todos os clientes
-- desenharem os pets seguindo o dono (sem modelos no servidor).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules.Config)
local Formulas = require(Modules.Formulas)
local PetConfig = require(Modules.PetConfig)
local Remotes = require(Modules.Remotes)

local DataService = require(script.Parent.DataService)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)

local PetService = {}

local limiter = RateLimiter.new(10, 10)

function PetService:UpdateEquippedAttribute(player: Player)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local names = {}
	for _, petId in data.Equipped do
		local pet = data.Pets[petId]
		if pet then
			table.insert(names, pet.N)
		end
	end
	player:SetAttribute("EquippedPets", HttpService:JSONEncode(names))
end

function PetService:IsInventoryFull(data): boolean
	return Formulas.PetCount(data) >= Config.Pets.MaxInventory
end

-- Dá um pet ao jogador (chamado apenas pelo servidor, ex.: EggService)
function PetService:GivePet(player: Player, petName: string): string?
	local data = DataService:Get(player)
	if not data or not PetConfig.Get(petName) then
		return nil
	end
	local petId = DataService:NewPetId(data)
	data.Pets[petId] = { N = petName, L = false }
	data.Discovered[petName] = true
	-- Equipa automaticamente se houver espaço
	if #data.Equipped < Formulas.MaxEquipped(data) then
		table.insert(data.Equipped, petId)
		self:UpdateEquippedAttribute(player)
	end
	DataService:MarkDirty(player)
	return petId
end

local function equipBest(data)
	local ids = {}
	for petId in data.Pets do
		if not Formulas.PlacedSlot(data, petId) then
			table.insert(ids, petId)
		end
	end
	table.sort(ids, function(a, b)
		return PetConfig.Score(data.Pets[a].N) > PetConfig.Score(data.Pets[b].N)
	end)
	local equipped = {}
	for i = 1, math.min(#ids, Formulas.MaxEquipped(data)) do
		table.insert(equipped, ids[i])
	end
	data.Equipped = equipped
end

local actions = {}

function actions.Equip(data, petId)
	if not data.Pets[petId] then
		return false, "Pet not found"
	end
	if table.find(data.Equipped, petId) then
		return true
	end
	if Formulas.PlacedSlot(data, petId) then
		return false, "This pet is on your base. Pick it up first!"
	end
	if #data.Equipped >= Formulas.MaxEquipped(data) then
		return false, "All pet slots are full"
	end
	table.insert(data.Equipped, petId)
	return true
end

function actions.Unequip(data, petId)
	local index = table.find(data.Equipped, petId)
	if index then
		table.remove(data.Equipped, index)
	end
	return true
end

function actions.Lock(data, petId)
	local pet = data.Pets[petId]
	if not pet then
		return false, "Pet not found"
	end
	pet.L = not pet.L
	return true
end

function actions.Delete(data, petId)
	local pet = data.Pets[petId]
	if not pet then
		return false, "Pet not found"
	end
	if pet.L then
		return false, "This pet is locked"
	end
	if Formulas.PlacedSlot(data, petId) then
		return false, "Pick this pet up from your base first"
	end
	actions.Unequip(data, petId)
	data.Pets[petId] = nil
	return true
end

function actions.EquipBest(data)
	equipBest(data)
	return true
end

function actions.UnequipAll(data)
	data.Equipped = {}
	return true
end

function PetService:Start()
	Remotes.Function("PetAction").OnServerInvoke = function(player, action, petId)
		if type(action) ~= "string" or not limiter:Check(player) then
			return false, "Slow down!"
		end
		local handler = actions[action]
		local data = DataService:Get(player)
		if not handler or not data then
			return false, "Invalid action"
		end
		if petId ~= nil and (type(petId) ~= "string" or #petId > 20) then
			return false, "Invalid pet"
		end
		local ok, err = handler(data, petId)
		if ok then
			self:UpdateEquippedAttribute(player)
			DataService:ReplicateNow(player)
		end
		return ok, err
	end

	DataService:OnPlayerLoaded(function(player)
		self:UpdateEquippedAttribute(player)
	end)
end

return PetService
