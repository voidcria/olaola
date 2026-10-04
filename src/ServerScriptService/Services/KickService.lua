-- KickService: valida o chute, calcula a trajetória (servidor é a autoridade),
-- avisa todos os clientes para desenharem o voo e entrega a recompensa no pouso.
--
-- O cliente só envia "quero chutar". Distância, moedas e recorde são calculados aqui.
-- O voo é uma trajetória determinística (arco + quicadas) calculada no servidor e
-- renderizada nos clientes: zero partes físicas no servidor, resultado consistente
-- para todos e impossível de manipular pelo cliente.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules.Config)
local Formulas = require(Modules.Formulas)
local TrackConfig = require(Modules.TrackConfig)
local Remotes = require(Modules.Remotes)
local Signal = require(Modules.Signal)

local DataService = require(script.Parent.DataService)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)

local KickService = {
	Landed = Signal.new(), -- (player, distance, coins, newBest)
}

type Flight = {
	EggId: string,
	Distance: number,
	Coins: number,
	EndTime: number,
}

local flights: { [Player]: Flight } = {}
local nextKickAt: { [Player]: number } = {}
local rng = Random.new()
local limiter = RateLimiter.new(4, 4)

local flightStarted: RemoteEvent
local flightLanded: RemoteEvent

local function getRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function KickService:IsInKickZone(player: Player): boolean
	local root = getRoot(player)
	if not root then
		return false
	end
	local z = TrackConfig.KickZone
	local pad = Config.Kick.ZonePadding
	local p = root.Position
	return p.X >= z.MinX - pad
		and p.X <= z.MaxX + pad
		and p.Z >= z.MinZ - pad
		and p.Z <= z.MaxZ + pad
		and p.Y >= TrackConfig.FloorY - 10
		and p.Y <= TrackConfig.FloorY + z.Height
end

function KickService:IsFlying(player: Player): boolean
	return flights[player] ~= nil
end

local function finishFlight(player: Player, flight: Flight)
	if flights[player] ~= flight then
		return
	end
	flights[player] = nil
	nextKickAt[player] = os.clock() + Config.Kick.Cooldown
	local data = DataService:Get(player)
	if not data or not player.Parent then
		return
	end

	local previousBest = data.BestDistance
	local newBest = flight.Distance > previousBest
	data.Coins += flight.Coins
	data.TotalCoinsEarned += flight.Coins
	data.TotalKicks += 1
	data.TotalDistance += flight.Distance
	if newBest then
		data.BestDistance = flight.Distance
	end
	DataService:MarkDirty(player)

	flightLanded:FireClient(player, {
		Distance = flight.Distance,
		Coins = flight.Coins,
		NewBest = newBest,
		PreviousBest = previousBest,
		Egg = flight.EggId,
	})
	KickService.Landed:Fire(player, flight.Distance, flight.Coins, newBest)
end

-- source: "Manual" | "Auto"
function KickService:TryKick(player: Player, source: string?): boolean
	local data = DataService:Get(player)
	if not data or flights[player] then
		return false
	end
	if os.clock() < (nextKickAt[player] or 0) then
		return false
	end
	if not self:IsInKickZone(player) then
		return false
	end
	local root = getRoot(player) :: BasePart

	local eggId = Formulas.KickEgg(data)
	local power = Formulas.KickPower(data)
	local roll = rng:NextNumber(Config.Kick.RandomMin, Config.Kick.RandomMax)
	local raw = Formulas.RawDistance(power, roll)
	local maxDistance = Formulas.MaxDistance(data)
	local blocked = raw >= maxDistance
	local distance = math.floor(math.min(raw, maxDistance - (blocked and 2 or 0)) * 10) / 10
	distance = math.max(distance, 1)

	local duration = Formulas.FlightTime(distance)
	local halfWidth = TrackConfig.TrackWidth / 2 - 8
	local startX = math.clamp(root.Position.X, TrackConfig.TrackCenterX - halfWidth, TrackConfig.TrackCenterX + halfWidth)
	local drift = rng:NextNumber(-1, 1) * math.min(distance * 0.05, 30)
	local endX = math.clamp(startX + drift, TrackConfig.TrackCenterX - halfWidth, TrackConfig.TrackCenterX + halfWidth)
	-- O ovo sai da frente do jogador (dentro da zona); a distância conta a partir da linha de chute
	local startZ = math.clamp(root.Position.Z - 4, TrackConfig.KickLineZ + 1, TrackConfig.KickZone.MaxZ)

	local flight: Flight = {
		EggId = eggId,
		Distance = distance,
		Coins = Formulas.CoinReward(data, distance, eggId),
		EndTime = os.clock() + duration,
	}
	flights[player] = flight

	flightStarted:FireAllClients(player, {
		Egg = eggId,
		StartX = startX,
		StartZ = startZ,
		EndX = endX,
		Distance = distance,
		Duration = duration,
		StartTime = workspace:GetServerTimeNow(),
		Blocked = blocked,
		Seed = rng:NextInteger(1, 1000000),
		Source = source or "Manual",
	})

	task.delay(duration, finishFlight, player, flight)
	return true
end

function KickService:Init()
	flightStarted = Remotes.Event("FlightStarted")
	flightLanded = Remotes.Event("FlightLanded")
end

function KickService:Start()
	Remotes.Event("KickRequest").OnServerEvent:Connect(function(player)
		if not limiter:Check(player) then
			return
		end
		self:TryKick(player, "Manual")
	end)

	Players.PlayerRemoving:Connect(function(player)
		flights[player] = nil
		nextKickAt[player] = nil
	end)

	-- Auto Kick (desligado por padrão: Config.AutoKick.Enabled)
	if Config.AutoKick.Enabled then
		task.spawn(function()
			while true do
				task.wait(0.5)
				for _, player in Players:GetPlayers() do
					local data = DataService:Get(player)
					if
						data
						and data.AutoKick
						and data.Rebirths >= Config.AutoKick.RebirthsRequired
						and not flights[player]
						and os.clock() >= (nextKickAt[player] or 0) + Config.AutoKick.Delay
					then
						self:TryKick(player, "Auto")
					end
				end
			end
		end)
	end
end

return KickService
