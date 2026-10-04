-- Simulação de balanceamento (roda com Lune): lune run tools/balance_sim.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local MOD = "src/ReplicatedStorage/Modules/"
local cache = {}
local function load(name)
	if cache[name] then return cache[name] end
	local src = fs.readFile(MOD .. name .. ".lua")
	local scriptShim = { Parent = setmetatable({}, { __index = function(_, k) return k end }) }
	local env = setmetatable({ script = scriptShim, require = function(n) return load(n) end }, { __index = _G })
	local fn = luau.load(src, { debugName = name, environment = env })
	cache[name] = fn()
	return cache[name]
end
local F = load("Formulas")
local Up = load("UpgradeConfig")
local Eggs = load("EggConfig")
local Areas = load("AreaConfig")
local RB = load("RebirthConfig")
local NF = load("NumberFormat")
local Train = load("TrainConfig")

local d = { Coins = 0, Strength = 0, Rebirths = 0, BestDistance = 0, HighestArea = 1, Upgrades = { KickPower = 0, StrengthGain = 0, CoinGain = 0, WalkSpeed = 0 }, UnlockedEggs = { Basic = true }, SelectedEgg = "Basic", Pets = {}, Equipped = {} }
local t = 0
local log = {}
local function note(s) table.insert(log, string.format("[%6s] %s", NF.Time(t), s)) end
local firstKick = true
local hatches = {}
local petN = 0
local kicks = 0
local function shop()
	local bought = true
	while bought do
		bought = false
		-- áreas
		local nextA = Areas.Areas[d.HighestArea + 1]
		if nextA and F.MeetsRequirements(d, nextA.Requirements) then
			d.Coins -= nextA.Requirements.Coins or 0 d.HighestArea += 1 bought = true
			note("Unlocked area " .. nextA.Name)
		end
		for _, id in Eggs.Order do
			local e = Eggs.Get(id)
			if not d.UnlockedEggs[id] and d.Strength >= e.StrengthRequired and d.Rebirths >= e.RebirthsRequired and d.Coins >= e.UnlockCost then
				d.Coins -= e.UnlockCost d.UnlockedEggs[id] = true d.SelectedEgg = id bought = true note("Unlocked " .. e.Name) end
		end
		local ok = F.CanRebirth(d)
		if ok then
			d.Coins = 0 d.Strength = 0 d.Rebirths += 1 bought = true note(("REBIRTH -> %d"):format(d.Rebirths))
		end
		-- choca alguns pets do melhor ovo (resultado médio: pet mais comum)
		local bestEgg = F.KickEgg(d)
		local e = Eggs.Get(bestEgg)
		hatches[bestEgg] = hatches[bestEgg] or 0
		if hatches[bestEgg] < 4 and d.Coins >= e.HatchCost then
			d.Coins -= e.HatchCost hatches[bestEgg] += 1
			petN += 1
			d.Pets["p" .. petN] = { N = e.Pets[1].Pet }
			table.insert(d.Equipped, 1, "p" .. petN)
			while #d.Equipped > F.MaxEquipped(d) do table.remove(d.Equipped) end
			bought = true
		end
		-- poupa para a próxima meta se os outros requisitos já foram cumpridos
		local saving = 0
		if nextA then
			local r = table.clone(nextA.Requirements) r.Coins = nil
			if F.MeetsRequirements(d, r) then saving = math.max(saving, nextA.Requirements.Coins or 0) end
		end
		if d.Strength >= RB.StrengthRequired(d.Rebirths) then saving = math.max(saving, RB.CoinCost(d.Rebirths)) end
		local cheapest, cc
		for _, id in Up.Order do
			local lvl = d.Upgrades[id]
			if lvl < Up.Get(id).MaxLevel then
				local c = Up.Cost(id, lvl)
				if not cc or c < cc then cheapest, cc = id, c end
			end
		end
		if cheapest and d.Coins - saving >= cc then d.Coins -= cc d.Upgrades[cheapest] += 1 bought = true end
	end
end
local nextReport = 60
while t < 12 * 3600 do
	-- treina 15s (3 cliques/s)
	for i = 1, 38 do d.Strength += F.TrainGain(d, F.BestStation(d)) end
	t += 15 + 6
	for k = 1, 3 do
		local egg = F.KickEgg(d)
		local dist = math.min(F.RawDistance(F.KickPower(d), 1), F.MaxDistance(d))
		local coins = F.CoinReward(d, dist, egg)
		d.Coins += coins
		kicks += 1
		if firstKick then note(("First kick: %.0fm, +%d coins (Str %d)"):format(dist, coins, d.Strength)) firstKick = false end
		if dist > d.BestDistance then d.BestDistance = dist end
		t += F.FlightTime(dist) + 1.2
	end
	t += 6
	shop()
	if t >= nextReport then
		note(("Str %s  Coins %s  Best %s  Area %d  Egg %s  R%d  Ups K%d S%d C%d W%d"):format(NF.Abbreviate(d.Strength), NF.Abbreviate(d.Coins), NF.Distance(d.BestDistance), d.HighestArea, F.KickEgg(d), d.Rebirths, d.Upgrades.KickPower, d.Upgrades.StrengthGain, d.Upgrades.CoinGain, d.Upgrades.WalkSpeed))
		nextReport = t < 600 and t + 120 or (t < 3600 and t + 900 or t + 3600)
	end
end
print(table.concat(log, "\n"))
