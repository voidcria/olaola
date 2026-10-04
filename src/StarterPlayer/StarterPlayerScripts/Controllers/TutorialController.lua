-- TutorialController: objetivos curtos no topo + seta/feixe até o próximo lugar.
-- Guia o primeiro minuto: treinar -> chutar -> comprar upgrade -> chutar de novo -> ovos -> pets -> áreas.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Formulas = require(Modules.Formulas)
local NumberFormat = require(Modules.NumberFormat)
local TrackConfig = require(Modules.TrackConfig)
local TrainConfig = require(Modules.TrainConfig)
local EggConfig = require(Modules.EggConfig)
local AreaConfig = require(Modules.AreaConfig)

local LocalPlayer = Players.LocalPlayer

local TutorialController = {}

local controllers
local targetPart: Part
local beam: Beam
local rootAttachment: Attachment? = nil
local arrow: BillboardGui

local FIRST_STRENGTH = 15

local function standPos(name: string): Vector3
	local s = TrackConfig.Stands[name]
	return Vector3.new(s.X, TrackConfig.FloorY, s.Z)
end

local kickPos = Vector3.new(TrackConfig.TrackCenterX, TrackConfig.FloorY, (TrackConfig.KickZone.MinZ + TrackConfig.KickZone.MaxZ) / 2)

-- Devolve (texto, posição alvo) do passo atual ou nil quando terminou
local function currentStep(data): (string?, Vector3?)
	local upgradesBought = 0
	for _, lvl in data.Upgrades do
		upgradesBought += lvl
	end
	local station1 = TrainConfig.Stations[1]
	if data.TotalKicks == 0 and data.Strength < FIRST_STRENGTH then
		return string.format("Train at the Training Dummy  (%d/%d)", math.floor(data.Strength), FIRST_STRENGTH), Vector3.new(station1.X, 0, station1.Z)
	end
	if data.TotalKicks == 0 then
		return "Go to the kick zone and KICK your egg!", kickPos
	end
	if upgradesBought == 0 then
		local cost = 20
		if data.Coins < cost then
			return "Kick again to earn more coins!", kickPos
		end
		return "Buy an upgrade at the Upgrades stand", standPos("Upgrades")
	end
	if data.TotalKicks < 3 then
		return "Kick again - you're stronger now!", kickPos
	end
	local rare = EggConfig.Get("Rare")
	if not data.UnlockedEggs.Rare then
		if data.Strength < rare.StrengthRequired then
			return string.format("Train to %s Strength for the Rare Egg  (%s)", NumberFormat.Abbreviate(rare.StrengthRequired), NumberFormat.Abbreviate(data.Strength)), nil
		end
		return "Unlock the Rare Egg at the Egg Shop", standPos("EggShop")
	end
	if Formulas.PetCount(data) == 0 then
		return "Hatch your first pet at the Hatchery", standPos("Hatchery")
	end
	if data.HighestArea < 2 then
		local area = AreaConfig.Get(2)
		if data.BestDistance < (area.Requirements.BestDistance or 0) then
			return "Kick " .. NumberFormat.Distance(area.Requirements.BestDistance) .. " to reach Sandy Dunes!", nil
		end
		return "Unlock Sandy Dunes at the Areas board", standPos("Areas")
	end
	return nil, nil
end

local function ensureRootAttachment()
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	if not rootAttachment or rootAttachment.Parent ~= root then
		local attachment = Instance.new("Attachment")
		attachment.Name = "TutorialAttachment"
		attachment.Parent = root
		rootAttachment = attachment
	end
	return rootAttachment
end

local function apply(data)
	local text, target = currentStep(data)
	controllers.UIController:SetObjective(text)
	local attachment = ensureRootAttachment()
	if target and attachment then
		targetPart.Position = target + Vector3.new(0, 3, 0)
		beam.Attachment0 = attachment
		beam.Enabled = true
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

	arrow = Instance.new("BillboardGui")
	arrow.Size = UDim2.fromOffset(60, 60)
	arrow.StudsOffset = Vector3.new(0, 5, 0)
	arrow.AlwaysOnTop = true
	arrow.Enabled = false
	arrow.Parent = targetPart
	local diamond = Instance.new("Frame")
	diamond.Size = UDim2.fromScale(0.55, 0.55)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = Color3.fromRGB(255, 215, 70)
	diamond.Parent = arrow
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(120, 80, 10)
	stroke.Parent = diamond
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.15, 0)
	corner.Parent = diamond

	-- Seta quicando
	RunService.Heartbeat:Connect(function()
		if arrow.Enabled then
			arrow.StudsOffset = Vector3.new(0, 5 + math.sin(os.clock() * 4) * 0.8, 0)
		end
	end)

	local DataController = controllers.DataController
	DataController.Changed:Connect(apply)
	LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.5)
		local data = DataController:Get()
		if data then
			apply(data)
		end
	end)
	if DataController:Get() then
		apply(DataController:Get())
	end
end

return TutorialController
