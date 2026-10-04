-- LeaderboardService: ranking global de melhor distância (OrderedDataStore)
-- exibido no painel do lobby (Workspace.Map.Lobby.Leaderboard).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules.Config)
local NumberFormat = require(Modules.NumberFormat)
local Remotes = require(Modules.Remotes)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local store: OrderedDataStore? = nil
local cached = {}
local lastSubmitted: { [number]: number } = {}
local nameCache: { [number]: string } = {}

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok then name else "Player"
	return nameCache[userId]
end

local function submit(player: Player)
	local data = DataService:Get(player)
	if not store or not data then
		return
	end
	local value = math.floor(data.BestDistance)
	if value <= 0 or lastSubmitted[player.UserId] == value then
		return
	end
	local ok = pcall(function()
		(store :: OrderedDataStore):SetAsync(tostring(player.UserId), value)
	end)
	if ok then
		lastSubmitted[player.UserId] = value
	end
end

local function render()
	local board = workspace:FindFirstChild("Map")
	board = board and board:FindFirstChild("Lobby")
	board = board and board:FindFirstChild("Leaderboard")
	local list = board and board:FindFirstChild("List", true)
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for rank, entry in cached do
		local row = Instance.new("Frame")
		row.Name = "Row" .. rank
		row.Size = UDim2.new(1, 0, 1 / Config.Leaderboard.Size, -4)
		row.BackgroundTransparency = if rank % 2 == 0 then 0.85 else 0.75
		row.BackgroundColor3 = Color3.new(1, 1, 1)
		row.LayoutOrder = rank
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.2, 0)
		corner.Parent = row

		local function label(text: string, x: number, w: number, align: Enum.TextXAlignment, color: Color3)
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Position = UDim2.fromScale(x, 0.1)
			t.Size = UDim2.fromScale(w, 0.8)
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.TextColor3 = color
			t.TextXAlignment = align
			t.Text = text
			t.Parent = row
		end
		local rankColor = if rank == 1
			then Color3.fromRGB(255, 210, 60)
			elseif rank == 2 then Color3.fromRGB(220, 225, 235)
			elseif rank == 3 then Color3.fromRGB(230, 150, 90)
			else Color3.new(1, 1, 1)
		label("#" .. rank, 0.03, 0.14, Enum.TextXAlignment.Left, rankColor)
		label(entry.Name, 0.18, 0.5, Enum.TextXAlignment.Left, Color3.new(1, 1, 1))
		label(NumberFormat.Distance(entry.Value), 0.65, 0.32, Enum.TextXAlignment.Right, Color3.fromRGB(255, 220, 90))
		row.Parent = list
	end
end

local function refresh()
	if not store then
		return
	end
	for _, player in Players:GetPlayers() do
		submit(player)
	end
	local ok, pages = pcall(function()
		return (store :: OrderedDataStore):GetSortedAsync(false, Config.Leaderboard.Size)
	end)
	if not ok then
		return
	end
	local entries = {}
	for _, item in (pages :: DataStorePages):GetCurrentPage() do
		local userId = tonumber(item.key)
		if userId then
			table.insert(entries, { Name = getName(userId), Value = item.value })
		end
	end
	cached = entries
	render()
end

function LeaderboardService:Start()
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.Data.LeaderboardStore)
	end)
	if ok then
		store = result
	end

	Remotes.Function("GetLeaderboard").OnServerInvoke = function()
		return cached
	end

	DataService.PlayerRemoving:Connect(function(player)
		submit(player)
	end)

	task.spawn(function()
		task.wait(10)
		while true do
			local success, err = pcall(refresh)
			if not success then
				warn("[LeaderboardService] " .. tostring(err))
			end
			task.wait(Config.Leaderboard.RefreshInterval)
		end
	end)
end

return LeaderboardService
