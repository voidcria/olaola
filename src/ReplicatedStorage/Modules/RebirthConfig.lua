-- Rebirth: reseta Coins e Strength e dá multiplicadores permanentes.
-- Custo cresce exponencialmente; o bônus cresce linearmente => cada rebirth fica mais difícil.
local RebirthConfig = {
	BaseCoinCost = 100000,
	CoinGrowth = 4.5,
	BaseStrengthRequired = 25000,
	StrengthGrowth = 4.2,

	-- Bônus permanentes por rebirth
	StrengthPerRebirth = 0.35, -- x1.35, x1.7, x2.05 ... de ganho de força
	CoinsPerRebirth = 0.25, -- x1.25, x1.5 ... de moedas
	KickPerRebirth = 0.05, -- x1.05, x1.1 ... de força do chute

	-- O que é resetado
	Resets = { Coins = true, Strength = true },

	-- Recompensas por marcos (mostradas no painel)
	Milestones = {
		{ Rebirths = 1, Text = "Unlocks Auto Train" },
		{ Rebirths = 2, Text = "+1 Pet equip slot" },
		{ Rebirths = 3, Text = "Unlocks the Cosmic Anvil" },
		{ Rebirths = 5, Text = "+1 Pet equip slot" },
		{ Rebirths = 10, Text = "+1 Pet equip slot" },
	},
	ExtraPetSlotsAt = { 2, 5, 10 },
}

function RebirthConfig.CoinCost(rebirths: number): number
	return math.floor(RebirthConfig.BaseCoinCost * RebirthConfig.CoinGrowth ^ rebirths)
end

function RebirthConfig.StrengthRequired(rebirths: number): number
	return math.floor(RebirthConfig.BaseStrengthRequired * RebirthConfig.StrengthGrowth ^ rebirths)
end

function RebirthConfig.Multipliers(rebirths: number)
	return {
		Strength = 1 + rebirths * RebirthConfig.StrengthPerRebirth,
		Coins = 1 + rebirths * RebirthConfig.CoinsPerRebirth,
		Kick = 1 + rebirths * RebirthConfig.KickPerRebirth,
	}
end

function RebirthConfig.ExtraPetSlots(rebirths: number): number
	local n = 0
	for _, r in RebirthConfig.ExtraPetSlotsAt do
		if rebirths >= r then
			n += 1
		end
	end
	return n
end

return RebirthConfig
