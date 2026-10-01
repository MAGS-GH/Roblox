--[[
	CameraBootstrap.client.luau
	---------------------------
	Minimal kamera-script UDEN require/remotes.
	Sikrer at Client-fanen ikke sidder fast på blå himmel, hvis andre scripts fejler
	eller Streaming/Character mangler.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local function followMarble()
	local ball = workspace:FindFirstChild(player.Name .. "_Marble")
	if not (ball and ball:IsA("BasePart")) then
		return
	end

	local cam = workspace.CurrentCamera
	if not cam then
		return
	end

	-- Hvis MarbleControl allerede styrer kameraet, lader det gøre det
	if cam:GetAttribute("MarbleControlActive") == true then
		return
	end

	cam.CameraType = Enum.CameraType.Scriptable
	local pos = ball.Position
	cam.CFrame = CFrame.lookAt(pos + Vector3.new(0, 14, 28), pos + Vector3.new(0, 2, 0))
end

RunService.RenderStepped:Connect(followMarble)
