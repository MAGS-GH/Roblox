--[[
	MarbleControl.client.luau
	-------------------------
	Klient-script der styrer kuglen (marble) lokalt.

	Hvorfor på klienten?
	- Serveren giver dig NetworkOwner over din marble.
	- Så kan vi sætte hastighed direkte her uden at vente på server-roundtrip.
	- Resultatet: smooth arcade-styring uden lag.

	Flow hvert frame (RenderStepped):
	1) Læs WASD → rawMove (ønsket retning ift. kamera)
	2) Læs pile → drej kamera (yaw/pitch)
	3) Glat rawMove → smoothMove (InputSmooth)
	4) Lerp nuværende hastighed mod ønsket (Accel/Steer/Brake)
	5) Hop hvis Space er trykket og vi er på jorden
	6) Flyt kameraet så det følger kuglen
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Delte moduler: hastigheder, remotes, race-state (mål/checkpoints)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CourseState = require(Shared:WaitForChild("CourseState"))

-- Den Part (ball) vi styrer lige nu. Nil indtil AssignMarble / find i workspace.
local marble: BasePart? = nil

-- rawMove  = hvad spilleren trykker lige nu (kan hoppe 0→1 på ét frame)
-- smoothMove = glattet udgave, så acceleration føles blød
local rawMove = Vector3.zero
local smoothMove = Vector3.zero

-- Kamera-orbit rundt om kuglen (radianer)
-- yaw = vandret drejning, pitch = op/ned-vinkel
local cameraYaw = math.pi
local cameraPitch = 0.35

-- Space sætter flag; hop udføres i RenderStepped (så vi kun hopper én gang pr. tryk)
local jumpRequested = false

-- Enter: snappyaw kameraet hen mod målet
local snapCameraToGoal = false
-- Første frame efter spawn: sæt kamera med det samme (ingen lerp)
local snapCameraOnce = false

-- Raycast-params til ground-check (vi ignorerer selve kuglen)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

