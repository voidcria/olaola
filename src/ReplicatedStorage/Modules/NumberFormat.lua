-- Formatação de números: 1.2K, 15M, 3.4Qa...
local NumberFormat = {}

local SUFFIXES = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc",
	"Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg",
}

local function trimZeros(s: string): string
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s
end

-- Abrevia: 999 -> "999", 1234 -> "1.23K", 15300 -> "15.3K", 152000 -> "152K"
function NumberFormat.Abbreviate(n: number): string
	if n ~= n then
		return "0"
	end
	if n == math.huge then
		return "inf"
	end
	local negative = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s
		if n < 10 and n % 1 ~= 0 then
			s = trimZeros(string.format("%.1f", math.floor(n * 10) / 10))
		else
			s = tostring(math.floor(n))
		end
		return (negative and "-" or "") .. s
	end
	local index = math.floor(math.log10(n) / 3)
	if index >= #SUFFIXES then
		return (negative and "-" or "") .. string.format("%.2e", n)
	end
	local scaled = n / (1000 ^ index)
	-- Arredonda para baixo (nunca mostra mais do que o jogador tem)
	local s
	if scaled < 10 then
		s = string.format("%.2f", math.floor(scaled * 100) / 100)
	elseif scaled < 100 then
		s = string.format("%.1f", math.floor(scaled * 10) / 10)
	else
		s = string.format("%d", math.floor(scaled))
	end
	return (negative and "-" or "") .. trimZeros(s) .. SUFFIXES[index + 1]
end

-- 1234567 -> "1,234,567"
function NumberFormat.Commas(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local formatted = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
	formatted = string.gsub(formatted, "^,", "")
	return (n < 0 and "-" or "") .. formatted
end

-- Distância em metros: 542 -> "542m", 12345 -> "12.3Km"
function NumberFormat.Distance(meters: number): string
	if meters < 10000 then
		return NumberFormat.Commas(math.floor(meters)) .. "m"
	end
	return NumberFormat.Abbreviate(meters) .. "m"
end

-- Multiplicador: 1.25 -> "x1.25"
function NumberFormat.Multiplier(m: number): string
	if m >= 1000 then
		return "x" .. NumberFormat.Abbreviate(m)
	end
	return "x" .. trimZeros(string.format("%.2f", m))
end

-- Porcentagem para chance: 0.05 -> "0.05%", 45 -> "45%"
function NumberFormat.Percent(p: number): string
	if p >= 10 then
		return trimZeros(string.format("%.1f", p)) .. "%"
	elseif p >= 1 then
		return trimZeros(string.format("%.2f", p)) .. "%"
	end
	return trimZeros(string.format("%.3f", p)) .. "%"
end

-- Segundos -> "1h 23m" / "4m 05s"
function NumberFormat.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local d = math.floor(seconds / 86400)
	local h = math.floor(seconds / 3600) % 24
	local m = math.floor(seconds / 60) % 60
	local s = seconds % 60
	if d > 0 then
		return string.format("%dd %dh", d, h)
	elseif h > 0 then
		return string.format("%dh %02dm", h, m)
	end
	return string.format("%dm %02ds", m, s)
end

return NumberFormat
