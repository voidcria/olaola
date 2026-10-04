-- Todas as fórmulas de balanceamento num só lugar.
-- Usado pelo SERVIDOR (autoritativo) e pelo cliente (apenas para mostrar previsões na UI).
local Modules = script.Parent
local Config = require(Modules.Config)
local EggConfig = require(Modules.EggConfig)
local PetConfig = require(Modules.PetConfig)
local UpgradeConfig = require(Modules.UpgradeConfig)
local RebirthConfig = require(Modules.RebirthConfig)
local AreaConfig = require(Modules.AreaConfig)
local WeightConfig = require(Modules.WeightConfig)
local BaseConfig = require(Modules.BaseConfig)

local Formulas = {}

local function upgradeLevel(data, id: string): number
	return (data.Upgrades and data.Upgrades[id]) or 0
end

function Formulas.UpgradeValue(data, id: string): number
	return UpgradeConfig.Value(id, upgradeLevel(data, id))
end

-- Soma dos bônus dos pets equipados
function Formulas.PetBonus(data)
	local bonus = { Coins = 1, Strength = 1, Kick = 1 }
	if not data.Equipped or not data.Pets then
		return bonus
	end
	for _, petId in data.Equipped do
		local owned = data.Pets[petId]
		local pet = owned and PetConfig.Get(owned.N)
		if pet then
			bonus.Coins += pet.Coins - 1
			bonus.Strength += pet.Strength - 1
			bonus.Kick += pet.Kick - 1
		end
	end
	return bonus
end

function Formulas.MaxEquipped(data): number
	return Config.Pets.BaseEquipSlots + RebirthConfig.ExtraPetSlots(data.Rebirths or 0)
end

function Formulas.StrengthMultiplier(data): number
	local rebirth = RebirthConfig.Multipliers(data.Rebirths or 0)
	return Formulas.UpgradeValue(data, "StrengthGain") * Formulas.PetBonus(data).Strength * rebirth.Strength
end

-- Strength ganho por levantada com o peso (padrão: o peso equipado)
function Formulas.TrainGain(data, weightId: string?): number
	local weight = WeightConfig.Get(weightId or data.EquippedWeight or "Wooden") or WeightConfig.Get("Wooden")
	return math.max(1, math.floor(weight.Gain * Formulas.StrengthMultiplier(data)))
end

-- Próximo peso ainda não comprado (ou nil se já tem todos)
function Formulas.NextWeight(data): string?
	for _, id in WeightConfig.Order do
		if not (data.OwnedWeights and data.OwnedWeights[id]) then
			return id
		end
	end
	return nil
end

function Formulas.CanBuyWeight(data, weightId: string): boolean
	local w = WeightConfig.Get(weightId)
	return w ~= nil
		and not (data.OwnedWeights and data.OwnedWeights[weightId])
		and (data.Rebirths or 0) >= w.RebirthsRequired
		and (data.Coins or 0) >= w.Cost
end

----------------------------------------------------------------------
-- Base (pets nos pedestais)
----------------------------------------------------------------------
-- Slot (string) onde o pet está na base, ou nil
function Formulas.PlacedSlot(data, petId: string): string?
	local slots = data.Base and data.Base.Slots
	if not slots then
		return nil
	end
	for slot, entry in slots do
		if entry.Pet == petId then
			return slot
		end
	end
	return nil
end

function Formulas.PlacedCount(data): number
	local n = 0
	for _, entry in (data.Base and data.Base.Slots) or {} do
		if entry.Pet then
			n += 1
		end
	end
	return n
end

-- Moedas por segundo de um pet na base
function Formulas.PetIncome(data, petName: string): number
	local pet = PetConfig.Get(petName)
	if not pet then
		return 0
	end
	local rebirth = RebirthConfig.Multipliers(data.Rebirths or 0)
	return (BaseConfig.RarityIncome[pet.Rarity] or 1) * pet.Coins * rebirth.Coins
end

function Formulas.BaseIncome(data): number
	local total = 0
	for _, entry in (data.Base and data.Base.Slots) or {} do
		local owned = entry.Pet and data.Pets[entry.Pet]
		if owned then
			total += Formulas.PetIncome(data, owned.N)
		end
	end
	return total
