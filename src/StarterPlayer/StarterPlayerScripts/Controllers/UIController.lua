-- UIController: HUD principal, janelas (painéis), notificações e textos flutuantes.
-- A tela principal mostra só o essencial (Coins, Strength, Rebirths);
-- o resto fica dentro de botões que aparecem aos poucos conforme o jogador progride.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules.Remotes)
local NumberFormat = require(Modules.NumberFormat)
local Formulas = require(Modules.Formulas)
local RebirthConfig = require(Modules.RebirthConfig)

local UIFolder = script.Parent.Parent:WaitForChild("UI")
local UI = require(UIFolder.UIKit)
local T = UI.Theme

local LocalPlayer = Players.LocalPlayer

local UIController = {
	Screens = {} :: { [string]: ScreenGui },
	Panels = {} :: { [string]: any },
	OpenPanelName = nil :: string?,
	Hud = {} :: { [string]: any },
}

local controllers
local blur: BlurEffect

----------------------------------------------------------------------
-- Helpers públicos
----------------------------------------------------------------------
function UIController:Invoke(remoteName: string, ...: any): (boolean, any)
	local ok, success, result = pcall(Remotes.Function(remoteName).InvokeServer, Remotes.Function(remoteName), ...)
	if not ok then
		self:Toast("Connection error, try again", "Error")
		return false, nil
	end
	if not success then
		if type(result) == "string" then
			self:Toast(result, "Error")
		end
		controllers.SoundController:Play("Error")
		return false, result
	end
	return true, result
end

----------------------------------------------------------------------
-- Toasts
----------------------------------------------------------------------
local toastHolder: Frame

