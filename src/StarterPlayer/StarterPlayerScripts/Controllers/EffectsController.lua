-- EffectsController: partículas de impacto/poeira (reutilizadas), confete leve na UI,
-- celebração de recorde, rebirth e desbloqueios.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules.Remotes)
local NumberFormat = require(Modules.NumberFormat)
local EggConfig = require(Modules.EggConfig)
local AreaConfig = require(Modules.AreaConfig)
local RebirthConfig = require(Modules.RebirthConfig)

local UI = require(script.Parent.Parent:WaitForChild("UI").UIKit)
local T = UI.Theme

local EffectsController = {}

local controllers
local fxAttachment: Attachment
local sparks: ParticleEmitter
local dust: ParticleEmitter
local ring: Part
local bannerHolder: Frame
local confettiLayer: Frame
local confettiAlive = 0
local MAX_CONFETTI = 70

local function emitAt(emitter: ParticleEmitter, position: Vector3, count: number, color: Color3?)
	fxAttachment.WorldPosition = position
	if color then
		emitter.Color = ColorSequence.new(color)
	end
	emitter:Emit(count)
end

function EffectsController:Impact(position: Vector3, color: Color3, strong: boolean?)
	emitAt(sparks, position, if strong then 28 else 12, color)
	emitAt(dust, position - Vector3.new(0, 1, 0), if strong then 14 else 6)
	-- Onda de choque (uma única peça reaproveitada)
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = CFrame.new(position.X, position.Y - 1.2, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	UI.tween(ring, 0.35, { Size = Vector3.new(0.4, 22, 22), Transparency = 1 })
end

function EffectsController:Dust(position: Vector3, count: number?)
	emitAt(dust, position, count or 10)
end

function EffectsController:Confetti(count: number)
	local colors = { T.Gold, T.Red, T.Blue, T.Green, T.Purple, Color3.fromRGB(255, 130, 200) }
	for _ = 1, count do
		if confettiAlive >= MAX_CONFETTI then
			return
		end
		confettiAlive += 1
		local piece = UI.new("Frame", {
			Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22)),
			Position = UDim2.new(math.random(), 0, 0, -30),
			BackgroundColor3 = colors[math.random(#colors)],
			Rotation = math.random(0, 360),
			BorderSizePixel = 0,
			Parent = confettiLayer,
		})
		local time = 1.6 + math.random() * 1.2
		UI.tween(piece, time, {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1.05, 0),
			Rotation = piece.Rotation + math.random(-360, 360),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(time, function()
			piece:Destroy()
			confettiAlive -= 1
		end)
	end
end

-- Faixa grande no topo (NEW BEST, REBIRTH, etc.)
local bannerToken = 0
function EffectsController:Banner(title: string, subtitle: string, color: Color3, iconKey: string?, duration: number?)
	bannerToken += 1
	local token = bannerToken
	for _, c in bannerHolder:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local frame = UI.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = bannerHolder,
	})
	if iconKey then
		local icon = UI.icon(iconKey, 74)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, -10)
		icon.Parent = frame
	end
	local titleLabel = UI.label({
		Text = title,
		Size = UDim2.new(1, 0, 0, 80),
		Position = UDim2.fromOffset(0, if iconKey then 60 else 10),
		TextColor3 = color,
		MaxTextSize = 80,
		Parent = frame,
	})
	;(titleLabel:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 4
	UI.label({
		Text = subtitle,
		Size = UDim2.new(1, 0, 0, 46),
		Position = UDim2.fromOffset(0, if iconKey then 140 else 90),
		MaxTextSize = 46,
		Parent = frame,
	})
	UI.pop(frame, 0.3)
	task.spawn(function()
		local s = UI.scaleOf(frame)
		task.wait(0.4)
		for _ = 1, 2 do
			if token ~= bannerToken then
				return
			end
			UI.tween(s, 0.25, { Scale = 1.06 })
			task.wait(0.25)
			UI.tween(s, 0.25, { Scale = 1 })
			task.wait(0.25)
		end
	end)
	task.delay(duration or 2.6, function()
		if token == bannerToken and frame.Parent then
			UI.tween(UI.scaleOf(frame), 0.2, { Scale = 0 })
			task.wait(0.2)
			frame:Destroy()
		end
	end)
end

function EffectsController:NewBest(distance: number, previous: number?)
	local sub = NumberFormat.Distance(distance)
	if previous and previous > 0 then
		sub ..= "  (+" .. NumberFormat.Distance(distance - previous) .. ")"
	end
	controllers.UIController.Hud.Distance.Visible = false
	self:Banner("NEW BEST!", sub, T.Gold, "Trophy", 2.6)
	controllers.SoundController:Play("NewBest")
	self:Confetti(28)
end

function EffectsController:Init(all)
	controllers = all
end

function EffectsController:Start()
	-- Âncora única para partículas
	local anchor = Instance.new("Part")
	anchor.Name = "KickAnEggFx"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(0, -500, 0)
	anchor.Parent = workspace
	fxAttachment = Instance.new("Attachment")
	fxAttachment.Parent = anchor

	sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Enabled = false
	sparks.Lifetime = NumberRange.new(0.3, 0.6)
	sparks.Speed = NumberRange.new(18, 34)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	sparks.LightEmission = 0.8
	sparks.Drag = 4
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Parent = fxAttachment

	dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Enabled = false
	dust.Lifetime = NumberRange.new(0.6, 1.1)
	dust.Speed = NumberRange.new(6, 14)
	dust.SpreadAngle = Vector2.new(80, 20)
	dust.Color = ColorSequence.new(Color3.fromRGB(235, 225, 200))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dust.Drag = 3
	dust.Parent = fxAttachment

	ring = Instance.new("Part")
	ring.Name = "KickAnEggShockwave"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 240, 200)
	ring.Transparency = 1
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = CFrame.new(0, -500, 0)
	ring.Parent = workspace

	local overlay = controllers.UIController.Screens.Overlay
	confettiLayer = UI.new("Frame", { Name = "Confetti", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = overlay })
	bannerHolder = UI.holder({
		Name = "Banner",
		Size = UDim2.fromOffset(700, 200),
		Position = UDim2.new(0.5, 0, 0, 60),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = overlay,
	})

	-- Celebrações enviadas pelo servidor
	Remotes.Event("Celebrate").OnClientEvent:Connect(function(kind, value)
		if kind == "Rebirth" then
			local m = RebirthConfig.Multipliers(value)
			self:Banner("REBIRTH " .. tostring(value) .. "!", "Strength " .. NumberFormat.Multiplier(m.Strength) .. "   Coins " .. NumberFormat.Multiplier(m.Coins), T.Purple, "Rebirth", 3.2)
			controllers.SoundController:Play("Rebirth")
			controllers.CameraController:Shake(0.6, 0.6)
			self:Confetti(50)
			if value == 1 then
				task.delay(3.4, function()
					controllers.UIController:Toast("Auto Train unlocked!", "Success")
				end)
			end
		elseif kind == "AreaUnlocked" then
			local area = AreaConfig.Get(value)
			if area then
				self:Banner("AREA UNLOCKED!", area.Name, T.Green, "Areas", 2.6)
				controllers.SoundController:Play("Reveal")
				self:Confetti(24)
			end
		elseif kind == "EggUnlocked" then
			local egg = EggConfig.Get(value)
			if egg then
				self:Banner("NEW EGG!", egg.Name, UI.rarityColor(egg.Rarity), "Eggs", 2.4)
				self:Confetti(20)
			end
		end
	end)
end

return EffectsController
