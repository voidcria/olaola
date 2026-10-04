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
local BaseConfig = loadConfig("BaseConfig")

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
-- Uma base por jogador: 6 bases = 6 jogadores por servidor
pcall(function()
	game:GetService("Players").MaxPlayers = #TrackConfig.Bases
end)
StarterPlayer.CharacterJumpPower = 50

local map = folder("Map", Workspace)

----------------------------------------------------------------------
-- PAREDES CARTUNESCAS (estilo do jogo de referência: parede grossa + topo arredondado)
----------------------------------------------------------------------
local WALL = TrackConfig.Walls
local WALL_THEMES = {
	Meadow = { Body = rgb(150, 95, 55), Band = rgb(110, 68, 40), Top = rgb(231, 104, 24), Pillar = rgb(125, 80, 45) },
	Desert = { Body = rgb(215, 160, 95), Band = rgb(180, 125, 70), Top = rgb(250, 205, 120), Pillar = rgb(195, 140, 80) },
	Snow = { Body = rgb(150, 185, 220), Band = rgb(120, 150, 190), Top = rgb(245, 250, 255), Pillar = rgb(130, 165, 205) },
	Lava = { Body = rgb(80, 48, 42), Band = rgb(58, 32, 28), Top = rgb(255, 105, 35), Pillar = rgb(64, 38, 34) },
	Cosmic = { Body = rgb(72, 46, 132), Band = rgb(52, 32, 102), Top = rgb(190, 130, 255), Pillar = rgb(60, 40, 115) },
}
local AREA_THEME = { "Meadow", "Desert", "Snow", "Lava", "Cosmic" }
local wallsFolder

-- Parede de A até B (no chão), com faixa, topo arredondado e pilares
local function cartoonWall(a, b, themeName: string, pillarSpacing: number?)
	local theme = WALL_THEMES[themeName]
	local dir = b - a
	local total = dir.Magnitude
	local unit = dir.Unit
	local h = WALL.Height
	local th = WALL.Thickness
	local chunks = math.ceil(total / 1800)
	for c = 0, chunks - 1 do
		local s = a + unit * (total * c / chunks)
		local e = a + unit * (total * (c + 1) / chunks)
		local len = (e - s).Magnitude
		local mid = (s + e) / 2
		local cf = CFrame.lookAt(mid, mid + unit) -- -Z ao longo da parede
		part(wallsFolder, "Wall", Vector3.new(th, h, len + th), cf * CFrame.new(0, FLOOR + h / 2 - mid.Y, 0), theme.Body, Enum.Material.SmoothPlastic)
		deco(part(wallsFolder, "WallBand", Vector3.new(th + 0.8, 3.5, len + th), cf * CFrame.new(0, FLOOR + 6 - mid.Y, 0), theme.Band, Enum.Material.SmoothPlastic))
		deco(part(wallsFolder, "WallBand", Vector3.new(th + 0.8, 1.6, len + th), cf * CFrame.new(0, FLOOR + h - 4 - mid.Y, 0), theme.Band, Enum.Material.SmoothPlastic))
		-- topo arredondado (cilindro deitado ao longo da parede)
		deco(part(wallsFolder, "WallTop", Vector3.new(len + th + 2, th + 5, th + 5), cf * CFrame.new(0, FLOOR + h + 1 - mid.Y, 0) * CFrame.Angles(0, math.rad(90), 0), theme.Top, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder))
	end
	local spacing = pillarSpacing or 90
	local count = math.floor(total / spacing)
	for i = 0, count do
		local pos = a + unit * math.min(i * spacing, total)
		local cf = CFrame.lookAt(pos, pos + unit)
		part(wallsFolder, "Pillar", Vector3.new(th + 6, h + 6, th + 6), cf * CFrame.new(0, FLOOR + (h + 6) / 2 - pos.Y, 0), theme.Pillar, Enum.Material.SmoothPlastic)
		deco(part(wallsFolder, "PillarCap", Vector3.new(th + 9, th + 9, th + 9), cf * CFrame.new(0, FLOOR + h + 8 - pos.Y, 0), theme.Top, Enum.Material.SmoothPlastic, Enum.PartType.Ball))
	end
