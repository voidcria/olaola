-- TrainController: o jogador segura o peso e clica (ou toca TRAIN / tecla E) para levantar.
-- Mostra "+5 Strength" a cada levantada.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules.Remotes)
local Config = require(Modules.Config)
local Formulas = require(Modules.Formulas)
local NumberFormat = require(Modules.NumberFormat)
local WeightConfig = require(Modules.WeightConfig)

local UI = require(script.Parent.Parent:WaitForChild("UI").UIKit)
local T = UI.Theme

local LocalPlayer = Players.LocalPlayer

local TrainController = {}

local controllers
local trainRequest: RemoteEvent
local holding = false
local nextTrainAt = 0
local INTERVAL = Config.Train.Cooldown + 0.04
local hookedTools: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function findWeightTool(): (Tool?, boolean)
	local character = LocalPlayer.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("WeightId") then
				return child, true
			end
		end
	end
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in backpack:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("WeightId") then
				return child, false
			end
		end
	end
	return nil, false
end

-- Garante que o peso esteja na mão
local function ensureEquipped(): boolean
	local tool, equipped = findWeightTool()
	if not tool then
		return false
	end
	if not equipped then
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:EquipTool(tool)
		end
	end
	return true
end

function TrainController:Train()
	local now = os.clock()
	if now < nextTrainAt then
		return
	end
	if not ensureEquipped() then
		return
	end
	nextTrainAt = now + INTERVAL
	trainRequest:FireServer()
	controllers.AnimationController:PlayTrain(LocalPlayer.Character)
	controllers.SoundController:Play("Train", 0.15)
end

local function hookTool(tool: Instance)
	if tool:IsA("Tool") and tool:GetAttribute("WeightId") and not hookedTools[tool] then
		hookedTools[tool] = true
		tool.Activated:Connect(function()
			TrainController:Train()
		end)
	end
end

local function refreshAction()
	local ui = controllers.UIController
	local data = controllers.DataController:Get()
	if not data or controllers.KickController.InZone then
		if ui.Hud.ActionKind == "Train" then
			ui:SetAction(nil)
		end
		return
	end
	local weight = WeightConfig.Get(data.EquippedWeight) or WeightConfig.Get("Wooden")
	ui:SetAction("Train", "TRAIN", weight.Name .. "  +" .. NumberFormat.Abbreviate(Formulas.TrainGain(data)), T.Strength)
end

function TrainController:Init(all)
	controllers = all
	trainRequest = Remotes.Event("TrainRequest")
end

function TrainController:Start()
	local ui = controllers.UIController
	local action = ui.Hud.Action :: TextButton

	-- Sem hotbar: o peso fica sempre na mão (como nos simuladores)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	local lastCheck = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastCheck > 0.2 then
			lastCheck = now
			refreshAction()
			-- Se o peso saiu da mão (ex.: renasceu), coloca de novo
			local tool, equipped = findWeightTool()
			if tool and not equipped then
				ensureEquipped()
			end
		end
		if holding then
			self:Train()
		end
	end)

	local function onCharacter(character: Model)
		for _, child in character:GetChildren() do
			hookTool(child)
		end
		character.ChildAdded:Connect(hookTool)
	end
	LocalPlayer.CharacterAdded:Connect(onCharacter)
	if LocalPlayer.Character then
		onCharacter(LocalPlayer.Character)
	end

	action.MouseButton1Down:Connect(function()
		if ui.Hud.ActionKind == "Train" then
			holding = true
			self:Train()
		end
	end)
	action.MouseButton1Up:Connect(function()
		holding = false
	end)
	action.MouseLeave:Connect(function()
		holding = false
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if (input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX) and ui.Hud.ActionKind == "Train" then
			holding = true
			self:Train()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.KeyCode == Enum.KeyCode.E
			or input.KeyCode == Enum.KeyCode.ButtonX
			or input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			holding = false
		end
	end)

	Remotes.Event("TrainResult").OnClientEvent:Connect(function(gain, auto)
		if type(gain) ~= "number" then
			return
		end
		ui:Float("+" .. NumberFormat.Abbreviate(gain) .. " Strength", T.Strength, nil, if auto then 26 else 38)
	end)
end

return TrainController
