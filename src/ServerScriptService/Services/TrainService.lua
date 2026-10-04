-- TrainService: treino manual nas estações do mapa + Auto Train (liberado por Rebirth).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules.Config)
local Formulas = require(Modules.Formulas)
local TrainConfig = require(Modules.TrainConfig)
local TrackConfig = require(Modules.TrackConfig)
local Remotes = require(Modules.Remotes)

local DataService = require(script.Parent.DataService)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)
local Notify = require(ServerScriptService.Util.Notify)

local TrainService = {}

local limiter = RateLimiter.new(1 / Config.Train.Cooldown, 2)
local trainResult: RemoteEvent

local function nearStation(player: Player, station): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local p = root.Position
	local dx, dz = p.X - station.X, p.Z - station.Z
	return dx * dx + dz * dz <= (TrainConfig.Radius + 4) ^ 2 and math.abs(p.Y - TrackConfig.FloorY) < 25
end

function TrainService:Train(player: Player, stationId: number, auto: boolean)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local gain = Formulas.TrainGain(data, stationId)
	data.Strength += gain
	DataService:MarkDirty(player)
	trainResult:FireClient(player, gain, if auto then 0 else stationId)
end

function TrainService:CanAutoTrain(data): boolean
	return data.Rebirths >= Config.Train.AutoRebirthsRequired
end

function TrainService:Init()
	trainResult = Remotes.Event("TrainResult")
end

function TrainService:Start()
	Remotes.Event("TrainRequest").OnServerEvent:Connect(function(player, stationId)
		if type(stationId) ~= "number" or stationId ~= stationId then
			return
		end
		stationId = math.floor(stationId)
		local station = TrainConfig.Get(stationId)
		local data = DataService:Get(player)
		if not station or not data then
			return
		end
		if not limiter:Check(player) then
			return
		end
		if not Formulas.CanUseStation(data, stationId) then
			Notify(player, "This station is locked!", "Error")
			return
		end
		if not nearStation(player, station) then
			return
		end
		self:Train(player, stationId, false)
	end)

	-- Auto Train: um único loop para todos os jogadores
	task.spawn(function()
		while true do
			task.wait(Config.Train.AutoInterval)
			for _, player in Players:GetPlayers() do
				local data = DataService:Get(player)
				if data and data.AutoTrain and self:CanAutoTrain(data) then
					self:Train(player, Formulas.BestStation(data), true)
				end
			end
		end
	end)
end

return TrainService
