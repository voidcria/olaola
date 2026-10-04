-- TrainService: levantar o peso (precisa estar segurando um peso que possui)
-- + Auto Train (liberado por Rebirth, usa o peso equipado).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules.Config)
local Formulas = require(Modules.Formulas)
local Remotes = require(Modules.Remotes)

local DataService = require(script.Parent.DataService)
local WeightService = require(script.Parent.WeightService)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)

local TrainService = {}

local limiter = RateLimiter.new(1 / Config.Train.Cooldown, 2)
local trainResult: RemoteEvent

function TrainService:Train(player: Player, weightId: string, auto: boolean)
	local data = DataService:Get(player)
	if not data then
		return
	end
	local gain = Formulas.TrainGain(data, weightId)
	data.Strength += gain
	DataService:MarkDirty(player)
	trainResult:FireClient(player, gain, auto)
end

function TrainService:CanAutoTrain(data): boolean
	return data.Rebirths >= Config.Train.AutoRebirthsRequired
end

function TrainService:Init()
	trainResult = Remotes.Event("TrainResult")
end

function TrainService:Start()
	Remotes.Event("TrainRequest").OnServerEvent:Connect(function(player)
		if not DataService:Get(player) or not limiter:Check(player) then
			return
		end
		local weightId = WeightService:HeldWeight(player)
		if not weightId then
			return
		end
		self:Train(player, weightId, false)
	end)

	-- Auto Train: um único loop para todos os jogadores
	task.spawn(function()
		while true do
			task.wait(Config.Train.AutoInterval)
			for _, player in Players:GetPlayers() do
				local data = DataService:Get(player)
				if data and data.AutoTrain and self:CanAutoTrain(data) then
					self:Train(player, data.EquippedWeight, true)
				end
			end
		end
	end)
end

return TrainService
