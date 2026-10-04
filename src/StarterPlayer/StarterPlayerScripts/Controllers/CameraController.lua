-- CameraController: câmera que acompanha o ovo após o chute, tremida de impacto
-- e retorno suave ao jogador. Pode ser desativada em Settings (Egg Camera).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules.Config)

local LocalPlayer = Players.LocalPlayer

local CameraController = {}

local camera = workspace.CurrentCamera
local following = false
local target: Model? = nil
local savedOffset: Vector3? = nil
local followStarted = 0
local releaseToken = 0
local baseFov = 70

local shakeIntensity = 0
local shakeUntil = 0

local function getRoot(): BasePart?
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function tweenFov(fov: number, time: number)
	TweenService:Create(camera, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = fov }):Play()
end

function CameraController:Shake(intensity: number, duration: number)
	shakeIntensity = math.max(shakeIntensity, intensity)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

local FOLLOW_OFFSET = Vector3.new(14, 10, 34)

local function followStep()
	if not following then
		return
	end
	local model = target
	if not model or not model.Parent then
		CameraController:Release(true)
		return
	end
	local eggPos = model:GetPivot().Position
	-- entra suavemente na posição de acompanhamento
	local blend = math.clamp((os.clock() - followStarted) / 0.45, 0, 1)
	blend = 1 - (1 - blend) ^ 3
	local root = getRoot()
	local startPos = if root and savedOffset then root.Position + savedOffset else eggPos + FOLLOW_OFFSET
	local desired = eggPos + FOLLOW_OFFSET
	local camPos = startPos:Lerp(desired, blend)
	camera.CFrame = CFrame.lookAt(camPos, eggPos + Vector3.new(0, 1, -10))
end

function CameraController:FollowEgg(model: Model, _info, enabled: boolean)
	self:Shake(0.35, 0.25)
	tweenFov(baseFov + 8, 0.12)
	task.delay(0.15, function()
		if not following then
			tweenFov(baseFov, 0.4)
		end
	end)
	if not enabled then
		return
	end
	local root = getRoot()
	if not root then
		return
	end
	releaseToken += 1
	savedOffset = camera.CFrame.Position - root.Position
	target = model
	following = true
	followStarted = os.clock()
	camera.CameraType = Enum.CameraType.Scriptable
	tweenFov(Config.Camera.FieldOfView, 0.5)
end

-- Volta ao jogador depois de um tempinho mostrando o pouso
function CameraController:Release(immediate: boolean?)
	if not following then
		return
	end
	releaseToken += 1
	local token = releaseToken
	task.delay(if immediate then 0 else Config.Camera.HoldAfterLanding, function()
		if token ~= releaseToken or not following then
			return
		end
		following = false
		local root = getRoot()
		if root and savedOffset then
			local fromCf = camera.CFrame
			local duration = Config.Camera.ReturnTime
			local start = os.clock()
			tweenFov(baseFov, duration)
			while os.clock() - start < duration do
				local a = (os.clock() - start) / duration
				a = 1 - (1 - a) ^ 3
				local r = getRoot()
				if not r then
					break
				end
				local toCf = CFrame.lookAt(r.Position + savedOffset, r.Position + Vector3.new(0, 1.5, 0))
				camera.CFrame = fromCf:Lerp(toCf, a)
				RunService.RenderStepped:Wait()
				if token ~= releaseToken then
					return
				end
			end
		end
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = baseFov
	end)
end

function CameraController:IsFollowing(): boolean
	return following
end

function CameraController:Init() end

function CameraController:Start()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		camera = workspace.CurrentCamera
	end)
	RunService:BindToRenderStep("KickAnEggFollow", Enum.RenderPriority.Camera.Value + 1, followStep)
	RunService:BindToRenderStep("KickAnEggShake", Enum.RenderPriority.Camera.Value + 2, function()
		local now = os.clock()
		if now < shakeUntil then
			local k = shakeIntensity * math.clamp((shakeUntil - now) / 0.3, 0, 1)
			camera.CFrame *= CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0) * CFrame.Angles(0, 0, (math.random() - 0.5) * k * 0.02)
		else
			shakeIntensity = 0
		end
	end)
	-- Ao renascer, garante câmera normal
	LocalPlayer.CharacterAdded:Connect(function()
		following = false
		releaseToken += 1
		camera.CameraType = Enum.CameraType.Custom
	end)
end

return CameraController
