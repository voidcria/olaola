-- DataService: carrega, salva e replica os dados dos jogadores.
-- * Session lock (evita dois servidores escrevendo o mesmo save)
-- * pcall + tentativas com backoff em toda chamada ao DataStore
-- * Nunca salva por cima se o load falhou (o jogador é desconectado com aviso)
-- * Autosave periódico + save ao sair + BindToClose
-- * Em Studio sem "API Services" ligado, usa um armazenamento temporário em memória
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules.Config)
local Signal = require(Modules.Signal)
local Remotes = require(Modules.Remotes)
local NumberFormat = require(Modules.NumberFormat)
local EggConfig = require(Modules.EggConfig)
local PetConfig = require(Modules.PetConfig)
local UpgradeConfig = require(Modules.UpgradeConfig)
local AreaConfig = require(Modules.AreaConfig)
local WeightConfig = require(Modules.WeightConfig)
local BaseConfig = require(Modules.BaseConfig)

local DATA_VERSION = 1

local DataService = {
	PlayerLoaded = Signal.new(),
	PlayerRemoving = Signal.new(),
}

type Profile = {
	Data: any,
	Key: string,
	LastPlaytimeTick: number,
	Released: boolean,
	Saving: boolean,
}

local profiles: { [Player]: Profile } = {}
local dirty: { [Player]: boolean } = {}
local useMock = false
local mockStore: { [string]: any } = {}
local store: DataStore? = nil

----------------------------------------------------------------------
-- Template
----------------------------------------------------------------------
local function defaultData()
	local upgrades = {}
	for _, id in UpgradeConfig.Order do
		upgrades[id] = 0
	end
	return {
		Version = DATA_VERSION,
		Coins = 0,
		Strength = 0,
		Rebirths = 0,
		BestDistance = 0,
		TotalDistance = 0,
		TotalKicks = 0,
		TotalCoinsEarned = 0,
		TotalHatches = 0,
		Playtime = 0,
		HighestArea = 1,
		SelectedEgg = "Basic",
		UnlockedEggs = { Basic = true },
		Upgrades = upgrades,
		Pets = {}, -- [petId] = { N = nome, L = bloqueado }
		Equipped = {}, -- { petId, ... }
		Discovered = {}, -- [nome] = true
		PetCounter = 0,
		OwnedWeights = { Wooden = true },
		EquippedWeight = "Wooden",
		-- Base: Slots["1".."8"] = { Pet = petId, Stored = moedas acumuladas }
		Base = { Unlocked = BaseConfig.FreeSlots, Slots = {} },
		TotalBaseCollected = 0,
		AutoTrain = false,
		AutoKick = false,
		Settings = {
			EggCamera = true,
			Music = true,
			Sounds = true,
			ShowOtherEggs = true,
		},
	}
end

