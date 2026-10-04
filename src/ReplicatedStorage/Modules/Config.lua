-- Configurações gerais de gameplay. Ajuste o balanceamento aqui.
local Config = {
	GameName = "Kick an Egg",

	Kick = {
		BasePower = 10, -- força mínima do chute
		StrengthToPower = 1, -- quanto cada ponto de Strength soma no KickPower
		-- Distância = DistanceScale * KickPower ^ DistanceExponent * (aleatório)
		DistanceScale = 4,
		DistanceExponent = 0.45,
		RandomMin = 0.94,
		RandomMax = 1.06,
		Cooldown = 0.5, -- segundos entre o fim de um voo e o próximo chute
		MinFlightTime = 1.8,
		MaxFlightTime = 6.5,
		ZonePadding = 8, -- tolerância (studs) da zona de chute na validação do servidor
	},

	Coins = {
		PerMeter = 1, -- moedas por metro (antes dos multiplicadores)
		Minimum = 1,
	},

	Train = {
		Cooldown = 0.28, -- intervalo mínimo entre treinos manuais (servidor)
		AutoInterval = 1.0, -- Auto Train: 1 treino por segundo
		AutoRebirthsRequired = 1, -- Auto Train é liberado por Rebirth
	},

	-- Estrutura pronta para Auto Kick: basta trocar Enabled para true
	AutoKick = {
		Enabled = false,
		RebirthsRequired = 5,
		Delay = 1.0, -- espera depois de cada voo
	},

	Pets = {
		BaseEquipSlots = 3,
		MaxInventory = 60,
	},

	Data = {
		StoreName = "KickAnEgg_PlayerData_v1",
		LeaderboardStore = "KickAnEgg_BestDistance_v1",
		AutoSaveInterval = 90,
		SessionLockTimeout = 240, -- lock mais velho que isso é considerado abandonado
		MaxLoadAttempts = 6,
	},

	Camera = {
		FollowDistance = 26,
		FollowHeight = 10,
		FieldOfView = 78,
		HoldAfterLanding = 0.9,
		ReturnTime = 0.7,
	},

	-- IDs de animação opcionais (rbxassetid://...). Vazio = animação procedural.
	Animations = {
		Kick = "",
		Train = "",
	},

	Leaderboard = {
		RefreshInterval = 120,
		Size = 10,
	},
}

return Config
