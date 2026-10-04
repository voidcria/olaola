-- Sons do jogo. Troque pelos seus asset ids ("rbxassetid://123") quando quiser.
-- Os padrões usam sons que já vêm com o cliente do Roblox (rbxasset://sounds/...).
local SoundConfig = {
	Kick = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.9, Pitch = 0.75 },
	Impact = { Id = "rbxasset://sounds/collide.wav", Volume = 0.6, Pitch = 1 },
	Land = { Id = "rbxasset://sounds/collide.wav", Volume = 0.35, Pitch = 0.7 },
	Coins = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 1.25 },
	Train = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.25, Pitch = 1.4 },
	Click = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.25, Pitch = 1.8 },
	NewBest = { Id = "rbxasset://sounds/victory.wav", Volume = 0.6, Pitch = 1 },
	Tick = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.18, Pitch = 2.2 },
	Reveal = { Id = "rbxasset://sounds/victory.wav", Volume = 0.5, Pitch = 1.1 },
	Rebirth = { Id = "rbxasset://sounds/victory.wav", Volume = 0.7, Pitch = 0.8 },
	Error = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, Pitch = 0.6 },
	-- Música de fundo (deixe vazio para desativar)
	Music = { Id = "", Volume = 0.25, Pitch = 1 },
}

return SoundConfig
