--[[
	Hud.client.luau — tid, checkpoints, afstand, debug
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local CourseState = require(Shared:WaitForChild("CourseState"))

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "MarbleHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextStrokeTransparency = 0.45
	t.Font = Enum.Font.GothamMedium
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = gui
	return t
end

makeLabel({
	Name = "Title",
	Position = UDim2.new(0, 24, 0, 24),
	Size = UDim2.new(0, 280, 0, 36),
	Font = Enum.Font.GothamBold,
	TextSize = 28,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.new(1, 1, 1),
	Text = "Marble Run",
})

local timerLabel = makeLabel({
	Name = "Timer",
	Position = UDim2.new(0, 24, 0, 64),
	Size = UDim2.new(0, 220, 0, 28),
	TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(200, 230, 255),
	Text = "Tid: 0:00.0",
})

local checkpointLabel = makeLabel({
	Name = "Checkpoints",
	Position = UDim2.new(0, 24, 0, 96),
	Size = UDim2.new(0, 220, 0, 24),
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = Color3.fromRGB(180, 210, 255),
	Text = "Checkpoint: 0/0",
})

local debugLabel = makeLabel({
	Name = "Debug",
	Position = UDim2.new(0, 24, 0, 128),
	Size = UDim2.new(0, 460, 0, 80),
	Font = Enum.Font.Code,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Color3.fromRGB(160, 255, 160),
	Text = "Debug...",
})

local goalLabel = makeLabel({
	Name = "GoalDistance",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -24, 0, 24),
	Size = UDim2.new(0, 260, 0, 40),
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = Color3.fromRGB(255, 230, 140),
	Text = "Mål: —",
})

makeLabel({
	Name = "Hint",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -20),
	Size = UDim2.new(0.95, 0, 0, 36),
	TextSize = 16,
	TextColor3 = Color3.fromRGB(240, 245, 255),
	Text = "Klik i Client-vinduet · WASD · pile · Space · Enter · R",
})

local banner = makeLabel({
	Name = "Banner",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.35),
	Size = UDim2.new(0.7, 0, 0, 72),
	Font = Enum.Font.GothamBold,
	TextSize = 48,
	TextColor3 = Color3.fromRGB(255, 220, 80),
	TextTransparency = 1,
	Text = "MÅL NÅET!",
})

local function formatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	local secs = seconds - minutes * 60
	return string.format("%d:%04.1f", minutes, secs)
end

local function showBanner(text: string)
	banner.TextTransparency = 0
	banner.Text = text
	task.delay(2.5, function()
		banner.TextTransparency = 1
	end)
end

Remotes.CourseInfo.OnClientEvent:Connect(function(payload)
	CourseState.applyCourseInfo(payload)
	checkpointLabel.Text = string.format("Checkpoint: 0/%d", payload.checkpointCount)
end)

Remotes.CheckpointUpdated.OnClientEvent:Connect(function(index: number, total: number)
	CourseState.setCheckpoint(index)
	checkpointLabel.Text = string.format("Checkpoint: %d/%d", index, total)
	showBanner("Checkpoint " .. index .. "!")
end)

Remotes.RunComplete.OnClientEvent:Connect(function(elapsed: number)
	CourseState.finishRace(elapsed)
	showBanner("MÅL! " .. formatTime(elapsed))
end)

Remotes.GoalReached.OnClientEvent:Connect(function()
	if not CourseState.lastFinishTime then
		showBanner("MÅL NÅET!")
	end
end)

RunService.RenderStepped:Connect(function()
	local elapsed = CourseState.getElapsed()
	if elapsed then
		timerLabel.Text = "Tid: " .. formatTime(elapsed)
	end

	local marbleInst = workspace:FindFirstChild(player.Name .. "_Marble")
	local w = UserInputService:IsKeyDown(Enum.KeyCode.W)
	local a = UserInputService:IsKeyDown(Enum.KeyCode.A)
	local s = UserInputService:IsKeyDown(Enum.KeyCode.S)
	local d = UserInputService:IsKeyDown(Enum.KeyCode.D)

	if marbleInst and marbleInst:IsA("BasePart") then
		local speed = Vector3.new(marbleInst.AssemblyLinearVelocity.X, 0, marbleInst.AssemblyLinearVelocity.Z).Magnitude
		local dist = if CourseState.goalPosition ~= Vector3.zero
			then (CourseState.goalPosition - marbleInst.Position).Magnitude
			else 0
		goalLabel.Text = string.format("Mål: %.0f m", dist)
		debugLabel.Text = string.format(
			"keys W%s A%s S%s D%s\nspeed=%.1f  pos=%.0f,%.0f,%.0f\n(Klik i spilvinduet hvis keys=false)",
			tostring(w),
			tostring(a),
			tostring(s),
			tostring(d),
			speed,
			marbleInst.Position.X,
			marbleInst.Position.Y,
			marbleInst.Position.Z
		)
	else
		debugLabel.Text = "Ingen marble på Client endnu..."
	end
end)
