-- Testes dos módulos puros (rodar com: lune run tools/tests.luau)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local MOD = "src/ReplicatedStorage/Modules/"
local cache = {}
local function load(name)
	if cache[name] then return cache[name] end
	local env = setmetatable({
		script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
		require = function(n) return load(n) end,
	}, { __index = _G })
	cache[name] = luau.load(fs.readFile(MOD .. name .. ".lua"), { debugName = name, environment = env })()
	return cache[name]
end

local failures, passed = 0, 0
local function eq(actual, expected, label)
	if actual == expected then passed += 1 else failures += 1 print(("FAIL %s: esperado %s, veio %s"):format(label, tostring(expected), tostring(actual))) end
end
local function ok(cond, label)
	if cond then passed += 1 else failures += 1 print("FAIL " .. label) end
end

local NF = load("NumberFormat")
eq(NF.Abbreviate(5), "5", "abbr 5")
eq(NF.Abbreviate(999), "999", "abbr 999")
eq(NF.Abbreviate(1000), "1K", "abbr 1000")
eq(NF.Abbreviate(1234), "1.23K", "abbr 1234")
eq(NF.Abbreviate(15300), "15.3K", "abbr 15300")
eq(NF.Abbreviate(152000), "152K", "abbr 152000")
eq(NF.Abbreviate(1.2e6), "1.2M", "abbr 1.2M")
eq(NF.Abbreviate(3.4e9), "3.4B", "abbr B")
eq(NF.Abbreviate(7e12), "7T", "abbr T")
eq(NF.Abbreviate(2.5e15), "2.5Qa", "abbr Qa")
eq(NF.Abbreviate(9.99e18), "9.99Qi", "abbr Qi")
eq(NF.Distance(542.7), "542m", "dist")
eq(NF.Distance(5432), "5,432m", "dist commas")
eq(NF.Commas(1234567), "1,234,567", "commas")
eq(NF.Multiplier(1.5), "x1.5", "mult")
eq(NF.Percent(0.3), "0.3%", "pct small")
eq(NF.Percent(45), "45%", "pct")
eq(NF.Time(3725), "1h 02m", "time")

-- Trajetória: começa no StartZ e termina exatamente na distância
local FP = load("FlightPath")
local Track = load("TrackConfig")
local info = { Distance = 500, StartX = 0, EndX = 10, StartZ = 10, Blocked = false }
local _, h0, z0 = FP.Sample(info, 0)
local x1, h1, z1 = FP.Sample(info, 1)
eq(z0, 10, "path start z")
eq(h0, 0, "path start h")
eq(math.floor(Track.KickLineZ - z1 + 0.5), 500, "path end distance")
eq(x1, 10, "path end x")
eq(h1, 0, "path end height")
local _, hMid = FP.Sample(info, 0.3)
ok(hMid > 50, "arco alto no meio do voo")
local prev = -math.huge
local monotonic = true
for i = 0, 100 do
	local _, _, z = FP.Sample(info, i / 100)
	local d = FP.DistanceAt(z)
	if d + 1e-6 < prev then monotonic = false end
	prev = d
end
ok(monotonic, "distância nunca diminui (voo normal)")
local blocked = { Distance = 248, StartX = 0, EndX = 0, StartZ = 5, Blocked = true }
local maxD = 0
for i = 0, 100 do
	local _, _, z = FP.Sample(blocked, i / 100)
	maxD = math.max(maxD, FP.DistanceAt(z))
end
ok(maxD <= 248.01 and maxD > 247, "bloqueado não passa do portão")

