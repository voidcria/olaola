-- Bases dos jogadores: pedestais onde os pets ficam gerando moedas.
-- Pise no botão (pad) em frente ao pedestal para coletar.
local BaseConfig = {
	SlotCount = 8,
	FreeSlots = 4, -- slots liberados de graça
	-- Custo para liberar cada slot extra (em moedas)
	SlotCosts = { [5] = 2500, [6] = 30000, [7] = 400000, [8] = 6000000 },

	-- Moedas por segundo de um pet na base = RarityIncome * bônus de Coins do pet * multiplicador de rebirth
	RarityIncome = {
		Common = 1,
		Rare = 3,
		Epic = 10,
		Legendary = 40,
		Mythic = 200,
		Secret = 1200,
	},
	IncomeInterval = 1,

	-- Posição dos pedestais no espaço local da base (frente/entrada = -Z local)
	-- 2 fileiras de 4: slots 1-4 na frente, 5-8 atrás
	SlotColumns = { -20, -6.7, 6.7, 20 },
	SlotRows = { -4, 12 },
	PadOffset = -6, -- botão de coletar fica na frente do pedestal
}

function BaseConfig.SlotLocal(slot: number): (number, number)
	local row = if slot <= 4 then 1 else 2
	local col = ((slot - 1) % 4) + 1
	return BaseConfig.SlotColumns[col], BaseConfig.SlotRows[row]
end

return BaseConfig
