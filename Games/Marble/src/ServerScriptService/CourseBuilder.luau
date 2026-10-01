--[[
	Marble course builder.
	Heights are FLOOR TOP (surface the marble rolls on).
	Segments overlap slightly so seams never leave gaps.
]]

local ObstacleEngine = require(script.Parent:WaitForChild("ObstacleEngine"))

export type CheckpointRecord = {
	index: number,
	position: Vector3,
}

local CourseBuilder = {}

local FLOOR = 2
local WALL_T = 1.5
local WALL_H = 7
local TRACK = 22
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

local function part(
	parent: Instance,
	props: {
		Name: string?,
		Size: Vector3,
		CFrame: CFrame,
		Color: Color3?,
		Material: Enum.Material?,
		Transparency: number?,
		CanCollide: boolean?,
	}
): Part
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

local function wall(parent: Instance, size: Vector3, cf: CFrame, color: Color3?): Part
	return part(parent, {
		Name = "Wall",
		Size = size,
		CFrame = cf,
		Color = color or ACCENT,
		Material = Enum.Material.Slate,
	})
end

local function label(parent: BasePart, text: string, color: Color3, studs: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = studs or 18
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

-- Floor whose TOP surface is at height `topY`
local function floorBox(
	parent: Instance,
	name: string,
	cx: number,
	cz: number,
	sx: number,
	sz: number,
	topY: number,
	color: Color3?,
	material: Enum.Material?
): Part
	return part(parent, {
		Name = name,
		Size = Vector3.new(sx, FLOOR, sz),
		CFrame = CFrame.new(cx, topY - FLOOR / 2, cz),
		Color = color or GRASS,
		Material = material or Enum.Material.Grass,
	})
end

-- Ramp along +X: top surface from (x0, y0) to (x1, y1) at fixed z
local function rampX(
	parent: Instance,
	name: string,
	x0: number,
	x1: number,
	z: number,
	width: number,
	y0: number,
	y1: number,
	color: Color3?,
	material: Enum.Material?
): Part
	local dx = x1 - x0
	local dy = y1 - y0
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

-- Ramp along +Z: top surface from (z0, y0) to (z1, y1) at fixed x
local function rampZ(
	parent: Instance,
	name: string,
	z0: number,
	z1: number,
	x: number,
	width: number,
	y0: number,
	y1: number,
	color: Color3?,
	material: Enum.Material?
): Part
	local dz = z1 - z0
	local dy = y1 - y0
	local dist = math.sqrt(dz * dz + dy * dy)
	local angle = math.atan2(dy, dz)
	local mid = Vector3.new(x, (y0 + y1) / 2, (z0 + z1) / 2)
	local cf = CFrame.new(mid) * CFrame.Angles(-angle, 0, 0) * CFrame.new(0, -FLOOR / 2, 0)
	return part(parent, {
		Name = name,
		Size = Vector3.new(width, FLOOR, dist),
		CFrame = cf,
		Color = color or PLANKS,
		Material = material or Enum.Material.WoodPlanks,
	})
end

local function wallsAlongZ(parent: Instance, cx: number, zMid: number, length: number, topY: number, trackWidth: number)
	local wallY = topY + WALL_H / 2
	local xL = cx - trackWidth / 2 - WALL_T / 2
	local xR = cx + trackWidth / 2 + WALL_T / 2
	wall(parent, Vector3.new(WALL_T, WALL_H, length), CFrame.new(xL, wallY, zMid))
	wall(parent, Vector3.new(WALL_T, WALL_H, length), CFrame.new(xR, wallY, zMid))
end

local function wallsAlongX(parent: Instance, cz: number, xMid: number, length: number, topY: number, trackWidth: number)
	local wallY = topY + WALL_H / 2
	local zL = cz - trackWidth / 2 - WALL_T / 2
	local zR = cz + trackWidth / 2 + WALL_T / 2
	wall(parent, Vector3.new(length, WALL_H, WALL_T), CFrame.new(xMid, wallY, zL))
	wall(parent, Vector3.new(length, WALL_H, WALL_T), CFrame.new(xMid, wallY, zR))
end

-- Walls on a ramp along X (same angle as floor)
local function rampWallsX(
	parent: Instance,
	x0: number,
	x1: number,
	z: number,
	trackWidth: number,
	y0: number,
	y1: number
)
	local dx = x1 - x0
	local dy = y1 - y0
	local dist = math.sqrt(dx * dx + dy * dy)
	local angle = math.atan2(dy, dx)
	local mid = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, z)
	local base = CFrame.new(mid) * CFrame.Angles(0, 0, angle)
	local xL = -trackWidth / 2 - WALL_T / 2
	local xR = trackWidth / 2 + WALL_T / 2
	-- Local: X along ramp, Y up from surface, Z sideways
	wall(parent, Vector3.new(dist, WALL_H, WALL_T), base * CFrame.new(0, WALL_H / 2, xL))
	wall(parent, Vector3.new(dist, WALL_H, WALL_T), base * CFrame.new(0, WALL_H / 2, xR))
