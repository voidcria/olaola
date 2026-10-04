-- GateController: abre/fecha (localmente) os portões das áreas da pista
-- e atualiza as placas com os requisitos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AreaConfig = require(Modules.AreaConfig)
local NumberFormat = require(Modules.NumberFormat)

local GateController = {}

local controllers

local function requirementsText(area): string
	local req = area.Requirements
	local parts = {}
	if req.Coins then
		table.insert(parts, NumberFormat.Abbreviate(req.Coins) .. " Coins")
	end
	if req.BestDistance then
		table.insert(parts, "Best " .. NumberFormat.Distance(req.BestDistance))
	end
	if req.Rebirths then
		table.insert(parts, req.Rebirths .. " Rebirths")
	end
	return table.concat(parts, "  |  ")
end

local function apply(data)
	local map = workspace:FindFirstChild("Map")
	local gates = map and map:FindFirstChild("Track") and map.Track:FindFirstChild("Gates")
	if not gates then
		return
	end
	for _, gate in gates:GetChildren() do
		local areaId = gate:GetAttribute("AreaId")
		local area = type(areaId) == "number" and AreaConfig.Get(areaId)
		if area then
			local open = areaId <= data.HighestArea
			for _, part in gate:GetDescendants() do
				if part:IsA("BasePart") and part.Name == "Barrier" then
					part.Transparency = if open then 1 else 0.45
					part.CanCollide = not open
				end
			end
			local info = gate:FindFirstChild("Info", true)
			if info and info:IsA("TextLabel") then
				info.Text = if open then "UNLOCKED" else requirementsText(area)
				info.TextColor3 = if open then Color3.fromRGB(120, 255, 140) else Color3.fromRGB(255, 220, 120)
			end
		end
	end
end

function GateController:Init(all)
	controllers = all
end

function GateController:Start()
	local last = -1
	controllers.DataController.Changed:Connect(function(data)
		if data.HighestArea ~= last then
			last = data.HighestArea
			apply(data)
		end
	end)
	if controllers.DataController:Get() then
		apply(controllers.DataController:Get())
	end
end

return GateController
