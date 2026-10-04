-- Constrói o modelo 3D de um ovo.
-- Se existir ReplicatedStorage.Assets.Eggs[<Model>] (ex.: seu próprio modelo), ele é usado.
-- Caso contrário, monta um ovo procedural com a aparência definida em EggConfig.Look.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = script.Parent.Parent
local EggConfig = require(Modules.EggConfig)

local EggModels = {}

local function rgb(t): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function newPart(model: Model, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
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
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function sphereMesh(part: BasePart)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
end

local function findCustom(egg): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Eggs")
	local custom = folder and egg.Model and folder:FindFirstChild(egg.Model)
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

-- scale: 1 = ovo de ~3 studs de altura
function EggModels.Build(eggId: string, scale: number?): Model
	local egg = EggConfig.Get(eggId) or EggConfig.Get("Basic")
	local s = scale or 1
	local custom = findCustom(egg)
	if custom then
		if s ~= 1 then
			custom:ScaleTo(s)
		end
		return custom
	end

	local look = egg.Look
	local primary = rgb(look.Primary)
	local secondary = rgb(look.Secondary)
	local model = Instance.new("Model")
	model.Name = egg.Name

	local shellMaterial = Enum.Material.SmoothPlastic
	if look.Material == "Cosmic" then
		shellMaterial = Enum.Material.Glass
	end
	local shellSize = Vector3.new(2.4, 3, 2.4) * s
	local shell = newPart(model, "Shell", shellSize, CFrame.new(), primary, shellMaterial)
	sphereMesh(shell)
	model.PrimaryPart = shell

	local function surfacePoint(theta: number, y: number): (Vector3, CFrame)
		-- ponto na superfície do elipsoide (y entre -1 e 1)
		local r = math.sqrt(math.max(0, 1 - y * y))
		local pos = Vector3.new(math.cos(theta) * r * shellSize.X / 2, y * shellSize.Y / 2, math.sin(theta) * r * shellSize.Z / 2)
		return pos, CFrame.lookAt(pos, pos * 2)
	end

	if look.Pattern == "Spots" then
		local spots = { { 0.3, 0.35 }, { 1.6, -0.1 }, { 2.9, 0.45 }, { 4.2, -0.3 }, { 5.3, 0.1 }, { 0.9, -0.55 }, { 3.6, 0.0 } }
		for i, sp in spots do
			local pos = surfacePoint(sp[1], sp[2])
			local d = (0.55 - (i % 3) * 0.1) * s
			local spot = newPart(model, "Spot", Vector3.new(d, d, d), CFrame.new(pos * 0.96), secondary)
			sphereMesh(spot)
		end
	elseif look.Pattern == "Stripes" then
		for _, y in { -0.35, 0.05, 0.45 } do
			local r = math.sqrt(1 - y * y)
			local band = newPart(
				model,
				"Stripe",
				Vector3.new(shellSize.X * r + 0.08 * s, 0.32 * s, shellSize.Z * r + 0.08 * s),
				CFrame.new(0, y * shellSize.Y / 2, 0),
				secondary
			)
			sphereMesh(band)
		end
	elseif look.Pattern == "Stars" then
		for i = 1, 9 do
			local theta = i * 2.39
			local y = ((i * 0.37) % 1.4) - 0.7
			local pos = surfacePoint(theta, y)
			local d = 0.3 * s
			local star = newPart(model, "Star", Vector3.new(d, d, d), CFrame.new(pos * 0.98), secondary, Enum.Material.Neon)
			sphereMesh(star)
		end
	end

	if look.Material == "Glow" or look.Material == "Cosmic" then
		local light = Instance.new("PointLight")
		light.Color = secondary
		light.Range = 8 * s
		light.Brightness = 1.5
		light.Parent = shell
	end
	if look.Material == "Cosmic" then
		local core = newPart(model, "Core", shellSize * 0.8, CFrame.new(), Color3.fromRGB(120, 60, 220), Enum.Material.Neon)
		core.Transparency = 0.5
		sphereMesh(core)
	end

	return model
end

-- Move um modelo construído por EggModels (todas as partes ancoradas)
function EggModels.Place(model: Model, cf: CFrame)
	model:PivotTo(cf)
end

return EggModels
