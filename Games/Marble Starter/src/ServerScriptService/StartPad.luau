--[[
	StartPad.luau
	-------------
	Kun UI-tekst på START/MÅL — banen ligger som Parts i Workspace (redigér dem i Studio).
]]

local StartPad = {}

local function ensureLabel(part: BasePart, text: string, color: Color3)
	if part:FindFirstChildWhichIsA("SurfaceGui") then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 14
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.45
	label.Text = text
	label.Parent = gui
end

function StartPad.getSpawnAttachment(): Attachment
	local course = workspace:WaitForChild("StudentCourse")
	local pad = course:WaitForChild("StartPad") :: BasePart
	ensureLabel(pad, "START\nFølg den smalle sti →", Color3.new(1, 1, 1))

	local goal = course:FindFirstChild("GoalPad")
	if goal and goal:IsA("BasePart") then
		-- Sikkerhed: markér som mål (hvis attribute mangler i place-filen)
		goal:SetAttribute("IsGoal", true)
		ensureLabel(goal, "MÅL!", Color3.fromRGB(40, 28, 8))

		local beacon = course:FindFirstChild("GoalBeacon")
		if beacon and beacon:IsA("BasePart") and not beacon:FindFirstChildWhichIsA("PointLight") then
			local light = Instance.new("PointLight")
			light.Brightness = 4
			light.Range = 140
			light.Color = Color3.fromRGB(255, 220, 100)
			light.Parent = beacon
		end
	end

	local spawn = pad:FindFirstChild("Spawn")
	if spawn and spawn:IsA("Attachment") then
		return spawn
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "Spawn"
	attachment.Position = Vector3.new(0, 6, 0)
	attachment.Parent = pad
	return attachment
end

return StartPad
