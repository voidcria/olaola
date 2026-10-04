-- EggService: desbloquear/selecionar ovos para chutar e chocar ovos (roleta de pets).
-- O sorteio acontece só no servidor; o cliente apenas anima o resultado recebido.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local EggConfig = require(Modules.EggConfig)
local Remotes = require(Modules.Remotes)

local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local Notify = require(ServerScriptService.Util.Notify)

local EggService = {}

local rng = Random.new()
local shopLimiter = RateLimiter.new(5, 5)
local hatchLimiter = RateLimiter.new(1 / 1.5, 1)

-- Sorteio ponderado pelas chances do ovo
function EggService:RollPet(eggId: string)
	local egg = EggConfig.Get(eggId)
	local total = 0
	for _, entry in egg.Pets do
		total += entry.Chance
	end
	local pick = rng:NextNumber(0, total)
	local acc = 0
	for _, entry in egg.Pets do
		acc += entry.Chance
		if pick <= acc then
			return entry.Pet, entry.Chance
		end
	end
	local last = egg.Pets[#egg.Pets]
	return last.Pet, last.Chance
end

function EggService:Start()
	Remotes.Function("UnlockEgg").OnServerInvoke = function(player, eggId)
		if type(eggId) ~= "string" or not shopLimiter:Check(player) then
			return false, "Slow down!"
		end
		local egg = EggConfig.Get(eggId)
		local data = DataService:Get(player)
		if not egg or not data then
			return false, "Invalid egg"
		end
		if data.UnlockedEggs[eggId] then
			return false, "Already unlocked"
		end
		if data.Rebirths < egg.RebirthsRequired then
			return false, "Requires " .. egg.RebirthsRequired .. " Rebirths"
		end
		if data.Strength < egg.StrengthRequired then
			return false, "Not enough Strength"
		end
		if data.Coins < egg.UnlockCost then
			return false, "Not enough coins"
		end
		data.Coins -= egg.UnlockCost
		data.UnlockedEggs[eggId] = true
		data.SelectedEgg = eggId
		DataService:ReplicateNow(player)
		Remotes.Event("Celebrate"):FireClient(player, "EggUnlocked", eggId)
		return true
	end

	Remotes.Function("SelectEgg").OnServerInvoke = function(player, eggId)
		if type(eggId) ~= "string" or not shopLimiter:Check(player) then
			return false, "Slow down!"
		end
		local egg = EggConfig.Get(eggId)
		local data = DataService:Get(player)
		if not egg or not data or not data.UnlockedEggs[eggId] then
			return false, "Egg locked"
		end
		if data.Strength < egg.StrengthRequired then
			return false, "Not enough Strength to kick this egg"
		end
		data.SelectedEgg = eggId
		DataService:ReplicateNow(player)
		return true
	end

	Remotes.Function("HatchEgg").OnServerInvoke = function(player, eggId)
		if type(eggId) ~= "string" then
			return false, "Invalid egg"
		end
		if not hatchLimiter:Check(player) then
			return false, "Wait for the current hatch!"
		end
		local egg = EggConfig.Get(eggId)
		local data = DataService:Get(player)
		if not egg or not data then
			return false, "Invalid egg"
		end
		if not data.UnlockedEggs[eggId] then
			return false, "Unlock this egg at the Egg Shop first"
		end
		if PetService:IsInventoryFull(data) then
			return false, "Your pet inventory is full!"
		end
		if data.Coins < egg.HatchCost then
			return false, "Not enough coins"
		end
		data.Coins -= egg.HatchCost
		data.TotalHatches += 1
		local petName, chance = self:RollPet(eggId)
		local wasDiscovered = data.Discovered[petName] == true
		local petId = PetService:GivePet(player, petName)
		if not petId then
			-- Reembolsa caso algo dê errado
			data.Coins += egg.HatchCost
			DataService:MarkDirty(player)
			return false, "Hatch failed"
		end
		DataService:ReplicateNow(player)
		return true, {
			Egg = eggId,
			Pet = petName,
			PetId = petId,
			Chance = chance,
			New = not wasDiscovered,
		}
	end

	-- Notificação útil quando um ovo novo pode ser desbloqueado
	DataService:OnPlayerLoaded(function(player, data)
		if data.TotalKicks == 0 then
			Notify(player, "Welcome to Kick an Egg! Train to get stronger, then kick your egg!", "Info")
		end
	end)
end

return EggService
