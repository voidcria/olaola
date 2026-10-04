-- Áreas da pista. O ovo para no portão da primeira área bloqueada.
-- Requirements: Coins (custo), BestDistance, Strength, Rebirths (todos opcionais).
-- Cores em {R, G, B} para o arquivo poder ser lido também pelo build.
local AreaConfig = {
	Areas = {
		{
			Id = 1,
			Name = "Sunny Meadow",
			Start = 0,
			End = 250,
			FloorColor = { 108, 196, 84 },
			Material = "Grass",
			Requirements = {},
		},
		{
			Id = 2,
			Name = "Sandy Dunes",
			Start = 250,
			End = 700,
			FloorColor = { 236, 205, 130 },
			Material = "Sand",
			Requirements = { Coins = 1000, BestDistance = 200 },
		},
		{
			Id = 3,
			Name = "Frosty Peaks",
			Start = 700,
			End = 1600,
			FloorColor = { 220, 235, 250 },
			Material = "Snow",
			Requirements = { Coins = 40000, BestDistance = 600 },
		},
		{
			Id = 4,
			Name = "Lava Fields",
			Start = 1600,
			End = 3200,
			FloorColor = { 90, 60, 55 },
			Material = "Basalt",
			Requirements = { Coins = 5000000, BestDistance = 1450, Rebirths = 2 },
		},
		{
			Id = 5,
			Name = "Cosmic Garden",
			Start = 3200,
			End = 6000,
			FloorColor = { 70, 50, 130 },
			Material = "Glass",
			Requirements = { Coins = 750000000, BestDistance = 3000, Rebirths = 4 },
		},
	},
}

function AreaConfig.Get(id: number)
	return AreaConfig.Areas[id]
end

-- Distância máxima (fim da maior área desbloqueada)
function AreaConfig.MaxDistance(highestArea: number): number
	local area = AreaConfig.Areas[math.clamp(highestArea, 1, #AreaConfig.Areas)]
	return area.End
end

-- Área em que uma distância cai
function AreaConfig.AreaAt(distance: number)
	for _, area in AreaConfig.Areas do
		if distance < area.End then
			return area
		end
	end
	return AreaConfig.Areas[#AreaConfig.Areas]
end

return AreaConfig
