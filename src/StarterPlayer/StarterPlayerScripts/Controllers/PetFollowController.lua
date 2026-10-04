-- PetFollowController: desenha os pets equipados seguindo cada jogador (lado do cliente).
-- Um único loop para todos; jogadores distantes não têm pets renderizados.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PetModels = require(Modules.Models.PetModels)

local PetFollowController = {}

local folder: Folder
local entries: { [Player]: { Names: { string }, Models: { Model }, Visible: boolean } } = {}
local RENDER_DISTANCE = 180
local PET_SCALE = 0.85

local function decode(player: Player): { string }
	local raw = player:GetAttribute("EquippedPets")
	if type(raw) ~= "string" then
		return {}
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	if ok and type(list) == "table" then
		return list
	end
	return {}
end

local function clear(player: Player)
	local entry = entries[player]
	if entry then
		for _, m in entry.Models do
			m:Destroy()
		end
	end
	entries[player] = nil
end

local function rebuild(player: Player)
	clear(player)
	local names = decode(player)
	local models = {}
	for _, name in names do
		local model = PetModels.Build(name)
		model:ScaleTo(PET_SCALE)
		table.insert(models, model)
	end
	entries[player] = { Names = names, Models = models, Visible = false }
end

local function track(player: Player)
	rebuild(player)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(player)
	end)
end

local function step()
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local camPos = camera and camera.CFrame.Position or Vector3.zero
	for player, entry in entries do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local visible = root ~= nil and (root.Position - camPos).Magnitude < RENDER_DISTANCE
		if visible ~= entry.Visible then
			entry.Visible = visible
			for _, m in entry.Models do
				m.Parent = if visible then folder else nil
			end
		end
		if visible and root then
			local count = #entry.Models
			local rootCf = root.CFrame
			for i, model in entry.Models do
				-- Semicírculo atrás do jogador
				local spread = if count > 1 then (i - 1) / (count - 1) - 0.5 else 0
				local angle = spread * math.rad(110)
				local offset = Vector3.new(math.sin(angle) * 5, 0, math.cos(angle) * 4.5 + 1)
				local bob = math.sin(now * 4 + i) * 0.35
				local goal = rootCf * CFrame.new(offset + Vector3.new(0, -0.6 + bob, 0))
				local current = model:GetPivot()
				local lerped = current:Lerp(goal, 0.15)
				if (current.Position - goal.Position).Magnitude > 40 then
					lerped = goal
				end
				model:PivotTo(lerped)
			end
		end
	end
end

function PetFollowController:Init() end

function PetFollowController:Start()
	folder = Instance.new("Folder")
	folder.Name = "ClientPets"
	folder.Parent = workspace
	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(clear)
	RunService.Heartbeat:Connect(step)
end

return PetFollowController
