-- BaseController: interação com a sua base (colocar/pegar pets, liberar slots),
-- efeito ao coletar moedas e animação dos pets nos pedestais.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules.Remotes)
local NumberFormat = require(Modules.NumberFormat)

local UI = require(script.Parent.Parent:WaitForChild("UI").UIKit)
local T = UI.Theme

local LocalPlayer = Players.LocalPlayer

local BaseController = {}

local controllers
local basesFolder: Instance? = nil
local restPivots: { [Model]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local function isMine(base: Instance): boolean
	return base:GetAttribute("OwnerId") == LocalPlayer.UserId
end

-- Só o dono vê os prompts da própria base
local function refreshPrompts(base: Instance)
	local mine = isMine(base)
	for _, d in base:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d.Enabled = mine
		end
	end
end

function BaseController:GetMyBase(): Model?
	if not basesFolder then
		return nil
	end
	for _, base in basesFolder:GetChildren() do
		if base:IsA("Model") and isMine(base) then
			return base
		end
	end
	return nil
end

function BaseController:GetSlot(slot: number): Model?
	local base = self:GetMyBase()
	local slots = base and base:FindFirstChild("Slots")
	return slots and slots:FindFirstChild("Slot" .. slot) :: Model?
end

-- Primeiro slot com o estado pedido (Empty / Pet / Locked)
function BaseController:FindSlot(state: string, needStored: boolean?): Model?
	for slot = 1, 8 do
		local m = self:GetSlot(slot)
		if m and m:GetAttribute("State") == state and (not needStored or (m:GetAttribute("Stored") or 0) > 0) then
			return m
		end
	end
	return nil
end

local function onPrompt(prompt: ProximityPrompt)
	local slot = prompt:GetAttribute("BaseSlot")
	if type(slot) ~= "number" then
		return
	end
	local slotModel = prompt:FindFirstAncestorWhichIsA("Model")
	local state = slotModel and slotModel:GetAttribute("State")
	local ui = controllers.UIController
	if state == "Empty" then
		ui:OpenPanel("Pets", { Mode = "Place", Slot = slot })
	elseif state == "Pet" then
		if ui:Invoke("BaseAction", "PickUp", slot, nil) then
			ui:Toast("Pet returned to your inventory", "Info")
		end
	elseif state == "Locked" then
		if ui:Invoke("BaseAction", "Unlock", slot, nil) then
			controllers.SoundController:Play("Reveal")
			ui:Toast("New slot unlocked!", "Success")
		end
	end
end

function BaseController:Init(all)
	controllers = all
end

function BaseController:Start()
	local map = workspace:WaitForChild("Map", 30)
	basesFolder = map and map:WaitForChild("Bases", 30)
	if basesFolder then
		for _, base in basesFolder:GetChildren() do
			refreshPrompts(base)
			base:GetAttributeChangedSignal("OwnerId"):Connect(function()
				refreshPrompts(base)
			end)
		end
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player == LocalPlayer then
			onPrompt(prompt)
		end
	end)

	Remotes.Event("BaseCollected").OnClientEvent:Connect(function(amount, slot)
		if type(amount) ~= "number" then
			return
		end
		controllers.SoundController:Play("Coins", 0.1)
		controllers.UIController:Float("+" .. NumberFormat.Abbreviate(amount) .. " Coins", T.Gold, "Center", 44)
		local slotModel = type(slot) == "number" and self:GetSlot(slot)
		local pad = slotModel and slotModel:FindFirstChild("Pad") :: BasePart?
		if pad then
			controllers.EffectsController:Impact(pad.Position + Vector3.new(0, 1, 0), T.Gold, false)
		end
	end)

	-- Pets nos pedestais flutuam e balançam (só no cliente, perto da câmera)
	RunService.RenderStepped:Connect(function()
		if not basesFolder then
			return
		end
		local camera = workspace.CurrentCamera
		local camPos = camera and camera.CFrame.Position or Vector3.zero
		local t = os.clock()
		for _, base in basesFolder:GetChildren() do
			if (base:GetPivot().Position - camPos).Magnitude < 160 then
				local slots = base:FindFirstChild("Slots")
				for i, slotModel in (slots and slots:GetChildren()) or {} do
					local pet = slotModel:FindFirstChild("PetModel")
					if pet and pet:IsA("Model") then
						local rest = restPivots[pet]
						if not rest then
							rest = pet:GetPivot()
							restPivots[pet] = rest
						end
						pet:PivotTo(rest * CFrame.new(0, math.sin(t * 2 + i) * 0.35, 0) * CFrame.Angles(0, math.sin(t * 0.8 + i) * 0.35, 0))
					end
				end
			end
		end
	end)
end

return BaseController
