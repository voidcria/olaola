-- Ovos do jogo.
-- Cada ovo pode ser CHUTADO (depois de desbloqueado) e CHOCADO no menu Eggs > Hatch Pets (gera pets).
--   StrengthRequired: força mínima para desbloquear/chutar
--   UnlockCost: moedas para desbloquear
--   CoinMultiplier: multiplicador de moedas ao chutar este ovo
--   HatchCost: preço para chocar (roleta de pets)
--   Pets: tabela de chances (%), soma = 100
--   Icon: asset id opcional (rbxassetid://...). Vazio = usa o modelo 3D em ViewportFrame
--   Model: nome de um modelo em ReplicatedStorage.Assets.Eggs (opcional). Se não existir, usa o modelo procedural.
local EggConfig = {
	Order = { "Basic", "Rare", "Epic", "Legendary", "Mythic", "Cosmic" },
	Eggs = {
		Basic = {
			Id = "Basic",
			Name = "Basic Egg",
			Rarity = "Common",
			StrengthRequired = 0,
			UnlockCost = 0,
			RebirthsRequired = 0,
			CoinMultiplier = 1,
			HatchCost = 75,
			Look = { Primary = { 250, 244, 228 }, Secondary = { 230, 200, 150 }, Pattern = "Spots", Material = "SmoothPlastic" },
			Icon = "",
			Model = "Basic Egg",
			Pets = {
				{ Pet = "Chick", Chance = 55 },
				{ Pet = "Bunny", Chance = 30 },
				{ Pet = "Piglet", Chance = 12 },
				{ Pet = "Golden Chick", Chance = 2.7 },
				{ Pet = "Rainbow Chick", Chance = 0.3 },
			},
		},
		Rare = {
			Id = "Rare",
			Name = "Rare Egg",
			Rarity = "Rare",
			StrengthRequired = 400,
			UnlockCost = 250,
			RebirthsRequired = 0,
			CoinMultiplier = 1.6,
			HatchCost = 900,
			Look = { Primary = { 110, 185, 255 }, Secondary = { 230, 245, 255 }, Pattern = "Stripes", Material = "SmoothPlastic" },
			Icon = "",
			Model = "Rare Egg",
			Pets = {
				{ Pet = "Kitten", Chance = 50 },
				{ Pet = "Puppy", Chance = 32 },
				{ Pet = "Fox", Chance = 14 },
				{ Pet = "Owl", Chance = 3.7 },
				{ Pet = "Sun Phoenix", Chance = 0.3 },
			},
		},
		Epic = {
			Id = "Epic",
			Name = "Epic Egg",
			Rarity = "Epic",
			StrengthRequired = 8000,
			UnlockCost = 9000,
			RebirthsRequired = 0,
			CoinMultiplier = 2.6,
			HatchCost = 20000,
			Look = { Primary = { 175, 95, 255 }, Secondary = { 255, 220, 120 }, Pattern = "Stars", Material = "SmoothPlastic" },
			Icon = "",
			Model = "Epic Egg",
			Pets = {
				{ Pet = "Panda", Chance = 50 },
				{ Pet = "Arctic Fox", Chance = 32 },
				{ Pet = "Snow Owl", Chance = 14 },
				{ Pet = "Ice Dragon", Chance = 3.8 },
				{ Pet = "Frost Spirit", Chance = 0.2 },
			},
		},
		Legendary = {
			Id = "Legendary",
			Name = "Legendary Egg",
			Rarity = "Legendary",
			StrengthRequired = 200000,
			UnlockCost = 2500000,
			RebirthsRequired = 2,
			CoinMultiplier = 4.5,
			HatchCost = 3000000,
			Look = { Primary = { 255, 200, 50 }, Secondary = { 255, 120, 40 }, Pattern = "Stripes", Material = "Glow" },
			Icon = "",
			Model = "Legendary Egg",
			Pets = {
				{ Pet = "Lava Pup", Chance = 50 },
				{ Pet = "Magma Bear", Chance = 33 },
				{ Pet = "Fire Dragon", Chance = 14 },
				{ Pet = "Volcano Titan", Chance = 2.95 },
				{ Pet = "Inferno Lord", Chance = 0.05 },
			},
		},
		Mythic = {
			Id = "Mythic",
			Name = "Mythic Egg",
			Rarity = "Mythic",
			StrengthRequired = 20000000,
			UnlockCost = 300000000,
			RebirthsRequired = 4,
			CoinMultiplier = 8,
			HatchCost = 500000000,
			Look = { Primary = { 255, 70, 140 }, Secondary = { 120, 230, 255 }, Pattern = "Stars", Material = "Glow" },
			Icon = "",
			Model = "Mythic Egg",
			Pets = {
				{ Pet = "Star Cat", Chance = 55 },
				{ Pet = "Nebula Bunny", Chance = 35 },
				{ Pet = "Galaxy Dragon", Chance = 9.5 },
				{ Pet = "Cosmic Overlord", Chance = 0.5 },
			},
		},
		Cosmic = {
			Id = "Cosmic",
			Name = "Cosmic Egg",
			Rarity = "Secret",
			StrengthRequired = 2000000000,
			UnlockCost = 80000000000,
			RebirthsRequired = 8,
			CoinMultiplier = 15,
			HatchCost = 150000000000,
			Look = { Primary = { 30, 25, 60 }, Secondary = { 255, 255, 255 }, Pattern = "Stars", Material = "Cosmic" },
			Icon = "",
			Model = "Cosmic Egg",
			Pets = {
				{ Pet = "Void Slime", Chance = 60 },
				{ Pet = "Celestial Phoenix", Chance = 35 },
				{ Pet = "Eggbert the Eternal", Chance = 5 },
			},
		},
	},
}

function EggConfig.Get(id: string)
	return EggConfig.Eggs[id]
end

function EggConfig.IndexOf(id: string): number
	return table.find(EggConfig.Order, id) or 0
end

return EggConfig
