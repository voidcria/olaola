-- Raridades: cores e intensidade das animações (roleta, efeitos).
local RarityConfig = {
	Order = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" },
	Rarities = {
		Common = { Color = { 190, 196, 205 }, Rank = 1, SpinTime = 2.6, Shake = 0, Glow = false },
		Rare = { Color = { 70, 160, 255 }, Rank = 2, SpinTime = 3.0, Shake = 0, Glow = false },
		Epic = { Color = { 175, 90, 255 }, Rank = 3, SpinTime = 3.4, Shake = 2, Glow = true },
		Legendary = { Color = { 255, 196, 40 }, Rank = 4, SpinTime = 4.0, Shake = 4, Glow = true },
		Mythic = { Color = { 255, 70, 130 }, Rank = 5, SpinTime = 4.6, Shake = 6, Glow = true },
		Secret = { Color = { 40, 40, 48 }, Rank = 6, SpinTime = 5.2, Shake = 8, Glow = true, Rainbow = true },
	},
}

function RarityConfig.Get(name: string)
	return RarityConfig.Rarities[name] or RarityConfig.Rarities.Common
end

function RarityConfig.Rank(name: string): number
	return RarityConfig.Get(name).Rank
end

return RarityConfig
