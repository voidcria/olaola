-- AnimationController: animações de chute e treino.
-- Se Config.Animations tiver IDs (suas animações publicadas), elas são usadas.
-- Senão, usamos uma animação procedural nos Motor6D (funciona sem nenhum asset).
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = require(Modules.Config)

local AnimationController = {}

local originalC0: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local busy: { [Motor6D]: number } = setmetatable({}, { __mode = "k" }) :: any
local loadedTracks: { [Instance]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any

local function getMotor(character: Model, r15Part: string, r15Name: string, r6Name: string): (Motor6D?, boolean)
	local part = character:FindFirstChild(r15Part)
	local motor = part and part:FindFirstChild(r15Name)
	if motor and motor:IsA("Motor6D") then
		return motor, true
	end
	local torso = character:FindFirstChild("Torso")
	local r6 = torso and torso:FindFirstChild(r6Name)
	if r6 and r6:IsA("Motor6D") then
		return r6, false
	end
	return nil, false
end

local function tweenC0(motor: Motor6D, cf: CFrame, time: number, style: Enum.EasingStyle?)
	local tween = TweenService:Create(motor, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = cf })
	tween:Play()
	return tween
end

-- Sequência de poses: { {ângulo, tempo}, ... } em volta do eixo de balanço da junta
local function playSequence(motor: Motor6D, isR15: boolean, poses: { { number } }, axisSign: number)
	if not originalC0[motor] then
		originalC0[motor] = motor.C0
	end
	local base = originalC0[motor]
	local token = (busy[motor] or 0) + 1
	busy[motor] = token
	task.spawn(function()
		for _, pose in poses do
			if busy[motor] ~= token then
				return
			end
			local angle = math.rad(pose[1]) * axisSign
			local rot = if isR15 then CFrame.Angles(angle, 0, 0) else CFrame.Angles(0, 0, -angle)
			tweenC0(motor, base * rot, pose[2])
			task.wait(pose[2])
		end
		if busy[motor] == token then
			tweenC0(motor, base, 0.2)
		end
	end)
end

local function playAnimationId(character: Model, key: string): boolean
	local id = Config.Animations and Config.Animations[key]
	if not id or id == "" then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return false
	end
	local cache = loadedTracks[character]
	if not cache then
		cache = {}
		loadedTracks[character] = cache
	end
	local track = cache[key]
	if not track then
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		track = animator:LoadAnimation(anim)
		cache[key] = track
	end
	track:Play(0.05)
	return true
end

function AnimationController:PlayKick(character: Model?)
	if not character then
		return
	end
	if playAnimationId(character, "Kick") then
		return
	end
	local motor, isR15 = getMotor(character, "RightUpperLeg", "RightHip", "Right Hip")
	if motor then
		-- recua, chuta forte, segura e volta
		playSequence(motor, isR15, { { -35, 0.1 }, { 85, 0.07 }, { 70, 0.12 } }, 1)
	end
end

local alternate = false
function AnimationController:PlayTrain(character: Model?)
	if not character then
		return
	end
	if playAnimationId(character, "Train") then
		return
	end
	-- Segurando o peso: levanta o braço direito (desenvolvimento acima da cabeça)
	if character:FindFirstChildOfClass("Tool") then
		local motor, isR15 = getMotor(character, "RightUpperArm", "RightShoulder", "Right Shoulder")
		if motor then
			playSequence(motor, isR15, { { 75, 0.09 }, { 65, 0.08 } }, 1)
		end
		return
	end
	alternate = not alternate
	local motor, isR15
	if alternate then
		motor, isR15 = getMotor(character, "RightUpperArm", "RightShoulder", "Right Shoulder")
	else
		motor, isR15 = getMotor(character, "LeftUpperArm", "LeftShoulder", "Left Shoulder")
	end
	if motor then
		-- soco para frente
		playSequence(motor, isR15, { { 95, 0.07 }, { 85, 0.08 } }, if isR15 or alternate then 1 else -1)
	end
end

function AnimationController:Init() end
function AnimationController:Start() end

return AnimationController