--[[
	expAlpha(rate, dt)
	Frame-rate-uafhængig lerp-faktor.
	I stedet for `lerp(a, b, 0.1)` hvert frame (som bliver hurtigere ved 120 fps),
	bruger vi 1 - e^(-rate * dt). Samme "følelse" ved 30 og 144 fps.
]]
local function expAlpha(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

-- Hent (eller opret) CurrentCamera, så vi altid kan styre den scriptable
local function getCamera(): Camera
	local cam = workspace.CurrentCamera
	if not cam then
		cam = Instance.new("Camera")
		cam.Parent = workspace
		workspace.CurrentCamera = cam
	end
	return cam
end

--[[
	cameraOffset()
	Vektor fra kugle → kamera-position, baseret på yaw/pitch + Config.Camera.
	Sin/cos omsætter vinkler til en punkt på en kugleflade bagved/over marble.
]]
local function cameraOffset(): Vector3
	local distance = Config.Camera.Distance
	local height = Config.Camera.Height
	return Vector3.new(
		math.sin(cameraYaw) * math.cos(cameraPitch) * distance,
		math.sin(cameraPitch) * distance + height * 0.25,
		math.cos(cameraYaw) * math.cos(cameraPitch) * distance
	)
end

--[[
	applyCamera(ball, immediate, dt)
	Sætter kamera til Scriptable og kigger på kuglen.
	immediate = true → snap med det samme (spawn).
	ellers → blød Lerp så kameraet ikke rykker hårdt.
]]
local function applyCamera(ball: BasePart, immediate: boolean, dt: number)
	local cam = getCamera()
	cam.CameraType = Enum.CameraType.Scriptable -- vi styrer CFrame selv (ikke Classic/Follow)
	cam.CameraSubject = ball
	cam:SetAttribute("MarbleControlActive", true) -- flag til andre scripts (fx CameraBootstrap)

	-- lookAt: kamera står bag kuglen, kigger lidt over midten (+1.5 i Y)
	local desired = CFrame.lookAt(ball.Position + cameraOffset(), ball.Position + Vector3.new(0, 1.5, 0))
	if immediate then
		cam.CFrame = desired
	else
		cam.CFrame = cam.CFrame:Lerp(desired, expAlpha(9, dt)) -- rate 9 ≈ ret responsivt
	end
end

--[[
	bindMarble(assigned)
	Kaldes når serveren giver os en ny kugle (spawn/respawn).
	Nulstiller input/kamera og starter race-timer via CourseState.
]]
local function bindMarble(assigned: BasePart?)
	local ball = assigned
	-- Fallback: find "SpillerNavn_Marble" i workspace hvis remote-payload mangler
	if not (ball and ball:IsA("BasePart")) then
		ball = workspace:FindFirstChild(player.Name .. "_Marble") :: BasePart?
	end
	if not ball then
		return
	end
	marble = ball
	smoothMove = Vector3.zero -- start uden "spøgelses-input" fra forrige run
	rawMove = Vector3.zero
	cameraYaw = math.pi -- standard: kig bagud langs -Z
	cameraPitch = 0.35
	snapCameraOnce = true -- næste frame: hard-snap kamera
	CourseState.beginRace()
	applyCamera(ball, true, 0)

	-- Serveren opretter stadig DriveForce (legacy). Slå den fra,
	-- ellers kæmper den imod vores AssemblyLinearVelocity-styring.
	local drive = ball:FindFirstChild("DriveForce")
	if drive and drive:IsA("VectorForce") then
		drive.Force = Vector3.zero
		drive.Enabled = false
	end
end

--[[
	getCameraFlatLook()
	Kameraretningsvektor projected ned på XZ-planet (Y=0).
	Bruges så W altid betyder "fremad på banen" ift. hvor du kigger — ikke op i luften.
]]
local function getCameraFlatLook(): Vector3
	local look = getCamera().CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.05 then
		-- Kamera kigger næsten lige op/ned → brug en default fremad-retning
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

--[[
	isGrounded(ball)
	Raycast nedad fra midten + 4 side-offsets.
	Offsets gør hop mere tilgivende på kanter (ikke kun præcis under centrum).
]]
local function isGrounded(ball: BasePart): boolean
	rayParams.FilterDescendantsInstances = { ball } -- ram ikke dig selv
	local radius = ball.Size.Y * 0.5
	local origin = ball.Position
	-- Lidt længere end radius, så små ujævnheder stadig tæller som "på jorden"
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

--[[
	updateRawMoveFromKeys()
	WASD → verdensretning relativt til kamera.

	Intern convention:
	  z = -1 når W (frem), +1 når S (bak)
	  x = -1 når A (venstre), +1 når D (højre)

	Derefter:
	  look * -z  → W giver +look (fremad i kamera-retning)
	  right * x  → A/D sidelæns
]]
local function updateRawMoveFromKeys()
	local x, z = 0, 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		z -= 1 -- frem
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		z += 1 -- bak
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		x -= 1 -- venstre
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		x += 1 -- højre
	end

	local look = getCameraFlatLook()
	-- right = look roteret 90° på XZ (venstre-hånds: (-z, 0, x) ift. look (x,0,z))
	local right = Vector3.new(-look.Z, 0, look.X)
	local dir = (look * -z) + (right * x)

	if dir.Magnitude > 1 then
		-- W+D samtidigt må ikke give √2 hastighed — normaliser til max 1
		dir = dir.Unit
	elseif dir.Magnitude > 0.01 then
		dir = dir.Unit * dir.Magnitude -- behold partial stick (her: fuld key = 1)
	else
		dir = Vector3.zero -- ingen input
	end
	rawMove = dir -- gemmes; glattes senere i applySmoothDrive
end

--[[
	updateCameraFromKeys(dt)
	Pile-taster orbit'er kameraet rundt om kuglen.
	Venstre/højre = yaw, op/ned = pitch (clamped så vi ikke går igennem gulvet/luften).
]]
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
		-- Clamp: 0.15 ≈ næsten fladt bagfra, 1.2 ≈ stejlt ovenfra
		cameraPitch = math.clamp(cameraPitch + pitchInput * Config.Camera.PitchSpeed * dt, 0.15, 1.2)
	end
end

--[[
	updateCameraSnapToGoal(dt)
	Enter aktiverer snapCameraToGoal.
	Vi drejer yaw gradvist mod vektoren kugle→mål (kun XZ),
	så spilleren hurtigt ser hvor banen går hen.
]]
local function updateCameraSnapToGoal(dt: number)
	if not snapCameraToGoal or not marble then
		return
	end
	local delta = CourseState.goalPosition - marble.Position
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if flat.Magnitude < 6 then
		-- Allerede tæt på mål — stop snap
		snapCameraToGoal = false
		return
	end
	-- atan2 matcher vores yaw-definition i cameraOffset (sin/cos)
	local targetYaw = math.atan2(-flat.X, -flat.Z)
	-- Korteste vinkel-difference i [-pi, pi]
	local diff = (targetYaw - cameraYaw + math.pi) % (2 * math.pi) - math.pi
	if math.abs(diff) < 0.04 then
		cameraYaw = targetYaw
		snapCameraToGoal = false -- færdig
	else
		-- Begræns hvor hurtigt vi drejer pr. frame (GoalSnapSpeed)
		cameraYaw += math.clamp(diff, -Config.Camera.GoalSnapSpeed * dt, Config.Camera.GoalSnapSpeed * dt)
	end
end

--[[
	applySmoothDrive(ball, dt)  — KERNE I STYRINGEN

	1) Glat input:   smoothMove → mod rawMove (InputSmooth)
	2) Ønsket fart:  desired = retning * MaxSpeed * input-styrke
	3) Med input:    lerp nuværende horisontal hastighed → desired (AccelRate / SteerRate)
	4) Uden input:   lerp → 0 (BrakeRate) — aktiv opbremsning, ikke kun friktion
	5) Bevar vel.Y:  hop/fald styres af gravity; vi rører kun XZ
	6) Fake-spin:    AngularVelocity så kuglen ser ud til at rulle
]]
local function applySmoothDrive(ball: BasePart, dt: number)
	-- Trin 1: input-smoothing (undgår "digital" start/stop)
	smoothMove = smoothMove:Lerp(rawMove, expAlpha(Config.Marble.InputSmooth, dt))
	if smoothMove.Magnitude < 0.02 then
		smoothMove = Vector3.zero -- dødzone: undgå mikro-kravlen
	end

	local vel = ball.AssemblyLinearVelocity
	local horizontal = Vector3.new(vel.X, 0, vel.Z) -- smid Y væk midlertidigt
	local newHorizontal: Vector3

	if smoothMove.Magnitude > 0.02 then
		-- Trin 2: ønsket hastighedsvektor (længde ≤ MaxSpeed)
		local desired = smoothMove.Unit * (Config.Marble.MaxSpeed * math.clamp(smoothMove.Magnitude, 0, 1))
		-- Trin 3: accel når vi bygger fart; brug mindst SteerRate når vi allerede kører
		-- (så man kan dreje skarpt uden at "glide" forbi svinget)
		local rate = Config.Marble.AccelRate
		if horizontal.Magnitude > 4 then
			rate = math.max(rate, Config.Marble.SteerRate)
		end
		newHorizontal = horizontal:Lerp(desired, expAlpha(rate, dt))
	else
		-- Trin 4: ingen input → bremse aktivt
		newHorizontal = horizontal:Lerp(Vector3.zero, expAlpha(Config.Marble.BrakeRate, dt))
		if newHorizontal.Magnitude < 0.35 then
			newHorizontal = Vector3.zero -- stop helt, så vi ikke kryber
		end
	end

	-- Trin 5: skriv XZ tilbage; behold Y (gravity / hop)
	ball.AssemblyLinearVelocity = Vector3.new(newHorizontal.X, vel.Y, newHorizontal.Z)

	-- Trin 6: visuelt spin (ikke fysisk korrekt rulle, men ser arcade-godt ud)
	local angular = ball.AssemblyAngularVelocity
	local targetSpin = Vector3.new(-newHorizontal.Z, 0, newHorizontal.X) * 0.35
	ball.AssemblyAngularVelocity = angular:Lerp(targetSpin, expAlpha(6, dt))
