--[[
	Game.server.luau (server)
	-------------------------
	Spillogik + SERVER-STYRET bevægelse.

	Hvorfor server-styring?
	- Client ApplyImpulse fejler ofte i Studio uden stabil network-owner.
	- Klienten sender kun input (retning + hop); server sætter VectorForce.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CourseBuilder = require(script.Parent:WaitForChild("CourseBuilder"))

Players.CharacterAutoLoads = false

pcall(function()
	workspace.StreamingEnabled = false
end)

local _, spawnAttachment, goalTrigger, checkpoints = CourseBuilder.build()
local goalPosition = goalTrigger.Position
local checkpointCount = #checkpoints

local marbles: { [Player]: BasePart } = {}
local driveForces: { [Player]: VectorForce } = {}
local finished: { [Player]: boolean } = {}
local lastCheckpoint: { [Player]: number } = {}
local runStartedAt: { [Player]: number } = {}

-- Seneste input fra klient (world XZ, already normalized-ish)
local playerMove: { [Player]: Vector3 } = {}
local playerJump: { [Player]: boolean } = {}

local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Exclude

local function getSpawnPosition(player: Player): Vector3
	local cpIndex = lastCheckpoint[player] or 0
	if cpIndex > 0 then
		for _, record in checkpoints do
			if record.index == cpIndex then
				return record.position
			end
		end
	end
	return spawnAttachment.WorldPosition
end

local function sendCourseInfo(player: Player)
	Remotes.CourseInfo:FireClient(player, {
		goalPosition = goalPosition,
		checkpointCount = checkpointCount,
	})
end

local function isGrounded(ball: BasePart): boolean
	groundRay.FilterDescendantsInstances = { ball }
	local radius = ball.Size.Y * 0.5
	local origin = ball.Position
	local direction = Vector3.new(0, -(radius + Config.Marble.GroundCheckPadding), 0)
	if workspace:Raycast(origin, direction, groundRay) then
		return true
	end
	local offsets = {
		Vector3.new(radius * 0.35, 0, 0),
		Vector3.new(-radius * 0.35, 0, 0),
		Vector3.new(0, 0, radius * 0.35),
		Vector3.new(0, 0, -radius * 0.35),
	}
	for _, offset in offsets do
		if workspace:Raycast(origin + offset, direction, groundRay) then
			return true
		end
	end
	return false
end

local function createMarble(player: Player, resetRunTimer: boolean?)
	local existing = marbles[player]
	if existing then
		existing:Destroy()
	end
	marbles[player] = nil
	driveForces[player] = nil
	playerMove[player] = Vector3.zero
	playerJump[player] = false

	local diameter = Config.Marble.Diameter
	local marble = Instance.new("Part")
	marble.Name = player.Name .. "_Marble"
	marble.Shape = Enum.PartType.Ball
	marble.Size = Vector3.new(diameter, diameter, diameter)
	marble.Color = Color3.fromHSV((player.UserId % 1000) / 1000, 0.65, 0.95)
	marble.Material = Enum.Material.SmoothPlastic
	marble.TopSurface = Enum.SurfaceType.Smooth
	marble.BottomSurface = Enum.SurfaceType.Smooth
	marble.CanCollide = true
	marble.Anchored = false
	marble:SetAttribute("IsMarble", true)
	marble.CustomPhysicalProperties = PhysicalProperties.new(
		Config.Marble.Density,
		Config.Marble.Friction,
		Config.Marble.Elasticity,
		1,
		1
	)

	local spawnPos = getSpawnPosition(player)
	local safeSpawn = spawnPos + Vector3.new(0, Config.Marble.Diameter * 0.5 + 2, 0)
	marble.CFrame = CFrame.new(safeSpawn)
	marble.AssemblyLinearVelocity = Vector3.zero
	marble.AssemblyAngularVelocity = Vector3.zero
	marble.Parent = workspace

	-- Drive force (server opdaterer Force hvert Heartbeat)
	local attachment = Instance.new("Attachment")
	attachment.Name = "DriveAttachment"
	attachment.Parent = marble

	local vectorForce = Instance.new("VectorForce")
	vectorForce.Name = "DriveForce"
	vectorForce.Attachment0 = attachment
	vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
	vectorForce.ApplyAtCenterOfMass = true
	vectorForce.Force = Vector3.zero
	vectorForce.Parent = marble

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0
	highlight.FillColor = marble.Color
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = marble

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 28)
	billboard.StudsOffset = Vector3.new(0, diameter * 0.7, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = marble

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Text = player.DisplayName
	nameLabel.Parent = billboard

	-- Klienten ejer fysikken → smooth lokal styring uden netværks-lag
	pcall(function()
		marble:SetNetworkOwner(player)
	end)

	-- DriveForce bruges ikke længere (klient kører velocity-arcade)
	vectorForce.Enabled = false
	vectorForce.Force = Vector3.zero


	marbles[player] = marble
	driveForces[player] = vectorForce
	finished[player] = false

	if resetRunTimer ~= false then
		runStartedAt[player] = os.clock()
	end

	task.defer(function()
		if not player.Parent or marble.Parent == nil then
			return
		end
		task.wait(0.15)
		if player.Parent and marble.Parent then
			Remotes.AssignMarble:FireClient(player, marble)
		end
	end)
end

local function setupPlayer(player: Player)
	sendCourseInfo(player)

	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			if character.Parent then
				character:Destroy()
			end
		end)
	end)

	lastCheckpoint[player] = 0
	task.defer(function()
		createMarble(player, true)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	local marble = marbles[player]
	if marble then
		marble:Destroy()
	end
	marbles[player] = nil
	driveForces[player] = nil
	finished[player] = nil
	lastCheckpoint[player] = nil
	runStartedAt[player] = nil
	playerMove[player] = nil
	playerJump[player] = nil
end)

