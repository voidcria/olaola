-- Ponto de entrada do cliente: inicializa os controllers em ordem.
local Controllers = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"DataController",
	"SoundController",
	"AnimationController",
	"UIController",
	"CameraController",
	"EffectsController",
	"HatchController",
	"KickController",
	"TrainController",
	"PetFollowController",
	"BaseController",
	"TutorialController",
	"GateController",
}

local controllers = {}
for _, name in ORDER do
	local module = Controllers:WaitForChild(name)
	local ok, result = pcall(require, module)
	if ok then
		controllers[name] = result
	else
		warn("[Main.client] Erro ao carregar " .. name .. ": " .. tostring(result))
	end
end

for _, name in ORDER do
	local c = controllers[name]
	if c and c.Init then
		local ok, err = pcall(c.Init, c, controllers)
		if not ok then
			warn("[Main.client] Init falhou em " .. name .. ": " .. tostring(err))
		end
	end
end
for _, name in ORDER do
	local c = controllers[name]
	if c and c.Start then
		task.spawn(function()
			local ok, err = pcall(c.Start, c, controllers)
			if not ok then
				warn("[Main.client] Start falhou em " .. name .. ": " .. tostring(err))
			end
		end)
	end
end
