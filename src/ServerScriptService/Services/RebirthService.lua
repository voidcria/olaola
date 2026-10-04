-- RebirthService: reseta Coins e Strength em troca de multiplicadores permanentes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Formulas = require(Modules.Formulas)
local RebirthConfig = require(Modules.RebirthConfig)
local Remotes = require(Modules.Remotes)

local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)

local RebirthService = {}

local limiter = RateLimiter.new(0.5, 1)

function RebirthService:Start()
	Remotes.Function("Rebirth").OnServerInvoke = function(player)
		if not limiter:Check(player) then
			return false, "Slow down!"
		end
		local data = DataService:Get(player)
		if not data then
			return false, "Data not loaded"
		end
		local ok, missing = Formulas.CanRebirth(data)
		if not ok then
			return false, if missing == "Strength" then "Not enough Strength" else "Not enough coins"
		end
		if RebirthConfig.Resets.Coins then
			data.Coins = 0
		end
		if RebirthConfig.Resets.Strength then
			data.Strength = 0
		end
		data.Rebirths += 1
		PetService:UpdateEquippedAttribute(player)
		DataService:ReplicateNow(player)
		Remotes.Event("Celebrate"):FireClient(player, "Rebirth", data.Rebirths)
		return true, data.Rebirths
	end
end

return RebirthService
