--[[
	Game.server.luau
	----------------
	Starter-kit til elever:
	- Spawner marble
	- Respawn (R / fald i void)
	- Valgfrit MÅL: lav en Part med Attribute `IsGoal` = true

	I skal IKKE ændre marble-styringen for at bygge en bane —
	byg Parts i Workspace (gerne under StudentCourse/BuildYourCourseHere).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local StartPad = require(script.Parent:WaitForChild("StartPad"))

Players.CharacterAutoLoads = false
pcall(function()
	workspace.StreamingEnabled = false
end)

local spawnAttachment = StartPad.getSpawnAttachment()

local marbles: { [Player]: BasePart } = {}
local finished: { [Player]: boolean } = {}

local function findGoalPart(): BasePart?
	for _, inst in workspace:GetDescendants() do
		if inst:IsA("BasePart") and inst:GetAttribute("IsGoal") == true then
			return inst
		end
	end
	return nil
end

local function sendCourseInfo(player: Player)
	local goal = findGoalPart()
	Remotes.CourseInfo:FireClient(player, {
		goalPosition = if goal then goal.Position else nil,
	})
end

local function createMarble(player: Player)
	local existing = marbles[player]
	if existing then
		existing:Destroy()
	end
	marbles[player] = nil
	finished[player] = false

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

	local spawnPos = spawnAttachment.WorldPosition + Vector3.new(0, diameter * 0.5 + 1, 0)
	marble.CFrame = CFrame.new(spawnPos)
	marble.AssemblyLinearVelocity = Vector3.zero
	marble.AssemblyAngularVelocity = Vector3.zero
	marble.Parent = workspace

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

	pcall(function()
		marble:SetNetworkOwner(player)
	end)

	marbles[player] = marble

	task.defer(function()
		task.wait(0.1)
		if player.Parent and marble.Parent then
			Remotes.AssignMarble:FireClient(player, marble)
			sendCourseInfo(player)
		end
	end)
end

local function setupPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			if character.Parent then
				character:Destroy()
			end
		end)
	end)

	task.defer(function()
		createMarble(player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in Players:GetPlayers() do
	setupPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	if marbles[player] then
		marbles[player]:Destroy()
	end
	marbles[player] = nil
	finished[player] = nil
end)

Remotes.RequestRespawn.OnServerEvent:Connect(function(player)
	createMarble(player)
end)

-- Lyt efter mål-dele elever opretter (Attribute IsGoal = true)
local function bindGoal(part: BasePart)
	part.Touched:Connect(function(hit)
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
		if not owner or finished[owner] then
			return
		end
		finished[owner] = true
		Remotes.GoalReached:FireClient(owner)
		task.delay(Config.Game.RestartDelayAfterGoal, function()
			if owner.Parent then
				createMarble(owner)
			end
		end)
	end)
end

for _, inst in workspace:GetDescendants() do
	if inst:IsA("BasePart") and inst:GetAttribute("IsGoal") == true then
		bindGoal(inst)
	end
end

workspace.DescendantAdded:Connect(function(inst)
	if inst:IsA("BasePart") and inst:GetAttribute("IsGoal") == true then
		bindGoal(inst)
		for _, player in Players:GetPlayers() do
			sendCourseInfo(player)
		end
	end
end)

-- Når elever ændrer IsGoal i Studio under Play (sjældent) — CourseInfo opdateres ved spawn

RunService.Heartbeat:Connect(function()
	for player, marble in marbles do
		if marble.Parent and marble.Position.Y < Config.RespawnY then
			createMarble(player)
		end
	end
end)

print("[Marble Starter] Klar! Byg banen under Workspace → StudentCourse → BuildYourCourseHere")
print("[Marble Starter] Tip: Attribute IsGoal=true på en Part = mål.")
