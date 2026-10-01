--[[
	CourseBuilder.luau
	------------------
	Ren, sammenhængende bane (ingen overlap-rod).
	Højder = gulv-TOP. Segmenter overlapper lidt i enderne.
	Mange stabile bevægelige forhindringer via ObstacleEngine.
]]

local ObstacleEngine = require(script.Parent:WaitForChild("ObstacleEngine"))

export type CheckpointRecord = {
	index: number,
	position: Vector3,
}

local CourseBuilder = {}

local FLOOR = 2
local WALL_T = 1.5
local WALL_H = 6
local TRACK = 20
local OVERLAP = 2

local GRASS = Color3.fromRGB(92, 148, 98)
local GRASS_DARK = Color3.fromRGB(78, 128, 88)
local WOOD = Color3.fromRGB(158, 118, 72)
local PLANKS = Color3.fromRGB(170, 135, 85)
local STONE = Color3.fromRGB(112, 118, 128)
local CONCRETE = Color3.fromRGB(130, 136, 142)
local ACCENT = Color3.fromRGB(70, 88, 110)
local GOAL_COLOR = Color3.fromRGB(236, 196, 64)
local START_COLOR = Color3.fromRGB(72, 168, 118)

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Name = props.Name or "Part"
	p.Anchored = true
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color or GRASS
	p.Material = props.Material or Enum.Material.Grass
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Transparency = props.Transparency or 0
	p.Parent = parent
	return p
end

local function wall(parent: Instance, size: Vector3, cf: CFrame): Part
	return part(parent, {
		Name = "Wall",
		Size = size,
		CFrame = cf,
		Color = ACCENT,
		Material = Enum.Material.Slate,
	})
end

local function label(parent: BasePart, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 16
	gui.Parent = parent
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.5
	t.Text = text
	t.Parent = gui
end

local function floorBox(parent, name, cx, cz, sx, sz, topY, color, material)
	return part(parent, {
		Name = name,
		Size = Vector3.new(sx, FLOOR, sz),
		CFrame = CFrame.new(cx, topY - FLOOR / 2, cz),
		Color = color or GRASS,
		Material = material or Enum.Material.Grass,
	})
end

local function rampX(parent, name, x0, x1, z, width, y0, y1, color, material)
	local dx, dy = x1 - x0, y1 - y0
	local dist = math.sqrt(dx * dx + dy * dy)
	local angle = math.atan2(dy, dx)
	local mid = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, z)
	local cf = CFrame.new(mid) * CFrame.Angles(0, 0, angle) * CFrame.new(0, -FLOOR / 2, 0)
	return part(parent, {
		Name = name,
		Size = Vector3.new(dist, FLOOR, width),
		CFrame = cf,
		Color = color or PLANKS,
		Material = material or Enum.Material.WoodPlanks,
	})
end

local function wallsAlongZ(parent, cx, zMid, length, topY, trackWidth)
	local wallY = topY + WALL_H / 2
	wall(parent, Vector3.new(WALL_T, WALL_H, length), CFrame.new(cx - trackWidth / 2 - WALL_T / 2, wallY, zMid))
	wall(parent, Vector3.new(WALL_T, WALL_H, length), CFrame.new(cx + trackWidth / 2 + WALL_T / 2, wallY, zMid))
end

local function wallsAlongX(parent, cz, xMid, length, topY, trackWidth)
	local wallY = topY + WALL_H / 2
	wall(parent, Vector3.new(length, WALL_H, WALL_T), CFrame.new(xMid, wallY, cz - trackWidth / 2 - WALL_T / 2))
	wall(parent, Vector3.new(length, WALL_H, WALL_T), CFrame.new(xMid, wallY, cz + trackWidth / 2 + WALL_T / 2))
end

local function rampWallsX(parent, x0, x1, z, trackWidth, y0, y1)
	local dx, dy = x1 - x0, y1 - y0
	local dist = math.sqrt(dx * dx + dy * dy)
	local angle = math.atan2(dy, dx)
	local mid = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, z)
	local base = CFrame.new(mid) * CFrame.Angles(0, 0, angle)
	local side = trackWidth / 2 + WALL_T / 2
	wall(parent, Vector3.new(dist, WALL_H, WALL_T), base * CFrame.new(0, WALL_H / 2, -side))
	wall(parent, Vector3.new(dist, WALL_H, WALL_T), base * CFrame.new(0, WALL_H / 2, side))
end

