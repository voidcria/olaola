-- Lista central de RemoteEvents / RemoteFunctions.
-- O servidor cria as instâncias; o cliente espera por elas.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EVENTS = {
	"DataSync", -- S->C  snapshot dos dados do jogador
	"Notify", -- S->C  mensagem curta (texto, tipo)
	"KickRequest", -- C->S  pedido de chute (sem valores: o servidor calcula tudo)
	"FlightStarted", -- S->Todos  um ovo foi chutado (dados da trajetória)
	"FlightLanded", -- S->C  resultado do chute (moedas, recorde)
	"TrainRequest", -- C->S  treino na estação (id da estação)
	"TrainResult", -- S->C  ganho de força
	"HatchResult", -- S->C  resultado da roleta
	"Celebrate", -- S->C  rebirth / desbloqueios
}

local FUNCTIONS = {
	"BuyUpgrade",
	"UnlockEgg",
	"SelectEgg",
	"HatchEgg",
	"PetAction",
	"Rebirth",
	"UnlockArea",
	"SetSetting",
	"SetAuto",
	"GetLeaderboard",
}

local Remotes = {}
local folder: Folder

if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = "Remotes"
		created.Parent = ReplicatedStorage
		folder = created
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local f = Instance.new("RemoteFunction")
			f.Name = name
			f.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.Event(name: string): RemoteEvent
	assert(table.find(EVENTS, name), "Unknown RemoteEvent " .. name)
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	assert(table.find(FUNCTIONS, name), "Unknown RemoteFunction " .. name)
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
