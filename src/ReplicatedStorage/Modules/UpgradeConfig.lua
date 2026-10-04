-- Upgrades compráveis com moedas. Custo = BaseCost * Growth ^ nível.
-- Value(level) devolve o efeito no nível atual. MaxLevel trava o balanceamento.
local UpgradeConfig = {
	Order = { "KickPower", "StrengthGain", "CoinGain", "WalkSpeed" },
	Upgrades = {
		KickPower = {
			Name = "Kick Power",
			Description = "Kick your eggs harder",
			Icon = "Kick",
			BaseCost = 40,
			Growth = 1.55,
			MaxLevel = 60,
			PerLevel = 0.12, -- +12% de força do chute por nível
			Format = "Multiplier",
		},
		StrengthGain = {
			Name = "Strength Gain",
			Description = "More Strength per training",
			Icon = "Strength",
			BaseCost = 20,
			Growth = 1.6,
			MaxLevel = 60,
			PerLevel = 0.15,
			Format = "Multiplier",
		},
		CoinGain = {
			Name = "Coin Gain",
			Description = "More coins per kick",
			Icon = "Coins",
			BaseCost = 120,
			Growth = 1.62,
			MaxLevel = 60,
			PerLevel = 0.1,
			Format = "Multiplier",
		},
		WalkSpeed = {
			Name = "Walk Speed",
			Description = "Run around faster",
			Icon = "Speed",
			BaseCost = 60,
			Growth = 1.9,
			MaxLevel = 12,
			PerLevel = 1.25, -- +1.25 de WalkSpeed por nível (16 -> 31)
			Format = "Speed",
		},
	},
}

function UpgradeConfig.Get(id: string)
	return UpgradeConfig.Upgrades[id]
end

function UpgradeConfig.Cost(id: string, level: number): number
	local u = UpgradeConfig.Upgrades[id]
	return math.floor(u.BaseCost * u.Growth ^ level)
end

function UpgradeConfig.Value(id: string, level: number): number
	local u = UpgradeConfig.Upgrades[id]
	if id == "WalkSpeed" then
		return 16 + u.PerLevel * level
	end
	return 1 + u.PerLevel * level
end

return UpgradeConfig