local function reconcile(target, template)
	for k, v in template do
		if target[k] == nil then
			target[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and type(target[k]) == "table" and next(v) ~= nil then
			reconcile(target[k], v)
		end
	end
end

local function finite(n: any, default: number): number
	if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return default
	end
	return n
end

-- Corrige qualquer valor inválido (dados antigos/corrompidos)
local function sanitize(data)
	for _, key in { "Coins", "Strength", "Rebirths", "BestDistance", "TotalDistance", "TotalKicks", "TotalCoinsEarned", "TotalHatches", "Playtime", "PetCounter", "TotalBaseCollected" } do
		data[key] = math.max(0, finite(data[key], 0))
	end
	data.HighestArea = math.clamp(math.floor(finite(data.HighestArea, 1)), 1, #AreaConfig.Areas)
	if not EggConfig.Get(data.SelectedEgg) then
		data.SelectedEgg = "Basic"
	end
	data.UnlockedEggs.Basic = true
	for id in data.UnlockedEggs do
		if not EggConfig.Get(id) then
			data.UnlockedEggs[id] = nil
		end
	end
	for id, level in data.Upgrades do
		local u = UpgradeConfig.Get(id)
		if not u then
			data.Upgrades[id] = nil
		else
			data.Upgrades[id] = math.clamp(math.floor(finite(level, 0)), 0, u.MaxLevel)
		end
	end
	for petId, pet in data.Pets do
		if type(pet) ~= "table" or not PetConfig.Get(pet.N) then
			data.Pets[petId] = nil
		end
	end
	-- Pesos
	data.OwnedWeights.Wooden = true
	for id in data.OwnedWeights do
		if not WeightConfig.Get(id) then
			data.OwnedWeights[id] = nil
		end
	end
	if not data.OwnedWeights[data.EquippedWeight] then
		data.EquippedWeight = "Wooden"
	end

	-- Base: slots válidos, pets existentes e sem duplicatas
	local base = data.Base
	base.Unlocked = math.clamp(math.floor(finite(base.Unlocked, BaseConfig.FreeSlots)), BaseConfig.FreeSlots, BaseConfig.SlotCount)
	local placed = {}
	for slot, entry in base.Slots do
		local n = tonumber(slot)
		if
			type(entry) ~= "table"
			or not n
			or n < 1
			or n > base.Unlocked
			or not data.Pets[entry.Pet]
			or placed[entry.Pet]
		then
			base.Slots[slot] = nil
		else
			placed[entry.Pet] = true
			entry.Stored = math.max(0, finite(entry.Stored, 0))
		end
	end

	local equipped = {}
	for _, petId in data.Equipped do
		if data.Pets[petId] and not table.find(equipped, petId) and not placed[petId] then
			table.insert(equipped, petId)
		end
	end
	data.Equipped = equipped
end

----------------------------------------------------------------------
-- Acesso ao DataStore (com mock para Studio)
----------------------------------------------------------------------
local function isStudioAccessError(err: any): boolean
	local msg = tostring(err)
	return string.find(msg, "StudioAccessToApisNotAllowed") ~= nil
		or string.find(msg, "API Services") ~= nil
		or string.find(msg, "403") ~= nil
end

local function updateAsync(key: string, transform: (any) -> any): (boolean, any)
	if useMock then
		local result = transform(mockStore[key])
		if result ~= nil then
			mockStore[key] = result
		end
		return true, result
	end
	local ok, result = pcall(function()
		return (store :: DataStore):UpdateAsync(key, transform)
	end)
	if not ok and RunService:IsStudio() and isStudioAccessError(result) then
		warn("[DataService] Studio sem acesso a API Services: usando dados temporários (não serão salvos).")
		useMock = true
		return updateAsync(key, transform)
	end
	return ok, result
end

----------------------------------------------------------------------
-- Load / Save
----------------------------------------------------------------------
local function loadData(player: Player)
	local key = "Player_" .. player.UserId
	local attempts = Config.Data.MaxLoadAttempts
	for attempt = 1, attempts do
		local lockedByOther = false
		local force = attempt == attempts
		local ok, result = updateAsync(key, function(old)
			if
				not force
				and type(old) == "table"
				and type(old.SessionLock) == "table"
				and old.SessionLock.JobId ~= game.JobId
				and os.time() - (old.SessionLock.Time or 0) < Config.Data.SessionLockTimeout
			then
				lockedByOther = true
				return nil -- cancela: outro servidor ainda está com o save
			end
			local data = (type(old) == "table" and type(old.Data) == "table") and old.Data or defaultData()
			return {
				Data = data,
				SessionLock = { JobId = game.JobId, Time = os.time() },
				SavedAt = os.time(),
			}
		end)
		if ok and result and not lockedByOther then
			return true, result.Data, key
		end
		if not player.Parent then
			return false, nil, key
		end
		if not ok then
			warn(string.format("[DataService] Falha ao carregar %s (tentativa %d): %s", player.Name, attempt, tostring(result)))
		end
		task.wait(math.min(2 ^ attempt, 10))
	end
	return false, nil, key
end

local function saveProfile(player: Player, profile: Profile, release: boolean): boolean
	if profile.Released then
		return true
	end
	-- Acumula tempo de jogo
	local now = os.clock()
	profile.Data.Playtime += now - profile.LastPlaytimeTick
	profile.LastPlaytimeTick = now

	while profile.Saving do
		task.wait(0.1)
	end
	profile.Saving = true
	local success = false
	for attempt = 1, 4 do
		local ok, err = updateAsync(profile.Key, function(old)
			if type(old) == "table" and type(old.SessionLock) == "table" and old.SessionLock.JobId ~= game.JobId then
				-- Outro servidor assumiu o save: não sobrescreve
				return nil
			end
			return {
				Data = profile.Data,
				SessionLock = if release then nil else { JobId = game.JobId, Time = os.time() },
				SavedAt = os.time(),
			}
		end)
		if ok then
			success = true
			break
		end
		warn(string.format("[DataService] Falha ao salvar %s (tentativa %d): %s", player.Name, attempt, tostring(err)))
		task.wait(attempt * 1.5)
	end
	profile.Saving = false
	if release then
		profile.Released = true
	end
	return success
end

----------------------------------------------------------------------
-- Replicação para o cliente
----------------------------------------------------------------------
local syncEvent: RemoteEvent

local function updateLeaderstats(player: Player, data)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		for _, name in { "Strength", "Best", "Rebirths" } do
			local v = Instance.new("StringValue")
			v.Name = name
			v.Parent = stats
		end
		stats.Parent = player
	end
	(stats :: any).Strength.Value = NumberFormat.Abbreviate(data.Strength)
	;(stats :: any).Best.Value = NumberFormat.Distance(data.BestDistance)
	;(stats :: any).Rebirths.Value = NumberFormat.Abbreviate(data.Rebirths)
end

local function replicate(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local snapshot = table.clone(profile.Data)
	snapshot.Playtime = profile.Data.Playtime + (os.clock() - profile.LastPlaytimeTick)
	syncEvent:FireClient(player, snapshot)
	updateLeaderstats(player, profile.Data)
end

----------------------------------------------------------------------
-- API pública
----------------------------------------------------------------------
function DataService:Get(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService:WaitForData(player: Player, timeout: number?)
	local started = os.clock()
	while player.Parent and not profiles[player] do
		if timeout and os.clock() - started > timeout then
			return nil
		end
		task.wait(0.1)
	end
	return self:Get(player)
end

-- Marca para replicar (agrupado a cada ~0.15s)
function DataService:MarkDirty(player: Player)
	if profiles[player] then
		dirty[player] = true
	end
end

function DataService:ReplicateNow(player: Player)
	dirty[player] = nil
	replicate(player)
end

function DataService:GetPlayers(): { Player }
	local list = {}
	for player in profiles do
		table.insert(list, player)
	end
	return list
end

-- Chama fn para jogadores já carregados e para os próximos
function DataService:OnPlayerLoaded(fn: (Player, any) -> ())
	for player, profile in profiles do
		task.spawn(fn, player, profile.Data)
	end
	return DataService.PlayerLoaded:Connect(fn)
end

function DataService:NewPetId(data): string
	data.PetCounter += 1
	return "p" .. data.PetCounter
end

----------------------------------------------------------------------
function DataService:Init()
	syncEvent = Remotes.Event("DataSync")
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore indisponível: " .. tostring(result))
		useMock = true
	end
end

function DataService:Start()
	local function onPlayerAdded(player: Player)
		local ok, data, key = loadData(player)
		if not player.Parent then
			-- Saiu durante o load: libera o lock se foi adquirido
			if ok then
				saveProfile(player, { Data = data, Key = key, LastPlaytimeTick = os.clock(), Released = false, Saving = false }, true)
			end
			return
		end
		if not ok then
			player:Kick("Could not load your data. Please rejoin in a moment - your progress is safe.")
			return
		end
		reconcile(data, defaultData())
		sanitize(data)
		data.Version = DATA_VERSION
		profiles[player] = {
			Data = data,
			Key = key,
			LastPlaytimeTick = os.clock(),
			Released = false,
			Saving = false,
		}
		replicate(player)
		DataService.PlayerLoaded:Fire(player, data)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if not profile then
			return
		end
		DataService.PlayerRemoving:Fire(player, profile.Data)
		saveProfile(player, profile, true)
		profiles[player] = nil
		dirty[player] = nil
	end)

	-- Replicação agrupada
	task.spawn(function()
		while true do
			task.wait(0.15)
			for player in dirty do
				dirty[player] = nil
				replicate(player)
			end
		end
	end)

	-- Autosave
	task.spawn(function()
		while true do
			task.wait(Config.Data.AutoSaveInterval)
			for player, profile in profiles do
				if player.Parent then
					task.spawn(saveProfile, player, profile, false)
					task.wait(0.5)
				end
			end
		end
	end)

	game:BindToClose(function()
		if useMock then
			return
		end
		local pending = 0
		for player, profile in profiles do
			pending += 1
			task.spawn(function()
				saveProfile(player, profile, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