local function plazaWalls(parent, cx, cz, sx, sz, topY, open)
	local wallY = topY + WALL_H / 2
	local hx, hz = sx / 2, sz / 2
	local gap = TRACK / 2

	local function edge(full: boolean, isX: boolean, sign: number, midShift: number)
		if full then
			if isX then
				wall(parent, Vector3.new(sx + WALL_T, WALL_H, WALL_T), CFrame.new(cx, wallY, cz + sign * (hz + WALL_T / 2)))
			else
				wall(parent, Vector3.new(WALL_T, WALL_H, sz + WALL_T), CFrame.new(cx + sign * (hx + WALL_T / 2), wallY, cz))
			end
		else
			local side = (if isX then hx else hz) - gap
			if side > 1 then
				if isX then
					wall(parent, Vector3.new(side, WALL_H, WALL_T), CFrame.new(cx - gap - side / 2, wallY, cz + sign * (hz + WALL_T / 2)))
					wall(parent, Vector3.new(side, WALL_H, WALL_T), CFrame.new(cx + gap + side / 2, wallY, cz + sign * (hz + WALL_T / 2)))
				else
					wall(parent, Vector3.new(WALL_T, WALL_H, side), CFrame.new(cx + sign * (hx + WALL_T / 2), wallY, cz - gap - side / 2))
					wall(parent, Vector3.new(WALL_T, WALL_H, side), CFrame.new(cx + sign * (hx + WALL_T / 2), wallY, cz + gap + side / 2))
				end
			end
		end
	end

	edge(not open.north, true, -1, 0)
	edge(not open.south, true, 1, 0)
	edge(not open.west, false, -1, 0)
	edge(not open.east, false, 1, 0)
end

local function addCheckpoint(parent, index, cx, cz, topY, checkpoints)
	local pad = floorBox(parent, "Checkpoint_" .. index, cx, cz, 16, 16, topY, Color3.fromRGB(80, 160, 220), Enum.Material.Neon)
	label(pad, "CP " .. index, Color3.fromRGB(255, 255, 255))
	local trigger = part(parent, {
		Name = "CheckpointTrigger",
		Size = Vector3.new(14, 8, 14),
		CFrame = CFrame.new(cx, topY + 4, cz),
		Transparency = 1,
		CanCollide = false,
	})
	trigger:SetAttribute("CheckpointIndex", index)
	table.insert(checkpoints, { index = index, position = Vector3.new(cx, topY + 5, cz) })
end

