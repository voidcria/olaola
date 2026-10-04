-- UIKit: tema e componentes reutilizáveis da interface (cantos arredondados, sombras,
-- gradientes, botões com hover/click, ícones, viewports e escala responsiva).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local IconConfig = require(Modules.IconConfig)
local RarityConfig = require(Modules.RarityConfig)

local LocalPlayer = Players.LocalPlayer

local UI = {}

UI.Theme = {
	Font = Enum.Font.FredokaOne,
	BodyFont = Enum.Font.GothamBold,
	Panel = Color3.fromRGB(32, 36, 62),
	PanelDark = Color3.fromRGB(22, 25, 44),
	PanelLight = Color3.fromRGB(48, 54, 92),
	Stroke = Color3.fromRGB(12, 14, 28),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(185, 195, 230),
	Gold = Color3.fromRGB(255, 205, 60),
	Green = Color3.fromRGB(80, 215, 110),
	Red = Color3.fromRGB(255, 92, 92),
	Blue = Color3.fromRGB(70, 160, 255),
	Purple = Color3.fromRGB(170, 100, 255),
	Orange = Color3.fromRGB(255, 140, 60),
	Gray = Color3.fromRGB(110, 116, 140),
	Strength = Color3.fromRGB(255, 110, 80),
}
local T = UI.Theme

-- Função chamada em todo clique (o UIController liga ao som de clique)
UI.OnClick = function() end

----------------------------------------------------------------------
-- Básico
----------------------------------------------------------------------
function UI.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UI.corner(inst: Instance, radius: number | UDim?): UICorner
	local r = radius or 12
	return UI.new("UICorner", {
		CornerRadius = if typeof(r) == "UDim" then r else UDim.new(0, r :: number),
		Parent = inst,
	})
end

function UI.stroke(inst: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UI.new("UIStroke", {
		Color = color or T.Stroke,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = if inst:IsA("TextLabel") or inst:IsA("TextBox") then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

function UI.gradient(inst: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	return UI.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
		Parent = inst,
	})
end

function UI.padding(inst: Instance, px: number)
	return UI.new("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = inst,
	})
end

function UI.list(inst: Instance, vertical: boolean, padding: number?, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?): UIListLayout
	return UI.new("UIListLayout", {
		FillDirection = if vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, padding or 8),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = inst,
	})
end

function UI.tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

-- Garante um UIScale filho (usado para animações de "pop")
function UI.scaleOf(inst: Instance): UIScale
	local s = inst:FindFirstChild("PopScale") :: UIScale?
	if not s then
		s = UI.new("UIScale", { Name = "PopScale", Parent = inst })
	end
	return s :: UIScale
end

function UI.pop(inst: Instance, amount: number?)
	local s = UI.scaleOf(inst)
	s.Scale = amount or 1.25
	UI.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Sombra discreta atrás de um frame
function UI.shadow(inst: GuiObject, offset: number?, transparency: number?)
	local o = offset or 4
	local corner = inst:FindFirstChildOfClass("UICorner")
	local shadow = UI.new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = transparency or 0.65,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, o),
		ZIndex = inst.ZIndex - 1,
		Parent = inst.Parent,
	})
	if corner then
		UI.corner(shadow, corner.CornerRadius)
	end
	-- Acompanha o frame
	local function sync()
		shadow.Size = inst.Size
		shadow.Position = inst.Position + UDim2.fromOffset(0, o)
		shadow.AnchorPoint = inst.AnchorPoint
		shadow.Visible = inst.Visible
		shadow.LayoutOrder = inst.LayoutOrder
	end
	sync()
	inst:GetPropertyChangedSignal("Size"):Connect(sync)
	inst:GetPropertyChangedSignal("Position"):Connect(sync)
	inst:GetPropertyChangedSignal("Visible"):Connect(sync)
	inst.Destroying:Connect(function()
		shadow:Destroy()
	end)
	return shadow
end

