-- TutorialController: objetivo curto no topo + SETA e feixe dourado até onde o jogador deve ir.
-- Quando o objetivo é um botão da tela (Upgrades, Eggs...), o botão pisca.
-- Depois do tutorial continua dando dicas (rebirth pronto, peso novo disponível).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Formulas = require(Modules.Formulas)
local NumberFormat = require(Modules.NumberFormat)
local TrackConfig = require(Modules.TrackConfig)
local EggConfig = require(Modules.EggConfig)
local AreaConfig = require(Modules.AreaConfig)
local WeightConfig = require(Modules.WeightConfig)
local UpgradeConfig = require(Modules.UpgradeConfig)
local RebirthConfig = require(Modules.RebirthConfig)

local LocalPlayer = Players.LocalPlayer

local TutorialController = {}

local controllers
local targetPart: Part
local beam: Beam
local rootAttachment: Attachment? = nil
local arrow: BillboardGui

local FIRST_STRENGTH = 15

local kickPos = Vector3.new(TrackConfig.TrackCenterX, TrackConfig.FloorY, (TrackConfig.KickZone.MinZ + TrackConfig.KickZone.MaxZ) / 2)

local function standPos(name: string): Vector3
	local x, z = TrackConfig.StandFront(name)
	return Vector3.new(x, TrackConfig.FloorY, z)
end

local function slotPos(slotModel: Model?, partName: string): Vector3?
	local p = slotModel and slotModel:FindFirstChild(partName) :: BasePart?
	return p and p.Position
end

-- Retorna (texto, posição alvo ou nil, botão para destacar ou nil)
local function currentStep(data): (string?, Vector3?, string?)
	local upgradesBought = 0
	for _, lvl in data.Upgrades do
		upgradesBought += lvl
	end
	local Base = controllers.BaseController

	-- 1. Levantar peso
	if data.TotalKicks == 0 and data.Strength < FIRST_STRENGTH then
		return string.format("Click to lift your weight!  (%d/%d Strength)", math.floor(data.Strength), FIRST_STRENGTH), nil, "Action"
	end
	-- 2. Primeiro chute
	if data.TotalKicks == 0 then
		return "Go to the Kick Zone and KICK your egg!", kickPos, nil
	end
	-- 3. Primeiro peso novo
	local iron = WeightConfig.Get("Iron")
	if not data.OwnedWeights.Iron then
		if data.Coins < iron.Cost then
			return string.format("Kick eggs to earn coins  (%s/%s)", NumberFormat.Abbreviate(data.Coins), NumberFormat.Abbreviate(iron.Cost)), kickPos, nil
		end
		return "Buy the Iron Dumbbell at the Weight Shop!", standPos("WeightShop"), nil
	end
	-- 4. Primeiro upgrade
	if upgradesBought == 0 then
		local cheapest = math.huge
		for _, id in UpgradeConfig.Order do
			cheapest = math.min(cheapest, UpgradeConfig.Cost(id, 0))
		end
		if data.Coins < cheapest then
			return "Kick again to earn coins for an Upgrade", kickPos, nil
		end
		return "Open Upgrades and buy one!", nil, "Upgrades"
	end
	-- 5. Primeiro pet
	if Formulas.PetCount(data) == 0 then
		local cost = EggConfig.Get("Basic").HatchCost
		if data.Coins < cost then
			return string.format("Kick to earn %d coins to hatch a pet  (%s)", cost, NumberFormat.Abbreviate(data.Coins)), kickPos, nil
		end
		return "Hatch your first pet: Eggs > Hatch Pets", nil, "EggShop"
	end
	-- 6. Colocar o pet na base
	local myBase = Base:GetMyBase()
	if myBase and Formulas.PlacedCount(data) == 0 and data.TotalBaseCollected == 0 then
		local empty = Base:FindSlot("Empty")
		return "Put a pet on your base: walk to a pedestal!", slotPos(empty, "Pedestal") or myBase:GetPivot().Position, nil
	end
	-- 7. Coletar moedas da base
	if myBase and data.TotalBaseCollected == 0 then
		local ready = Base:FindSlot("Pet", true)
		if ready then
			return "Step on the green button to collect your coins!", slotPos(ready, "Pad"), nil
		end
		return "Your pet is making coins... collect them on the green button", slotPos(Base:FindSlot("Pet"), "Pad"), nil
	end
	-- 8. Rare Egg
	local rare = EggConfig.Get("Rare")
	if not data.UnlockedEggs.Rare then
		if data.Strength < rare.StrengthRequired then
			return string.format("Lift weights to %s Strength  (%s)", NumberFormat.Abbreviate(rare.StrengthRequired), NumberFormat.Abbreviate(data.Strength)), nil, "Action"
		end
		return "Unlock the Rare Egg in the Eggs menu", nil, "EggShop"
	end
	-- 9. Sandy Dunes
	if data.HighestArea < 2 then
		local area = AreaConfig.Get(2)
		if data.BestDistance < (area.Requirements.BestDistance or 0) then
			return "Kick " .. NumberFormat.Distance(area.Requirements.BestDistance) .. " to reach Sandy Dunes!", kickPos, nil
		end
		return "Unlock Sandy Dunes in the Areas menu", nil, "Areas"
	end
	-- 10. Primeiro rebirth
	if data.Rebirths == 0 then
		if Formulas.CanRebirth(data) then
			return "REBIRTH is ready! Go to the Rebirth stand", standPos("Rebirth"), nil
		end
		return string.format(
			"Rebirth goal: %s Strength + %s Coins",
			NumberFormat.Abbreviate(RebirthConfig.StrengthRequired(0)),
			NumberFormat.Abbreviate(RebirthConfig.CoinCost(0))
		), nil, nil
	end

	-- Dicas contínuas
	if Formulas.CanRebirth(data) then
		return "Rebirth is ready! Go to the Rebirth stand", standPos("Rebirth"), nil
	end
	local nextWeight = Formulas.NextWeight(data)
	if nextWeight and Formulas.CanBuyWeight(data, nextWeight) then
		return "New weight available: " .. WeightConfig.Get(nextWeight).Name .. "!", standPos("WeightShop"), nil
	end
	return nil, nil, nil
