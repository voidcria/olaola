-- Geometria do mapa (dados puros, sem APIs do Roblox).
-- Usado pelo jogo E pelo script de build (build/build.luau) para montar o mapa.
-- A pista vai no sentido -Z a partir da linha de chute (KickLineZ).
local TrackConfig = {
	FloorY = 0, -- topo do chão

	-- Linha de chute: o ovo sai daqui e a distância é medida a partir dela
	KickLineZ = 0,
	TrackCenterX = 0,
	TrackWidth = 120,
	Length = 6000, -- metros (1 stud = 1m no display)

	-- Área onde o jogador pode chutar (em cima da plataforma de chute)
	KickZone = { MinX = -56, MaxX = 56, MinZ = 0, MaxZ = 34, Height = 30 },

	-- Lobby (atrás da linha de chute)
	Lobby = { MinX = -130, MaxX = 130, MinZ = 0, MaxZ = 260 },
	Spawn = { X = 0, Z = 205 },

	-- Barracas / stands (posição do centro do balcão; olham para Facing)
	Stands = {
		EggShop = { X = 92, Z = 82, Title = "EGG SHOP", Subtitle = "Unlock & choose eggs", Color = { 255, 196, 64 } },
		Hatchery = { X = 92, Z = 132, Title = "HATCHERY", Subtitle = "Hatch pets!", Color = { 120, 220, 120 } },
		Upgrades = { X = 92, Z = 182, Title = "UPGRADES", Subtitle = "Get stronger", Color = { 80, 170, 255 } },
		Rebirth = { X = -15, Z = 238, Title = "REBIRTH", Subtitle = "Reset for power", Color = { 180, 100, 255 } },
		Areas = { X = 82, Z = 30, Title = "AREAS", Subtitle = "Unlock new areas", Color = { 255, 120, 90 } },
	},

	Leaderboard = { X = 40, Z = 250 },
}

return TrackConfig