function UI.label(props: { [string]: any }): TextLabel
	local label = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = T.Font,
		TextColor3 = T.Text,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	})
	local maxSize = props.MaxTextSize
	props.MaxTextSize = nil
	local strokeColor = props.StrokeColor
	props.StrokeColor = nil
	local noStroke = props.NoStroke
	props.NoStroke = nil
	for k, v in props do
		if k ~= "Parent" then
			label[k] = v
		end
	end
	if maxSize then
		UI.new("UITextSizeConstraint", { MaxTextSize = maxSize, Parent = label })
	end
	if not noStroke then
		UI.new("UIStroke", { Color = strokeColor or T.Stroke, Thickness = 1.6, Parent = label })
	end
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

----------------------------------------------------------------------
-- Botões
----------------------------------------------------------------------
local function darker(c: Color3, f: number): Color3
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

-- Comportamento de hover / clique para qualquer GuiButton
function UI.interactive(button: GuiButton, onActivate: (() -> ())?)
	local scale = UI.scaleOf(button)
	local hovering = false
	button.MouseEnter:Connect(function()
		hovering = true
		UI.tween(scale, 0.12, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		UI.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UI.tween(scale, 0.08, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		UI.tween(scale, 0.18, { Scale = if hovering then 1.05 else 1 }, Enum.EasingStyle.Back)
	end)
	if onActivate then
		button.Activated:Connect(function()
			UI.OnClick()
			onActivate()
		end)
	end
end

export type ButtonOptions = {
	Text: string?,
	Color: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Icon: string?,
	TextSize: number?,
	LayoutOrder: number?,
	Parent: Instance?,
	OnClick: (() -> ())?,
	Name: string?,
}

-- Botão padrão com gradiente, contorno e sombra
function UI.button(opts: ButtonOptions)
	local color = opts.Color or T.Green
	local button = UI.new("TextButton", {
		Name = opts.Name or "Button",
		AutoButtonColor = false,
		BackgroundColor3 = color,
		Size = opts.Size or UDim2.fromOffset(160, 50),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		LayoutOrder = opts.LayoutOrder or 0,
		Text = "",
	})
	UI.corner(button, 12)
	UI.stroke(button, darker(color, 0.45), 2.5)
	local gradient = UI.gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	gradient.Name = "Shine"

	local label = UI.label({
		Name = "Label",
		Text = opts.Text or "",
		Size = UDim2.new(1, -16, 1, -12),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = opts.TextSize or 26,
		StrokeColor = darker(color, 0.35),
		Parent = button,
	})
	if opts.Icon then
		local iconSize = 28
		local icon = UI.icon(opts.Icon, iconSize)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 10, 0.5, 0)
		icon.Parent = button
		label.Size = UDim2.new(1, -(iconSize + 24), 1, -12)
		label.Position = UDim2.new(0.5, (iconSize + 8) / 2, 0.5, 0)
	end
	UI.interactive(button, opts.OnClick)
	if opts.Parent then
		button.Parent = opts.Parent
	end
	return button
end

function UI.setButtonColor(button: GuiObject, color: Color3)
	button.BackgroundColor3 = color
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = darker(color, 0.45)
	end
	local label = button:FindFirstChild("Label")
	local labelStroke = label and label:FindFirstChildOfClass("UIStroke")
	if labelStroke then
		labelStroke.Color = darker(color, 0.35)
	end
end

function UI.setButtonText(button: Instance, text: string)
	local label = button:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = text
	end
end

----------------------------------------------------------------------
-- Ícones (usa IconConfig; sem asset, desenha um ícone simples)
----------------------------------------------------------------------
local function circle(parent: Instance, size: UDim2, pos: UDim2, color: Color3, z: number?): Frame
	local f = UI.new("Frame", {
		Size = size,
		Position = pos,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = z or 1,
		Parent = parent,
	})
	UI.corner(f, UDim.new(1, 0))
	return f
end

local function rect(parent: Instance, size: UDim2, pos: UDim2, color: Color3, rotation: number?, radius: number?): Frame
	local f = UI.new("Frame", {
		Size = size,
		Position = pos,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Rotation = rotation or 0,
		Parent = parent,
	})
	if radius then
		UI.corner(f, UDim.new(radius, 0))
	end
	return f
end

local drawers = {}

function drawers.Coins(f: Frame)
	local outer = circle(f, UDim2.fromScale(0.95, 0.95), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(230, 160, 20))
	UI.stroke(outer, Color3.fromRGB(150, 90, 10), 1.5)
	circle(f, UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(255, 215, 70))
	UI.label({ Text = "$", Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = Color3.fromRGB(200, 120, 10), NoStroke = true, Parent = f })
end

function drawers.Strength(f: Frame)
	local c = Color3.fromRGB(70, 70, 80)
	rect(f, UDim2.fromScale(0.8, 0.14), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(180, 185, 195), 0, 0.5)
	for _, x in { 0.2, 0.8 } do
		local plate = rect(f, UDim2.fromScale(0.16, 0.7), UDim2.fromScale(x, 0.5), Color3.fromRGB(255, 100, 70), 0, 0.3)
		UI.stroke(plate, c, 1.2)
	end
	for _, x in { 0.06, 0.94 } do
		rect(f, UDim2.fromScale(0.1, 0.45), UDim2.fromScale(x, 0.5), Color3.fromRGB(220, 70, 50), 0, 0.3)
	end
end
drawers.Train = drawers.Strength

function drawers.Rebirth(f: Frame)
	local ring = circle(f, UDim2.fromScale(0.78, 0.78), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(170, 100, 255))
	ring.BackgroundTransparency = 1
	UI.stroke(ring, Color3.fromRGB(190, 120, 255), 4)
	rect(f, UDim2.fromScale(0.28, 0.28), UDim2.fromScale(0.75, 0.18), Color3.fromRGB(190, 120, 255), 45, 0.1)
	circle(f, UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(255, 230, 120))
end

function drawers.Pets(f: Frame)
	local c = Color3.fromRGB(255, 160, 190)
	circle(f, UDim2.fromScale(0.5, 0.42), UDim2.fromScale(0.5, 0.68), c)
	circle(f, UDim2.fromScale(0.22, 0.26), UDim2.fromScale(0.22, 0.38), c)
	circle(f, UDim2.fromScale(0.22, 0.26), UDim2.fromScale(0.42, 0.2), c)
	circle(f, UDim2.fromScale(0.22, 0.26), UDim2.fromScale(0.62, 0.2), c)
	circle(f, UDim2.fromScale(0.22, 0.26), UDim2.fromScale(0.8, 0.38), c)
end

function drawers.Eggs(f: Frame)
	local egg = circle(f, UDim2.fromScale(0.66, 0.9), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(255, 245, 225))
	UI.stroke(egg, Color3.fromRGB(200, 160, 110), 1.5)
	circle(f, UDim2.fromScale(0.16, 0.14), UDim2.fromScale(0.4, 0.35), Color3.fromRGB(240, 190, 120))
	circle(f, UDim2.fromScale(0.2, 0.18), UDim2.fromScale(0.6, 0.62), Color3.fromRGB(240, 190, 120))
end

function drawers.Upgrades(f: Frame)
	local c = Color3.fromRGB(90, 220, 110)
	rect(f, UDim2.fromScale(0.55, 0.55), UDim2.fromScale(0.5, 0.42), c, 45, 0.15)
	rect(f, UDim2.fromScale(0.3, 0.5), UDim2.fromScale(0.5, 0.7), c, 0, 0.2)
end

function drawers.Stats(f: Frame)
	local colors = { Color3.fromRGB(90, 170, 255), Color3.fromRGB(255, 200, 70), Color3.fromRGB(90, 220, 110) }
	for i, h in { 0.4, 0.62, 0.85 } do
		local bar = UI.new("Frame", {
			Size = UDim2.fromScale(0.22, h),
			Position = UDim2.fromScale(0.08 + (i - 1) * 0.3, 0.95),
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = colors[i],
			BorderSizePixel = 0,
			Parent = f,
		})
		UI.corner(bar, UDim.new(0.25, 0))
	end
end

function drawers.Settings(f: Frame)
	local c = Color3.fromRGB(200, 205, 220)
	for i = 0, 3 do
		rect(f, UDim2.fromScale(0.95, 0.2), UDim2.fromScale(0.5, 0.5), c, i * 45, 0.3)
	end
	circle(f, UDim2.fromScale(0.68, 0.68), UDim2.fromScale(0.5, 0.5), c)
	circle(f, UDim2.fromScale(0.3, 0.3), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(60, 65, 90))
end

function drawers.Areas(f: Frame)
	rect(f, UDim2.fromScale(0.1, 0.9), UDim2.fromScale(0.25, 0.5), Color3.fromRGB(220, 220, 230), 0, 0.5)
	local flag = rect(f, UDim2.fromScale(0.55, 0.38), UDim2.fromScale(0.55, 0.28), Color3.fromRGB(255, 110, 90), 0, 0.15)
	UI.stroke(flag, Color3.fromRGB(150, 50, 40), 1.2)
end

function drawers.Trophy(f: Frame)
	local gold = Color3.fromRGB(255, 200, 50)
	rect(f, UDim2.fromScale(0.6, 0.45), UDim2.fromScale(0.5, 0.3), gold, 0, 0.35)
	rect(f, UDim2.fromScale(0.14, 0.3), UDim2.fromScale(0.5, 0.62), gold)
	rect(f, UDim2.fromScale(0.5, 0.14), UDim2.fromScale(0.5, 0.85), Color3.fromRGB(220, 160, 30), 0, 0.3)
end

function drawers.Kick(f: Frame)
	local c = Color3.fromRGB(255, 150, 60)
	rect(f, UDim2.fromScale(0.3, 0.6), UDim2.fromScale(0.38, 0.38), c, 0, 0.25)
	rect(f, UDim2.fromScale(0.7, 0.3), UDim2.fromScale(0.5, 0.75), c, 0, 0.45)
	rect(f, UDim2.fromScale(0.7, 0.08), UDim2.fromScale(0.5, 0.92), Color3.fromRGB(120, 60, 20), 0, 0.5)
end

function drawers.Speed(f: Frame)
	local c = Color3.fromRGB(110, 220, 255)
	for i, w in { 0.5, 0.75, 0.5 } do
		rect(f, UDim2.fromScale(w, 0.13), UDim2.new(0.95 - w / 2, 0, 0.25 * i, 0), c, 0, 0.5)
	end
end

function drawers.Lock(f: Frame)
	local shackle = UI.new("Frame", {
		Size = UDim2.fromScale(0.5, 0.55),
		Position = UDim2.fromScale(0.5, 0.36),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = f,
	})
	UI.corner(shackle, UDim.new(0.5, 0))
	UI.stroke(shackle, Color3.fromRGB(200, 205, 215), 3)
	rect(f, UDim2.fromScale(0.75, 0.5), UDim2.fromScale(0.5, 0.68), Color3.fromRGB(255, 200, 60), 0, 0.2)
end

function drawers.Close(f: Frame)
	rect(f, UDim2.fromScale(0.85, 0.2), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1), 45, 0.5)
	rect(f, UDim2.fromScale(0.85, 0.2), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1), -45, 0.5)
