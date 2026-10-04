-- HatchController: animação de roleta ao chocar um ovo.
-- O resultado JÁ foi sorteado pelo servidor; aqui só animamos até parar nele.
-- Quanto mais raro, mais longa e mais impressionante a animação.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local NumberFormat = require(Modules.NumberFormat)
local EggConfig = require(Modules.EggConfig)
local PetConfig = require(Modules.PetConfig)
local RarityConfig = require(Modules.RarityConfig)
local PetModels = require(Modules.Models.PetModels)

local UI = require(script.Parent.Parent:WaitForChild("UI").UIKit)
local T = UI.Theme

local HatchController = {}

local controllers
local overlay: Frame
local center: Frame
local playing = false

local CARD_W = 140
local CARD_GAP = 12
local STEP = CARD_W + CARD_GAP
local STRIP_W = 880
local ITEMS = 42
local RESULT_INDEX = 36

local function weightedPick(egg)
	local total = 0
	for _, e in egg.Pets do
		total += e.Chance
	end
	local r = math.random() * total
	for _, e in egg.Pets do
		r -= e.Chance
		if r <= 0 then
			return e.Pet
		end
	end
	return egg.Pets[1].Pet
end

-- Na roleta, raros aparecem um pouco mais (só visual) para dar emoção
local function stripPick(egg)
	if math.random() < 0.18 then
		local rare = egg.Pets[math.random(math.max(1, #egg.Pets - 2), #egg.Pets)]
		return rare.Pet
	end
	return weightedPick(egg)
end

local function petCard(petName: string, size: Vector2, chance: number?): Frame
	local pet = PetConfig.Get(petName)
	local color = UI.rarityColor(pet.Rarity)
	local card = UI.new("Frame", {
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = color:Lerp(T.PanelDark, 0.55),
	})
	UI.corner(card, 14)
	local stroke = UI.stroke(card, color, 3)
	if pet.Rarity == "Secret" then
		UI.rainbow(stroke)
	end
	local view
	if pet.Icon ~= "" then
		view = UI.new("ImageLabel", { BackgroundTransparency = 1, Image = pet.Icon, ScaleType = Enum.ScaleType.Fit })
	else
		view = UI.viewport(PetModels.Build(petName))
	end
	view.Size = UDim2.new(1, -16, 0.6, 0)
	view.Position = UDim2.fromOffset(8, 6)
	view.Parent = card
	UI.label({ Text = petName, Size = UDim2.new(1, -10, 0.16, 0), Position = UDim2.new(0, 5, 0.62, 0), MaxTextSize = 22, Parent = card })
	UI.label({
		Text = string.upper(pet.Rarity) .. (if chance then "  " .. NumberFormat.Percent(chance) else ""),
		Size = UDim2.new(1, -10, 0.14, 0),
		Position = UDim2.new(0, 5, 0.8, 0),
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3),
		MaxTextSize = 18,
		Parent = card,
	})
	return card
end

local function chanceOf(egg, petName: string): number
	for _, e in egg.Pets do
		if e.Pet == petName then
			return e.Chance
		end
	end
	return 0
end

function HatchController:Play(result)
	while playing do
		task.wait(0.2)
	end
	playing = true
	local egg = EggConfig.Get(result.Egg)
	local pet = PetConfig.Get(result.Pet)
	if not egg or not pet then
		playing = false
		return
	end
	local rarity = RarityConfig.Get(pet.Rarity)
	local rarityColor = UI.rarityColor(pet.Rarity)
	local Sound = controllers.SoundController

	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	UI.tween(overlay, 0.25, { BackgroundTransparency = 0.3 })

	local title = UI.label({
		Text = "Hatching " .. egg.Name .. "...",
		Size = UDim2.fromOffset(700, 50),
		Position = UDim2.new(0.5, 0, 0.5, -170),
		AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = 44,
		Parent = center,
	})

	-- Janela da roleta
	local window = UI.new("Frame", {
		Size = UDim2.fromOffset(STRIP_W, 210),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.PanelDark,
		ClipsDescendants = true,
		Parent = center,
	})
	UI.corner(window, 18)
	UI.stroke(window, T.Gold, 3)
	local strip = UI.new("Frame", {
		Size = UDim2.fromOffset(ITEMS * STEP, 186),
		Position = UDim2.fromOffset(0, 12),
		BackgroundTransparency = 1,
		Parent = window,
	})
	local cards = {}
	for i = 1, ITEMS do
		local name = if i == RESULT_INDEX then result.Pet else stripPick(egg)
		local card = petCard(name, Vector2.new(CARD_W, 186), nil)
		card.Position = UDim2.fromOffset((i - 1) * STEP, 0)
		card.Parent = strip
		cards[i] = card
	end
	-- Ponteiro central
	local pointer = UI.new("Frame", {
		Size = UDim2.fromOffset(6, 230),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = T.Gold,
		ZIndex = 5,
		Parent = center,
	})
	UI.corner(pointer, UDim.new(1, 0))
	for _, y in { -125, 125 } do
		local tip = UI.new("Frame", {
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.new(0.5, 0, 0.5, y),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = 45,
			BackgroundColor3 = T.Gold,
			ZIndex = 5,
			Parent = center,
		})
		UI.corner(tip, 4)
	end

	-- Giro (desacelera até o resultado)
	local finalX = -((RESULT_INDEX - 1) * STEP) + STRIP_W / 2 - CARD_W / 2 + math.random(-45, 45)
	local value = Instance.new("NumberValue")
	value.Value = 0
	local lastIndex = 0
	local conn = value.Changed:Connect(function(x)
		strip.Position = UDim2.fromOffset(x, 12)
		local index = math.floor((-x + STRIP_W / 2) / STEP)
		if index ~= lastIndex then
			lastIndex = index
			Sound:Play("Tick", 0.05)
		end
	end)
	local spin = UI.tween(value, rarity.SpinTime, { Value = finalX }, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	spin.Completed:Wait()
	conn:Disconnect()
	value:Destroy()

	-- Destaque no card vencedor
	local winner = cards[RESULT_INDEX]
	UI.pop(winner, 1.15)
	task.wait(0.45)

	-- Revelação
	window:Destroy()
	pointer:Destroy()
	for _, c in center:GetChildren() do
		if c:IsA("Frame") and c.Rotation == 45 then
			c:Destroy()
		end
	end
	title.Text = if result.New then "NEW PET!" else "YOU GOT"
	title.TextColor3 = if result.New then T.Gold else T.Text

	local rays
	if rarity.Glow then
		rays = UI.new("Frame", {
			Size = UDim2.fromOffset(520, 520),
			Position = UDim2.fromScale(0.5, 0.52),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Parent = center,
		})
		for i = 0, 5 do
			local ray = UI.new("Frame", {
				Size = UDim2.new(0, 46, 1, 0),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = i * 30,
				BackgroundColor3 = rarityColor,
				BackgroundTransparency = 0.55,
				Parent = rays,
			})
			UI.new("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Rotation = 90,
				Parent = ray,
			})
		end
	end

	local reveal = petCard(result.Pet, Vector2.new(260, 330), result.Chance or chanceOf(egg, result.Pet))
	reveal.Position = UDim2.fromScale(0.5, 0.52)
	reveal.AnchorPoint = Vector2.new(0.5, 0.5)
	reveal.Parent = center
	local s = UI.scaleOf(reveal)
	s.Scale = 0
	UI.tween(s, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)

	UI.label({
		Text = string.format("Coins %s   Strength %s   Kick %s", NumberFormat.Multiplier(pet.Coins), NumberFormat.Multiplier(pet.Strength), NumberFormat.Multiplier(pet.Kick)),
		Size = UDim2.fromOffset(700, 34),
		Position = UDim2.new(0.5, 0, 0.52, 190),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = T.Gold,
		MaxTextSize = 28,
		Parent = center,
	})

	Sound:Play("Reveal", 0, 0.7 + rarity.Rank * 0.1)
	if rarity.Shake > 0 then
		controllers.CameraController:Shake(rarity.Shake * 0.12, 0.5)
		local origin = center.Position
		task.spawn(function()
			for _ = 1, 10 do
				center.Position = origin + UDim2.fromOffset(math.random(-rarity.Shake, rarity.Shake), math.random(-rarity.Shake, rarity.Shake))
				task.wait(0.03)
			end
			center.Position = origin
		end)
	end
	if rarity.Rank >= 4 then
		controllers.EffectsController:Confetti(if rarity.Rank >= 5 then 60 else 36)
	end

	local spinConn
	if rays then
		spinConn = RunService.RenderStepped:Connect(function(dt)
			rays.Rotation += dt * 25
		end)
	end

	-- Fecha com clique ou automaticamente
	local done = false
	local closeButton = UI.new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 20,
		Parent = overlay,
	})
	closeButton.Activated:Connect(function()
		done = true
	end)
	local started = os.clock()
	while not done and os.clock() - started < 3.5 do
		task.wait(0.05)
	end

	if spinConn then
		spinConn:Disconnect()
	end
	UI.tween(s, 0.2, { Scale = 0 })
	UI.tween(overlay, 0.25, { BackgroundTransparency = 1 })
	task.wait(0.25)
	for _, c in center:GetChildren() do
		if not c:IsA("UIBase") then
			c:Destroy()
		end
	end
	closeButton:Destroy()
	overlay.Visible = false
	controllers.UIController:Toast("+1 " .. result.Pet .. " (" .. pet.Rarity .. ")", "Reward")
	playing = false
end

function HatchController:Init(all)
	controllers = all
end

function HatchController:Start()
	overlay = UI.new("Frame", {
		Name = "HatchOverlay",
		Size = UDim2.new(1, 0, 1, 80),
		Position = UDim2.fromOffset(0, -60),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 1,
		Parent = controllers.UIController.Screens.Overlay,
	})
	center = UI.holder({
		Name = "Center",
		Size = UDim2.fromOffset(900, 700),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = overlay,
	})
end

return HatchController
