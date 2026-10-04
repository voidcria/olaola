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
	Lobby = { MinX = -178, MaxX = 178, MinZ = 0, MaxZ = 300 },
	Spawn = { X = 0, Z = 150 },

	-- Barracas: uma de cada lado da pista. Facing = direção (X) para onde a frente aponta.
	Stands = {
		WeightShop = {
			X = -82,
			Z = 66,
			Facing = 1,
			Title = "WEIGHT SHOP",
			Subtitle = "New weights = more Strength",
			Color = { 255, 140, 60 },
			Panel = "Weights",
			Action = "Buy Weights",
		},
		Rebirth = {
			X = 82,
			Z = 66,
			Facing = -1,
			Title = "REBIRTH",
			Subtitle = "Reset for permanent power",
			Color = { 180, 100, 255 },
			Panel = "Rebirth",
			Action = "Rebirth",
		},
	},

	-- Bases dos jogadores (pets). Facing = direção (X) da entrada (virada para a rua central).
	Bases = {
		{ X = -148, Z = 130, Facing = 1, Color = { 255, 150, 180 } },
		{ X = 148, Z = 130, Facing = -1, Color = { 120, 190, 255 } },
		{ X = -148, Z = 194, Facing = 1, Color = { 140, 220, 120 } },
		{ X = 148, Z = 194, Facing = -1, Color = { 255, 210, 90 } },
		{ X = -148, Z = 258, Facing = 1, Color = { 190, 140, 255 } },
		{ X = 148, Z = 258, Facing = -1, Color = { 255, 160, 90 } },
	},
	BaseSize = { Width = 58, Depth = 52 }, -- Width = ao longo de Z, Depth = ao longo de X

	-- Paredes cartunescas em volta de todo o mapa
	Walls = {
		TrackHalfWidth = 148, -- distância do centro da pista até a parede lateral
		Thickness = 12,
		Height = 40,
	},

	Leaderboard = { X = 0, Z = 290 },
}

-- Ponto em frente a uma barraca (usado pela seta do tutorial)
function TrackConfig.StandFront(name: string): (number, number)
	local s = TrackConfig.Stands[name]
	return s.X + s.Facing * 12, s.Z
end

return TrackConfig