function UIController:Toast(text: string, kind: string?)
	local colors = {
		Info = T.Blue,
		Success = T.Green,
		Error = T.Red,
		Reward = T.Gold,
	}
	local color = colors[kind or "Info"] or T.Blue
	local toast = UI.new("Frame", {
		Size = UDim2.fromOffset(420, 44),
		BackgroundColor3 = T.PanelDark,
		BackgroundTransparency = 0.1,
		Parent = toastHolder,
	})
	UI.corner(toast, 12)
	UI.stroke(toast, color, 2.5)
	UI.label({
		Text = text,
		Size = UDim2.new(1, -24, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = 22,
		Parent = toast,
	})
	UI.pop(toast, 0.6)
	local children = 0
	for _, c in toastHolder:GetChildren() do
		if c:IsA("Frame") then
			children += 1
		end
	end
	if children > 4 then
		for _, c in toastHolder:GetChildren() do
			if c:IsA("Frame") and c ~= toast then
				c:Destroy()
				break
			end
		end
	end
	task.delay(3, function()
		if toast.Parent then
			UI.tween(toast, 0.3, { BackgroundTransparency = 1 })
			for _, d in toast:GetDescendants() do
				if d:IsA("TextLabel") then
					UI.tween(d, 0.3, { TextTransparency = 1 })
				elseif d:IsA("UIStroke") then
					UI.tween(d, 0.3, { Transparency = 1 })
				end
			end
			task.wait(0.32)
			toast:Destroy()
		end
	end)
end

----------------------------------------------------------------------
-- Textos flutuantes (+5 Strength, +120 Coins) com pool de labels
----------------------------------------------------------------------
local floatPool: { TextLabel } = {}
local floatIndex = 0
local floatLayer: Frame

function UIController:Float(text: string, color: Color3, anchor: string?, size: number?)
	floatIndex = floatIndex % #floatPool + 1
	local label = floatPool[floatIndex]
	local base = if anchor == "Center" then UDim2.fromScale(0.5, 0.42) else UDim2.new(0.5, 0, 1, -170)
	local jitterX = math.random(-90, 90) * UI.getScale()
	label.Text = text
	label.TextColor3 = color
	local scale = UI.getScale()
	label.Size = UDim2.fromOffset(320 * scale, (size or 38) * scale)
	label.Position = base + UDim2.fromOffset(jitterX, 0)
	label.TextTransparency = 0
	label.Visible = true
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0
	end
	UI.pop(label, 1.5)
	UI.tween(label, 0.9, { Position = base + UDim2.fromOffset(jitterX, -90 * scale), TextTransparency = 1 })
	if stroke then
		UI.tween(stroke, 0.9, { Transparency = 1 })
	end
end

----------------------------------------------------------------------
-- Janelas / painéis
----------------------------------------------------------------------
function UIController:CreateWindow(name: string, title: string, iconKey: string, color: Color3, size: Vector2?)
	local s = size or Vector2.new(760, 470)
	-- root: escala responsiva / window: animação de abrir
	local root = UI.holder({
		Name = name,
		Size = UDim2.fromOffset(s.X, s.Y),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Visible = false,
		Parent = self.Screens.Panels,
	})
	local window = UI.new("Frame", {
		Name = "Window",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.Panel,
		Parent = root,
	})
	UI.corner(window, 18)
	UI.stroke(window, T.Stroke, 3)
	UI.gradient(window, Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 205, 225))
	UI.scaleOf(window)

	local header = UI.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = color,
		Parent = window,
	})
	UI.corner(header, 18)
	UI.gradient(header, Color3.new(1, 1, 1), Color3.fromRGB(180, 180, 180))
	-- cobre os cantos de baixo do header
	UI.new("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -18),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = header,
	}, { UI.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(200, 200, 200), Color3.fromRGB(180, 180, 180)), Rotation = 90 }) })

	local icon = UI.icon(iconKey, 40)
	icon.Position = UDim2.new(0, 14, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Parent = header
	UI.label({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, -140, 0, 38),
		Position = UDim2.new(0, 62, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 34,
		Parent = header,
	})

	local close = UI.new("TextButton", {
		Name = "Close",
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(1, 8, 0, -8),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = T.Red,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 5,
		Parent = window,
	})
	UI.corner(close, UDim.new(1, 0))
	UI.stroke(close, Color3.fromRGB(120, 30, 30), 3)
	local x = UI.icon("Close", 24)
	x.AnchorPoint = Vector2.new(0.5, 0.5)
	x.Position = UDim2.fromScale(0.5, 0.5)
	x.ZIndex = 6
	for _, d in x:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 6
		end
	end
	x.Parent = close
	UI.interactive(close, function()
		self:ClosePanel()
	end)

	local content = UI.new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -28, 1, -76),
		Position = UDim2.fromOffset(14, 66),
		BackgroundTransparency = 1,
		Parent = window,
	})
	return root, content
end

function UIController:OpenPanel(name: string, args: any?)
	local panel = self.Panels[name]
	if not panel then
		return
	end
	if self.OpenPanelName == name then
		if panel.OnOpen then
			panel:OnOpen(args)
		end
		return
	end
	self:ClosePanel(true)
	self.OpenPanelName = name
	local window = panel.Window :: Frame
	window.Visible = true
	local s = UI.scaleOf(window:FindFirstChild("Window") :: Frame)
	s.Scale = 0.85
	UI.tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	UI.tween(blur, 0.25, { Size = 10 })
	local data = controllers.DataController:Get()
	if data and panel.Refresh then
		panel:Refresh(data)
	end
	if panel.OnOpen then
		panel:OnOpen(args)
	end
end

function UIController:ClosePanel(instant: boolean?)
	local name = self.OpenPanelName
	if not name then
		return
	end
	self.OpenPanelName = nil
	local panel = self.Panels[name]
	local window = panel.Window :: Frame
	if panel.OnClose then
		panel:OnClose()
	end
	if instant then
		window.Visible = false
	else
		local s = UI.scaleOf(window:FindFirstChild("Window") :: Frame)
		UI.tween(s, 0.15, { Scale = 0.85 })
		task.delay(0.15, function()
			if self.OpenPanelName ~= name then
				window.Visible = false
			end
		end)
	end
	UI.tween(blur, 0.2, { Size = 0 })