end

function Formulas.KickMultiplier(data): number
	local rebirth = RebirthConfig.Multipliers(data.Rebirths or 0)
	return Formulas.UpgradeValue(data, "KickPower") * Formulas.PetBonus(data).Kick * rebirth.Kick
end

-- KickPower = (BasePower + Strength * StrengthToPower) * multiplicadores
function Formulas.KickPower(data): number
	local raw = Config.Kick.BasePower + (data.Strength or 0) * Config.Kick.StrengthToPower
	return raw * Formulas.KickMultiplier(data)
end

-- Distância "potencial" (sem o limite das áreas)
function Formulas.RawDistance(power: number, roll: number?): number
	local k = Config.Kick
	return k.DistanceScale * power ^ k.DistanceExponent * (roll or 1)
end

function Formulas.MaxDistance(data): number
	return AreaConfig.MaxDistance(data.HighestArea or 1)
end

-- Ovo que realmente será chutado (se o selecionado exigir mais força, usa o melhor possível)
function Formulas.KickEgg(data): string
	local selected = data.SelectedEgg
	local egg = selected and EggConfig.Get(selected)
	if egg and data.UnlockedEggs and data.UnlockedEggs[selected] and (data.Strength or 0) >= egg.StrengthRequired then
		return selected
	end
	local best = "Basic"
	for _, id in EggConfig.Order do
		local e = EggConfig.Get(id)
		if data.UnlockedEggs and data.UnlockedEggs[id] and (data.Strength or 0) >= e.StrengthRequired then
			best = id
		end
	end
	return best
end

function Formulas.CoinMultiplier(data, eggId: string): number
	local egg = EggConfig.Get(eggId) or EggConfig.Get("Basic")
	local rebirth = RebirthConfig.Multipliers(data.Rebirths or 0)
	return egg.CoinMultiplier * Formulas.UpgradeValue(data, "CoinGain") * Formulas.PetBonus(data).Coins * rebirth.Coins
end

function Formulas.CoinReward(data, distance: number, eggId: string): number
	local coins = distance * Config.Coins.PerMeter * Formulas.CoinMultiplier(data, eggId)
	return math.max(Config.Coins.Minimum, math.floor(coins))
end

-- Duração do voo (segundos) cresce devagar com a distância
function Formulas.FlightTime(distance: number): number
	local k = Config.Kick
	return math.clamp(1.2 + distance ^ 0.42 * 0.2, k.MinFlightTime, k.MaxFlightTime)
end

function Formulas.WalkSpeed(data): number
	return Formulas.UpgradeValue(data, "WalkSpeed")
end

-- Requisitos genéricos: { Coins, Strength, Rebirths, BestDistance }
function Formulas.MeetsRequirements(data, req): (boolean, string?)
	if req.Rebirths and (data.Rebirths or 0) < req.Rebirths then
		return false, "Rebirths"
	end
	if req.BestDistance and (data.BestDistance or 0) < req.BestDistance then
		return false, "BestDistance"
	end
	if req.Strength and (data.Strength or 0) < req.Strength then
		return false, "Strength"
	end
	if req.Coins and (data.Coins or 0) < req.Coins then
		return false, "Coins"
	end
	return true, nil
end

function Formulas.CanRebirth(data): (boolean, string?)
	local r = data.Rebirths or 0
	if (data.Strength or 0) < RebirthConfig.StrengthRequired(r) then
		return false, "Strength"
	end
	if (data.Coins or 0) < RebirthConfig.CoinCost(r) then
		return false, "Coins"
	end
	return true, nil
end

function Formulas.PetCount(data): number
	local n = 0
	for _ in data.Pets or {} do
		n += 1
	end
	return n
end

function Formulas.DiscoveredCount(data): number
	local n = 0
	for _ in data.Discovered or {} do
		n += 1
	end
	return n
end

function Formulas.TotalPetTypes(): number
	local n = 0
	for _ in PetConfig.Pets do
		n += 1
	end
	return n
end

return Formulas
