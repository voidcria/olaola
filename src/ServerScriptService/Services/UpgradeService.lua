-- UpgradeService: compra de upgrades (Kick Power, Strength Gain, Coin Gain, Walk Speed).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Formulas = require(Modules.Formulas)
local UpgradeConfig = require(Modules.UpgradeConfig)
local Remotes = require(Modules.Remotes)

local DataService = require(script.Parent.DataService)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)

local UpgradeService = {}

local limiter = RateLimiter.new(8, 8)

function UpgradeService:ApplyWalkSpeed(player: Player)
	local data = DataService:Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if data and humanoid then
		humanoid.WalkSpeed = Formulas.WalkSpeed(data)
	end
end

function UpgradeService:Start()
	Remotes.Function("BuyUpgrade").OnServerInvoke = function(player, upgradeId)
		if type(upgradeId) ~= "string" or not limiter:Check(player) then
			return false, "Slow down!"
		end
		local upgrade = UpgradeConfig.Get(upgradeId)
		local data = DataService:Get(player)
		if not upgrade or not data then
			return false, "Invalid upgrade"
		end
		local level = data.Upgrades[upgradeId] or 0
		if level >= upgrade.MaxLevel then
			return false, "Max level!"
		end
		local cost = UpgradeConfig.Cost(upgradeId, level)
		if data.Coins < cost then
			return false, "Not enough coins"
		end
		data.Coins -= cost
		data.Upgrades[upgradeId] = level + 1
		if upgradeId == "WalkSpeed" then
			self:ApplyWalkSpeed(player)
		end
		DataService:ReplicateNow(player)
		return true, level + 1
	end

	local function hookCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			self:ApplyWalkSpeed(player)
		end)
		if player.Character then
			self:ApplyWalkSpeed(player)
		end
	end
	DataService:OnPlayerLoaded(hookCharacter)
end

return UpgradeService
