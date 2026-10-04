-- WeightService: Weight Shop (comprar/equipar pesos) e o Tool do peso na mão do jogador.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local WeightConfig = require(Modules.WeightConfig)
local Remotes = require(Modules.Remotes)
local WeightModels = require(Modules.Models.WeightModels)

local DataService = require(script.Parent.DataService)
local RateLimiter = require(ServerScriptService.Util.RateLimiter)

local WeightService = {}

local limiter = RateLimiter.new(5, 5)

local function removeWeightTools(player: Player)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("WeightId") then
					child:Destroy()
				end
			end
		end
	end
end

-- Dá (ou troca) o peso equipado e já coloca na mão
function WeightService:GiveTool(player: Player)
	local data = DataService:Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not humanoid or not backpack then
		return
	end
	removeWeightTools(player)
	local tool = WeightModels.BuildTool(data.EquippedWeight)
	tool.Parent = backpack
	humanoid:EquipTool(tool)
end

-- O jogador está segurando um peso que possui?
function WeightService:HeldWeight(player: Player): string?
	local data = DataService:Get(player)
	local character = player.Character
	if not data or not character then
		return nil
	end
	local tool = character:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("WeightId")
	if type(id) == "string" and data.OwnedWeights[id] then
		return id
	end
	return nil
end

function WeightService:Start()
	Remotes.Function("BuyWeight").OnServerInvoke = function(player, weightId)
		if type(weightId) ~= "string" or not limiter:Check(player) then
			return false, "Slow down!"
		end
		local weight = WeightConfig.Get(weightId)
		local data = DataService:Get(player)
		if not weight or not data then
			return false, "Invalid weight"
		end
		if data.OwnedWeights[weightId] then
			return false, "Already owned"
		end
		if data.Rebirths < weight.RebirthsRequired then
			return false, "Requires " .. weight.RebirthsRequired .. " Rebirth" .. (if weight.RebirthsRequired > 1 then "s" else "")
		end
		if data.Coins < weight.Cost then
			return false, "Not enough coins"
		end
		data.Coins -= weight.Cost
		data.OwnedWeights[weightId] = true
		data.EquippedWeight = weightId
		DataService:ReplicateNow(player)
		self:GiveTool(player)
		return true
	end

	Remotes.Function("EquipWeight").OnServerInvoke = function(player, weightId)
		if type(weightId) ~= "string" or not limiter:Check(player) then
			return false, "Slow down!"
		end
		local data = DataService:Get(player)
		if not data or not data.OwnedWeights[weightId] then
			return false, "You don't own this weight"
		end
		data.EquippedWeight = weightId
		DataService:ReplicateNow(player)
		self:GiveTool(player)
		return true
	end

	DataService:OnPlayerLoaded(function(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid", 10)
			player:WaitForChild("Backpack", 10)
			task.wait(0.2)
			self:GiveTool(player)
		end)
		if player.Character then
			self:GiveTool(player)
		end
	end)
end

return WeightService
