-- Pets. Bônus são multiplicadores individuais; pets equipados SOMAM os bônus:
--   Total = 1 + soma(bonus - 1)   (ex.: 3 pets x1.2 de moedas = x1.6)
-- Coins / Strength / Kick: multiplicadores de moedas, ganho de força e força do chute.
-- Shape: modelo procedural (Bird, Bunny, Cat, Dog, Bear, Pig, Dragon, Slime, Golem).
-- Model: nome de um modelo em ReplicatedStorage.Assets.Pets (opcional) para substituir o procedural.
-- Icon: asset id opcional. Vazio = renderiza o modelo 3D em ViewportFrame.
local PetConfig = {
	Pets = {
		-- Basic Egg
		["Chick"] = { Rarity = "Common", Coins = 1.10, Strength = 1.03, Kick = 1, Shape = "Bird", Colors = { { 255, 225, 80 }, { 255, 150, 40 } } },
		["Bunny"] = { Rarity = "Common", Coins = 1.05, Strength = 1.07, Kick = 1, Shape = "Bunny", Colors = { { 245, 245, 245 }, { 255, 170, 190 } } },
		["Piglet"] = { Rarity = "Rare", Coins = 1.25, Strength = 1.11, Kick = 1, Shape = "Pig", Colors = { { 255, 170, 185 }, { 230, 120, 140 } } },
		["Golden Chick"] = { Rarity = "Epic", Coins = 1.6, Strength = 1.22, Kick = 1.05, Shape = "Bird", Colors = { { 255, 200, 40 }, { 255, 120, 20 } }, Shiny = true },
		["Rainbow Chick"] = { Rarity = "Legendary", Coins = 2.4, Strength = 1.55, Kick = 1.1, Shape = "Bird", Colors = { { 255, 90, 160 }, { 90, 200, 255 } }, Shiny = true },

		-- Rare Egg
		["Kitten"] = { Rarity = "Common", Coins = 1.3, Strength = 1.14, Kick = 1, Shape = "Cat", Colors = { { 255, 170, 90 }, { 255, 235, 210 } } },
		["Puppy"] = { Rarity = "Rare", Coins = 1.45, Strength = 1.22, Kick = 1, Shape = "Dog", Colors = { { 200, 150, 100 }, { 120, 80, 50 } } },
		["Fox"] = { Rarity = "Epic", Coins = 1.8, Strength = 1.39, Kick = 1.05, Shape = "Cat", Colors = { { 255, 120, 40 }, { 255, 255, 255 } } },
		["Owl"] = { Rarity = "Legendary", Coins = 2.8, Strength = 1.83, Kick = 1.1, Shape = "Bird", Colors = { { 140, 100, 70 }, { 240, 220, 180 } } },
		["Sun Phoenix"] = { Rarity = "Mythic", Coins = 5, Strength = 2.93, Kick = 1.2, Shape = "Dragon", Colors = { { 255, 140, 30 }, { 255, 230, 80 } }, Shiny = true },

		-- Epic Egg
		["Panda"] = { Rarity = "Rare", Coins = 2.0, Strength = 1.55, Kick = 1.02, Shape = "Bear", Colors = { { 250, 250, 250 }, { 30, 30, 35 } } },
		["Arctic Fox"] = { Rarity = "Epic", Coins = 2.6, Strength = 1.83, Kick = 1.05, Shape = "Cat", Colors = { { 235, 245, 255 }, { 160, 200, 255 } } },
		["Snow Owl"] = { Rarity = "Epic", Coins = 3.0, Strength = 2.1, Kick = 1.08, Shape = "Bird", Colors = { { 245, 250, 255 }, { 120, 140, 170 } } },
		["Ice Dragon"] = { Rarity = "Legendary", Coins = 4.5, Strength = 2.93, Kick = 1.15, Shape = "Dragon", Colors = { { 120, 200, 255 }, { 230, 250, 255 } }, Shiny = true },
		["Frost Spirit"] = { Rarity = "Mythic", Coins = 8, Strength = 4.85, Kick = 1.25, Shape = "Slime", Colors = { { 170, 230, 255 }, { 255, 255, 255 } }, Shiny = true },

		-- Legendary Egg
		["Lava Pup"] = { Rarity = "Epic", Coins = 4, Strength = 2.65, Kick = 1.08, Shape = "Dog", Colors = { { 60, 40, 40 }, { 255, 100, 30 } } },
		["Magma Bear"] = { Rarity = "Legendary", Coins = 6, Strength = 3.75, Kick = 1.12, Shape = "Bear", Colors = { { 90, 50, 40 }, { 255, 120, 30 } } },
		["Fire Dragon"] = { Rarity = "Legendary", Coins = 8, Strength = 4.85, Kick = 1.18, Shape = "Dragon", Colors = { { 220, 50, 40 }, { 255, 200, 60 } }, Shiny = true },
		["Volcano Titan"] = { Rarity = "Mythic", Coins = 15, Strength = 8.7, Kick = 1.3, Shape = "Golem", Colors = { { 70, 60, 60 }, { 255, 110, 20 } }, Shiny = true },
		["Inferno Lord"] = { Rarity = "Secret", Coins = 40, Strength = 22.45, Kick = 1.5, Shape = "Dragon", Colors = { { 20, 10, 10 }, { 255, 60, 20 } }, Shiny = true },

		-- Mythic Egg
		["Star Cat"] = { Rarity = "Legendary", Coins = 14, Strength = 8.15, Kick = 1.2, Shape = "Cat", Colors = { { 60, 60, 140 }, { 255, 240, 120 } }, Shiny = true },
		["Nebula Bunny"] = { Rarity = "Mythic", Coins = 22, Strength = 12.55, Kick = 1.3, Shape = "Bunny", Colors = { { 200, 90, 255 }, { 90, 220, 255 } }, Shiny = true },
		["Galaxy Dragon"] = { Rarity = "Mythic", Coins = 35, Strength = 19.7, Kick = 1.4, Shape = "Dragon", Colors = { { 40, 30, 90 }, { 255, 120, 220 } }, Shiny = true },
		["Cosmic Overlord"] = { Rarity = "Secret", Coins = 90, Strength = 49.95, Kick = 1.6, Shape = "Golem", Colors = { { 25, 20, 50 }, { 120, 255, 230 } }, Shiny = true },

		-- Cosmic Egg
		["Void Slime"] = { Rarity = "Mythic", Coins = 60, Strength = 33.45, Kick = 1.45, Shape = "Slime", Colors = { { 30, 10, 50 }, { 180, 80, 255 } }, Shiny = true },
		["Celestial Phoenix"] = { Rarity = "Secret", Coins = 150, Strength = 82.95, Kick = 1.7, Shape = "Dragon", Colors = { { 255, 255, 255 }, { 255, 210, 90 } }, Shiny = true },
		["Eggbert the Eternal"] = { Rarity = "Secret", Coins = 400, Strength = 220.45, Kick = 2.0, Shape = "Slime", Colors = { { 255, 250, 235 }, { 255, 200, 60 } }, Shiny = true },
	},
}

for name, pet in PetConfig.Pets do
	pet.Name = name
	pet.Icon = pet.Icon or ""
	pet.Model = pet.Model or name
end

function PetConfig.Get(name: string)
	return PetConfig.Pets[name]
end

-- Pontuação usada pelo "Equip Best"
function PetConfig.Score(name: string): number
	local pet = PetConfig.Pets[name]
	if not pet then
		return 0
	end
	return (pet.Coins - 1) + (pet.Strength - 1) + (pet.Kick - 1) * 10
end

return PetConfig
