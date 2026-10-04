-- Estações de treino do lobby. Gain = Strength base por treino (antes dos multiplicadores).
-- X/Z = posição no mapa (usado pelo build e pela validação do servidor).
local TrainConfig = {
	Radius = 13, -- distância máxima (studs) do jogador até a estação para treinar
	Stations = {
		{ Id = 1, Name = "Training Dummy", Kind = "Dummy", Gain = 1, StrengthRequired = 0, RebirthsRequired = 0, X = -92, Z = 70, Color = { 214, 170, 110 } },
		{ Id = 2, Name = "Tire Flip", Kind = "Tire", Gain = 4, StrengthRequired = 300, RebirthsRequired = 0, X = -92, Z = 112, Color = { 60, 60, 66 } },
		{ Id = 3, Name = "Iron Dumbbells", Kind = "Dumbbell", Gain = 15, StrengthRequired = 3000, RebirthsRequired = 0, X = -92, Z = 154, Color = { 150, 155, 170 } },
		{ Id = 4, Name = "Boulder Push", Kind = "Boulder", Gain = 60, StrengthRequired = 30000, RebirthsRequired = 0, X = -50, Z = 70, Color = { 130, 120, 110 } },
		{ Id = 5, Name = "Titan Weights", Kind = "Dumbbell", Gain = 260, StrengthRequired = 300000, RebirthsRequired = 1, X = -50, Z = 112, Color = { 255, 190, 60 } },
		{ Id = 6, Name = "Cosmic Anvil", Kind = "Anvil", Gain = 1300, StrengthRequired = 4000000, RebirthsRequired = 3, X = -50, Z = 154, Color = { 150, 100, 255 } },
	},
}

function TrainConfig.Get(id: number)
	return TrainConfig.Stations[id]
end

return TrainConfig
