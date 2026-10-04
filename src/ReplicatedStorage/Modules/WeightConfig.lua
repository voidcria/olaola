-- Pesos (objetos de força) vendidos na Weight Shop.
-- O jogador segura o peso e clica para levantar: ganha Gain de Strength (antes dos multiplicadores).
--   Cost: moedas | RebirthsRequired: rebirths mínimos
--   Kind: Dumbbell | Barbell | Kettlebell (modelo procedural)
--   Model: nome de um Model em ReplicatedStorage.Assets.Weights para usar o seu modelo
--   Icon: asset id opcional para a loja (vazio = modelo 3D)
local WeightConfig = {
	Order = { "Wooden", "Iron", "Steel", "Golden", "Diamond", "Lava", "Cosmic", "Galaxy" },
	Weights = {
		Wooden = { Name = "Wooden Dumbbell", Kind = "Dumbbell", Gain = 1, Cost = 0, RebirthsRequired = 0, Rarity = "Common", Colors = { { 170, 120, 75 }, { 120, 80, 50 } } },
		Iron = { Name = "Iron Dumbbell", Kind = "Dumbbell", Gain = 3, Cost = 120, RebirthsRequired = 0, Rarity = "Common", Colors = { { 120, 125, 135 }, { 70, 70, 80 } } },
		Steel = { Name = "Steel Barbell", Kind = "Barbell", Gain = 10, Cost = 1500, RebirthsRequired = 0, Rarity = "Rare", Colors = { { 200, 205, 215 }, { 70, 160, 255 } } },
		Golden = { Name = "Golden Kettlebell", Kind = "Kettlebell", Gain = 35, Cost = 20000, RebirthsRequired = 0, Rarity = "Epic", Colors = { { 255, 200, 50 }, { 200, 140, 20 } } },
		Diamond = { Name = "Diamond Dumbbell", Kind = "Dumbbell", Gain = 120, Cost = 300000, RebirthsRequired = 1, Rarity = "Legendary", Colors = { { 120, 230, 255 }, { 200, 245, 255 } }, Glow = true },
		Lava = { Name = "Lava Barbell", Kind = "Barbell", Gain = 450, Cost = 6000000, RebirthsRequired = 2, Rarity = "Legendary", Colors = { { 60, 40, 40 }, { 255, 110, 30 } }, Glow = true },
		Cosmic = { Name = "Cosmic Kettlebell", Kind = "Kettlebell", Gain = 1800, Cost = 150000000, RebirthsRequired = 4, Rarity = "Mythic", Colors = { { 60, 30, 120 }, { 200, 120, 255 } }, Glow = true },
		Galaxy = { Name = "Galaxy Barbell", Kind = "Barbell", Gain = 8000, Cost = 5000000000, RebirthsRequired = 6, Rarity = "Secret", Colors = { { 20, 20, 40 }, { 120, 255, 230 } }, Glow = true },
	},
}

for id, w in WeightConfig.Weights do
	w.Id = id
	w.Icon = w.Icon or ""
	w.Model = w.Model or w.Name
end

function WeightConfig.Get(id: string)
	return WeightConfig.Weights[id]
end

function WeightConfig.IndexOf(id: string): number
	return table.find(WeightConfig.Order, id) or 0
end

return WeightConfig