-- Fórmulas
local F = load("Formulas")
local Areas = load("AreaConfig")
local Eggs = load("EggConfig")
local Pets = load("PetConfig")
local data = { Coins = 0, Strength = 0, Rebirths = 0, BestDistance = 0, HighestArea = 1, Upgrades = { KickPower = 0, StrengthGain = 0, CoinGain = 0, WalkSpeed = 0 }, UnlockedEggs = { Basic = true }, SelectedEgg = "Basic", Pets = {}, Equipped = {} }
eq(F.KickPower(data), 10, "kick power base")
ok(F.RawDistance(F.KickPower(data)) > 8, "primeiro chute > 8m")
eq(F.TrainGain(data, 1), 1, "treino base")
eq(F.MaxDistance(data), 250, "limite área 1")
data.SelectedEgg = "Rare"
eq(F.KickEgg(data), "Basic", "ovo não desbloqueado volta para Basic")
data.UnlockedEggs.Rare = true
eq(F.KickEgg(data), "Basic", "ovo pesado demais volta para Basic")
data.Strength = 500
eq(F.KickEgg(data), "Rare", "ovo Rare liberado")
data.Pets = { p1 = { N = "Chick" }, p2 = { N = "Bunny" } }
data.Equipped = { "p1", "p2" }
local bonus = F.PetBonus(data)
ok(math.abs(bonus.Coins - (1 + 0.10 + 0.05)) < 1e-9, "bônus de pets somados")
eq(F.MaxEquipped(data), 3, "slots base")
data.Rebirths = 2
eq(F.MaxEquipped(data), 4, "slot extra com 2 rebirths")

-- Pesos e base
local Weights = load("WeightConfig")
local BaseConfig = load("BaseConfig")
local d2 = { Coins = 200, Strength = 0, Rebirths = 0, Upgrades = { KickPower = 0, StrengthGain = 0, CoinGain = 0, WalkSpeed = 0 }, Pets = { a = { N = "Chick" }, b = { N = "Piglet" } }, Equipped = {}, OwnedWeights = { Wooden = true }, EquippedWeight = "Wooden", Base = { Unlocked = 4, Slots = { ["1"] = { Pet = "a", Stored = 0 } } } }
eq(F.TrainGain(d2), 1, "peso inicial dá 1")
eq(F.NextWeight(d2), "Iron", "próximo peso")
ok(F.CanBuyWeight(d2, "Iron"), "pode comprar Iron com 200 moedas")
ok(not F.CanBuyWeight(d2, "Diamond"), "Diamond exige rebirth")
d2.OwnedWeights.Iron = true
d2.EquippedWeight = "Iron"
eq(F.TrainGain(d2), 3, "Iron dá 3")
eq(F.PlacedSlot(d2, "a"), "1", "pet na base")
eq(F.PlacedSlot(d2, "b"), nil, "pet fora da base")
eq(F.PlacedCount(d2), 1, "contagem da base")
ok(math.abs(F.BaseIncome(d2) - BaseConfig.RarityIncome.Common * 1.10) < 1e-9, "renda da base")
local lastCost = -1
for _, id in Weights.Order do
	ok(Weights.Get(id).Cost > lastCost, "pesos ficam mais caros: " .. id)
	lastCost = Weights.Get(id).Cost
end
for slot = 1, BaseConfig.SlotCount do
	local x, z = BaseConfig.SlotLocal(slot)
	ok(x ~= nil and z ~= nil, "slot " .. slot .. " tem posição")
	if slot > BaseConfig.FreeSlots then ok(BaseConfig.SlotCosts[slot] ~= nil, "slot " .. slot .. " tem preço") end
end

-- Consistência das configs
for _, id in Eggs.Order do
	local egg = Eggs.Get(id)
	local total = 0
	for _, e in egg.Pets do
		total += e.Chance
		ok(Pets.Get(e.Pet) ~= nil, "pet existe: " .. e.Pet)
	end
	ok(math.abs(total - 100) < 1e-6, "chances somam 100% em " .. id)
end
for i, area in Areas.Areas do
	if i > 1 then eq(area.Start, Areas.Areas[i - 1].End, "áreas contínuas " .. i) end
end
eq(Areas.Areas[#Areas.Areas].End, Track.Length, "última área termina no fim da pista")

print(("%d testes passaram, %d falharam"):format(passed, failures))
if failures > 0 then error("testes falharam") end
