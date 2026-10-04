-- TrainController: detecta a estação de treino próxima, mostra o botão TRAIN
-- (toque ou segure / tecla E) e exibe "+5 Strength".
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules.Remotes)
local Config = require(Modules.Config)
local Formulas = require(Modules.Formulas)
local NumberFormat = require(Modules.NumberFormat)
local TrainConfig = require(Modules.TrainConfig)
local TrackConfig = require(Modules.TrackConfig)

local UI = require(script.Parent.Parent:WaitForChild("UI").UIKit)
local T = UI.Theme

local LocalPlayer = Players.LocalPlayer

local TrainController = {
	Station = nil :: number?,
}

local controllers
local trainRequest: RemoteEvent
local holding = false
local nextTrainAt = 0
local lastCheck = 0
local INTERVAL = Config.Train.Cooldown + 0.04

local function nearestStation(): number?
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local p = root.Position
	if math.abs(p.Y - TrackConfig.FloorY) > 20 then
		return nil
	end
	local best, bestDist = nil, TrainConfig.Radius ^ 2
	for _, station in TrainConfig.Stations do
		local dx, dz = p.X - station.X, p.Z - station.Z
		local d = dx * dx + dz * dz
		if d <= bestDist then
			best, bestDist = station.Id, d
		end
	end
	return best
end

function TrainController:Train()
	local stationId = self.Station
	local data = controllers.DataController:Get()
	if not stationId or not data or not Formulas.CanUseStation(data, stationId) then
		return
	end
	local now = os.clock()
	if now < nextTrainAt then
		return
	end
	nextTrainAt = now + INTERVAL
	trainRequest:FireServer(stationId)
	controllers.AnimationController:PlayTrain(LocalPlayer.Character)
	controllers.SoundController:Play("Train", 0.15)
end

local function refreshAction()
	local ui = controllers.UIController
	local data = controllers.DataController:Get()
	local stationId = TrainController.Station
	if not stationId or not data then
		if ui.Hud.ActionKind == "Train" then
			ui:SetAction(nil)
		end
		return
	end
	local station = TrainConfig.Get(stationId)
	if Formulas.CanUseStation(data, stationId) then
		ui:SetAction("Train", "TRAIN", station.Name .. "  +" .. NumberFormat.Abbreviate(Formulas.TrainGain(data, stationId)), T.Strength)
	else
		local need = {}
		if data.Strength < station.StrengthRequired then
			table.insert(need, NumberFormat.Abbreviate(station.StrengthRequired) .. " Strength")
		end
		if data.Rebirths < station.RebirthsRequired then
			table.insert(need, station.RebirthsRequired .. " Rebirth" .. (if station.RebirthsRequired > 1 then "s" else ""))
		end
		ui:SetAction("Train", "LOCKED", "Needs " .. table.concat(need, " + "), T.Gray)
	end
end

function TrainController:Init(all)
	controllers = all
	trainRequest = Remotes.Event("TrainRequest")
end

function TrainController:Start()
	local ui = controllers.UIController
	local action = ui.Hud.Action :: TextButton

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastCheck > 0.15 then
			lastCheck = now
			local station = nearestStation()
			if station ~= self.Station then
				self.Station = station
			end
			refreshAction()
		end
		if holding and self.Station then
			self:Train()
		end
	end)

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
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = false
		end
	end)

	Remotes.Event("TrainResult").OnClientEvent:Connect(function(gain, stationId)
		if type(gain) ~= "number" then
			return
		end
		local auto = stationId == 0
		ui:Float("+" .. NumberFormat.Abbreviate(gain) .. " Strength", T.Strength, nil, if auto then 26 else 38)
	end)
end

return TrainController