end

--[[
	tryJump(ball)
	Kun hvis grounded og ikke allerede på vej kraftigt opad.
	Sætter Y-hastighed direkte til JumpSpeed (arcade-hop).
]]
local function tryJump(ball: BasePart)
	if not isGrounded(ball) then
		return -- ingen double-jump midt i luften
	end
	local vel = ball.AssemblyLinearVelocity
	if vel.Y > 6 then
		return -- allerede i hop — undgå at "booste" ekstra
	end
	ball.AssemblyLinearVelocity = Vector3.new(vel.X, Config.Marble.JumpSpeed, vel.Z)
end

-- Engangs-taster (ikke holdt nede hvert frame)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return -- UI / chat har allerede "spist" inputtet
	end
	if input.KeyCode == Enum.KeyCode.R then
		Remotes.RequestRespawn:FireServer() -- server spawner ny marble ved checkpoint
	elseif input.KeyCode == Enum.KeyCode.Return then
		snapCameraToGoal = true -- start yaw-snap i updateCameraSnapToGoal
	elseif input.KeyCode == Enum.KeyCode.Space then
		jumpRequested = true -- udføres i RenderStepped (én gang)
	end
end)

-- Server sender mål/checkpoint-antal → CourseState (HUD bruger det også)
Remotes.CourseInfo.OnClientEvent:Connect(function(payload)
	CourseState.applyCourseInfo(payload)
end)

-- Server: "her er din marble-Part" (efter join / respawn / mål-restart)
Remotes.AssignMarble.OnClientEvent:Connect(function(assigned)
	bindMarble(assigned)
end)

-- Backup hvis AssignMarble kom før vi lyttede: vent op til 10s på kuglen i workspace
task.defer(function()
	local found = workspace:WaitForChild(player.Name .. "_Marble", 10)
	if found and found:IsA("BasePart") then
		bindMarble(found)
	end
end)

--[[
	Hovedloop — kører lige før hvert frame tegnes (RenderStepped).
	Her samles input → fysik → kamera i rækkefølge.
]]
RunService.RenderStepped:Connect(function(dt)
	-- Clamp dt: et langt hitch (fx 0.5s) må ikke give kæmpe hop i hastighed/kamera
	dt = math.clamp(dt, 0, 1 / 20)

	updateRawMoveFromKeys() -- WASD → rawMove
	updateCameraFromKeys(dt) -- pile → yaw/pitch
	updateCameraSnapToGoal(dt) -- Enter-snap hvis aktiv

	local ball = marble
	if not ball or not ball.Parent then
		return -- ingen kugle endnu / lige destrueret
	end

	if jumpRequested then
		jumpRequested = false -- clear flag med det samme
		tryJump(ball)
	end

	applySmoothDrive(ball, dt) -- selve arcade-bevægelsen

	local immediate = snapCameraOnce
	snapCameraOnce = false -- kun første frame efter bind
	applyCamera(ball, immediate, dt)
end)