end

function UI.icon(key: string, size: number?): GuiObject
	local px = size or 32
	local asset = IconConfig[key]
	if asset and asset ~= "" then
		return UI.new("ImageLabel", {
			Name = key .. "Icon",
			BackgroundTransparency = 1,
			Image = asset,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(px, px),
		})
	end
	local frame = UI.new("Frame", {
		Name = key .. "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(px, px),
	})
	local drawer = drawers[key]
	if drawer then
		drawer(frame)
	end
	return frame
end

----------------------------------------------------------------------
-- Viewport (mostra um modelo 3D dentro da UI)
----------------------------------------------------------------------
function UI.viewport(model: Model?, props: { [string]: any }?): ViewportFrame
	local vp = UI.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1.2, -1),
	})
	if props then
		for k, v in props do
			vp[k] = v
		end
	end
	if model then
		UI.setViewportModel(vp, model)
	end
	return vp
end

function UI.setViewportModel(vp: ViewportFrame, model: Model, angle: number?)
	for _, child in vp:GetChildren() do
		if child:IsA("Model") or child:IsA("Camera") then
			child:Destroy()
		end
	end
	model:PivotTo(CFrame.new())
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local dist = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.05
	local dir = (CFrame.Angles(0, math.rad(angle or 200), 0) * CFrame.Angles(math.rad(-12), 0, 0)).LookVector
	camera.CFrame = CFrame.lookAt(cf.Position - dir * dist, cf.Position)
	camera.Parent = vp
	vp.CurrentCamera = camera