function CourseBuilder.build(): (Folder, Attachment, BasePart, { CheckpointRecord })
	local folder = Instance.new("Folder")
	folder.Name = "MarbleCourse"
	folder.Parent = workspace
	local checkpoints: { CheckpointRecord } = {}

	local H0 = 4

	----------------------------------------------------------------
	-- 1 START
	----------------------------------------------------------------
	local start = floorBox(folder, "StartPad", 0, 0, 44, 44, H0, START_COLOR, Enum.Material.Grass)
	label(start, "START", Color3.new(1, 1, 1))
	plazaWalls(folder, 0, 0, 44, 44, H0, { south = true })
	local spawnAttachment = Instance.new("Attachment")
	spawnAttachment.Name = "Spawn"
	spawnAttachment.Position = Vector3.new(0, 7, 0)
	spawnAttachment.Parent = start

	----------------------------------------------------------------
	-- 2 INTRO (+Z) — rolige platforme der glider sideværts
	----------------------------------------------------------------
	local z = 22
	local introLen = 70
	floorBox(folder, "Intro", 0, z + introLen / 2, TRACK, introLen, H0, GRASS)
	wallsAlongZ(folder, 0, z + introLen / 2, introLen, H0, TRACK)

	for i = 1, 3 do
		local pz = z + 18 + (i - 1) * 18
		-- Intro: safe orange platforms (ikke lethal)
		ObstacleEngine.addSlidingPlatform(
			folder,
			CFrame.new(0, H0 + 1.2, pz),
			Vector3.new(7, 1.5, 7),
			Vector3.xAxis,
			7,
			1.5 + i * 0.2,
			i * 1.1,
			Color3.fromRGB(230, 140, 60),
			false
		)
	end
	-- Ét kill-blade midt i intro
	ObstacleEngine.addSpinner(folder, Vector3.new(0, H0 + 3.5, z + 40), 9, 5, 2.4, 0.2, true)
	z += introLen - OVERLAP

	addCheckpoint(folder, 1, 0, z + 10, H0, checkpoints)
	floorBox(folder, "CP1Plaza", 0, z + 12, 36, 28, H0, GRASS_DARK)
	plazaWalls(folder, 0, z + 12, 36, 28, H0, { north = true, south = true })
	z += 26

	----------------------------------------------------------------
	-- 3 VOID + GLIDENDE PLATFORME (rigtigt hul — to canyon-stykker)
	----------------------------------------------------------------
	local beforeLen = 40
	floorBox(folder, "CanyonA", 0, z + beforeLen / 2, TRACK, beforeLen, H0, STONE, Enum.Material.Slate)
	wallsAlongZ(folder, 0, z + beforeLen / 2, beforeLen, H0, TRACK)
	z += beforeLen

	local gapLen = 56
	local gapMid = z + gapLen / 2
	part(folder, {
		Name = "VoidHint",
		Size = Vector3.new(TRACK + 4, 1, gapLen),
		CFrame = CFrame.new(0, H0 - 8, gapMid),
		Color = Color3.fromRGB(25, 28, 35),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Transparency = 0.35,
	})
	wallsAlongZ(folder, 0, gapMid, gapLen, H0, TRACK)

	-- Kun 3 stepping stones (sværere timing) + kill-spinner
	for i = 1, 3 do
		local t = (i - 0.5) / 3
		local pz = z + t * gapLen
		local axis = if i % 2 == 1 then Vector3.xAxis else Vector3.zAxis
		ObstacleEngine.addSlidingPlatform(
			folder,
			CFrame.new(0, H0, pz),
			Vector3.new(9, 2, 9),
			axis,
			6.5,
			1.4 + i * 0.25,
			i * 0.9,
			Color3.fromRGB(255, 150, 70),
			false
		)
	end
	ObstacleEngine.addSpinner(folder, Vector3.new(0, H0 + 3.5, gapMid), 12, 5, 2.2, 0.3, true)
	ObstacleEngine.addSwingingHammer(folder, Vector3.new(0, H0 + 15, gapMid + 10), 13, 1.8, 60, 0.5, true)
	z += gapLen

	local afterLen = 35
	floorBox(folder, "CanyonB", 0, z + afterLen / 2, TRACK, afterLen, H0, STONE, Enum.Material.Slate)
	wallsAlongZ(folder, 0, z + afterLen / 2, afterLen, H0, TRACK)
	z += afterLen - OVERLAP

	----------------------------------------------------------------
	-- 4 TURN EAST (+X)
	----------------------------------------------------------------
	floorBox(folder, "Turn1", 16, z + 18, 52, 40, H0, GRASS_DARK)
	plazaWalls(folder, 16, z + 18, 52, 40, H0, { north = true, east = true })
	local turnZ = z + 18
	local x = 16 + 26 - OVERLAP

	----------------------------------------------------------------
	-- 5 HAMMER ALLEY (+X)
	----------------------------------------------------------------
	local alleyLen = 140
	floorBox(folder, "HammerAlley", x + alleyLen / 2, turnZ, alleyLen, TRACK, H0, CONCRETE, Enum.Material.Concrete)
	wallsAlongX(folder, turnZ, x + alleyLen / 2, alleyLen, H0, TRACK)

	-- 7 lethale hamre
	for i = 1, 7 do
		local px = x + 14 + (i - 1) * 17
		ObstacleEngine.addSwingingHammer(
			folder,
			Vector3.new(px, H0 + 14, turnZ),
			12,
			1.7 + i * 0.1,
			62,
			i * 0.55,
			true
		)
	end
	-- Glidende KILL-crushers på gulvet
	for i = 1, 4 do
		local px = x + 22 + (i - 1) * 28
		ObstacleEngine.addSlidingPlatform(
			folder,
			CFrame.new(px, H0 + 2.2, turnZ),
			Vector3.new(5, 4, 5),
			Vector3.zAxis,
			6,
			2.0,
			i * 0.8,
			nil,
			true
		)
	end
	x += alleyLen - OVERLAP

	addCheckpoint(folder, 2, x + 14, turnZ, H0, checkpoints)
	floorBox(folder, "CP2Plaza", x + 16, turnZ, 36, 36, H0, STONE, Enum.Material.Concrete)
	plazaWalls(folder, x + 16, turnZ, 36, 36, H0, { west = true, east = true })
	x += 34

	----------------------------------------------------------------
	-- 6 ELEVATOR TOWER (+X climb via rising pads + ramp)
	----------------------------------------------------------------
	local H1 = 28
	-- Solid climb ramp (stable)
	local climbLen = 70
	rampX(folder, "ClimbRamp", x, x + climbLen, turnZ, TRACK, H0, H1, PLANKS)
	rampWallsX(folder, x, x + climbLen, turnZ, TRACK, H0, H1)

	-- Side elevators as optional hard path / hazard near mid
	for i = 1, 3 do
		local px = x + 18 + (i - 1) * 16
		ObstacleEngine.addElevator(
			folder,
			CFrame.new(px, H0 + 4 + (i - 1) * 3, turnZ + TRACK / 2 + 6),
			Vector3.new(8, 1.5, 8),
			5,
			1.1,
			i * 0.9
		)
	end
	x += climbLen - OVERLAP

	floorBox(folder, "SkyPlaza", x + 22, turnZ, 48, 48, H1, CONCRETE, Enum.Material.Concrete)
	plazaWalls(folder, x + 22, turnZ, 48, 48, H1, { west = true, south = true })
	addCheckpoint(folder, 3, x + 22, turnZ, H1, checkpoints)
	local skyCX, skyCZ = x + 22, turnZ
	x = skyCX -- continue from plaza center for naming; actual leave south

	----------------------------------------------------------------
	-- 7 HIGH ROAD (+Z) with moving side-crushers + spinner
	----------------------------------------------------------------
	local highZ0 = skyCZ + 24 - OVERLAP
	local highLen = 90
	floorBox(folder, "HighRoad", skyCX, highZ0 + highLen / 2, TRACK, highLen, H1, CONCRETE, Enum.Material.Concrete)
	wallsAlongZ(folder, skyCX, highZ0 + highLen / 2, highLen, H1, TRACK)

	for i = 1, 5 do
		local pz = highZ0 + 12 + (i - 1) * 15
		-- Side-crushers = KILL
		ObstacleEngine.addSlidingPlatform(
			folder,
			CFrame.new(skyCX, H1 + 2.5, pz),
			Vector3.new(5, 5, 3.5),
			Vector3.xAxis,
			8,
			2.2,
			i * 1.1,
			nil,
			true
		)
	end
	ObstacleEngine.addSpinner(folder, Vector3.new(skyCX, H1 + 4, highZ0 + highLen / 2), 14, 6, 2.6, 0.5, true)
	ObstacleEngine.addSpinner(folder, Vector3.new(skyCX, H1 + 4, highZ0 + highLen * 0.75), 10, 5, 2.8, 1.2, true)
	ObstacleEngine.addIceStrip(
		folder,
		CFrame.new(skyCX, H1 - 1, highZ0 + highLen * 0.65),
		Vector3.new(TRACK - 4, FLOOR, 36)
	)

	local highZ1 = highZ0 + highLen - OVERLAP

	----------------------------------------------------------------
	-- 8 NARROW BRIDGE with swinging hammers
	----------------------------------------------------------------
	floorBox(folder, "BridgePlaza", skyCX, highZ1 + 16, 36, 36, H1, WOOD, Enum.Material.Wood)
	plazaWalls(folder, skyCX, highZ1 + 16, 36, 36, H1, { north = true, south = true })

	local bridgeZ0 = highZ1 + 16 + 18 - OVERLAP
	local bridgeW = 9
	local bridgeLen = 110
	floorBox(folder, "Bridge", skyCX, bridgeZ0 + bridgeLen / 2, bridgeW, bridgeLen, H1, WOOD, Enum.Material.Wood)
	for i = 1, 6 do
		local pz = bridgeZ0 + 14 + (i - 1) * 16
		ObstacleEngine.addSwingingHammer(
			folder,
			Vector3.new(skyCX, H1 + 13, pz),
			11,
			1.8 + i * 0.12,
			58,
			i * 0.7,
			true
		)
	end
	local bridgeZ1 = bridgeZ0 + bridgeLen - OVERLAP

	----------------------------------------------------------------
	-- 9 LANDING + DESCENT
	----------------------------------------------------------------
	floorBox(folder, "Landing", skyCX, bridgeZ1 + 18, 40, 40, H1, CONCRETE, Enum.Material.Concrete)
	plazaWalls(folder, skyCX, bridgeZ1 + 18, 40, 40, H1, { north = true, east = true })
	addCheckpoint(folder, 4, skyCX, bridgeZ1 + 18, H1, checkpoints)

	local H2 = 10
	local landCZ = bridgeZ1 + 18
	local descX0 = skyCX + 20 - OVERLAP
	local descX1 = descX0 + 50
	rampX(folder, "Descend", descX0, descX1, landCZ, TRACK, H1, H2, PLANKS)
	rampWallsX(folder, descX0, descX1, landCZ, TRACK, H1, H2)

	----------------------------------------------------------------
	-- 10 FINAL GAUNTLET (+X) — elevators + spinners + bounce
	----------------------------------------------------------------
	local finX0 = descX1 - OVERLAP
	local finLen = 130
	floorBox(folder, "Final", finX0 + finLen / 2, landCZ, finLen, TRACK, H2, GRASS)
	wallsAlongX(folder, landCZ, finX0 + finLen / 2, finLen, H2, TRACK)

	for i = 1, 5 do
		local px = finX0 + 16 + (i - 1) * 20
		ObstacleEngine.addElevator(
			folder,
			CFrame.new(px, H2 + 1, landCZ),
			Vector3.new(8, 1.5, 8),
			4.5,
			1.6,
			i * 0.5,
			Color3.fromRGB(90, 170, 220),
			false
		)
		ObstacleEngine.addSpinner(folder, Vector3.new(px + 9, H2 + 4, landCZ), 10, 5, 2.8, i, true)
	end
	-- Lethal floor crushers
	for i = 1, 3 do
		local px = finX0 + 30 + (i - 1) * 32
		ObstacleEngine.addSlidingPlatform(
			folder,
			CFrame.new(px, H2 + 2, landCZ),
			Vector3.new(4, 4, 4),
			Vector3.zAxis,
			7,
			2.4,
			i,
			nil,
			true
		)
	end
	ObstacleEngine.addBouncePad(folder, CFrame.new(finX0 + 55, H2 + 0.8, landCZ), Vector3.new(9, 1.2, 9))
	ObstacleEngine.addIceStrip(
		folder,
		CFrame.new(finX0 + 95, H2 - 1, landCZ),
		Vector3.new(45, FLOOR, TRACK - 4)
	)

	local finX1 = finX0 + finLen - OVERLAP
	floorBox(folder, "PreGoal", finX1 + 18, landCZ, 40, 40, H2, GRASS_DARK)
	plazaWalls(folder, finX1 + 18, landCZ, 40, 40, H2, { west = true, south = true })
	addCheckpoint(folder, 5, finX1 + 18, landCZ, H2, checkpoints)

	local approachZ0 = landCZ + 20 - OVERLAP
	local approachLen = 55
	floorBox(folder, "GoalApproach", finX1 + 18, approachZ0 + approachLen / 2, TRACK, approachLen, H2, GRASS)
	wallsAlongZ(folder, finX1 + 18, approachZ0 + approachLen / 2, approachLen, H2, TRACK)

	-- Sidste kill-spinner før mål
	ObstacleEngine.addSpinner(folder, Vector3.new(finX1 + 18, H2 + 4, approachZ0 + 28), 11, 5, 2.5, 0.4, true)
	ObstacleEngine.addSlidingPlatform(
		folder,
		CFrame.new(finX1 + 18, H2 + 1, approachZ0 + 40),
		Vector3.new(7, 1.5, 7),
		Vector3.xAxis,
		6.5,
		2.0,
		0.2,
		Color3.fromRGB(230, 140, 60),
		false
	)

	----------------------------------------------------------------
	-- 11 GOAL
	----------------------------------------------------------------
	local goalCX = finX1 + 18
	local goalCZ = approachZ0 + approachLen + 18 - OVERLAP
	local goalPad = floorBox(folder, "GoalPad", goalCX, goalCZ, 40, 40, H2, GOAL_COLOR, Enum.Material.Neon)
	label(goalPad, "MÅL!", Color3.fromRGB(40, 28, 8))
	plazaWalls(folder, goalCX, goalCZ, 40, 40, H2, { north = true })

	local goal = part(folder, {
		Name = "GoalTrigger",
		Size = Vector3.new(26, 12, 26),
		CFrame = CFrame.new(goalCX, H2 + 6, goalCZ),
		Transparency = 1,
		CanCollide = false,
	})
	goal:SetAttribute("IsGoal", true)

	local light = Instance.new("PointLight")
	light.Brightness = 2.5
	light.Range = 45
	light.Color = Color3.fromRGB(255, 220, 120)
	light.Parent = goalPad

	ObstacleEngine.bindBouncePads(folder)
	ObstacleEngine.start()

	return folder, spawnAttachment, goal, checkpoints
end

return CourseBuilder
