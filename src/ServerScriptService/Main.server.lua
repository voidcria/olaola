-- Ponto de entrada do servidor: inicializa todos os Services em ordem.
local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService:WaitForChild("Services")

local ORDER = {
	"DataService",
	"PetService",
	"KickService",
	"TrainService",
	"UpgradeService",
	"EggService",
	"RebirthService",
	"AreaService",
	"SettingsService",
	"LeaderboardService",
}

local loaded = {}
for _, name in ORDER do
	local module = Services:FindFirstChild(name)
	if module then
		local ok, service = pcall(require, module)
		if ok then
			table.insert(loaded, { Name = name, Service = service })
		else
			warn("[Main] Erro ao carregar " .. name .. ": " .. tostring(service))
		end
	end
end

for _, entry in loaded do
	if entry.Service.Init then
		entry.Service:Init()
	end
end
for _, entry in loaded do
	if entry.Service.Start then
		task.spawn(entry.Service.Start, entry.Service)
	end
end

print("[Kick an Egg] Servidor iniciado com " .. #loaded .. " services")