end

function UIController:TogglePanel(name: string)
	if self.OpenPanelName == name then
		self:ClosePanel()
	else
		self:OpenPanel(name)
	end
end

----------------------------------------------------------------------
-- HUD
----------------------------------------------------------------------
local function animatedNumber(onUpdate: (number) -> ())
	local value = Instance.new("NumberValue")
	value.Changed:Connect(onUpdate)
	return value
end

local function buildStatPill(parent: Instance, iconKey: string, color: Color3, order: number)
	local pill = UI.new("Frame", {
		Name = iconKey .. "Pill",
		Size = UDim2.fromOffset(210, 46),
		BackgroundColor3 = T.PanelDark,
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
		Parent = parent,
	})
	UI.corner(pill, UDim.new(1, 0))
	UI.stroke(pill, color, 2.5)
	local icon = UI.icon(iconKey, 50)
	icon.Position = UDim2.new(0, -10, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Parent = pill
	local text = UI.label({
		Name = "Value",
		Text = "0",
		Size = UDim2.new(1, -62, 1, -10),
		Position = UDim2.new(0, 48, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 30,
		TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.55),
		Parent = pill,
	})
	local shown = 0
	local nv = animatedNumber(function(v)
		shown = v
		text.Text = NumberFormat.Abbreviate(v)
	end)
	return {
		Frame = pill,
		Set = function(_, target: number, animate: boolean?)
			if animate and target > shown then
				UI.tween(nv, 0.5, { Value = target })
				UI.pop(icon, 1.25)
			else
				nv.Value = target
			end
		end,
	}
end

local MENU = {
	{ Id = "Pets", Text = "Pets", Icon = "Pets", Color = Color3.fromRGB(255, 130, 170) },
	{ Id = "EggShop", Text = "Eggs", Icon = "Eggs", Color = Color3.fromRGB(255, 196, 64) },
	{ Id = "Upgrades", Text = "Upgrades", Icon = "Upgrades", Color = Color3.fromRGB(80, 170, 255) },
	{ Id = "Areas", Text = "Areas", Icon = "Areas", Color = Color3.fromRGB(255, 120, 90) },
	{ Id = "Rebirth", Text = "Rebirth", Icon = "Rebirth", Color = Color3.fromRGB(180, 100, 255) },
	{ Id = "Stats", Text = "Stats", Icon = "Stats", Color = Color3.fromRGB(90, 200, 150) },
	{ Id = "Settings", Text = "Settings", Icon = "Settings", Color = Color3.fromRGB(130, 140, 170) },
}

-- Quando cada botão aparece (progressão suave: não joga tudo na cara do jogador)
local function isMenuVisible(id: string, data): boolean
	if id == "Stats" or id == "Settings" then
		return true
	elseif id == "Upgrades" then
		return data.TotalKicks >= 1
	elseif id == "EggShop" then
		return data.TotalKicks >= 3 or data.Strength >= 250
	elseif id == "Pets" then
		return Formulas.PetCount(data) > 0 or data.TotalKicks >= 6
	elseif id == "Areas" then
		return data.BestDistance >= 120 or data.HighestArea > 1
	elseif id == "Rebirth" then
		return data.Rebirths > 0 or data.Strength >= RebirthConfig.StrengthRequired(0) * 0.3
	end
	return true
end

local function buildMenuButton(parent: Instance, def, order: number)
	local button = UI.new("TextButton", {
		Name = def.Id,
		Size = UDim2.fromOffset(74, 74),
		BackgroundColor3 = def.Color,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = order,
		Visible = false,
		Parent = parent,
	})
	UI.corner(button, 16)
	UI.stroke(button, Color3.new(def.Color.R * 0.4, def.Color.G * 0.4, def.Color.B * 0.4), 3)
	UI.gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 175))
	local icon = UI.icon(def.Icon, 42)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.42)
	icon.Parent = button
	UI.label({
		Text = def.Text,
		Size = UDim2.new(1, -4, 0, 20),
		Position = UDim2.new(0.5, 0, 1, -3),
		AnchorPoint = Vector2.new(0.5, 1),
		MaxTextSize = 17,
		Parent = button,
	})
	local badge = UI.new("Frame", {
		Name = "NewBadge",
		Size = UDim2.fromOffset(40, 20),
		Position = UDim2.new(1, 6, 0, -6),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = T.Red,
		Visible = false,
		Parent = button,
	})
	UI.corner(badge, UDim.new(1, 0))
	UI.label({ Text = "NEW", Size = UDim2.new(1, -6, 1, -4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = badge })
	UI.interactive(button, function()
		badge.Visible = false
		UIController:TogglePanel(def.Id)
	end)
	return button
end

function UIController:BuildHud()
	local hud = self.Screens.HUD

	-- Status (canto superior esquerdo)
	-- Coluna esquerda (status + menu) num único container escalável
	local left = UI.holder({
		Name = "Left",
		Size = UDim2.fromOffset(250, 440),
		Position = UDim2.fromOffset(16, 10),
		Parent = hud,
	})
	local stats = UI.new("Frame", {
		Name = "Stats",
		Size = UDim2.fromOffset(230, 170),
		Position = UDim2.fromOffset(10, 4),
		BackgroundTransparency = 1,
		Parent = left,
	})
	UI.list(stats, true, 10)
	self.Hud.Coins = buildStatPill(stats, "Coins", T.Gold, 1)
	self.Hud.Strength = buildStatPill(stats, "Strength", T.Strength, 2)
	self.Hud.Rebirths = buildStatPill(stats, "Rebirth", T.Purple, 3)

	-- Menu (lado esquerdo)
	local menu = UI.new("Frame", {
		Name = "Menu",
		Size = UDim2.fromOffset(250, 260),
		Position = UDim2.fromOffset(0, 184),
		BackgroundTransparency = 1,
		Parent = left,
	})
	UI.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(74, 74),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = 3,
		Parent = menu,
	})
	self.Hud.MenuButtons = {}
	for i, def in MENU do
		self.Hud.MenuButtons[def.Id] = buildMenuButton(menu, def, i)
	end

	-- Botão de ação (centro inferior): KICK / TRAIN
	local actionHolder = UI.holder({
		Name = "ActionHolder",
		Size = UDim2.fromOffset(250, 86),
		Position = UDim2.new(0.5, 0, 1, -24),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = hud,
	})
	local action = UI.button({
		Name = "Action",
		Text = "KICK!",
		Color = T.Orange,
		Size = UDim2.fromScale(1, 1),
		TextSize = 44,
		Parent = actionHolder,
	})
	action.Visible = false
	local actionLabel = action:FindFirstChild("Label") :: TextLabel
	actionLabel.Size = UDim2.new(1, -20, 0.62, 0)
	actionLabel.Position = UDim2.new(0.5, 0, 0.4, 0)
	local sub = UI.label({
		Name = "Sub",
		Text = "",
		Size = UDim2.new(1, -20, 0.3, 0),
		Position = UDim2.new(0.5, 0, 0.82, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = 20,
		Parent = action,
	})
	local keyHint = UI.new("Frame", {
		Name = "KeyHint",
		Size = UDim2.fromOffset(38, 38),
		Position = UDim2.new(0, -12, 0, -12),
		BackgroundColor3 = T.PanelDark,
		Visible = not UI.isTouch(),
		Parent = action,
	})
	UI.corner(keyHint, 10)
	UI.stroke(keyHint, Color3.new(1, 1, 1), 2)
	UI.label({ Text = "E", Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = keyHint })
	self.Hud.Action = action
	self.Hud.ActionSub = sub

	-- Auto Train (aparece depois do primeiro Rebirth)
	local autoHolder = UI.holder({
		Name = "AutoHolder",
		Size = UDim2.fromOffset(210, 46),
		Position = UDim2.new(1, -16, 1, -150),
		AnchorPoint = Vector2.new(1, 1),
		Parent = hud,
	})
	local auto = UI.button({
		Name = "AutoTrain",
		Text = "AUTO TRAIN: OFF",
		Color = T.Gray,
		Size = UDim2.fromScale(1, 1),
		TextSize = 22,
		Icon = "Train",
		Parent = autoHolder,
		OnClick = function()
			local data = controllers.DataController:Get()
			if data then
				self:Invoke("SetAuto", "AutoTrain", not data.AutoTrain)
			end
		end,
	})
	auto.Visible = false
	self.Hud.AutoTrain = auto

	-- Objetivo / tutorial (topo)
	local objectiveHolder = UI.holder({
		Name = "ObjectiveHolder",
		Size = UDim2.fromOffset(480, 50),
		Position = UDim2.new(0.5, 0, 0, 12),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = hud,
	})
	local objective = UI.new("Frame", {
		Name = "Objective",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.PanelDark,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = objectiveHolder,
	})
	UI.corner(objective, UDim.new(1, 0))
	UI.stroke(objective, T.Gold, 2.5)
	local diamond = UI.new("Frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.new(0, 22, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = T.Gold,
		Parent = objective,
	})
	UI.corner(diamond, 4)
	local objectiveText = UI.label({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, -60, 1, -14),
		Position = UDim2.new(0, 42, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 24,
		Parent = objective,
	})
	self.Hud.Objective = objective
	self.Hud.ObjectiveText = objectiveText

	-- Distância durante o voo (topo, grande)
	local distance = UI.holder({
		Name = "Distance",
		Size = UDim2.fromOffset(520, 150),
		Position = UDim2.new(0.5, 0, 0, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		Visible = false,
		Parent = self.Screens.Overlay,
	})
	local distanceText = UI.label({
		Name = "Value",
		Text = "0m",
		Size = UDim2.new(1, 0, 0, 96),
		MaxTextSize = 96,
		StrokeColor = Color3.fromRGB(20, 20, 40),
		Parent = distance,
	})
	;(distanceText:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 4
	local distanceSub = UI.label({
		Name = "Sub",
		Text = "",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 98),
		MaxTextSize = 36,
		TextColor3 = T.Gold,
		Parent = distance,
	})
	self.Hud.Distance = distance
	self.Hud.DistanceText = distanceText
	self.Hud.DistanceSub = distanceSub
end

function UIController:RefreshHud(data, previous)
	local animate = previous ~= nil
	self.Hud.Coins:Set(data.Coins, animate)
	self.Hud.Strength:Set(data.Strength, animate)
	self.Hud.Rebirths:Set(data.Rebirths, animate)

	for id, button in self.Hud.MenuButtons do
		local visible = isMenuVisible(id, data)
		if visible and not button.Visible then
			button.Visible = true
			if previous then
				(button:FindFirstChild("NewBadge") :: Frame).Visible = true
				UI.pop(button, 1.4)
			end
		elseif not visible then
			button.Visible = false
		end
	end

	local autoUnlocked = data.Rebirths >= 1
	self.Hud.AutoTrain.Visible = autoUnlocked
	if autoUnlocked then
		UI.setButtonText(self.Hud.AutoTrain, if data.AutoTrain then "AUTO TRAIN: ON" else "AUTO TRAIN: OFF")
		UI.setButtonColor(self.Hud.AutoTrain, if data.AutoTrain then T.Green else T.Gray)
	end

	if self.OpenPanelName then
		local panel = self.Panels[self.OpenPanelName]
		if panel.Refresh then
			panel:Refresh(data)
		end
	end
end

-- Botão de ação (KickController / TrainController controlam o conteúdo)
function UIController:SetAction(kind: string?, text: string?, sub: string?, color: Color3?)
	local action = self.Hud.Action
	if not kind then
		action.Visible = false
		self.Hud.ActionKind = nil
		return
	end
	if self.Hud.ActionKind ~= kind then
		action.Visible = true
		UI.pop(action, 0.7)
	end
	self.Hud.ActionKind = kind
	UI.setButtonText(action, text or "")
	self.Hud.ActionSub.Text = sub or ""
	if color then
		UI.setButtonColor(action, color)
	end
end

function UIController:SetObjective(text: string?)
	local objective = self.Hud.Objective
	if not text then
		objective.Visible = false
		return
	end
	if self.Hud.ObjectiveText.Text ~= text then
		self.Hud.ObjectiveText.Text = text
		objective.Visible = true
		UI.pop(objective, 0.85)
	end
end

----------------------------------------------------------------------
function UIController:Init(allControllers)
	controllers = allControllers
	UI.OnClick = function()
		controllers.SoundController:Play("Click", 0.05)
	end

	self.Screens.HUD = UI.screen("KickAnEggHUD", 1)
	self.Screens.Panels = UI.screen("KickAnEggPanels", 5)
	self.Screens.Overlay = UI.screen("KickAnEggOverlay", 10)
	self.Screens.Toasts = UI.screen("KickAnEggToasts", 20)

	blur = Instance.new("BlurEffect")
	blur.Name = "KickAnEggPanelBlur"
	blur.Size = 0
	blur.Parent = Lighting

	toastHolder = UI.holder({
		Name = "Toasts",
		Size = UDim2.fromOffset(440, 260),
		Position = UDim2.new(0.5, 0, 0, 72),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = self.Screens.Toasts,
	})
	UI.list(toastHolder, true, 8, Enum.HorizontalAlignment.Center)

	floatLayer = UI.new("Frame", {
		Name = "Floats",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = self.Screens.Overlay,
	})
	for i = 1, 14 do
		local label = UI.label({
			Name = "Float" .. i,
			Text = "",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Visible = false,
			MaxTextSize = 40,
			Parent = floatLayer,
		})
		;(label:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 3
		table.insert(floatPool, label)
	end

	self:BuildHud()

	-- Painéis
	local ctx = {
		UI = UI,
		Controllers = controllers,
		UIController = self,
	}
	for _, module in UIFolder:WaitForChild("Panels"):GetChildren() do
		if module:IsA("ModuleScript") then
			local ok, result = pcall(function()
				return require(module)(ctx)
			end)
			if ok then
				self.Panels[module.Name] = result
			else
				warn("[UIController] Falha no painel " .. module.Name .. ": " .. tostring(result))
			end
		end
	end

	-- Escala responsiva
	local function onViewport()
		UI.refreshScale()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if workspace.CurrentCamera then
			workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(onViewport)
		end
		onViewport()
	end)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(onViewport)
	end
end

function UIController:Start()
	local DataController = controllers.DataController
	DataController.Changed:Connect(function(data, previous)
		self:RefreshHud(data, previous)
	end)
	if DataController:Get() then
		self:RefreshHud(DataController:Get(), nil)
	end

	Remotes.Event("Notify").OnClientEvent:Connect(function(text, kind)
		if type(text) == "string" then
			self:Toast(text, kind)
		end
	end)

	-- Fechar painel com ESC / B do controle
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			self:ClosePanel()
		end
	end)

	-- Abre painéis pelos ProximityPrompts das barracas
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, player)
		if player ~= LocalPlayer then
			return
		end
		local panel = prompt:GetAttribute("Panel")
		if type(panel) == "string" then
			self:OpenPanel(panel)
		end
	end)
end

return UIController