end

----------------------------------------------------------------------
-- ScreenGui responsiva
----------------------------------------------------------------------
local scales: { UIScale } = {}

local function computeScale(): number
	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1280, 760)
	local s = math.min(vp.X / 1280, vp.Y / 760)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	return math.clamp(s, if touch then 0.6 else 0.55, 1.15)
end

function UI.refreshScale()
	local s = computeScale()
	for _, uiScale in scales do
		uiScale.Scale = s
	end
end

function UI.getScale(): number
	return computeScale()
end

function UI.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function UI.screen(name: string, displayOrder: number?): ScreenGui
	return UI.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = displayOrder or 0,
		Parent = LocalPlayer:WaitForChild("PlayerGui"),
	})
end

-- Aplica a escala responsiva num container (escala em torno do AnchorPoint).
-- Use em containers de topo; animações de "pop" ficam nos filhos (UI.scaleOf).
function UI.responsive(frame: GuiObject): GuiObject
	local s = UI.new("UIScale", { Name = "ResponsiveScale", Scale = computeScale(), Parent = frame })
	table.insert(scales, s)
	return frame
end

-- Container transparente com escala responsiva
function UI.holder(props: { [string]: any }): Frame
	local frame = UI.new("Frame", { BackgroundTransparency = 1 })
	for k, v in props do
		if k ~= "Parent" then
			frame[k] = v
		end
	end
	UI.responsive(frame)
	frame.Parent = props.Parent
	return frame
