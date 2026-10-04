-- KickController: zona de chute, ovo na frente do jogador, botão KICK, desenho dos voos
-- (seu e dos outros jogadores), contador de metros e resultado do chute.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules.Remotes)
local NumberFormat = require(Modules.NumberFormat)
local Formulas = require(Modules.Formulas)
local EggConfig = require(Modules.EggConfig)
local AreaConfig = require(Modules.AreaConfig)
local TrackConfig = require(Modules.TrackConfig)
local FlightPath = require(Modules.FlightPath)
local EggModels = require(Modules.Models.EggModels)

local UI = require(script.Parent.Parent:WaitForChild("UI").UIKit)
local T = UI.Theme

local LocalPlayer = Players.LocalPlayer

local KickController = {
	InZone = false,
}

local controllers
local eggsFolder: Folder
local restEgg: Model? = nil
local restEggId: string? = nil
local waitingSince: number? = nil
local localFlight = nil
local flights = {}
local MAX_OTHER_FLIGHTS = 8
local EGG_SCALE = 1.35

local kickRequest: RemoteEvent

local function getRoot(): BasePart?
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function inKickZone(pos: Vector3): boolean
	local z = TrackConfig.KickZone
	return pos.X >= z.MinX and pos.X <= z.MaxX and pos.Z >= z.MinZ and pos.Z <= z.MaxZ and pos.Y < TrackConfig.FloorY + z.Height
end

local function eggHalfHeight(): number
	return 1.5 * EGG_SCALE
end

local function addTrail(model: Model, color: Color3)
	local shell = model.PrimaryPart
	if not shell then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.6, 0)
	a0.Parent = shell
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.6, 0)
	a1.Parent = shell
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.35
	trail.FaceCamera = true
	trail.LightEmission = 0.4
	trail.Parent = shell
end

----------------------------------------------------------------------
-- Ovo parado na frente do jogador
----------------------------------------------------------------------
local function updateRestEgg(show: boolean, root: BasePart?)
	local data = controllers.DataController:Get()
	if not show or not data or not root then
		if restEgg then
			restEgg.Parent = nil
		end
		return
	end
	local eggId = Formulas.KickEgg(data)
	if restEggId ~= eggId then
		if restEgg then
			restEgg:Destroy()
		end
		restEgg = EggModels.Build(eggId, EGG_SCALE)
		restEggId = eggId
	end
	local egg = restEgg :: Model
	local halfWidth = TrackConfig.TrackWidth / 2 - 8
	local x = math.clamp(root.Position.X, TrackConfig.TrackCenterX - halfWidth, TrackConfig.TrackCenterX + halfWidth)
	local z = math.clamp(root.Position.Z - 4, TrackConfig.KickLineZ + 1, TrackConfig.KickZone.MaxZ)
	local bob = math.sin(os.clock() * 3) * 0.08
	egg:PivotTo(CFrame.new(x, TrackConfig.FloorY + eggHalfHeight() + bob, z) * CFrame.Angles(0, os.clock() * 0.6, 0))
	if egg.Parent ~= eggsFolder then
		egg.Parent = eggsFolder
	end
end

----------------------------------------------------------------------
-- Chute
----------------------------------------------------------------------
function KickController:Kick()
	if not self.InZone or localFlight or waitingSince then
		return
	end
	local root = getRoot()
	if not root then
		return
	end
	waitingSince = os.clock()
	-- Vira o personagem para a pista
	root.CFrame = CFrame.lookAt(root.Position, root.Position + Vector3.new(0, 0, -1))
	controllers.AnimationController:PlayKick(LocalPlayer.Character)
	task.delay(0.14, function()
		kickRequest:FireServer()
	end)
end

local function finishFlightVisual(flight)
	flight.Landed = true
	local model = flight.Model :: Model
	local pos = model:GetPivot().Position
	controllers.EffectsController:Dust(Vector3.new(pos.X, TrackConfig.FloorY + 0.5, pos.Z), 18)
	task.delay(1.6, function()
		-- encolhe e some
		local start = os.clock()
		local base = model:GetPivot()
		while os.clock() - start < 0.3 and model.Parent do
			local a = (os.clock() - start) / 0.3
			model:PivotTo(base * CFrame.new(0, -a * 1.5, 0))
			task.wait()
		end
		model:Destroy()
	end)
end

local function onFlightStarted(player: Player, info)
	if type(info) ~= "table" or type(info.Distance) ~= "number" then
		return
	end
	local isLocal = player == LocalPlayer
	local data = controllers.DataController:Get()
	if not isLocal then
		if data and data.Settings and data.Settings.ShowOtherEggs == false then
			return
		end
		local others = 0
		for _, f in flights do
			if not f.IsLocal then
				others += 1
			end
		end
		if others >= MAX_OTHER_FLIGHTS then
			return
		end
		if player.Character then
			controllers.AnimationController:PlayKick(player.Character)
		end
	end

	local egg = EggConfig.Get(info.Egg) or EggConfig.Get("Basic")
	local model = EggModels.Build(egg.Id, EGG_SCALE)
	addTrail(model, UI.rarityColor(egg.Rarity))
	model.Parent = eggsFolder

	local offset = workspace:GetServerTimeNow() - info.StartTime
	local flight = {
		Info = info,
		Model = model,
		IsLocal = isLocal,
		StartClock = os.clock() - math.max(0, offset),
		Landed = false,
		BestProgress = 0,
		AreaId = 1,
		Spin = 0,
	}
	table.insert(flights, flight)

	local startPos = Vector3.new(info.StartX, TrackConfig.FloorY + eggHalfHeight(), info.StartZ or TrackConfig.KickLineZ)
	model:PivotTo(CFrame.new(startPos))
	controllers.EffectsController:Impact(startPos, UI.rarityColor(egg.Rarity), isLocal)

	if isLocal then
		waitingSince = nil
		localFlight = flight
		updateRestEgg(false, nil)
		controllers.SoundController:Play("Kick", 0.08)
		controllers.SoundController:Play("Impact", 0.1)
		local settings = data and data.Settings
		controllers.CameraController:FollowEgg(model, info, settings == nil or settings.EggCamera ~= false)
		local ui = controllers.UIController
		ui.Hud.Distance.Visible = true
		ui.Hud.DistanceText.Text = "0m"
		ui.Hud.DistanceText.TextColor3 = T.Text
		ui.Hud.DistanceSub.Text = AreaConfig.Areas[1].Name
		ui:SetAction(nil)
	end