Remotes.RequestRespawn.OnServerEvent:Connect(function(player)
	createMarble(player, false)
end)

-- Klient sender: moveX, moveZ (world), jump (bool)
Remotes.PlayerInput.OnServerEvent:Connect(function(player, moveX, moveZ, jump)
	if typeof(moveX) ~= "number" or typeof(moveZ) ~= "number" then
		return
	end
	if not marbles[player] then
		return
	end

	-- Clamp for at undgå exploit / NaN
	if moveX ~= moveX or moveZ ~= moveZ then
		return
	end
	moveX = math.clamp(moveX, -1, 1)
	moveZ = math.clamp(moveZ, -1, 1)

	local move = Vector3.new(moveX, 0, moveZ)
	if move.Magnitude > 1 then
		move = move.Unit
	elseif move.Magnitude < 0.05 then
		move = Vector3.zero
	end
	playerMove[player] = move
	if jump == true then
		playerJump[player] = true
	end
end)

local courseFolder = workspace:WaitForChild("MarbleCourse")
for _, desc in courseFolder:GetDescendants() do
	if desc:IsA("BasePart") and desc:GetAttribute("CheckpointIndex") then
		local cpIndex = desc:GetAttribute("CheckpointIndex") :: number
		desc.Touched:Connect(function(hit)
			if hit:GetAttribute("IsMarble") ~= true then
				return
			end
			local owner: Player? = nil
			for p, marble in marbles do
				if marble == hit then
					owner = p
					break
				end
			end
			if not owner then
				return
			end
			local current = lastCheckpoint[owner] or 0
			if cpIndex <= current then
				return
			end
			lastCheckpoint[owner] = cpIndex
			Remotes.CheckpointUpdated:FireClient(owner, cpIndex, checkpointCount)
		end)
	end
end

goalTrigger.Touched:Connect(function(hit)
	if hit:GetAttribute("IsMarble") ~= true then
		return
	end
	local owner: Player? = nil
	for p, marble in marbles do
		if hit == marble then
			owner = p
			break
		end
	end
	if not owner or finished[owner] then
		return
	end

	finished[owner] = true
	local started = runStartedAt[owner] or os.clock()
	local elapsed = os.clock() - started

	Remotes.RunComplete:FireClient(owner, elapsed)
	Remotes.GoalReached:FireClient(owner)

	task.delay(Config.Game.RestartDelayAfterGoal, function()
		if owner.Parent then
			lastCheckpoint[owner] = 0
			createMarble(owner, true)
		end
	end)
end)

RunService.Heartbeat:Connect(function()
	for player, marble in marbles do
		if not marble.Parent then
			continue
		end

		if marble.Position.Y < Config.RespawnY then
			createMarble(player, false)
			continue
		end

		-- Bevægelse styres lokalt på klienten (smooth arcade).
		-- Hold evt. legacy VectorForce slået fra.
		local forceObj = driveForces[player]
		if forceObj then
			forceObj.Enabled = false
			forceObj.Force = Vector3.zero
		end

		-- Hop kan stadig komme via remote (backup) — primært håndteres på klient
		if playerJump[player] then
			playerJump[player] = false
			if isGrounded(marble) then
				local velocity = marble.AssemblyLinearVelocity
				if velocity.Y <= 8 then
					marble.AssemblyLinearVelocity =
						Vector3.new(velocity.X, Config.Marble.JumpSpeed, velocity.Z)
				end
			end
		end
	end
end)