end

----------------------------------------------------------------------
-- Raridades
----------------------------------------------------------------------
function UI.rarityColor(rarity: string): Color3
	local c = RarityConfig.Get(rarity).Color
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Gradiente arco-íris para "Secret"
function UI.rainbow(inst: Instance): UIGradient
	return UI.new("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 230, 110)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 170, 255)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(180, 90, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 160)),
		}),
		Parent = inst,
	})
end

-- Barra de progresso simples
function UI.progressBar(parent: Instance, color: Color3, size: UDim2, position: UDim2?)
	local back = UI.new("Frame", {
		Name = "ProgressBar",
		BackgroundColor3 = T.PanelDark,
		Size = size,
		Position = position or UDim2.new(),
		Parent = parent,
	})
	UI.corner(back, UDim.new(1, 0))
	UI.stroke(back, T.Stroke, 1.5)
	local fill = UI.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = color,
		Size = UDim2.fromScale(0, 1),
		Parent = back,
	})
	UI.corner(fill, UDim.new(1, 0))
	UI.gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	local text = UI.label({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, -10, 1, -4),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		MaxTextSize = 18,
		ZIndex = 3,
		Parent = back,
	})
	return {
		Frame = back,
		Set = function(_, alpha: number, label: string?)
			UI.tween(fill, 0.25, { Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1) })
			text.Text = label or ""
		end,
	}
end

return UI