end

----------------------------------------------------------------------
-- LOBBY
----------------------------------------------------------------------
local lobby = folder("Lobby", map)
wallsFolder = folder("Walls", map)
local L = TrackConfig.Lobby
local lobbyW = L.MaxX - L.MinX
local lobbyD = L.MaxZ - L.MinZ
local lobbyCenter = Vector3.new((L.MinX + L.MaxX) / 2, FLOOR - 2, (L.MinZ + L.MaxZ) / 2)
local WX = L.MaxX + WALL.Thickness / 2 + 1 -- linha das paredes laterais do lobby
local WZ = L.MaxZ + WALL.Thickness / 2 + 1 -- linha da parede do fundo

part(lobby, "Ground", Vector3.new(WX * 2 + 20, 4, lobbyD + 30), CFrame.new(lobbyCenter + Vector3.new(0, 0, 6)), rgb(110, 200, 90), Enum.Material.Grass)

-- Caminhos (rua central, ida às barracas e às bases)
local pathColor = rgb(235, 225, 200)
part(lobby, "PathMain", Vector3.new(26, 0.2, L.MaxZ - 34), CFrame.new(0, FLOOR + 0.05, 34 + (L.MaxZ - 34) / 2), pathColor, Enum.Material.Pavement)
part(lobby, "PathStands", Vector3.new(150, 0.2, 16), CFrame.new(0, FLOOR + 0.05, TrackConfig.Stands.WeightShop.Z), pathColor, Enum.Material.Pavement)
for _, b in TrackConfig.Bases do
	if b.Facing > 0 then
		part(lobby, "PathBase", Vector3.new(240, 0.2, 14), CFrame.new(0, FLOOR + 0.05, b.Z), pathColor, Enum.Material.Pavement)
	end
end

-- Paredes do lobby (laterais, fundo e "ombros" que ligam com a pista)
local TW = WALL.TrackHalfWidth
cartoonWall(Vector3.new(-WX, FLOOR, -6), Vector3.new(-WX, FLOOR, WZ), "Meadow", 80)
cartoonWall(Vector3.new(WX, FLOOR, -6), Vector3.new(WX, FLOOR, WZ), "Meadow", 80)
cartoonWall(Vector3.new(-WX, FLOOR, WZ), Vector3.new(WX, FLOOR, WZ), "Meadow", 80)
cartoonWall(Vector3.new(-WX, FLOOR, -6), Vector3.new(-TW, FLOOR, -6), "Meadow", 60)
cartoonWall(Vector3.new(TW, FLOOR, -6), Vector3.new(WX, FLOOR, -6), "Meadow", 60)

