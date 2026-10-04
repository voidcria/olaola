-- DataController: cópia local (somente leitura) dos dados enviados pelo servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules.Remotes)
local Signal = require(Modules.Signal)

local DataController = {
	Data = nil :: any,
	Changed = Signal.new(), -- (data, previous)
	Loaded = false,
	_syncClock = 0,
}

function DataController:Get()
	return self.Data
end

function DataController:WaitForData()
	while not self.Data do
		self.Changed:Wait()
	end
	return self.Data
end

-- Tempo de jogo atualizado localmente entre snapshots
function DataController:GetPlaytime(): number
	if not self.Data then
		return 0
	end
	return self.Data.Playtime + (os.clock() - self._syncClock)
end

function DataController:Init()
	Remotes.Event("DataSync").OnClientEvent:Connect(function(snapshot)
		local previous = self.Data
		self.Data = snapshot
		self._syncClock = os.clock()
		self.Loaded = true
		self.Changed:Fire(snapshot, previous)
	end)
end

return DataController
