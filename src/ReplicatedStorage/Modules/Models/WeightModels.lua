-- Modelos dos pesos: para a loja (ViewportFrame) e como Tool na mão do jogador.
-- Se existir ReplicatedStorage.Assets.Weights[<Model>], usa o seu modelo.
-- A barra fica no eixo X (atravessa a mão), placas nas pontas.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = script.Parent.Parent
local WeightConfig = require(Modules.WeightConfig)

local WeightModels = {}

local function rgb(t): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function part(model: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function findCustom(weight): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Weights")
	local custom = folder and folder:FindFirstChild(weight.Model)
	if custom and custom:IsA("Model") then
		local clone = custom:Clone()
		if not clone.PrimaryPart then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
		end
		return clone
	end
	return nil
end

-- Modelo ancorado (centro na origem). PrimaryPart = "Handle" (a pegada).
function WeightModels.Build(weightId: string): Model
	local weight = WeightConfig.Get(weightId) or WeightConfig.Get("Wooden")
	local custom = findCustom(weight)
	if custom then
		for _, d in custom:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		return custom
	end

	local c1 = rgb(weight.Colors[1])
	local c2 = rgb(weight.Colors[2])
	local plateMaterial = if weight.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local model = Instance.new("Model")
	model.Name = weight.Name

	local handle: Part
	if weight.Kind == "Kettlebell" then
		handle = part(model, "Handle", Vector3.new(1.4, 0.35, 0.35), CFrame.new(0, 0, 0), c1, Enum.PartType.Cylinder)
		for _, x in { -0.6, 0.6 } do
			part(model, "HandleSide", Vector3.new(0.35, 0.9, 0.35), CFrame.new(x, -0.4, 0), c1)
		end
		part(model, "Bell", Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, -1.7, 0), c1, Enum.PartType.Ball)
		part(model, "Band", Vector3.new(0.4, 2.3, 2.3), CFrame.new(0, -1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), c2, Enum.PartType.Cylinder, plateMaterial)
	else
		local barbell = weight.Kind == "Barbell"
		local length = if barbell then 4.6 else 2.4
		local plate = if barbell then 1.9 else 1.3
		handle = part(model, "Handle", Vector3.new(length, 0.3, 0.3), CFrame.new(), c1, Enum.PartType.Cylinder, Enum.Material.Metal)
		for _, s in { -1, 1 } do
			local x = s * (length / 2 - 0.35)
			part(model, "Plate", Vector3.new(0.4, plate, plate), CFrame.new(x, 0, 0), c2, Enum.PartType.Cylinder, plateMaterial)
			part(model, "Plate", Vector3.new(0.3, plate * 0.75, plate * 0.75), CFrame.new(x - s * 0.35, 0, 0), c1, Enum.PartType.Cylinder)
		end
	end
	model.PrimaryPart = handle

	if weight.Glow then
		local light = Instance.new("PointLight")
		light.Color = c2
		light.Range = 6
		light.Brightness = 1
		light.Parent = handle
	end
	return model
end

-- Tool para a mão do jogador (partes soldadas no Handle, sem âncora)
function WeightModels.BuildTool(weightId: string): Tool
	local weight = WeightConfig.Get(weightId) or WeightConfig.Get("Wooden")
	local model = WeightModels.Build(weight.Id)
	local tool = Instance.new("Tool")
	tool.Name = weight.Name
	tool.ToolTip = "+" .. weight.Gain .. " Strength"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("WeightId", weight.Id)

	local handle = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart") :: BasePart
	handle.Name = "Handle"
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
			if d ~= handle then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = handle
				weld.Part1 = d
				weld.Parent = d
			end
		end
	end
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	-- Segura o peso um pouco à frente da mão
	tool.Grip = CFrame.new(0, 0, 0)
	return tool
end

return WeightModels
