--[[
	Hud.client.luau — enkel hjælpetekst til elever
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "MarbleStarterHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 24, 0, 24)
title.Size = UDim2.new(0, 360, 0, 36)
title.Font = Enum.Font.GothamBold
title.TextSize = 26
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.new(1, 1, 1)
title.TextStrokeTransparency = 0.4
title.Text = "Marble Starter"
title.Parent = gui

local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -20)
hint.Size = UDim2.new(0.95, 0, 0, 50)
hint.Font = Enum.Font.GothamMedium
hint.TextSize = 16
hint.TextColor3 = Color3.fromRGB(240, 245, 255)
hint.TextStrokeTransparency = 0.45
hint.Text =
	"WASD · pile · Space · R · Enter = MÅL\nStien er Parts i StudentCourse — redigér dem i Studio!"
hint.Parent = gui

local banner = Instance.new("TextLabel")
banner.BackgroundTransparency = 1
banner.AnchorPoint = Vector2.new(0.5, 0.5)
banner.Position = UDim2.fromScale(0.5, 0.35)
banner.Size = UDim2.new(0.7, 0, 0, 64)
banner.Font = Enum.Font.GothamBold
banner.TextSize = 42
banner.TextColor3 = Color3.fromRGB(255, 220, 80)
banner.TextStrokeTransparency = 0.3
banner.TextTransparency = 1
banner.Text = "MÅL NÅET!"
banner.Parent = gui

Remotes.GoalReached.OnClientEvent:Connect(function()
	banner.TextTransparency = 0
	task.delay(2.2, function()
		banner.TextTransparency = 1
	end)
end)
