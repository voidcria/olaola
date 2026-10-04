-- SoundController: toca sons de feedback respeitando as configurações do jogador.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local SoundConfig = require(Modules.SoundConfig)

local SoundController = {}

local pools: { [string]: { Sound } } = {}
local folder: Folder
local music: Sound? = nil
local soundsEnabled = true

local POOL_SIZE = 3

local function getSound(name: string): Sound?
	local def = SoundConfig[name]
	if not def or def.Id == "" then
		return nil
	end
	local pool = pools[name]
	if not pool then
		pool = {}
		pools[name] = pool
	end
	for _, s in pool do
		if not s.IsPlaying then
			return s
		end
	end
	if #pool < POOL_SIZE then
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = def.Id
		s.Volume = def.Volume
		s.PlaybackSpeed = def.Pitch
		s.Parent = folder
		table.insert(pool, s)
		return s
	end
	return pool[1]
end

-- pitchJitter: variação aleatória de tom (deixa sons repetidos menos cansativos)
function SoundController:Play(name: string, pitchJitter: number?, volumeScale: number?)
	if not soundsEnabled then
		return
	end
	local s = getSound(name)
	if not s then
		return
	end
	local def = SoundConfig[name]
	s.PlaybackSpeed = def.Pitch * (1 + (pitchJitter or 0) * (math.random() * 2 - 1))
	s.Volume = def.Volume * (volumeScale or 1)
	s.TimePosition = 0
	s:Play()
end

function SoundController:SetSoundsEnabled(enabled: boolean)
	soundsEnabled = enabled
end

function SoundController:SetMusicEnabled(enabled: boolean)
	if not music then
		return
	end
	if enabled and not music.IsPlaying then
		music:Play()
	elseif not enabled then
		music:Stop()
	end
end

function SoundController:Init()
	folder = Instance.new("Folder")
	folder.Name = "KickAnEggSounds"
	folder.Parent = SoundService
	if SoundConfig.Music.Id ~= "" then
		local m = Instance.new("Sound")
		m.Name = "Music"
		m.SoundId = SoundConfig.Music.Id
		m.Volume = SoundConfig.Music.Volume
		m.Looped = true
		m.Parent = folder
		music = m
	end
end

function SoundController:Start(controllers)
	local DataController = controllers.DataController
	local function apply(data)
		self:SetSoundsEnabled(data.Settings.Sounds)
		self:SetMusicEnabled(data.Settings.Music)
	end
	DataController.Changed:Connect(apply)
	if DataController:Get() then
		apply(DataController:Get())
	end
end

return SoundController