-- Árvores fofinhas
local function tree(parent, pos: any, scale: number, leafColor)
	local m = model("Tree", parent)
	deco(part(m, "Trunk", Vector3.new(7, 1.6, 1.6) * scale, CFrame.new(pos + Vector3.new(0, 3.5 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(130, 90, 60), Enum.Material.Wood, Enum.PartType.Cylinder))
	deco(part(m, "Leaves", Vector3.new(8, 8, 8) * scale, CFrame.new(pos + Vector3.new(0, 8.5 * scale, 0)), leafColor, Enum.Material.Grass, Enum.PartType.Ball))
	deco(part(m, "Leaves", Vector3.new(5.5, 5.5, 5.5) * scale, CFrame.new(pos + Vector3.new(2.2 * scale, 7 * scale, 1.2 * scale)), leafColor, Enum.Material.Grass, Enum.PartType.Ball))
	deco(part(m, "Leaves", Vector3.new(5, 5, 5) * scale, CFrame.new(pos + Vector3.new(-2 * scale, 7.4 * scale, -1.4 * scale)), leafColor, Enum.Material.Grass, Enum.PartType.Ball))
	return m
end
local decor = folder("Decor", lobby)
for i, p in {
	{ -140, 22 }, { 140, 22 }, { -165, 60 }, { 165, 60 }, { -125, 82 }, { 125, 82 },
	{ -62, 112 }, { 62, 112 }, { -62, 236 }, { 62, 236 }, { -95, 290 }, { 95, 290 },
} do
	tree(decor, Vector3.new(p[1], FLOOR, p[2]), 0.9 + (i % 3) * 0.15, rgb(80 + (i % 3) * 15, 185, 90))
end
-- Canteiros de flores
local flowerColors = { rgb(255, 120, 150), rgb(255, 220, 90), rgb(170, 130, 255), rgb(255, 255, 255) }
for i = 1, 70 do
	local side = if i % 2 == 0 then 1 else -1
	local x = side * (32 + (i * 37) % 70)
	local z = 96 + (i * 53) % 190
	deco(part(decor, "Flower", Vector3.new(0.9, 0.9, 0.9), CFrame.new(x, FLOOR + 0.45, z), flowerColors[i % 4 + 1], Enum.Material.SmoothPlastic, Enum.PartType.Ball))
end
-- Fonte no centro do lobby
local fountain = model("Fountain", decor)
local FZ = 222
part(fountain, "Basin", Vector3.new(2.4, 26, 26), CFrame.new(0, FLOOR + 1.2, FZ) * CFrame.Angles(0, 0, math.rad(90)), rgb(220, 220, 235), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
deco(part(fountain, "Water", Vector3.new(0.4, 23, 23), CFrame.new(0, FLOOR + 2.3, FZ) * CFrame.Angles(0, 0, math.rad(90)), rgb(90, 190, 255), Enum.Material.Glass, Enum.PartType.Cylinder)).Transparency = 0.2
part(fountain, "Column", Vector3.new(8, 3, 3), CFrame.new(0, FLOOR + 5, FZ) * CFrame.Angles(0, 0, math.rad(90)), rgb(220, 220, 235), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
local fEgg = deco(part(fountain, "GoldenEgg", Vector3.new(4, 5, 4), CFrame.new(0, FLOOR + 11, FZ), rgb(255, 205, 60), Enum.Material.SmoothPlastic))
new("SpecialMesh", { MeshType = Enum.MeshType.Sphere }, fEgg)
new("PointLight", { Range = 14, Brightness = 1.2, Color = rgb(255, 220, 120) }, fEgg)
-- Postes de luz ao longo da rua
for _, z in { 50, 100, 170, 260 } do
	for _, x in { -18, 18 } do
		local m = model("Lamp", decor)
		part(m, "Pole", Vector3.new(0.8, 12, 0.8), CFrame.new(x, FLOOR + 6, z), rgb(60, 60, 70), Enum.Material.Metal)
		local bulb = deco(part(m, "Bulb", Vector3.new(2.2, 2.2, 2.2), CFrame.new(x, FLOOR + 12.5, z), rgb(255, 240, 200), Enum.Material.Neon, Enum.PartType.Ball))
		new("PointLight", { Range = 18, Brightness = 1.2, Color = rgb(255, 230, 190) }, bulb)
	end
end

-- Spawn geral (o jogador é levado para a própria base depois de carregar)
local spawn = new("SpawnLocation", {
	Name = "Spawn",
	Anchored = true,
	Size = Vector3.new(1, 16, 16),
	CFrame = CFrame.new(TrackConfig.Spawn.X, FLOOR + 0.3, TrackConfig.Spawn.Z) * CFrame.Angles(0, 0, math.rad(90)),
	Color = rgb(255, 210, 90),
	Material = Enum.Material.SmoothPlastic,
	Neutral = true,
	Duration = 0,
}, lobby)
spawn.Shape = Enum.PartType.Cylinder

----------------------------------------------------------------------
-- ZONA DE CHUTE
----------------------------------------------------------------------
local kick = folder("KickZone", map)
local KZ = TrackConfig.KickZone
local kzW = KZ.MaxX - KZ.MinX
local kzD = KZ.MaxZ - KZ.MinZ
local pad = part(kick, "Pad", Vector3.new(kzW, 1, kzD), CFrame.new(0, FLOOR - 0.45, (KZ.MinZ + KZ.MaxZ) / 2), rgb(255, 175, 70), Enum.Material.SmoothPlastic)
pad.CanQuery = true
for i = 0, 6 do
	local x = KZ.MinX + 8 + i * (kzW - 16) / 6
	deco(part(kick, "Stripe", Vector3.new(3, 0.12, kzD - 6), CFrame.new(x, FLOOR + 0.07, (KZ.MinZ + KZ.MaxZ) / 2), rgb(255, 235, 200), Enum.Material.SmoothPlastic))
end
deco(part(kick, "KickLine", Vector3.new(kzW, 0.25, 1.6), CFrame.new(0, FLOOR + 0.12, TrackConfig.KickLineZ), rgb(255, 255, 255), Enum.Material.Neon))
local floorSign = deco(part(kick, "FloorText", Vector3.new(60, 0.1, 12), CFrame.new(0, FLOOR + 0.1, KZ.MaxZ - 9), rgb(255, 175, 70), Enum.Material.SmoothPlastic))
floorSign.Transparency = 1
surfaceText(floorSign, { { Text = "KICK ZONE", Color = rgb(255, 255, 255) } }, Enum.NormalId.Top, 20)

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
-- BARRACAS (só duas: Weight Shop e Rebirth, uma de cada lado)
----------------------------------------------------------------------
local stands = folder("Stands", map)

local function facingRotation(facing: number)
	-- frente (-Z local) apontando para +X (facing = 1) ou -X (facing = -1)
	return if facing > 0 then CFrame.Angles(0, math.rad(-90), 0) else CFrame.Angles(0, math.rad(90), 0)
end

local function dumbbellDeco(parent, cf, color, scale: number)
	deco(part(parent, "Bar", Vector3.new(3 * scale, 0.4 * scale, 0.4 * scale), cf, rgb(200, 200, 210), Enum.Material.Metal, Enum.PartType.Cylinder))
	for _, s in { -1, 1 } do
		deco(part(parent, "Plate", Vector3.new(0.5 * scale, 1.8 * scale, 1.8 * scale), cf * CFrame.new(s * 1.2 * scale, 0, 0), color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder))
	end
end

local function buildStall(key: string, def)
	local m = model(def.Title, stands)
	m:SetAttribute("Panel", def.Panel)
	local color = rgbT(def.Color)
	local base = CFrame.new(def.X, FLOOR, def.Z) * facingRotation(def.Facing)
	part(m, "Counter", Vector3.new(18, 4, 4), base * CFrame.new(0, 2, -3), rgb(250, 245, 235), Enum.Material.Wood)
	part(m, "CounterTrim", Vector3.new(18.4, 0.6, 4.4), base * CFrame.new(0, 4.2, -3), color, Enum.Material.SmoothPlastic)
	part(m, "Back", Vector3.new(18, 12, 1), base * CFrame.new(0, 6, 4), rgb(240, 230, 210), Enum.Material.Wood)
	for _, x in { -8.5, 8.5 } do
		part(m, "Post", Vector3.new(1.2, 13, 1.2), base * CFrame.new(x, 6.5, -4.5), rgb(250, 245, 235), Enum.Material.Wood)
		deco(part(m, "PostBall", Vector3.new(2, 2, 2), base * CFrame.new(x, 13.4, -4.5), color, Enum.Material.SmoothPlastic, Enum.PartType.Ball))
	end
	for i = 0, 8 do
		local stripe = if i % 2 == 0 then color else rgb(255, 255, 255)
		wedge(m, "Awning", Vector3.new(2, 2.5, 9.5), base * CFrame.new(-8 + i * 2, 14.25, -0.5) * CFrame.Angles(0, math.rad(180), 0), stripe, Enum.Material.Fabric)
	end
	local sign = part(m, "Sign", Vector3.new(16, 4, 0.6), base * CFrame.new(0, 17.6, 0.5), rgb(40, 45, 80), Enum.Material.SmoothPlastic)
	surfaceText(sign, {
		{ Text = def.Title, Color = color, Height = 0.65 },
		{ Text = def.Subtitle, Color = rgb(255, 255, 255), Height = 0.35, Stroke = 2 },
	}, Enum.NormalId.Front, 30)
	if key == "WeightShop" then
		local weightColors = { rgb(170, 120, 75), rgb(120, 125, 135), rgb(70, 160, 255), rgb(255, 200, 50) }
		for i, c in weightColors do
			dumbbellDeco(m, base * CFrame.new(-6 + (i - 1) * 4, 5.4, -3), c, 1)
		end
		-- halter gigante no topo
		dumbbellDeco(m, base * CFrame.new(0, 21.5, 0.5), color, 3)
	else
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
		for _, x in { -6, 6 } do
			deco(part(m, "Crystal", Vector3.new(1.6, 4, 1.6), base * CFrame.new(x, 6.2, -3) * CFrame.Angles(0, math.rad(45), math.rad(10)), color, Enum.Material.Neon))
		end
	end
	local promptPart = deco(part(m, "PromptPart", Vector3.new(4, 4, 4), base * CFrame.new(0, 3, -6), color, Enum.Material.SmoothPlastic))
	promptPart.Transparency = 1
	prompt(promptPart, def.Action, def.Title, def.Panel)
	deco(part(m, "Mat", Vector3.new(16, 0.2, 9), base * CFrame.new(0, 0.12, -10), color, Enum.Material.Fabric))
	return m
end
for key, def in TrackConfig.Stands do
	buildStall(key, def)
end

----------------------------------------------------------------------
-- BASES DOS JOGADORES (pedestais para pets, como no jogo de referência)
----------------------------------------------------------------------
local basesFolder = folder("Bases", map)
local BW = TrackConfig.BaseSize.Width
local BD = TrackConfig.BaseSize.Depth
for index, def in TrackConfig.Bases do
	local m = model("Base" .. index, basesFolder)
	m:SetAttribute("BaseId", index)
	local color = rgbT(def.Color)
	local dark = Color3.new(color.R * 0.75, color.G * 0.75, color.B * 0.75)
	local cf0 = CFrame.new(def.X, FLOOR, def.Z) * facingRotation(def.Facing)
	local floor = part(m, "Floor", Vector3.new(BW, 1.2, BD), cf0 * CFrame.new(0, 0.6, 0), color, Enum.Material.SmoothPlastic)
	m.PrimaryPart = floor
	part(m, "FloorTrim", Vector3.new(BW + 2, 0.8, BD + 2), cf0 * CFrame.new(0, 0.4, 0), dark, Enum.Material.SmoothPlastic)
	-- xadrez suave no chão
	for gx = 0, 3 do
		for gz = 0, 3 do
			if (gx + gz) % 2 == 0 then
				deco(part(m, "Tile", Vector3.new(BW / 4 - 0.5, 0.1, BD / 4 - 0.5), cf0 * CFrame.new(-BW / 2 + BW / 8 + gx * BW / 4, 1.22, -BD / 2 + BD / 8 + gz * BD / 4), color:Lerp(Color3.new(1, 1, 1), 0.25), Enum.Material.SmoothPlastic))
			end
		end
	end
	-- Muretas com topo arredondado (fundo, lados e frente com entrada)
	local function lowWall(fromX, fromZ, toX, toZ)
		local a = cf0 * CFrame.new(fromX, 0, fromZ)
		local b = cf0 * CFrame.new(toX, 0, toZ)
		local len = (b.Position - a.Position).Magnitude
		local mid = (a.Position + b.Position) / 2
		local wcf = CFrame.lookAt(mid, b.Position)
		part(m, "Wall", Vector3.new(2.4, 6, len), wcf * CFrame.new(0, 4.2, 0), rgb(255, 250, 240), Enum.Material.SmoothPlastic)
		deco(part(m, "WallTop", Vector3.new(len + 1, 3.4, 3.4), wcf * CFrame.new(0, 7.4, 0) * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder))
	end
	lowWall(-BW / 2, BD / 2, BW / 2, BD / 2)
	lowWall(-BW / 2, -BD / 2, -BW / 2, BD / 2)
	lowWall(BW / 2, -BD / 2, BW / 2, BD / 2)
	lowWall(-BW / 2, -BD / 2, -10, -BD / 2)
	lowWall(10, -BD / 2, BW / 2, -BD / 2)
	-- Postes nos cantos
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local pcf = cf0 * CFrame.new(c[1] * BW / 2, 0, c[2] * BD / 2)
		part(m, "CornerPost", Vector3.new(10, 4, 4), pcf * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)), dark, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		deco(part(m, "CornerBall", Vector3.new(4.6, 4.6, 4.6), pcf * CFrame.new(0, 11, 0), color, Enum.Material.SmoothPlastic, Enum.PartType.Ball))
	end
	-- Portal de entrada com placa do dono
	for _, x in { -11, 11 } do
		part(m, "GatePost", Vector3.new(2, 15, 2), cf0 * CFrame.new(x, 7.5, -BD / 2), dark, Enum.Material.SmoothPlastic)
	end
	local sign = part(m, "Sign", Vector3.new(24, 5.5, 1), cf0 * CFrame.new(0, 16, -BD / 2), rgb(40, 45, 80), Enum.Material.SmoothPlastic)
	surfaceText(sign, {
		{ Name = "Owner", Text = "FREE BASE", Color = rgb(255, 255, 255), Height = 0.6 },
		{ Name = "Income", Text = "", Color = rgb(255, 215, 80), Height = 0.4, Stroke = 2 },
	}, Enum.NormalId.Front, 30)
	-- Ponto de nascimento (olhando para a rua / zona de chute)
	local spawnPoint = deco(part(m, "SpawnPoint", Vector3.new(4, 1, 4), cf0 * CFrame.new(0, 1.3, -BD / 2 + 7), color, Enum.Material.SmoothPlastic))
	spawnPoint.Transparency = 1
	deco(part(m, "WelcomeMat", Vector3.new(16, 0.15, 6), cf0 * CFrame.new(0, 1.25, -BD / 2 + 4), dark, Enum.Material.Fabric))

	-- Pedestais
	local slots = folder("Slots", m)
	for slot = 1, BaseConfig.SlotCount do
		local sx, sz = BaseConfig.SlotLocal(slot)
		local sm = model("Slot" .. slot, slots)
		sm:SetAttribute("Slot", slot)
		local scf = cf0 * CFrame.new(sx, 0, sz)
		part(sm, "Pedestal", Vector3.new(2.6, 7.5, 7.5), scf * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(245, 245, 250), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		deco(part(sm, "Rim", Vector3.new(0.8, 8.4, 8.4), scf * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), dark, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder))
		local anchor = deco(part(sm, "Anchor", Vector3.new(1, 1, 1), scf * CFrame.new(0, 3.8, 0), color, Enum.Material.SmoothPlastic))
		anchor.Transparency = 1
		-- Botão de coletar (pise para pegar as moedas)
		local collect = part(sm, "Pad", Vector3.new(0.5, 4.6, 4.6), scf * CFrame.new(0, 1.4, BaseConfig.PadOffset) * CFrame.Angles(0, 0, math.rad(90)), rgb(90, 210, 90), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		collect.CanTouch = true
		-- Prompt (colocar / pegar pet / liberar slot)
		local promptPart = deco(part(sm, "PromptPart", Vector3.new(2, 2, 2), scf * CFrame.new(0, 4, 0), color, Enum.Material.SmoothPlastic))
		promptPart.Transparency = 1
		local pp = new("ProximityPrompt", {
			Name = "Prompt",
			ActionText = "",
			ObjectText = "",
			HoldDuration = 0,
			MaxActivationDistance = 9,
			RequiresLineOfSight = false,
			KeyboardKeyCode = Enum.KeyCode.F,
			GamepadKeyCode = Enum.KeyCode.ButtonY,
		}, promptPart)
		pp:SetAttribute("BaseSlot", slot)
		-- Texto acima do pedestal
		local gui = new("BillboardGui", {
			Name = "Info",
			Size = UDim2.fromOffset(170, 74),
			StudsOffset = Vector3.new(0, 6, 0),
			MaxDistance = 70,
			LightInfluence = 0,
		}, anchor)
		local lines = { { "Title", 0, 0.4, rgb(255, 255, 255) }, { "Rate", 0.4, 0.3, rgb(140, 255, 150) }, { "Stored", 0.7, 0.3, rgb(255, 215, 80) } }
		for _, l in lines do
			local label = new("TextLabel", {
				Name = l[1],
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0, l[2]),
				Size = UDim2.fromScale(1, l[3]),
				Text = "",
				TextScaled = true,
				FontFace = FONT,
				TextColor3 = l[4],
			}, gui)
			new("UIStroke", { Thickness = 2, Color = rgb(30, 30, 50) }, label)
		end
	end
end

----------------------------------------------------------------------
-- LEADERBOARD
----------------------------------------------------------------------
local lbDef = TrackConfig.Leaderboard
local lb = model("Leaderboard", lobby)
part(lb, "PostL", Vector3.new(1.4, 22, 1.4), CFrame.new(lbDef.X - 10, FLOOR + 11, lbDef.Z), rgb(60, 60, 75), Enum.Material.Metal)
part(lb, "PostR", Vector3.new(1.4, 22, 1.4), CFrame.new(lbDef.X + 10, FLOOR + 11, lbDef.Z), rgb(60, 60, 75), Enum.Material.Metal)
local board = part(lb, "Board", Vector3.new(19, 18, 0.8), CFrame.new(lbDef.X, FLOOR + 13, lbDef.Z), rgb(35, 40, 70), Enum.Material.SmoothPlastic)
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
		local side = part(floors, "Side" .. area.Id, Vector3.new(TW * 2 + 40, 4, chunkLen), CFrame.new(CX, FLOOR - 2.6, zStart - chunkLen / 2), Color3.new(color.R * 0.8, color.G * 0.8, color.B * 0.8), material)
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

-- Paredes cartunescas dos dois lados da pista (tema de cada área) e no fim
for _, area in AreaConfig.Areas do
	local theme = AREA_THEME[area.Id] or "Meadow"
	local z0 = K0 - (if area.Id == 1 then -6 else area.Start)
	local z1 = K0 - area.End - (if area.Id == #AreaConfig.Areas then 12 else 0)
	cartoonWall(Vector3.new(CX - TW, FLOOR, z0), Vector3.new(CX - TW, FLOOR, z1), theme, 100)
	cartoonWall(Vector3.new(CX + TW, FLOOR, z0), Vector3.new(CX + TW, FLOOR, z1), theme, 100)
end
cartoonWall(Vector3.new(CX - TW, FLOOR, K0 - TrackConfig.Length - 12), Vector3.new(CX + TW, FLOOR, K0 - TrackConfig.Length - 12), "Cosmic", 60)

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
local weightAssets = folder("Weights", assets)
weightAssets:SetAttribute("Info", "Coloque aqui um Model com o nome do peso (WeightConfig.Name) para substituir o peso procedural")

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
