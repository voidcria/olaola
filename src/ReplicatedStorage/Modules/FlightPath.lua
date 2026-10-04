-- Trajetória do ovo (pura, determinística): arco principal + quicadas + rolagem.
-- O servidor decide Distance/Duration; os clientes usam esta função para desenhar o voo.
local Modules = script.Parent
local TrackConfig = require(Modules.TrackConfig)

local FlightPath = {}

-- { t0, t1, d0, d1, heightFactor, roll }
local NORMAL = {
	{ 0.00, 0.60, 0.00, 0.74, 1.00, false },
	{ 0.60, 0.80, 0.74, 0.92, 0.22, false },
	{ 0.80, 0.90, 0.92, 0.98, 0.06, false },
	{ 0.90, 1.00, 0.98, 1.00, 0.00, true },
}
-- Quando bate no portão de uma área bloqueada: vai até o portão e quica para trás
local BLOCKED = {
	{ 0.00, 0.72, 0.00, 1.000, 1.00, false },
	{ 0.72, 0.92, 1.00, 0.985, 0.12, false },
	{ 0.92, 1.00, 0.985, 0.985, 0.00, true },
}

function FlightPath.PeakHeight(distance: number): number
	return math.clamp(distance * 0.18, 4, 220)
end

-- Retorna (x, alturaAcimaDoChão, z, fraçãoDaDistância) para t em [0, 1]
function FlightPath.Sample(info, t: number): (number, number, number, number)
	t = math.clamp(t, 0, 1)
	local phases = if info.Blocked then BLOCKED else NORMAL
	local peak = FlightPath.PeakHeight(info.Distance)
	local d, h = 1, 0
	for _, p in phases do
		if t <= p[2] then
			local u = if p[2] > p[1] then (t - p[1]) / (p[2] - p[1]) else 1
			if p[6] then
				u = 1 - (1 - u) ^ 2 -- rolagem desacelerando
			end
			d = p[3] + (p[4] - p[3]) * u
			h = 4 * peak * p[5] * u * (1 - u)
			break
		end
	end
	local startZ = info.StartZ or TrackConfig.KickLineZ
	local endZ = TrackConfig.KickLineZ - info.Distance
	local z = startZ + (endZ - startZ) * d
	local x = info.StartX + (info.EndX - info.StartX) * d
	return x, h, z, d
end

-- Distância (m) a partir da linha de chute para uma posição Z
function FlightPath.DistanceAt(z: number): number
	return math.max(0, TrackConfig.KickLineZ - z)
end

return FlightPath