end

local function ensureRootAttachment(): (Attachment?, BasePart?)
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil, nil
	end
	if not rootAttachment or rootAttachment.Parent ~= root then
		local attachment = Instance.new("Attachment")
		attachment.Name = "TutorialAttachment"
		attachment.Parent = root
		rootAttachment = attachment
	end
	return rootAttachment, root
end

local function apply()
	local data = controllers.DataController:Get()
	if not data then
		return
	end
	local text, target, highlight = currentStep(data)
	local ui = controllers.UIController
	ui:SetObjective(text)
	ui:Highlight(highlight)
	local attachment, root = ensureRootAttachment()
	if target and attachment and root then
		targetPart.Position = target + Vector3.new(0, 3, 0)
		local flat = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
		local close = flat.Magnitude < 14
		beam.Attachment0 = attachment
		beam.Enabled = not close
		arrow.Enabled = true
	else
		beam.Enabled = false
		arrow.Enabled = false
	end
end

function TutorialController:Init(all)
	controllers = all
end

function TutorialController:Start()
	targetPart = Instance.new("Part")
	targetPart.Name = "TutorialTarget"
	targetPart.Anchored = true
	targetPart.CanCollide = false
	targetPart.CanQuery = false
	targetPart.CanTouch = false
	targetPart.Transparency = 1
	targetPart.Size = Vector3.new(1, 1, 1)
	targetPart.Position = Vector3.new(0, -500, 0)
	targetPart.Parent = workspace
	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = targetPart

	beam = Instance.new("Beam")
	beam.Attachment1 = targetAttachment
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 215, 70))
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.15, 0.35), NumberSequenceKeypoint.new(1, 0.1) })
	beam.Width0 = 0.6
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.LightEmission = 0.6
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = targetPart

	-- Seta (losango dourado com ponta para baixo)
	arrow = Instance.new("BillboardGui")
	arrow.Size = UDim2.fromOffset(70, 90)
	arrow.StudsOffset = Vector3.new(0, 5, 0)
	arrow.AlwaysOnTop = true
	arrow.Enabled = false
	arrow.Parent = targetPart
	local shaft = Instance.new("Frame")
	shaft.Size = UDim2.fromScale(0.3, 0.5)
	shaft.Position = UDim2.fromScale(0.5, 0.05)
	shaft.AnchorPoint = Vector2.new(0.5, 0)
	shaft.BackgroundColor3 = Color3.fromRGB(255, 215, 70)
	shaft.Parent = arrow
	local head = Instance.new("Frame")
	head.Size = UDim2.fromOffset(42, 42)
	head.Position = UDim2.fromScale(0.5, 0.58)
	head.AnchorPoint = Vector2.new(0.5, 0.5)
	head.Rotation = 45
	head.BackgroundColor3 = Color3.fromRGB(255, 215, 70)
	head.Parent = arrow
	for _, f in { shaft, head } do
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(120, 80, 10)
		stroke.Parent = f
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.15, 0)
		corner.Parent = f
	end

	-- Seta quicando
	RunService.Heartbeat:Connect(function()
		if arrow.Enabled then
			arrow.StudsOffset = Vector3.new(0, 6 + math.sin(os.clock() * 4) * 0.9, 0)
		end
	end)

	-- Reavalia o passo várias vezes por segundo (o estado da base muda sem DataSync)
	controllers.DataController.Changed:Connect(apply)
	task.spawn(function()
		while true do
			apply()
			task.wait(0.4)
		end
	end)
end

return TutorialController