end

local function rampWallsZ(
	parent: Instance,
	z0: number,
	z1: number,
	x: number,
	trackWidth: number,
	y0: number,
	y1: number
)
	local dz = z1 - z0
	local dy = y1 - y0
	local dist = math.sqrt(dz * dz + dy * dy)
	local angle = math.atan2(dy, dz)
	local mid = Vector3.new(x, (y0 + y1) / 2, (z0 + z1) / 2)
	local base = CFrame.new(mid) * CFrame.Angles(-angle, 0, 0)
	local xL = -trackWidth / 2 - WALL_T / 2
	local xR = trackWidth / 2 + WALL_T / 2
	wall(parent, Vector3.new(WALL_T, WALL_H, dist), base * CFrame.new(xL, WALL_H / 2, 0))
	wall(parent, Vector3.new(WALL_T, WALL_H, dist), base * CFrame.new(xR, WALL_H / 2, 0))
end

local function plazaWalls(
	parent: Instance,
	cx: number,
	cz: number,
	sx: number,
	sz: number,
	topY: number,
	open: { north: boolean?, south: boolean?, east: boolean?, west: boolean? }
)
	-- north = -Z, south = +Z, west = -X, east = +X
	local wallY = topY + WALL_H / 2
	local halfX = sx / 2
	local halfZ = sz / 2

	if not open.north then
		wall(parent, Vector3.new(sx + WALL_T, WALL_H, WALL_T), CFrame.new(cx, wallY, cz - halfZ - WALL_T / 2))
	else
		-- side stubs leaving a TRACK-wide gap
		local gap = TRACK / 2
		local side = halfX - gap
		if side > 1 then
			wall(parent, Vector3.new(side, WALL_H, WALL_T), CFrame.new(cx - gap - side / 2, wallY, cz - halfZ - WALL_T / 2))
			wall(parent, Vector3.new(side, WALL_H, WALL_T), CFrame.new(cx + gap + side / 2, wallY, cz - halfZ - WALL_T / 2))
		end
	end

	if not open.south then
		wall(parent, Vector3.new(sx + WALL_T, WALL_H, WALL_T), CFrame.new(cx, wallY, cz + halfZ + WALL_T / 2))
	else
		local gap = TRACK / 2
		local side = halfX - gap
		if side > 1 then
			wall(parent, Vector3.new(side, WALL_H, WALL_T), CFrame.new(cx - gap - side / 2, wallY, cz + halfZ + WALL_T / 2))
			wall(parent, Vector3.new(side, WALL_H, WALL_T), CFrame.new(cx + gap + side / 2, wallY, cz + halfZ + WALL_T / 2))
		end
	end

	if not open.west then
		wall(parent, Vector3.new(WALL_T, WALL_H, sz + WALL_T), CFrame.new(cx - halfX - WALL_T / 2, wallY, cz))
	else
		local gap = TRACK / 2
		local side = halfZ - gap
		if side > 1 then
			wall(parent, Vector3.new(WALL_T, WALL_H, side), CFrame.new(cx - halfX - WALL_T / 2, wallY, cz - gap - side / 2))
			wall(parent, Vector3.new(WALL_T, WALL_H, side), CFrame.new(cx - halfX - WALL_T / 2, wallY, cz + gap + side / 2))
		end
	end

	if not open.east then
		wall(parent, Vector3.new(WALL_T, WALL_H, sz + WALL_T), CFrame.new(cx + halfX + WALL_T / 2, wallY, cz))
	else
		local gap = TRACK / 2
		local side = halfZ - gap
		if side > 1 then
			wall(parent, Vector3.new(WALL_T, WALL_H, side), CFrame.new(cx + halfX + WALL_T / 2, wallY, cz - gap - side / 2))
			wall(parent, Vector3.new(WALL_T, WALL_H, side), CFrame.new(cx + halfX + WALL_T / 2, wallY, cz + gap + side / 2))
		end
	end
