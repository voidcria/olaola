-- Token bucket por jogador: limita quantas vezes um remote pode ser usado.
local Players = game:GetService("Players")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

local all = setmetatable({}, { __mode = "k" })

-- rate: usos por segundo, burst: quantos usos seguidos são permitidos
function RateLimiter.new(rate: number, burst: number?)
	local self = setmetatable({ Rate = rate, Burst = burst or 1, Buckets = {} }, RateLimiter)
	all[self] = true
	return self
end

function RateLimiter:Check(player: Player): boolean
	local now = os.clock()
	local bucket = self.Buckets[player]
	if not bucket then
		bucket = { Tokens = self.Burst, Last = now }
		self.Buckets[player] = bucket
	end
	bucket.Tokens = math.min(self.Burst, bucket.Tokens + (now - bucket.Last) * self.Rate)
	bucket.Last = now
	if bucket.Tokens >= 1 then
		bucket.Tokens -= 1
		return true
	end
	return false
end

Players.PlayerRemoving:Connect(function(player)
	for limiter in all do
		limiter.Buckets[player] = nil
	end
end)

return RateLimiter