end

local function onFlightLanded(result)
	if type(result) ~= "table" then
		return
	end
	local ui = controllers.UIController
	ui.Hud.DistanceText.Text = NumberFormat.Distance(result.Distance)
	UI.pop(ui.Hud.DistanceText, 1.3)
	controllers.SoundController:Play("Coins", 0.05)
	ui:Float("+" .. NumberFormat.Abbreviate(result.Coins) .. " Coins", T.Gold, "Center", 48)
	if result.NewBest then
		ui.Hud.DistanceSub.Text = ""
		controllers.EffectsController:NewBest(result.Distance, result.PreviousBest)
	else
		ui.Hud.DistanceSub.Text = "+" .. NumberFormat.Abbreviate(result.Coins) .. " Coins"
	end
	controllers.CameraController:Release()
	local thisFlight = localFlight
	task.delay(2.2, function()
		if localFlight == thisFlight or localFlight == nil then
			ui.Hud.Distance.Visible = false
		end
	end)
	if localFlight then
		localFlight.Done = true
	end
	localFlight = nil
end

----------------------------------------------------------------------
-- Loop único para todos os voos
----------------------------------------------------------------------
local function step(_dt: number)
	local now = os.clock()
	for i = #flights, 1, -1 do
		local f = flights[i]
		if not f.Model.Parent then
			table.remove(flights, i)
			continue
		end
		if f.Landed then
			continue
		end
		local info = f.Info
		local t = (now - f.StartClock) / info.Duration
		local x, h, z = FlightPath.Sample(info, t)
		local pos = Vector3.new(x, TrackConfig.FloorY + eggHalfHeight() + h, z)
		local traveled = FlightPath.DistanceAt(z)
		-- Rotação: rola para frente + gira no ar
		f.Spin = traveled / eggHalfHeight() + (if h > 0.5 then t * 25 else 0)
		f.Model:PivotTo(CFrame.new(pos) * CFrame.Angles(-f.Spin, 0, math.sin(t * 20) * 0.2 * math.min(h, 1)))

		if f.IsLocal then
			if traveled > f.BestProgress then
				f.BestProgress = traveled
				local ui = controllers.UIController
				ui.Hud.DistanceText.Text = NumberFormat.Distance(traveled)
				local area = AreaConfig.AreaAt(traveled)
				if area.Id ~= f.AreaId then
					f.AreaId = area.Id
					ui.Hud.DistanceSub.Text = area.Name .. "!"
					UI.pop(ui.Hud.DistanceSub, 1.4)
					controllers.SoundController:Play("Tick", 0, 0.8)
				end
			end
		end

		if t >= 1 then
			finishFlightVisual(f)
			if f.IsLocal and info.Blocked then
				controllers.UIController:Toast("Your egg hit a locked gate! Unlock the next Area to go further.", "Info")
			end
		end
	end

	-- Zona de chute
	local root = getRoot()
	local inZone = root ~= nil and inKickZone((root :: BasePart).Position)
	if inZone ~= KickController.InZone then
		KickController.InZone = inZone
	end
	local ui = controllers.UIController
	if waitingSince and now - waitingSince > 2 then
		waitingSince = nil -- o servidor recusou (cooldown etc.)
	end
	if inZone and not localFlight then
		updateRestEgg(true, root)
		local data = controllers.DataController:Get()
		if data then
			local eggId = Formulas.KickEgg(data)
			local egg = EggConfig.Get(eggId)
			ui:SetAction("Kick", "KICK!", egg.Name .. "  " .. NumberFormat.Multiplier(Formulas.CoinMultiplier(data, eggId)) .. " Coins", T.Orange)
		end
	else
		updateRestEgg(false, nil)
		if ui.Hud.ActionKind == "Kick" then
			ui:SetAction(nil)
		end
	end
end

function KickController:Init(all)
	controllers = all
	kickRequest = Remotes.Event("KickRequest")
end

function KickController:Start()
	eggsFolder = Instance.new("Folder")
	eggsFolder.Name = "KickedEggs"
	eggsFolder.Parent = workspace

	Remotes.Event("FlightStarted").OnClientEvent:Connect(onFlightStarted)
	Remotes.Event("FlightLanded").OnClientEvent:Connect(onFlightLanded)
	RunService.RenderStepped:Connect(step)

	local ui = controllers.UIController
	ui.Hud.Action.Activated:Connect(function()
		if ui.Hud.ActionKind == "Kick" then
			self:Kick()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
			if ui.Hud.ActionKind == "Kick" then
				self:Kick()
			end
		end
	end)
end

return KickController