end

-- Synlig checkpoint + usynlig trigger; server gemmer position til respawn
local function addCheckpoint(
	parent: Instance,
	index: number,
	cx: number,
	cz: number,
	topY: number,
	checkpoints: { CheckpointRecord }
)
	local pad = floorBox(parent, "Checkpoint_" .. index, cx, cz, 18, 18, topY, Color3.fromRGB(80, 160, 220), Enum.Material.Neon)
	label(pad, "CP " .. index, Color3.fromRGB(255, 255, 255), 10)

	local trigger = part(parent, {
		Name = "CheckpointTrigger",
		Size = Vector3.new(16, 8, 16),
		CFrame = CFrame.new(cx, topY + 4, cz),
		Transparency = 1,
		CanCollide = false,
	})
	trigger:SetAttribute("CheckpointIndex", index)

	local spawnY = topY + 5
	table.insert(checkpoints, {
		index = index,
		position = Vector3.new(cx, spawnY, cz),
	})
end

function CourseBuilder.build(): (Folder, Attachment, BasePart, { CheckpointRecord })
	local folder = Instance.new("Folder")
	folder.Name = "MarbleCourse"
	folder.Parent = workspace

	local checkpoints: { CheckpointRecord } = {}

	----------------------------------------------------------------
	-- 1) START PLAZA
	----------------------------------------------------------------
	local H0 = 4
	local start = floorBox(folder, "StartPad", 0, 0, 48, 48, H0, START_COLOR, Enum.Material.Grass)
	label(start, "START", Color3.fromRGB(255, 255, 255), 14)
	plazaWalls(folder, 0, 0, 48, 48, H0, { south = true })

	local spawnAttachment = Instance.new("Attachment")
	spawnAttachment.Name = "Spawn"
	spawnAttachment.Position = Vector3.new(0, 8, 0)
	spawnAttachment.Parent = start

	----------------------------------------------------------------
	-- 2) LONG MEADOW (+Z)
	----------------------------------------------------------------
	local meadowLen = 140
	local meadowZ0 = 24 - OVERLAP
	local meadowZ1 = meadowZ0 + meadowLen
	local meadowMid = (meadowZ0 + meadowZ1) / 2
	floorBox(folder, "Meadow", 0, meadowMid, TRACK, meadowLen, H0, GRASS)
	wallsAlongZ(folder, 0, meadowMid, meadowLen, H0, TRACK)

	-- Gentle hill (up then down) — continuous surface
	local hillZ = meadowZ0 + 45
	rampZ(folder, "HillUp", hillZ, hillZ + 18, 0, TRACK - 1, H0, H0 + 5, GRASS_DARK, Enum.Material.Grass)
	rampWallsZ(folder, hillZ, hillZ + 18, 0, TRACK - 1, H0, H0 + 5)
	rampZ(folder, "HillDown", hillZ + 18 - OVERLAP, hillZ + 36, 0, TRACK - 1, H0 + 5, H0, GRASS_DARK, Enum.Material.Grass)
	rampWallsZ(folder, hillZ + 18 - OVERLAP, hillZ + 36, 0, TRACK - 1, H0 + 5, H0)

	addCheckpoint(folder, 1, 0, meadowZ0 + 55, H0, checkpoints)

	-- Svingende bro-stykke (small gaps — hop eller timing)
	for i = 1, 4 do
		local segZ = meadowZ0 + 78 + (i - 1) * 14
		floorBox(folder, "SwingSegment" .. i, (i % 2 == 0) and 4 or -4, segZ, 12, 12, H0, WOOD, Enum.Material.WoodPlanks)
	end
	-- Sikker midtersti så sving-pladerne ikke efterlader huller
	floorBox(folder, "MeadowCenter", 0, meadowZ0 + 92, 10, 58, H0, GRASS)
	wallsAlongZ(folder, 0, meadowZ0 + 92, 58, H0, TRACK)

	----------------------------------------------------------------
	-- 3) TURN PLAZA (to +X)
	----------------------------------------------------------------
	local turnCX, turnCZ = 18, meadowZ1 + 18 - OVERLAP
	floorBox(folder, "TurnPlaza", turnCX, turnCZ, 60, 44, H0, GRASS_DARK)
	plazaWalls(folder, turnCX, turnCZ, 60, 44, H0, { north = true, east = true })

	----------------------------------------------------------------
	-- 4) CANYON STRAIGHT (+X)
	----------------------------------------------------------------
	local canyonX0 = turnCX + 30 - OVERLAP
	local canyonLen = 175
	local canyonX1 = canyonX0 + canyonLen
	local canyonMid = (canyonX0 + canyonX1) / 2
	local canyonZ = turnCZ
	floorBox(folder, "Canyon", canyonMid, canyonZ, canyonLen, TRACK, H0, STONE, Enum.Material.Slate)
	wallsAlongX(folder, canyonZ, canyonMid, canyonLen, H0, TRACK)

	-- Side pillars as visual obstacles (not blocking center)
	for i = 1, 7 do
		local px = canyonX0 + 18 + (i - 1) * 22
		local side = if i % 2 == 0 then 1 else -1
		part(folder, {
			Name = "Pillar",
			Size = Vector3.new(3, 10, 3),
			CFrame = CFrame.new(px, H0 + 5, canyonZ + side * (TRACK / 2 - 2.5)),
			Color = Color3.fromRGB(90, 95, 105),
			Material = Enum.Material.Concrete,
		})
	end

	-- Bevægelige platforme over et "hul" i canyon (hop på dem i rækkefølge)
	local gapX = canyonX0 + 95
	part(folder, {
		Name = "CanyonGap",
		Size = Vector3.new(22, 1, TRACK - 4),
		CFrame = CFrame.new(gapX, H0 - 1.2, canyonZ),
		Color = Color3.fromRGB(40, 45, 55),
		Material = Enum.Material.Slate,
		CanCollide = false,
	})
	ObstacleEngine.addMovingPlatform(
		folder,
		Vector3.new(gapX - 8, H0 + 0.5, canyonZ),
		Vector3.new(10, 2, 14),
		"X",
		7,
		1.1
	)
	ObstacleEngine.addMovingPlatform(
		folder,
		Vector3.new(gapX, H0 + 0.5, canyonZ),
		Vector3.new(10, 2, 14),
		"Z",
		6,
		1.4
	)
	ObstacleEngine.addMovingPlatform(
		folder,
		Vector3.new(gapX + 8, H0 + 0.5, canyonZ),
		Vector3.new(10, 2, 14),
		"X",
		7,
		0.95
	)
	ObstacleEngine.addSpinner(folder, Vector3.new(gapX + 28, H0 + 4, canyonZ), 14, 6, 1.8)

	addCheckpoint(folder, 2, canyonX1 - 20, canyonZ, H0, checkpoints)

	----------------------------------------------------------------
	-- 4b) ZIGZAG (skift retning + smalle svinge)
	----------------------------------------------------------------
	local zigX, zigZ = canyonX1 - OVERLAP, canyonZ
	for i = 1, 6 do
		local len = 38
		if i % 2 == 1 then
			zigX += len / 2
			floorBox(folder, "ZigX" .. i, zigX, zigZ, len, TRACK - 2, H0, GRASS_DARK)
			wallsAlongX(folder, zigZ, zigX, len, H0, TRACK - 2)
			zigX += len / 2 - OVERLAP
		else
			zigZ += len / 2
			floorBox(folder, "ZigZ" .. i, zigX, zigZ, TRACK - 2, len, H0, STONE, Enum.Material.Slate)
			wallsAlongZ(folder, zigX, zigZ, len, H0, TRACK - 2)
			zigZ += len / 2 - OVERLAP
			ObstacleEngine.addBouncePad(
				folder,
				CFrame.new(zigX, H0 + 1, zigZ - len / 4),
				Vector3.new(8, 1, 8)
			)
		end
	end

	----------------------------------------------------------------
	-- 5) BIG CLIMB
	----------------------------------------------------------------
	local H1 = 26
	local climbX0 = zigX - OVERLAP
	local climbX1 = climbX0 + 85
	local climbZ = zigZ
	rampX(folder, "BigClimb", climbX0, climbX1, climbZ, TRACK, H0, H1, PLANKS)
	rampWallsX(folder, climbX0, climbX1, climbZ, TRACK, H0, H1)

	----------------------------------------------------------------
	-- 6) SKY PLAZA
	----------------------------------------------------------------
	local skyCX = climbX1 + 22 - OVERLAP
	local skyCZ = climbZ
	addCheckpoint(folder, 3, skyCX, skyCZ, H1, checkpoints)
	floorBox(folder, "SkyPlaza", skyCX, skyCZ, 52, 52, H1, CONCRETE, Enum.Material.Concrete)
	plazaWalls(folder, skyCX, skyCZ, 52, 52, H1, { west = true, south = true })

	-- Decorative corner blocks
	for _, ox in { -18, 18 } do
		for _, oz in { -18, 18 } do
			part(folder, {
				Name = "SkyDecor",
				Size = Vector3.new(4, 1.2, 4),
				CFrame = CFrame.new(skyCX + ox, H1 + 0.6, skyCZ + oz),
				Color = Color3.fromRGB(160, 165, 175),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
			})
		end
	end

	----------------------------------------------------------------
	-- 7) ELEVATED RUN (+Z) + TURN WEST + BRIDGE
	----------------------------------------------------------------
	local elevZ0 = skyCZ + 26 - OVERLAP
	local elevLen = 75
	local elevZ1 = elevZ0 + elevLen
	local elevMid = (elevZ0 + elevZ1) / 2
	floorBox(folder, "ElevatedRun", skyCX, elevMid, TRACK, elevLen, H1, CONCRETE, Enum.Material.Concrete)
	wallsAlongZ(folder, skyCX, elevMid, elevLen, H1, TRACK)

	-- Turn plaza: arrive from north, leave west
	local turn2CX = skyCX
	local turn2CZ = elevZ1 + 22 - OVERLAP
	floorBox(folder, "HighTurn", turn2CX, turn2CZ, 56, 48, H1, STONE, Enum.Material.Concrete)
	plazaWalls(folder, turn2CX, turn2CZ, 56, 48, H1, { north = true, west = true })

	-- West corridor toward bridge start
	local westLen = 55
	local westX1 = turn2CX - 28 + OVERLAP -- plaza west edge ~ turn2CX-28
	local westX0 = westX1 - westLen
	local westMid = (westX0 + westX1) / 2
	floorBox(folder, "WestRun", westMid, turn2CZ, westLen, TRACK, H1, CONCRETE, Enum.Material.Concrete)
	wallsAlongX(folder, turn2CZ, westMid, westLen, H1, TRACK)
	ObstacleEngine.addSpinner(folder, Vector3.new(westMid, H1 + 5, turn2CZ), 16, 7, 2.2)
	ObstacleEngine.addIceStrip(
		folder,
		CFrame.new(westMid - 12, H1 - 1, turn2CZ),
		Vector3.new(24, FLOOR, TRACK - 4)
	)

	-- Bridge plaza
	local bridgePlazaCX = westX0 - 18 + OVERLAP
	local bridgePlazaCZ = turn2CZ
	floorBox(folder, "BridgePlaza", bridgePlazaCX, bridgePlazaCZ, 40, 40, H1, WOOD, Enum.Material.Wood)
	plazaWalls(folder, bridgePlazaCX, bridgePlazaCZ, 40, 40, H1, { east = true, south = true })

	----------------------------------------------------------------
	-- 8) NARROW BRIDGE (+Z)
	----------------------------------------------------------------
	local bridgeW = 12
	local bridgeZ0 = bridgePlazaCZ + 20 - OVERLAP
	local bridgeLen = 120
	local bridgeZ1 = bridgeZ0 + bridgeLen
	local bridgeMid = (bridgeZ0 + bridgeZ1) / 2
	floorBox(folder, "Bridge", bridgePlazaCX, bridgeMid, bridgeW, bridgeLen, H1, WOOD, Enum.Material.Wood)
	local railH = 2.8
	wall(
		folder,
		Vector3.new(1, railH, bridgeLen),
		CFrame.new(bridgePlazaCX - bridgeW / 2 - 0.5, H1 + railH / 2, bridgeMid),
		Color3.fromRGB(120, 90, 55)
	)
	wall(
		folder,
		Vector3.new(1, railH, bridgeLen),
		CFrame.new(bridgePlazaCX + bridgeW / 2 + 0.5, H1 + railH / 2, bridgeMid),
		Color3.fromRGB(120, 90, 55)
	)

	----------------------------------------------------------------
	-- 9) LANDING + DESCEND
	----------------------------------------------------------------
	local landCX = bridgePlazaCX
	local landCZ = bridgeZ1 + 22 - OVERLAP
	floorBox(folder, "Landing", landCX, landCZ, 44, 44, H1, CONCRETE, Enum.Material.Concrete)
	plazaWalls(folder, landCX, landCZ, 44, 44, H1, { north = true, east = true })
	addCheckpoint(folder, 4, landCX, landCZ, H1, checkpoints)

	local H2 = 10
	local descX0 = landCX + 22 - OVERLAP
	local descX1 = descX0 + 55
	rampX(folder, "Descend", descX0, descX1, landCZ, TRACK, H1, H2, PLANKS)
	rampWallsX(folder, descX0, descX1, landCZ, TRACK, H1, H2)

	----------------------------------------------------------------
	-- 10) FINAL APPROACH (+X then +Z to goal)
	----------------------------------------------------------------
	local finalX0 = descX1 - OVERLAP
	local finalLen = 110
	local finalX1 = finalX0 + finalLen
	local finalMid = (finalX0 + finalX1) / 2
	floorBox(folder, "FinalStraight", finalMid, landCZ, finalLen, TRACK, H2, GRASS)
	wallsAlongX(folder, landCZ, finalMid, finalLen, H2, TRACK)

	for i = 1, 4 do
		local hx = finalX0 + 18 + (i - 1) * 22
		part(folder, {
			Name = "HopPad",
			Size = Vector3.new(8, 1.5, 8),
			CFrame = CFrame.new(hx, H2 + 0.75, landCZ),
			Color = Color3.fromRGB(100, 160, 120),
			Material = Enum.Material.Grass,
		})
	end
	ObstacleEngine.addIceStrip(
		folder,
		CFrame.new(finalMid, H2 - 1, landCZ + 6),
		Vector3.new(finalLen - 10, FLOOR, 10)
	)
	ObstacleEngine.addSpinner(folder, Vector3.new(finalX1 - 25, H2 + 5, landCZ), 12, 6, 2.5)

	local preGoalCX = finalX1 + 20 - OVERLAP
	local preGoalCZ = landCZ
	floorBox(folder, "PreGoal", preGoalCX, preGoalCZ, 48, 48, H2, GRASS_DARK)
	plazaWalls(folder, preGoalCX, preGoalCZ, 48, 48, H2, { west = true, south = true })

	local approachZ0 = preGoalCZ + 24 - OVERLAP
	local approachLen = 85
	addCheckpoint(folder, 5, preGoalCX, preGoalCZ, H2, checkpoints)
	local approachZ1 = approachZ0 + approachLen
	local approachMid = (approachZ0 + approachZ1) / 2
	floorBox(folder, "GoalApproach", preGoalCX, approachMid, TRACK, approachLen, H2, GRASS)
	wallsAlongZ(folder, preGoalCX, approachMid, approachLen, H2, TRACK)

	----------------------------------------------------------------
	-- 11) GOAL
	----------------------------------------------------------------
	local goalCX = preGoalCX
	local goalCZ = approachZ1 + 22 - OVERLAP
	local goalPad = floorBox(folder, "GoalPad", goalCX, goalCZ, 44, 44, H2, GOAL_COLOR, Enum.Material.Neon)
	label(goalPad, "MÅL!", Color3.fromRGB(40, 28, 8), 12)
	plazaWalls(folder, goalCX, goalCZ, 44, 44, H2, { north = true })

	for i = 1, 12 do
		local angle = (i / 12) * math.pi * 2
		local x = goalCX + math.cos(angle) * 14
		local z = goalCZ + math.sin(angle) * 14
		part(folder, {
			Name = "GoalDecor",
			Size = Vector3.new(2.2, 1, 2.2),
			CFrame = CFrame.new(x, H2 + 0.5, z),
			Color = if i % 2 == 0 then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(25, 25, 25),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end

	local goal = part(folder, {
		Name = "GoalTrigger",
		Size = Vector3.new(28, 14, 28),
		CFrame = CFrame.new(goalCX, H2 + 7, goalCZ),
		Transparency = 1,
		CanCollide = false,
		Color = GOAL_COLOR,
		Material = Enum.Material.SmoothPlastic,
	})
	goal:SetAttribute("IsGoal", true)

	local light = Instance.new("PointLight")
	light.Brightness = 2.5
	light.Range = 50
	light.Color = Color3.fromRGB(255, 220, 120)
	light.Parent = goalPad

	ObstacleEngine.bindBouncePads(folder)
	ObstacleEngine.start()

	return folder, spawnAttachment, goal, checkpoints
end

return CourseBuilder
