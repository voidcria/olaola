-- SettingsService: configurações do jogador e toggles de Auto Train / Auto Kick.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules.Config)
local Remotes = require(Modules.Remotes)

local DataService = require(script.Parent.DataService)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)

local SettingsService = {}

local ALLOWED_SETTINGS = {
	EggCamera = "boolean",
	Music = "boolean",
	Sounds = "boolean",
	ShowOtherEggs = "boolean",
}

local limiter = RateLimiter.new(5, 5)

function SettingsService:Start()
	Remotes.Function("SetSetting").OnServerInvoke = function(player, key, value)
		if type(key) ~= "string" or not limiter:Check(player) then
			return false
		end
		local expected = ALLOWED_SETTINGS[key]
		local data = DataService:Get(player)
		if not expected or type(value) ~= expected or not data then
			return false
		end
		data.Settings[key] = value
		DataService:MarkDirty(player)
		return true
	end

	Remotes.Function("SetAuto").OnServerInvoke = function(player, kind, enabled)
		if type(kind) ~= "string" or type(enabled) ~= "boolean" or not limiter:Check(player) then
			return false, "Invalid"
		end
		local data = DataService:Get(player)
		if not data then
			return false, "Data not loaded"
		end
		if kind == "AutoTrain" then
			if enabled and data.Rebirths < Config.Train.AutoRebirthsRequired then
				return false, "Auto Train unlocks at " .. Config.Train.AutoRebirthsRequired .. " Rebirth"
			end
			data.AutoTrain = enabled
		elseif kind == "AutoKick" then
			if enabled and (not Config.AutoKick.Enabled or data.Rebirths < Config.AutoKick.RebirthsRequired) then
				return false, "Auto Kick is not available yet"
			end
			data.AutoKick = enabled
		else
			return false, "Invalid"
		end
		DataService:ReplicateNow(player)
		return true
	end
end

return SettingsService
