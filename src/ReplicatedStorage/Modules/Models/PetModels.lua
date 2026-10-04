-- Constrói o modelo 3D de um pet.
-- Se existir ReplicatedStorage.Assets.Pets[<Model>], usa o seu modelo.
-- Caso contrário, monta um pet procedural fofinho a partir de PetConfig (Shape + Colors).
-- O pet olha para -Z (frente padrão do Roblox).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = script.Parent.Parent
local PetConfig = require(Modules.PetConfig)

local PetModels = {}

local function rgb(t): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function part(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, shape: string?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "Sphere" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif shape == "Wedge" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Wedge
		mesh.Parent = p
	end
	p.Parent = model
	return p
end

local function findCustom(pet): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Pets")
	local custom = folder and folder:FindFirstChild(pet.Model)
	if custom and custom:IsA("Model") then
		local clone = custom:Clone()
		if not clone.PrimaryPart then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
		end
		for _, d in clone:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		return clone
	end
	return nil
end

local function eyes(model: Model, y: number, z: number, spread: number)
	local black = Color3.fromRGB(25, 25, 30)
	for _, side in { -1, 1 } do
		part(model, "Eye", Vector3.new(0.34, 0.42, 0.2), CFrame.new(side * spread, y, z), black, "Sphere")
		part(model, "Shine", Vector3.new(0.12, 0.12, 0.06), CFrame.new(side * spread + 0.06, y + 0.1, z - 0.09), Color3.new(1, 1, 1), "Sphere")
	end
	-- bochechas
	for _, side in { -1, 1 } do
		local cheek = part(model, "Cheek", Vector3.new(0.3, 0.16, 0.08), CFrame.new(side * (spread + 0.22), y - 0.28, z + 0.05), Color3.fromRGB(255, 140, 160), "Sphere")
		cheek.Transparency = 0.25
	end
end

function PetModels.Build(petName: string): Model
	local pet = PetConfig.Get(petName)
	if not pet then
		pet = PetConfig.Get("Chick")
	end
	local custom = findCustom(pet)
	if custom then
		return custom
	end

	local c1 = rgb(pet.Colors[1])
	local c2 = rgb(pet.Colors[2])
	local model = Instance.new("Model")
	model.Name = pet.Name
	local shape = pet.Shape
	local body: Part

	if shape == "Golem" then
		body = part(model, "Body", Vector3.new(2.1, 2.1, 1.9), CFrame.new(), c1, nil, Enum.Material.Slate)
		local mesh = Instance.new("BlockMesh")
		mesh.Parent = body
		for i = 1, 3 do
			part(model, "Crack", Vector3.new(0.12, 0.9, 0.05), CFrame.new(-0.6 + i * 0.35, 0.1 * i - 0.2, -0.96) * CFrame.Angles(0, 0, 0.4 * (i - 2)), c2, nil, Enum.Material.Neon)
		end
		part(model, "Horn", Vector3.new(0.4, 0.5, 0.4), CFrame.new(-0.7, 1.25, 0), c2, nil, Enum.Material.Neon)
		part(model, "Horn", Vector3.new(0.4, 0.5, 0.4), CFrame.new(0.7, 1.25, 0), c2, nil, Enum.Material.Neon)
		eyes(model, 0.35, -0.98, 0.42)
	elseif shape == "Slime" then
		body = part(model, "Body", Vector3.new(2.3, 1.7, 2.3), CFrame.new(0, -0.15, 0), c1, "Sphere", Enum.Material.Glass)
		body.Transparency = 0.15
		part(model, "Core", Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, -0.2, 0.1), c2, "Sphere", Enum.Material.Neon)
		part(model, "Drop", Vector3.new(0.6, 0.8, 0.6), CFrame.new(0, 0.85, 0), c1, "Sphere", Enum.Material.Glass)
		eyes(model, 0.15, -1.05, 0.4)
	else
		body = part(model, "Body", Vector3.new(2, 2, 2), CFrame.new(), c1, "Sphere")
		-- barriguinha
		part(model, "Belly", Vector3.new(1.3, 1.2, 0.6), CFrame.new(0, -0.35, -0.75), c2:Lerp(Color3.new(1, 1, 1), 0.35), "Sphere")
		eyes(model, 0.25, -0.88, 0.38)

		if shape == "Bird" then
			part(model, "Beak", Vector3.new(0.45, 0.3, 0.5), CFrame.new(0, -0.02, -1.05) * CFrame.Angles(math.rad(-90), 0, 0), c2, "Wedge")
			part(model, "Wing", Vector3.new(0.35, 0.9, 1.1), CFrame.new(-1.0, -0.1, 0.1) * CFrame.Angles(0, 0, math.rad(15)), c2, "Sphere")
			part(model, "Wing", Vector3.new(0.35, 0.9, 1.1), CFrame.new(1.0, -0.1, 0.1) * CFrame.Angles(0, 0, math.rad(-15)), c2, "Sphere")
			part(model, "Tuft", Vector3.new(0.3, 0.6, 0.3), CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.rad(15)), c2, "Sphere")
		elseif shape == "Bunny" then
			for _, side in { -1, 1 } do
				part(model, "Ear", Vector3.new(0.45, 1.5, 0.3), CFrame.new(side * 0.45, 1.45, 0.1) * CFrame.Angles(0, 0, side * -0.18), c1, "Sphere")
				part(model, "EarInner", Vector3.new(0.25, 1.1, 0.12), CFrame.new(side * 0.45, 1.45, -0.04) * CFrame.Angles(0, 0, side * -0.18), c2, "Sphere")
			end
			part(model, "Tail", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, -0.4, 1.0), Color3.new(1, 1, 1), "Sphere")
			part(model, "Nose", Vector3.new(0.18, 0.14, 0.1), CFrame.new(0, 0, -0.98), c2, "Sphere")
		elseif shape == "Cat" then
			for _, side in { -1, 1 } do
				part(model, "Ear", Vector3.new(0.18, 0.65, 0.55), CFrame.new(side * 0.55, 1.0, 0) * CFrame.Angles(0, math.rad(90), side * 0.25), c1, "Wedge")
			end
			part(model, "Nose", Vector3.new(0.18, 0.12, 0.1), CFrame.new(0, 0, -0.98), Color3.fromRGB(255, 120, 140), "Sphere")
			part(model, "Tail", Vector3.new(0.3, 0.3, 1.3), CFrame.new(0, 0.1, 1.1) * CFrame.Angles(math.rad(35), 0, 0), c2, "Sphere")
		elseif shape == "Dog" then
			for _, side in { -1, 1 } do
				part(model, "Ear", Vector3.new(0.35, 0.95, 0.5), CFrame.new(side * 0.95, 0.35, 0) * CFrame.Angles(0, 0, side * 0.3), c2, "Sphere")
			end
			part(model, "Snout", Vector3.new(0.7, 0.45, 0.4), CFrame.new(0, -0.15, -0.92), c1:Lerp(Color3.new(1, 1, 1), 0.4), "Sphere")
			part(model, "Nose", Vector3.new(0.25, 0.16, 0.12), CFrame.new(0, -0.03, -1.1), Color3.fromRGB(30, 30, 30), "Sphere")
			part(model, "Tail", Vector3.new(0.25, 0.25, 0.9), CFrame.new(0, 0.2, 1.05) * CFrame.Angles(math.rad(45), 0, 0), c1, "Sphere")
		elseif shape == "Bear" then
			for _, side in { -1, 1 } do
				part(model, "Ear", Vector3.new(0.6, 0.6, 0.35), CFrame.new(side * 0.68, 0.9, 0), c2, "Sphere")
			end
			part(model, "Snout", Vector3.new(0.7, 0.45, 0.4), CFrame.new(0, -0.15, -0.92), c1:Lerp(Color3.new(1, 1, 1), 0.5), "Sphere")
			part(model, "Nose", Vector3.new(0.25, 0.16, 0.12), CFrame.new(0, -0.03, -1.1), Color3.fromRGB(30, 30, 30), "Sphere")
		elseif shape == "Pig" then
			part(model, "Snout", Vector3.new(0.6, 0.45, 0.3), CFrame.new(0, -0.1, -1.0), c2, "Sphere")
			for _, side in { -1, 1 } do
				part(model, "Nostril", Vector3.new(0.1, 0.14, 0.05), CFrame.new(side * 0.12, -0.1, -1.15), Color3.fromRGB(150, 70, 90), "Sphere")
				part(model, "Ear", Vector3.new(0.15, 0.45, 0.45), CFrame.new(side * 0.55, 0.95, 0) * CFrame.Angles(0, math.rad(90), side * 0.4), c2, "Wedge")
			end
		elseif shape == "Dragon" then
			for _, side in { -1, 1 } do
				part(model, "Horn", Vector3.new(0.2, 0.6, 0.35), CFrame.new(side * 0.45, 1.05, 0.15) * CFrame.Angles(0, math.rad(90), side * 0.3), c2, "Wedge")
				part(model, "Wing", Vector3.new(0.12, 1.1, 1.4), CFrame.new(side * 1.25, 0.45, 0.35) * CFrame.Angles(0, 0, side * -0.6), c2, "Wedge", Enum.Material.Neon)
			end
			part(model, "Snout", Vector3.new(0.7, 0.4, 0.4), CFrame.new(0, -0.15, -0.92), c1:Lerp(Color3.new(1, 1, 1), 0.2), "Sphere")
			part(model, "Tail", Vector3.new(0.3, 0.3, 1.2), CFrame.new(0, -0.3, 1.15) * CFrame.Angles(math.rad(-20), 0, 0), c1, "Sphere")
		end
	end

	model.PrimaryPart = body

	if pet.Shiny then
		local light = Instance.new("PointLight")
		light.Color = c2
		light.Range = 6
		light.Brightness = 0.8
		light.Parent = body
	end
	return model
end

return PetModels
