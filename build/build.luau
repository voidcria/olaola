--[[
	Build do Kick an Egg (roda com Lune: https://lune-org.github.io)

		lune run build/build.luau

	Gera:
	  build/KickAnEgg.rbxl   -> place completo (mapa + scripts) para abrir no Roblox Studio
	  build/Map.rbxm         -> só o mapa (para quem usa Rojo: veja default.project.json)
	  sourcemap.json         -> mapa de arquivos (usado pelo luau-lsp)
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local Vector2 = roblox.Vector2
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local UDim2 = roblox.UDim2
local UDim = roblox.UDim
local Enum = roblox.Enum
local Font = roblox.Font
local NumberRange = roblox.NumberRange
local NumberSequence = roblox.NumberSequence
local ColorSequence = roblox.ColorSequence

local ROOT = process.cwd
if string.sub(ROOT, -1) ~= "/" then
	ROOT ..= "/"
end
local SRC = ROOT .. "src/"
local MODULES = SRC .. "ReplicatedStorage/Modules/"

----------------------------------------------------------------------
-- Carrega configs puras do jogo (mesmos arquivos usados em runtime)
----------------------------------------------------------------------
local configCache = {}
local function loadConfig(name: string)
	if configCache[name] then
		return configCache[name]
	end
	local source = fs.readFile(MODULES .. name .. ".lua")
	local env = setmetatable({
		script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
		require = function(n) return loadConfig(n) end,
	}, { __index = _G })
	local result = luau.load(source, { debugName = name, environment = env })()
	configCache[name] = result
	return result
end

local TrackConfig = loadConfig("TrackConfig")
local AreaConfig = loadConfig("AreaConfig")
local TrainConfig = loadConfig("TrainConfig")

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local FLOOR = TrackConfig.FloorY
local FONT = Font.fromEnum(Enum.Font.FredokaOne)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local function rgbT(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function new(className: string, props: { [string]: any }?, parent: any?)
	local inst = Instance.new(className)
	if props then
		for k, v in props do
			inst[k] = v
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function folder(name: string, parent)
	return new("Folder", { Name = name }, parent)
end

local function model(name: string, parent)
	return new("Model", { Name = name }, parent)
end

-- Peça ancorada (size, cframe, cor, material)
local function part(parent, name: string, size, cf, color, material, shape)
	local p = new("Part", {
		Name = name,
		Anchored = true,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function deco(p)
	-- Decoração: sem colisão e fora de raycasts
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function wedge(parent, name, size, cf, color, material)
	local w = new("WedgePart", {
		Name = name,
		Anchored = true,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
	w.Parent = parent
	return w
end

-- Texto num SurfaceGui (face frontal da peça)
local function surfaceText(p, lines, face, ppsOverride)
	local gui = new("SurfaceGui", {
		Name = "Gui",
		Face = face or Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = ppsOverride or 40,
		LightInfluence = 0,
		AlwaysOnTop = false,
	}, p)
	local n = #lines
	local y = 0
	for _, line in lines do
		local h = line.Height or (1 / n)
		local label = new("TextLabel", {
			Name = line.Name or "Text",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.94, h),
			Position = UDim2.fromScale(0.03, y),
			Text = line.Text,
			TextColor3 = line.Color or Color3.new(1, 1, 1),
			TextScaled = true,
			FontFace = FONT,
		}, gui)
		new("UIStroke", { Thickness = line.Stroke or 3, Color = line.StrokeColor or rgb(30, 30, 50) }, label)
		y += h
	end
	return gui
end

local function prompt(parent, actionText: string, objectText: string, panel: string)
	local pp = new("ProximityPrompt", {
		ActionText = actionText,
		ObjectText = objectText,
		HoldDuration = 0,
		MaxActivationDistance = 14,
		RequiresLineOfSight = false,
		KeyboardKeyCode = Enum.KeyCode.F,
		GamepadKeyCode = Enum.KeyCode.ButtonY,
	}, parent)
	pp:SetAttribute("Panel", panel)
	return pp
end

----------------------------------------------------------------------
-- DataModel
----------------------------------------------------------------------
local game = Instance.new("DataModel")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local StarterPlayer = game:GetService("StarterPlayer")

-- Ambiente
Lighting.ClockTime = 14.5
Lighting.Brightness = 2.6
Lighting.Ambient = rgb(70, 70, 90)
Lighting.OutdoorAmbient = rgb(150, 150, 165)
Lighting.GlobalShadows = true
Lighting.EnvironmentDiffuseScale = 0.6
Lighting.EnvironmentSpecularScale = 0.6
new("Atmosphere", { Density = 0.22, Offset = 0.1, Color = rgb(200, 220, 255), Decay = rgb(120, 140, 190), Glare = 0.2, Haze = 1.2 }, Lighting)
new("ColorCorrectionEffect", { Name = "Vibrance", Saturation = 0.12, Contrast = 0.05, Brightness = 0.02 }, Lighting)
new("BloomEffect", { Intensity = 0.4, Size = 24, Threshold = 1.6 }, Lighting)
new("SunRaysEffect", { Intensity = 0.04, Spread = 0.6 }, Lighting)
Workspace.Gravity = 196.2

StarterPlayer.CharacterWalkSpeed = 16
StarterPlayer.CharacterJumpPower = 50

local map = folder("Map", Workspace)

----------------------------------------------------------------------
-- LOBBY
----------------------------------------------------------------------
local lobby = folder("Lobby", map)
local L = TrackConfig.Lobby
local lobbyW = L.MaxX - L.MinX
local lobbyD = L.MaxZ - L.MinZ
local lobbyCenter = Vector3.new((L.MinX + L.MaxX) / 2, FLOOR - 2, (L.MinZ + L.MaxZ) / 2)

part(lobby, "Ground", Vector3.new(lobbyW, 4, lobbyD), CFrame.new(lobbyCenter), rgb(110, 200, 90), Enum.Material.Grass)
-- base mais larga (borda do lobby)
part(lobby, "Base", Vector3.new(lobbyW + 60, 6, lobbyD + 60), CFrame.new(lobbyCenter + Vector3.new(0, -3.2, 15)), rgb(95, 170, 80), Enum.Material.Grass)

-- Caminhos
local pathColor = rgb(235, 225, 200)
part(lobby, "PathMain", Vector3.new(26, 0.2, lobbyD - 30), CFrame.new(0, FLOOR + 0.05, L.MinZ + 30 + (lobbyD - 30) / 2), pathColor, Enum.Material.Pavement)
part(lobby, "PathCross1", Vector3.new(lobbyW - 40, 0.2, 18), CFrame.new(0, FLOOR + 0.05, 112), pathColor, Enum.Material.Pavement)
part(lobby, "PathCross2", Vector3.new(lobbyW - 40, 0.2, 18), CFrame.new(0, FLOOR + 0.05, 182), pathColor, Enum.Material.Pavement)

-- Cercas laterais e do fundo
local fenceColor = rgb(255, 250, 240)
local function fenceLine(fromV, toV)
	local dir = toV - fromV
	local len = dir.Magnitude
	local cf = CFrame.lookAt(fromV, toV) * CFrame.new(0, 0, -len / 2)
	part(lobby, "FenceRail", Vector3.new(0.6, 0.6, len), cf * CFrame.new(0, 2.6, 0), fenceColor, Enum.Material.Wood)
	part(lobby, "FenceRail", Vector3.new(0.6, 0.6, len), cf * CFrame.new(0, 1.4, 0), fenceColor, Enum.Material.Wood)
	local posts = math.floor(len / 8)
	for i = 0, posts do
		local pos = fromV + dir.Unit * (i * len / posts)
		part(lobby, "FencePost", Vector3.new(1, 3.6, 1), CFrame.new(pos + Vector3.new(0, 1.8, 0)), fenceColor, Enum.Material.Wood)
	end
end
fenceLine(Vector3.new(L.MinX + 2, FLOOR, L.MinZ + 36), Vector3.new(L.MinX + 2, FLOOR, L.MaxZ - 2))
fenceLine(Vector3.new(L.MaxX - 2, FLOOR, L.MinZ + 36), Vector3.new(L.MaxX - 2, FLOOR, L.MaxZ - 2))
fenceLine(Vector3.new(L.MinX + 2, FLOOR, L.MaxZ - 2), Vector3.new(L.MaxX - 2, FLOOR, L.MaxZ - 2))

-- Árvores fofinhas
local function tree(parent, pos: any, scale: number, leafColor)
	local m = model("Tree", parent)
	deco(part(m, "Trunk", Vector3.new(1.6, 7, 1.6) * scale, CFrame.new(pos + Vector3.new(0, 3.5 * scale, 0)), rgb(130, 90, 60), Enum.Material.Wood, Enum.PartType.Cylinder)).CFrame =
		CFrame.new(pos + Vector3.new(0, 3.5 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90))
	deco(part(m, "Leaves", Vector3.new(8, 8, 8) * scale, CFrame.new(pos + Vector3.new(0, 8.5 * scale, 0)), leafColor, Enum.Material.Grass, Enum.PartType.Ball))
	deco(part(m, "Leaves", Vector3.new(5.5, 5.5, 5.5) * scale, CFrame.new(pos + Vector3.new(2.2 * scale, 7 * scale, 1.2 * scale)), leafColor, Enum.Material.Grass, Enum.PartType.Ball))
	deco(part(m, "Leaves", Vector3.new(5, 5, 5) * scale, CFrame.new(pos + Vector3.new(-2 * scale, 7.4 * scale, -1.4 * scale)), leafColor, Enum.Material.Grass, Enum.PartType.Ball))
	return m
end
local decor = folder("Decor", lobby)
for i, p in {
	{ -118, 30 }, { -118, 200 }, { -118, 250 }, { 118, 230 }, { 118, 250 }, { -70, 245 }, { 60, 210 },
	{ -150, 90 }, { -150, 170 }, { 150, 60 }, { 150, 150 }, { 150, 240 }, { -150, 250 },
} do
	tree(decor, Vector3.new(p[1], FLOOR, p[2]), 0.9 + (i % 3) * 0.15, rgb(80 + (i % 3) * 15, 185, 90))
end
-- Flores
local flowerColors = { rgb(255, 120, 150), rgb(255, 220, 90), rgb(170, 130, 255), rgb(255, 255, 255) }
for i = 1, 60 do
	local x = L.MinX + 8 + ((i * 37) % (lobbyW - 16))
	local z = L.MinZ + 44 + ((i * 53) % (lobbyD - 50))
	if math.abs(x) > 18 then
		deco(part(decor, "Flower", Vector3.new(0.8, 0.8, 0.8), CFrame.new(x, FLOOR + 0.4, z), flowerColors[i % 4 + 1], Enum.Material.SmoothPlastic, Enum.PartType.Ball))
	end
end
-- Postes de luz
for _, p in { { 16, 60 }, { -16, 60 }, { 16, 150 }, { -16, 150 }, { 16, 230 }, { -16, 230 } } do
	local m = model("Lamp", decor)
	part(m, "Pole", Vector3.new(0.8, 12, 0.8), CFrame.new(p[1], FLOOR + 6, p[2]), rgb(60, 60, 70), Enum.Material.Metal)
	local bulb = deco(part(m, "Bulb", Vector3.new(2.2, 2.2, 2.2), CFrame.new(p[1], FLOOR + 12.5, p[2]), rgb(255, 240, 200), Enum.Material.Neon, Enum.PartType.Ball))
	new("PointLight", { Range = 18, Brightness = 1.2, Color = rgb(255, 230, 190) }, bulb)
end

-- Spawn
local spawn = new("SpawnLocation", {
	Name = "Spawn",
	Anchored = true,
	Size = Vector3.new(14, 1, 14),
	CFrame = CFrame.new(TrackConfig.Spawn.X, FLOOR + 0.3, TrackConfig.Spawn.Z),
	Color = rgb(255, 210, 90),
	Material = Enum.Material.SmoothPlastic,
	Neutral = true,
	Duration = 0,
	TopSurface = Enum.SurfaceType.Smooth,
}, lobby)
spawn.Shape = Enum.PartType.Cylinder
spawn.Size = Vector3.new(1, 16, 16)
spawn.CFrame = CFrame.new(TrackConfig.Spawn.X, FLOOR + 0.3, TrackConfig.Spawn.Z) * CFrame.Angles(0, 0, math.rad(90))

----------------------------------------------------------------------
-- ZONA DE CHUTE
----------------------------------------------------------------------
local kick = folder("KickZone", map)
local KZ = TrackConfig.KickZone
local kzW = KZ.MaxX - KZ.MinX
local kzD = KZ.MaxZ - KZ.MinZ
local pad = part(kick, "Pad", Vector3.new(kzW, 1, kzD), CFrame.new(0, FLOOR - 0.45, (KZ.MinZ + KZ.MaxZ) / 2), rgb(255, 175, 70), Enum.Material.SmoothPlastic)
pad.CanQuery = true
-- Faixas
for i = 0, 6 do
	local x = KZ.MinX + 8 + i * (kzW - 16) / 6
	deco(part(kick, "Stripe", Vector3.new(3, 0.12, kzD - 6), CFrame.new(x, FLOOR + 0.07, (KZ.MinZ + KZ.MaxZ) / 2), rgb(255, 235, 200), Enum.Material.SmoothPlastic))
end
-- Linha de chute (neon)
deco(part(kick, "KickLine", Vector3.new(kzW, 0.25, 1.6), CFrame.new(0, FLOOR + 0.12, TrackConfig.KickLineZ), rgb(255, 255, 255), Enum.Material.Neon))
-- Texto no chão
local floorSign = deco(part(kick, "FloorText", Vector3.new(60, 0.1, 12), CFrame.new(0, FLOOR + 0.1, KZ.MaxZ - 9), rgb(255, 175, 70), Enum.Material.SmoothPlastic))
floorSign.Transparency = 1
surfaceText(floorSign, { { Text = "KICK ZONE", Color = rgb(255, 255, 255) } }, Enum.NormalId.Top, 20)

-- Arco "KICK AN EGG"
local arch = model("Arch", kick)
local archColor = rgb(255, 120, 60)
part(arch, "PillarL", Vector3.new(5, 34, 5), CFrame.new(-64, FLOOR + 17, TrackConfig.KickLineZ + 2), archColor, Enum.Material.SmoothPlastic)
part(arch, "PillarR", Vector3.new(5, 34, 5), CFrame.new(64, FLOOR + 17, TrackConfig.KickLineZ + 2), archColor, Enum.Material.SmoothPlastic)
local archTop = part(arch, "Top", Vector3.new(134, 9, 4), CFrame.new(0, FLOOR + 36, TrackConfig.KickLineZ + 2), rgb(40, 45, 80), Enum.Material.SmoothPlastic)
surfaceText(archTop, { { Text = "KICK AN EGG", Color = rgb(255, 215, 70), Stroke = 5 } }, Enum.NormalId.Back, 12)
surfaceText(archTop, { { Text = "GO FARTHER!", Color = rgb(255, 255, 255), Stroke = 5 } }, Enum.NormalId.Front, 12).Name = "GuiFront"
for _, x in { -64, 64 } do
	local ball = deco(part(arch, "Egg", Vector3.new(6, 7.5, 6), CFrame.new(x, FLOOR + 38.5, TrackConfig.KickLineZ + 2), rgb(255, 245, 225), Enum.Material.SmoothPlastic))
	new("SpecialMesh", { MeshType = Enum.MeshType.Sphere }, ball)
end

----------------------------------------------------------------------
-- ESTAÇÕES DE TREINO
----------------------------------------------------------------------
local training = folder("Training", map)
local function stationSign(parent, station, pos)
	local sign = deco(part(parent, "Sign", Vector3.new(10, 3.6, 0.4), CFrame.new(pos + Vector3.new(0, 11, 0)), rgb(40, 45, 80), Enum.Material.SmoothPlastic))
	local req = if station.StrengthRequired > 0 then "Needs " .. station.StrengthRequired .. " Strength" else "Free!"
	if station.RebirthsRequired > 0 then
		req ..= " + " .. station.RebirthsRequired .. " Rebirth" .. (if station.RebirthsRequired > 1 then "s" else "")
	end
	local gui = new("BillboardGui", {
		Name = "Label",
		Size = UDim2.fromOffset(240, 80),
		StudsOffset = Vector3.new(0, 1, 0),
		MaxDistance = 90,
		LightInfluence = 0,
	}, sign)
	sign.Transparency = 1
	local title = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.55), Text = station.Name, TextScaled = true, FontFace = FONT, TextColor3 = rgb(255, 255, 255) }, gui)
	new("UIStroke", { Thickness = 2.5, Color = rgb(30, 30, 50) }, title)
	local info = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.55), Size = UDim2.fromScale(1, 0.4), Text = "+" .. station.Gain .. " Strength  |  " .. req, TextScaled = true, FontFace = FONT, TextColor3 = rgb(255, 200, 120) }, gui)
	new("UIStroke", { Thickness = 2, Color = rgb(30, 30, 50) }, info)
end

for _, station in TrainConfig.Stations do
	local m = model(station.Name, training)
	m:SetAttribute("StationId", station.Id)
	local pos = Vector3.new(station.X, FLOOR, station.Z)
	local color = rgbT(station.Color)
	-- Plataforma circular com anel
	local base = part(m, "Pad", Vector3.new(1, 22, 22), CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(70, 75, 110), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	base.Name = "Pad"
	deco(part(m, "Ring", Vector3.new(0.9, 24, 24), CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 200, 80), Enum.Material.Neon, Enum.PartType.Cylinder))
	local top = FLOOR + 0.8
	if station.Kind == "Dummy" then
		part(m, "Post", Vector3.new(1, 5, 1), CFrame.new(pos + Vector3.new(0, 3.3, -4)), rgb(120, 85, 55), Enum.Material.Wood)
		part(m, "Body", Vector3.new(3.2, 4, 2.2), CFrame.new(pos + Vector3.new(0, 6.5, -4)), color, Enum.Material.Fabric)
		part(m, "Head", Vector3.new(2.4, 2.4, 2.4), CFrame.new(pos + Vector3.new(0, 9.7, -4)), color, Enum.Material.Fabric, Enum.PartType.Ball)
		part(m, "Target", Vector3.new(0.2, 2, 2), CFrame.new(pos + Vector3.new(0, 6.5, -2.85)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(230, 60, 60), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	elseif station.Kind == "Tire" then
		for i = 0, 2 do
			local tire = part(m, "Tire", Vector3.new(1.6, 6, 6), CFrame.new(pos + Vector3.new(-3 + i * 3, top + 0.8 + (if i == 1 then 0 else 0), -3)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Rubber, Enum.PartType.Cylinder)
			tire.CFrame = CFrame.new(pos + Vector3.new(-4 + i * 4, top + 0.8, -3)) * CFrame.Angles(0, 0, math.rad(90))
		end
		part(m, "BigTire", Vector3.new(2.2, 9, 9), CFrame.new(pos + Vector3.new(0, top + 4.5, 3)) * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.Rubber, Enum.PartType.Cylinder)
	elseif station.Kind == "Dumbbell" then
		part(m, "Rack", Vector3.new(10, 3, 2.4), CFrame.new(pos + Vector3.new(0, top + 1.5, -4)), rgb(60, 60, 70), Enum.Material.Metal)
		for i = -1, 1 do
			local x = i * 3.2
			part(m, "Bar", Vector3.new(3.4, 0.5, 0.5), CFrame.new(pos + Vector3.new(x, top + 3.4, -4)), rgb(200, 200, 210), Enum.Material.Metal, Enum.PartType.Cylinder)
			for _, s in { -1, 1 } do
				part(m, "Weight", Vector3.new(0.6, 1.8, 1.8), CFrame.new(pos + Vector3.new(x + s * 1.5, top + 3.4, -4)), color, Enum.Material.Metal, Enum.PartType.Cylinder)
			end
		end
	elseif station.Kind == "Boulder" then
		part(m, "Boulder", Vector3.new(9, 9, 9), CFrame.new(pos + Vector3.new(0, top + 4, -3)), color, Enum.Material.Slate, Enum.PartType.Ball)
		part(m, "Rock", Vector3.new(4, 4, 4), CFrame.new(pos + Vector3.new(4.5, top + 1.5, 2)), color, Enum.Material.Slate, Enum.PartType.Ball)
	elseif station.Kind == "Anvil" then
		part(m, "AnvilBase", Vector3.new(4, 3, 3), CFrame.new(pos + Vector3.new(0, top + 1.5, -3)), rgb(40, 35, 60), Enum.Material.Metal)
		part(m, "AnvilTop", Vector3.new(8, 2, 3.4), CFrame.new(pos + Vector3.new(0, top + 4, -3)), color, Enum.Material.Neon)
		new("PointLight", { Range = 16, Brightness = 2, Color = color }, m.AnvilTop)
	end
	stationSign(m, station, pos)
end

----------------------------------------------------------------------
-- BARRACAS / STANDS
----------------------------------------------------------------------
local stands = folder("Stands", map)
local PANEL_FOR = { EggShop = "EggShop", Hatchery = "Hatchery", Upgrades = "Upgrades", Rebirth = "Rebirth", Areas = "Areas" }
local ACTION_FOR = { EggShop = "Shop Eggs", Hatchery = "Hatch Pets", Upgrades = "Upgrades", Rebirth = "Rebirth", Areas = "Unlock Areas" }

local function buildStall(key: string, def)
	local m = model(def.Title, stands)
	m:SetAttribute("Panel", PANEL_FOR[key])
	local color = rgbT(def.Color)
	local pos = Vector3.new(def.X, FLOOR, def.Z)
	-- Barraca olha para o centro do lobby (x = 0)
	local facing = if def.X > 0 then CFrame.Angles(0, math.rad(90), 0) else CFrame.Angles(0, math.rad(-90), 0)
	if key == "Rebirth" then
		facing = CFrame.Angles(0, 0, 0) -- olha para -Z (para a pista)
	end
	local base = CFrame.new(pos) * facing
	-- Balcão (frente = -Z local)
	local counter = part(m, "Counter", Vector3.new(16, 4, 4), base * CFrame.new(0, 2, -3), rgb(250, 245, 235), Enum.Material.Wood)
	part(m, "CounterTrim", Vector3.new(16.4, 0.6, 4.4), base * CFrame.new(0, 4.2, -3), color, Enum.Material.SmoothPlastic)
	part(m, "Back", Vector3.new(16, 12, 1), base * CFrame.new(0, 6, 4), rgb(240, 230, 210), Enum.Material.Wood)
	for _, x in { -7.5, 7.5 } do
		part(m, "Post", Vector3.new(1, 13, 1), base * CFrame.new(x, 6.5, -4.5), rgb(250, 245, 235), Enum.Material.Wood)
	end
	-- Toldo listrado
	for i = 0, 7 do
		local stripe = if i % 2 == 0 then color else rgb(255, 255, 255)
		wedge(m, "Awning", Vector3.new(2, 2.5, 9.5), base * CFrame.new(-7 + i * 2, 14.25, -0.5) * CFrame.Angles(0, math.rad(180), 0), stripe, Enum.Material.Fabric)
	end
	-- Placa
	local sign = part(m, "Sign", Vector3.new(14, 3.6, 0.6), base * CFrame.new(0, 17.4, 0.5), rgb(40, 45, 80), Enum.Material.SmoothPlastic)
	surfaceText(sign, {
		{ Text = def.Title, Color = color, Height = 0.65 },
		{ Text = def.Subtitle, Color = rgb(255, 255, 255), Height = 0.35, Stroke = 2 },
	}, Enum.NormalId.Front, 30)
	-- Enfeites por tipo
	if key == "EggShop" or key == "Hatchery" then
		local eggColors = { rgb(250, 244, 228), rgb(110, 185, 255), rgb(175, 95, 255), rgb(255, 200, 50) }
		for i, c in eggColors do
			local e = deco(part(m, "DisplayEgg", Vector3.new(1.6, 2, 1.6), base * CFrame.new(-5.4 + (i - 1) * 3.6, 5.5, -3), c, Enum.Material.SmoothPlastic))
			new("SpecialMesh", { MeshType = Enum.MeshType.Sphere }, e)
		end
	elseif key == "Upgrades" then
		for i = -1, 1 do
			local arrow = deco(wedge(m, "Arrow", Vector3.new(1, 2, 2), base * CFrame.new(i * 4, 6, -3) * CFrame.Angles(math.rad(-90), 0, 0), rgb(90, 220, 110), Enum.Material.Neon))
			arrow.CFrame = base * CFrame.new(i * 4, 6.2, -3)
		end
	elseif key == "Rebirth" then
		local orb = deco(part(m, "Orb", Vector3.new(4, 4, 4), base * CFrame.new(0, 7.5, -3), color, Enum.Material.Neon, Enum.PartType.Ball))
		new("PointLight", { Range = 20, Brightness = 2, Color = color }, orb)
		new("ParticleEmitter", {
			Rate = 6,
			Lifetime = NumberRange.new(1, 1.6),
			Speed = NumberRange.new(1, 2),
			Size = NumberSequence.new(0.4),
			Color = ColorSequence.new(color),
			LightEmission = 1,
		}, orb)
	elseif key == "Areas" then
		for i = 0, 2 do
			local flag = deco(part(m, "Flag", Vector3.new(0.3, 1.6, 2.4), base * CFrame.new(-4 + i * 4, 6.6, -3), rgbT(AreaConfig.Areas[i + 2].FloorColor), Enum.Material.Fabric))
			flag.Size = Vector3.new(2.4, 1.6, 0.3)
			part(m, "FlagPole", Vector3.new(0.25, 3.4, 0.25), base * CFrame.new(-5.3 + i * 4, 5.9, -3), rgb(200, 200, 210), Enum.Material.Metal)
		end
	end
	-- Interação
	local promptPart = deco(part(m, "PromptPart", Vector3.new(4, 4, 4), base * CFrame.new(0, 3, -6), color, Enum.Material.SmoothPlastic))
	promptPart.Transparency = 1
	prompt(promptPart, ACTION_FOR[key], def.Title, PANEL_FOR[key])
	-- tapete
	deco(part(m, "Mat", Vector3.new(14, 0.2, 8), base * CFrame.new(0, 0.12, -9), color, Enum.Material.Fabric))
	return m, counter
end
for key, def in TrackConfig.Stands do
	buildStall(key, def)
end

----------------------------------------------------------------------
-- LEADERBOARD
----------------------------------------------------------------------
local lbDef = TrackConfig.Leaderboard
local lb = model("Leaderboard", lobby)
part(lb, "PostL", Vector3.new(1.4, 22, 1.4), CFrame.new(lbDef.X - 10, FLOOR + 11, lbDef.Z), rgb(60, 60, 75), Enum.Material.Metal)
part(lb, "PostR", Vector3.new(1.4, 22, 1.4), CFrame.new(lbDef.X + 10, FLOOR + 11, lbDef.Z), rgb(60, 60, 75), Enum.Material.Metal)
local board = part(lb, "Board", Vector3.new(19, 18, 0.8), CFrame.new(lbDef.X, FLOOR + 13, lbDef.Z), rgb(35, 40, 70), Enum.Material.SmoothPlastic)
-- Face voltada para -Z (para o lobby)
local lbGui = new("SurfaceGui", { Name = "Gui", Face = Enum.NormalId.Front, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 30, LightInfluence = 0 }, board)
local lbTitle = new("TextLabel", { Name = "Title", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.14), Text = "TOP KICKS", TextScaled = true, FontFace = FONT, TextColor3 = rgb(255, 210, 70) }, lbGui)
new("UIStroke", { Thickness = 4, Color = rgb(20, 20, 40) }, lbTitle)
local list = new("Frame", { Name = "List", BackgroundTransparency = 1, Position = UDim2.fromScale(0.04, 0.16), Size = UDim2.fromScale(0.92, 0.82) }, lbGui)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)

----------------------------------------------------------------------
-- PISTA (áreas, marcadores, portões)
----------------------------------------------------------------------
local track = folder("Track", map)
local floors = folder("Floors", track)
local markers = folder("Markers", track)
local gates = folder("Gates", track)
local trackDecor = folder("Decor", track)
local W = TrackConfig.TrackWidth
local CX = TrackConfig.TrackCenterX
local K0 = TrackConfig.KickLineZ

local MATERIALS = {
	Grass = Enum.Material.Grass,
	Sand = Enum.Material.Sand,
	Snow = Enum.Material.Snow,
	Basalt = Enum.Material.Basalt,
	Glass = Enum.Material.Glass,
}

for _, area in AreaConfig.Areas do
	local color = rgbT(area.FloorColor)
	local material = MATERIALS[area.Material] or Enum.Material.SmoothPlastic
	local length = area.End - area.Start + (if area.Id == #AreaConfig.Areas then 60 else 0)
	local chunks = math.ceil(length / 1900)
	local chunkLen = length / chunks
	for c = 0, chunks - 1 do
		local zStart = K0 - area.Start - c * chunkLen
		local f = part(floors, "Area" .. area.Id, Vector3.new(W, 4, chunkLen), CFrame.new(CX, FLOOR - 2, zStart - chunkLen / 2), color, material)
		f:SetAttribute("AreaId", area.Id)
		f:AddTag("Floor")
		-- terreno lateral (mais largo, mais escuro)
		local side = part(floors, "Side" .. area.Id, Vector3.new(W + 160, 4, chunkLen), CFrame.new(CX, FLOOR - 2.6, zStart - chunkLen / 2), Color3.new(color.R * 0.8, color.G * 0.8, color.B * 0.8), material)
		side.CanQuery = false
		-- muretas
		for _, s in { -1, 1 } do
			part(floors, "Rail", Vector3.new(2, 3, chunkLen), CFrame.new(CX + s * (W / 2 + 1), FLOOR + 1.5, zStart - chunkLen / 2), rgb(255, 255, 255), Enum.Material.SmoothPlastic)
		end
	end
	-- Faixa central tracejada
	local dash = 0
	local z = area.Start
	while z < area.End do
		dash += 1
		if dash % 2 == 0 then
			deco(part(markers, "Dash", Vector3.new(1, 0.1, 8), CFrame.new(CX, FLOOR + 0.06, K0 - z - 4), rgb(255, 255, 255), Enum.Material.SmoothPlastic)).Transparency = 0.4
		end
		z += 16
	end
end

-- Marcadores de distância
local function markerAt(m: number)
	local z = K0 - m
	for _, s in { -1, 1 } do
		local sign = part(markers, "Marker", Vector3.new(0.6, 5, 10), CFrame.new(CX + s * (W / 2 + 6), FLOOR + 5, z), rgb(40, 45, 80), Enum.Material.SmoothPlastic)
		sign.CanQuery = false
		part(markers, "MarkerPost", Vector3.new(0.8, 3, 0.8), CFrame.new(CX + s * (W / 2 + 6), FLOOR + 1.5, z), rgb(200, 200, 210), Enum.Material.Metal)
		-- texto voltado para a pista
		surfaceText(sign, { { Text = m .. "m", Color = rgb(255, 215, 80) } }, if s < 0 then Enum.NormalId.Right else Enum.NormalId.Left, 20)
	end
	-- linha no chão
	deco(part(markers, "Line", Vector3.new(W, 0.1, 0.8), CFrame.new(CX, FLOOR + 0.06, z), rgb(255, 255, 255), Enum.Material.SmoothPlastic)).Transparency = 0.5
end
local mDist = 25
while mDist <= TrackConfig.Length do
	markerAt(mDist)
	if mDist < 200 then
		mDist += 25
	elseif mDist < 1000 then
		mDist += 50
	else
		mDist += 100
	end
end

-- Portões das áreas
for _, area in AreaConfig.Areas do
	if area.Id > 1 then
		local z = K0 - area.Start
		local g = model("Gate" .. area.Id, gates)
		g:SetAttribute("AreaId", area.Id)
		local color = rgbT(area.FloorColor)
		for _, s in { -1, 1 } do
			part(g, "Pillar", Vector3.new(6, 40, 6), CFrame.new(CX + s * (W / 2 + 3), FLOOR + 20, z), Color3.new(color.R * 0.7, color.G * 0.7, color.B * 0.7), Enum.Material.Slate)
		end
		local top = part(g, "Top", Vector3.new(W + 14, 8, 6), CFrame.new(CX, FLOOR + 44, z), rgb(40, 45, 80), Enum.Material.SmoothPlastic)
		local gui = surfaceText(top, {
			{ Name = "Title", Text = "AREA " .. area.Id .. " - " .. string.upper(area.Name), Color = color, Height = 0.6 },
			{ Name = "Info", Text = "LOCKED", Color = rgb(255, 220, 120), Height = 0.4, Stroke = 2 },
		}, Enum.NormalId.Back, 10)
		gui.Name = "Gui"
		local barrier = part(g, "Barrier", Vector3.new(W, 40, 1), CFrame.new(CX, FLOOR + 20, z), rgb(255, 80, 80), Enum.Material.ForceField)
		barrier.Transparency = 0.45
		barrier.CanQuery = false
	end
end

-- Fim da pista
local endWall = part(track, "EndWall", Vector3.new(W + 20, 50, 6), CFrame.new(CX, FLOOR + 25, K0 - TrackConfig.Length - 3), rgb(50, 40, 100), Enum.Material.SmoothPlastic)
surfaceText(endWall, { { Text = "THE END - " .. TrackConfig.Length .. "m", Color = rgb(255, 220, 90) } }, Enum.NormalId.Back, 6)

-- Decoração por área (fora da pista)
local function cactus(parent, pos)
	local c = rgb(90, 160, 80)
	deco(part(parent, "Cactus", Vector3.new(2, 9, 2), CFrame.new(pos + Vector3.new(0, 4.5, 0)), c, Enum.Material.Grass))
	deco(part(parent, "Arm", Vector3.new(1.4, 4, 1.4), CFrame.new(pos + Vector3.new(1.6, 6, 0)), c, Enum.Material.Grass))
end
local function snowRock(parent, pos)
	deco(part(parent, "IceRock", Vector3.new(7, 6, 7), CFrame.new(pos + Vector3.new(0, 2, 0)), rgb(200, 225, 255), Enum.Material.Ice, Enum.PartType.Ball))
	local pine = deco(wedge(parent, "Pine", Vector3.new(1, 10, 6), CFrame.new(pos + Vector3.new(6, 5, 0)), rgb(60, 120, 90), Enum.Material.Grass))
	pine.Size = Vector3.new(6, 10, 6)
end
local function lavaRock(parent, pos)
	deco(part(parent, "Rock", Vector3.new(8, 6, 8), CFrame.new(pos + Vector3.new(0, 2, 0)), rgb(60, 45, 45), Enum.Material.Basalt, Enum.PartType.Ball))
	local lava = deco(part(parent, "Lava", Vector3.new(0.4, 6, 6), CFrame.new(pos + Vector3.new(7, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 110, 30), Enum.Material.Neon, Enum.PartType.Cylinder))
	lava.Size = Vector3.new(0.4, 7, 7)
end
local function crystal(parent, pos, i)
	local colors = { rgb(170, 110, 255), rgb(90, 220, 255), rgb(255, 120, 220) }
	local c = deco(part(parent, "Crystal", Vector3.new(2.5, 10, 2.5), CFrame.new(pos + Vector3.new(0, 5, 0)) * CFrame.Angles(0, math.rad(i * 37), math.rad(12)), colors[i % 3 + 1], Enum.Material.Neon))
	c.Transparency = 0.15
end
for _, area in AreaConfig.Areas do
	local spacing = math.clamp((area.End - area.Start) / 14, 30, 160)
	local z = area.Start + 20
	local i = 0
	while z < area.End - 10 do
		i += 1
		for _, s in { -1, 1 } do
			local x = CX + s * (W / 2 + 22 + (i * 13) % 40)
			local pos = Vector3.new(x, FLOOR, K0 - z)
			if area.Id == 1 then
				tree(trackDecor, pos, 0.9 + (i % 3) * 0.2, rgb(80 + (i % 3) * 15, 185, 90))
			elseif area.Id == 2 then
				cactus(trackDecor, pos)
			elseif area.Id == 3 then
				snowRock(trackDecor, pos)
			elseif area.Id == 4 then
				lavaRock(trackDecor, pos)
			else
				crystal(trackDecor, pos, i)
			end
		end
		z += spacing
	end
end

----------------------------------------------------------------------
-- Assets (pastas para seus modelos personalizados)
----------------------------------------------------------------------
local assets = folder("Assets", ReplicatedStorage)
local eggAssets = folder("Eggs", assets)
eggAssets:SetAttribute("Info", "Coloque aqui um Model com o mesmo nome do campo Model do EggConfig para substituir o ovo procedural")
local petAssets = folder("Pets", assets)
petAssets:SetAttribute("Info", "Coloque aqui um Model com o mesmo nome do pet (PetConfig) para substituir o pet procedural")

----------------------------------------------------------------------
-- Scripts (src/ -> instâncias, convenção do Rojo)
----------------------------------------------------------------------
local SERVICE_DIRS = {
	ReplicatedStorage = ReplicatedStorage,
	ServerScriptService = game:GetService("ServerScriptService"),
	StarterPlayer = StarterPlayer,
}

local sourcemapChildren = {}

local function classFor(fileName: string): (string?, string?)
	if string.match(fileName, "%.server%.lua$") then
		return "Script", (string.gsub(fileName, "%.server%.lua$", ""))
	elseif string.match(fileName, "%.client%.lua$") then
		return "LocalScript", (string.gsub(fileName, "%.client%.lua$", ""))
	elseif string.match(fileName, "%.lua$") then
		return "ModuleScript", (string.gsub(fileName, "%.lua$", ""))
	end
	return nil, nil
end

local scriptCount = 0
local function mount(dirPath: string, relPath: string, parent, smNode)
	local entries = fs.readDir(dirPath)
	table.sort(entries)
	for _, entry in entries do
		local full = dirPath .. "/" .. entry
		local rel = relPath .. "/" .. entry
		if fs.isDir(full) then
			local existing = parent:FindFirstChild(entry)
			local inst = existing or new("Folder", { Name = entry }, parent)
			local node = { name = entry, className = inst.ClassName, children = {} }
			table.insert(smNode.children, node)
			mount(full, rel, inst, node)
		else
			local className, name = classFor(entry)
			if className then
				local source = fs.readFile(full)
				-- valida sintaxe antes de embutir
				local ok, err = pcall(luau.compile, source)
				if not ok then
					error("Erro de sintaxe em " .. rel .. ":\n" .. tostring(err))
				end
				local inst = new(className, { Name = name, Source = source }, parent)
				if className == "LocalScript" or className == "Script" then
					inst.Disabled = false
				end
				scriptCount += 1
				table.insert(smNode.children, { name = name, className = className, filePaths = { rel } })
			end
		end
	end
end

for dirName, service in SERVICE_DIRS do
	local node = { name = dirName, className = service.ClassName, children = {} }
	table.insert(sourcemapChildren, node)
	if dirName == "StarterPlayer" then
		local sps = service:FindFirstChildOfClass("StarterPlayerScripts") or new("StarterPlayerScripts", { Name = "StarterPlayerScripts" }, service)
		local spsNode = { name = "StarterPlayerScripts", className = "StarterPlayerScripts", children = {} }
		table.insert(node.children, spsNode)
		mount(SRC .. "StarterPlayer/StarterPlayerScripts", "src/StarterPlayer/StarterPlayerScripts", sps, spsNode)
	else
		mount(SRC .. dirName, "src/" .. dirName, service, node)
	end
end

----------------------------------------------------------------------
-- Saída
----------------------------------------------------------------------
fs.writeDir(ROOT .. "build")
fs.writeFile(ROOT .. "build/KickAnEgg.rbxl", roblox.serializePlace(game))
fs.writeFile(ROOT .. "build/Map.rbxm", roblox.serializeModel({ map }))
fs.writeFile(ROOT .. "sourcemap.json", serde.encode("json", { name = "Kick an Egg", className = "DataModel", children = sourcemapChildren }, true))

local partCount = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		partCount += 1
	end
end
print(string.format("OK: %d scripts, %d partes no mapa -> build/KickAnEgg.rbxl", scriptCount, partCount))
