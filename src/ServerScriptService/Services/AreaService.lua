-- AreaService: desbloqueio sequencial das áreas da pista.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Formulas = require(Modules.Formulas)
local AreaConfig = require(Modules.AreaConfig)
local Remotes = require(Modules.Remotes)

local DataService = require(script.Parent.DataService)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)

local AreaService = {}

local limiter = RateLimiter.new(2, 2)

function AreaService:Start()
	Remotes.Function("UnlockArea").OnServerInvoke = function(player, areaId)
		if type(areaId) ~= "number" or not limiter:Check(player) then
			return false, "Slow down!"
		end
		local data = DataService:Get(player)
		local area = AreaConfig.Get(math.floor(areaId))
		if not data or not area then
			return false, "Invalid area"
		end
		if area.Id <= data.HighestArea then
			return false, "Already unlocked"
		end
		if area.Id ~= data.HighestArea + 1 then
			return false, "Unlock the previous area first"
		end
		local ok, missing = Formulas.MeetsRequirements(data, area.Requirements)
		if not ok then
			local messages = {
				Coins = "Not enough coins",
				Strength = "Not enough Strength",
				Rebirths = "Requires " .. tostring(area.Requirements.Rebirths) .. " Rebirths",
				BestDistance = "Kick an egg at least " .. tostring(area.Requirements.BestDistance) .. "m first",
			}
			return false, messages[missing :: string] or "Requirements not met"
		end
		data.Coins -= area.Requirements.Coins or 0
		data.HighestArea = area.Id
		DataService:ReplicateNow(player)
		Remotes.Event("Celebrate"):FireClient(player, "AreaUnlocked", area.Id)
		return true
	end
end

return AreaService
