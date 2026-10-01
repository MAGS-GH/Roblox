--[[
	MarbleControl.client.luau
	-------------------------
	Smooth arcade-styring:
	- Input glattes (InputSmooth)
	- Hastighed lerper mod ønsket retning (Accel/Steer/Brake)
	- NetworkOwner = spiller → ingen input-lag fra server-roundtrip
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CourseState = require(Shared:WaitForChild("CourseState"))

local marble: BasePart? = nil
local rawMove = Vector3.zero
local smoothMove = Vector3.zero
local cameraYaw = math.pi
local cameraPitch = 0.35
local jumpRequested = false
local snapCameraToGoal = false
local snapCameraOnce = false

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function expAlpha(rate: number, dt: number): number
	-- Frame-rate uafhængig lerp-faktor
	return 1 - math.exp(-rate * dt)
end

local function getCamera(): Camera
	local cam = workspace.CurrentCamera
	if not cam then
		cam = Instance.new("Camera")
		cam.Parent = workspace
		workspace.CurrentCamera = cam
	end
	return cam
end

local function cameraOffset(): Vector3
	local distance = Config.Camera.Distance
	local height = Config.Camera.Height
	return Vector3.new(
		math.sin(cameraYaw) * math.cos(cameraPitch) * distance,
		math.sin(cameraPitch) * distance + height * 0.25,
		math.cos(cameraYaw) * math.cos(cameraPitch) * distance
	)
end

local function applyCamera(ball: BasePart, immediate: boolean, dt: number)
	local cam = getCamera()
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CameraSubject = ball
	cam:SetAttribute("MarbleControlActive", true)

	local desired = CFrame.lookAt(ball.Position + cameraOffset(), ball.Position + Vector3.new(0, 1.5, 0))
	if immediate then
		cam.CFrame = desired
	else
		cam.CFrame = cam.CFrame:Lerp(desired, expAlpha(9, dt))
	end
end

local function bindMarble(assigned: BasePart?)
	local ball = assigned
	if not (ball and ball:IsA("BasePart")) then
		ball = workspace:FindFirstChild(player.Name .. "_Marble") :: BasePart?
	end
	if not ball then
		return
	end
	marble = ball
	smoothMove = Vector3.zero
	rawMove = Vector3.zero
	cameraYaw = math.pi
	cameraPitch = 0.35
	snapCameraOnce = true
	CourseState.beginRace()
	applyCamera(ball, true, 0)

	-- Sørg for at DriveForce ikke kæmper imod vores velocity-styring
	local drive = ball:FindFirstChild("DriveForce")
	if drive and drive:IsA("VectorForce") then
		drive.Force = Vector3.zero
		drive.Enabled = false
	end
end

local function getCameraFlatLook(): Vector3
	local look = getCamera().CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.05 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function isGrounded(ball: BasePart): boolean
	rayParams.FilterDescendantsInstances = { ball }
	local radius = ball.Size.Y * 0.5
	local origin = ball.Position
	local direction = Vector3.new(0, -(radius + Config.Marble.GroundCheckPadding), 0)
	if workspace:Raycast(origin, direction, rayParams) then
		return true
	end
	local offsets = {
		Vector3.new(radius * 0.4, 0, 0),
		Vector3.new(-radius * 0.4, 0, 0),
		Vector3.new(0, 0, radius * 0.4),
		Vector3.new(0, 0, -radius * 0.4),
	}
	for _, offset in offsets do
		if workspace:Raycast(origin + offset, direction, rayParams) then
			return true
		end
	end
	return false
end

local function updateRawMoveFromKeys()
	local x, z = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		z -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		z += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		x -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		x += 1
	end

	local look = getCameraFlatLook()
	local right = Vector3.new(-look.Z, 0, look.X)
	local dir = (look * -z) + (right * x)
	if dir.Magnitude > 1 then
		dir = dir.Unit
	elseif dir.Magnitude > 0.01 then
		dir = dir.Unit * dir.Magnitude
	else
		dir = Vector3.zero
	end
	rawMove = dir
end

local function updateCameraFromKeys(dt: number)
	local yawInput = 0
	local pitchInput = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		yawInput += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		yawInput -= 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		pitchInput += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		pitchInput -= 1
	end
	if yawInput ~= 0 then
		cameraYaw += yawInput * Config.Camera.TurnSpeed * dt
	end
	if pitchInput ~= 0 then
		cameraPitch = math.clamp(cameraPitch + pitchInput * Config.Camera.PitchSpeed * dt, 0.15, 1.2)
	end
end

local function updateCameraSnapToGoal(dt: number)
	if not snapCameraToGoal or not marble then
		return
	end
	local delta = CourseState.goalPosition - marble.Position
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude < 6 then
		snapCameraToGoal = false
		return
	end
	local targetYaw = math.atan2(-flat.X, -flat.Z)
	local diff = (targetYaw - cameraYaw + math.pi) % (2 * math.pi) - math.pi
	if math.abs(diff) < 0.04 then
		cameraYaw = targetYaw
		snapCameraToGoal = false
	else
		cameraYaw += math.clamp(diff, -Config.Camera.GoalSnapSpeed * dt, Config.Camera.GoalSnapSpeed * dt)
	end
end

--[[
	Kerne: smooth velocity-styring
	desiredVel = smoothMove * MaxSpeed
	Nuværende horisontal hastighed lerper mod desired (accel/steer),
	eller mod 0 når der ikke er input (brake).
]]
local function applySmoothDrive(ball: BasePart, dt: number)
	smoothMove = smoothMove:Lerp(rawMove, expAlpha(Config.Marble.InputSmooth, dt))
	if smoothMove.Magnitude < 0.02 then
		smoothMove = Vector3.zero
	end

	local vel = ball.AssemblyLinearVelocity
	local horizontal = Vector3.new(vel.X, 0, vel.Z)
	local newHorizontal: Vector3

	if smoothMove.Magnitude > 0.02 then
		local desired = smoothMove.Unit * (Config.Marble.MaxSpeed * math.clamp(smoothMove.Magnitude, 0, 1))
		-- Bland accel + steer: hurtigere drejning når vi allerede kører
		local rate = Config.Marble.AccelRate
		if horizontal.Magnitude > 4 then
			rate = math.max(rate, Config.Marble.SteerRate)
		end
		newHorizontal = horizontal:Lerp(desired, expAlpha(rate, dt))
	else
		newHorizontal = horizontal:Lerp(Vector3.zero, expAlpha(Config.Marble.BrakeRate, dt))
		if newHorizontal.Magnitude < 0.35 then
			newHorizontal = Vector3.zero
		end
	end

	ball.AssemblyLinearVelocity = Vector3.new(newHorizontal.X, vel.Y, newHorizontal.Z)

	-- Blød rotation (ser mere “rullende” ud)
	local angular = ball.AssemblyAngularVelocity
	local targetSpin = Vector3.new(-newHorizontal.Z, 0, newHorizontal.X) * 0.35
	ball.AssemblyAngularVelocity = angular:Lerp(targetSpin, expAlpha(6, dt))
end

local function tryJump(ball: BasePart)
	if not isGrounded(ball) then
		return
	end
	local vel = ball.AssemblyLinearVelocity
	if vel.Y > 6 then
		return
	end
	ball.AssemblyLinearVelocity = Vector3.new(vel.X, Config.Marble.JumpSpeed, vel.Z)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		Remotes.RequestRespawn:FireServer()
	elseif input.KeyCode == Enum.KeyCode.Return then
		snapCameraToGoal = true
	elseif input.KeyCode == Enum.KeyCode.Space then
		jumpRequested = true
	end
end)

Remotes.CourseInfo.OnClientEvent:Connect(function(payload)
	CourseState.applyCourseInfo(payload)
end)

Remotes.AssignMarble.OnClientEvent:Connect(function(assigned)
	bindMarble(assigned)
end)

task.defer(function()
	local found = workspace:WaitForChild(player.Name .. "_Marble", 10)
	if found and found:IsA("BasePart") then
		bindMarble(found)
	end
end)

RunService.RenderStepped:Connect(function(dt)
	-- Clamp dt så et hitch ikke skyder marble afsted
	dt = math.clamp(dt, 0, 1 / 20)

	updateRawMoveFromKeys()
	updateCameraFromKeys(dt)
	updateCameraSnapToGoal(dt)

	local ball = marble
	if not ball or not ball.Parent then
		return
	end

	if jumpRequested then
		jumpRequested = false
		tryJump(ball)
	end

	applySmoothDrive(ball, dt)

	local immediate = snapCameraOnce
	snapCameraOnce = false
	applyCamera(ball, immediate, dt)
end)
