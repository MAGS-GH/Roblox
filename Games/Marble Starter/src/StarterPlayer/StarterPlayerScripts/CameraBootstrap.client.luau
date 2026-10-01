--[[
	CameraBootstrap.client.luau
	Backup-kamera hvis MarbleControl ikke har bundet marble endnu.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

RunService.RenderStepped:Connect(function()
	local ball = workspace:FindFirstChild(player.Name .. "_Marble")
	if not (ball and ball:IsA("BasePart")) then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam or cam:GetAttribute("MarbleControlActive") == true then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	local pos = ball.Position
	cam.CFrame = CFrame.lookAt(pos + Vector3.new(0, 14, 28), pos + Vector3.new(0, 2, 0))
end)
