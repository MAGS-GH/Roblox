--[[
	ObstacleEngine.luau
	-------------------
	Bevægelige forhindringer. Nogle er LETHAL (KillsMarble) → respawn.
]]

local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local ObstacleEngine = {}

type Slider = {
	part: BasePart,
	origin: CFrame,
	axis: Vector3,
	amplitude: number,
	speed: number,
	phase: number,
}

type Spinner = {
	hub: BasePart,
	arm: BasePart,
	speed: number,
	phase: number,
	armHeight: number,
}

type Swinger = {
	part: BasePart,
	pivot: CFrame,
	speed: number,
	phase: number,
	maxAngle: number,
	length: number,
}

local sliders: { Slider } = {}
local spinners: { Spinner } = {}
local swingers: { Swinger } = {}
local started = false

local KILL_COLOR = Color3.fromRGB(220, 30, 40)
local KILL_NEON = Color3.fromRGB(255, 40, 60)

local function makePart(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function markLethal(p: BasePart)
	p:SetAttribute("KillsMarble", true)
	p.Color = KILL_NEON
	p.Material = Enum.Material.Neon
	-- Lille highlight så spilleren kan se faren
	local h = Instance.new("Highlight")
	h.FillColor = KILL_COLOR
	h.FillTransparency = 0.55
	h.OutlineColor = Color3.fromRGB(255, 120, 120)
	h.OutlineTransparency = 0.2
	h.Parent = p
end

function ObstacleEngine.addSlidingPlatform(
	parent: Instance,
	origin: CFrame,
	size: Vector3,
	axis: Vector3,
	amplitude: number,
	speed: number,
	phase: number?,
	color: Color3?,
	lethal: boolean?
): Part
	local p = makePart(parent, {
		Name = if lethal then "KillSlider" else "SlidingPlatform",
		Size = size,
		CFrame = origin,
		Color = color or Color3.fromRGB(220, 130, 55),
		Material = Enum.Material.Metal,
	})
	if lethal then
		markLethal(p)
	end
	table.insert(sliders, {
		part = p,
		origin = origin,
		axis = axis.Unit,
		amplitude = amplitude,
		speed = speed,
		phase = phase or 0,
	})
	return p
end

function ObstacleEngine.addElevator(
	parent: Instance,
	origin: CFrame,
	size: Vector3,
	amplitude: number,
	speed: number,
	phase: number?,
	color: Color3?,
	lethal: boolean?
): Part
	return ObstacleEngine.addSlidingPlatform(
		parent,
		origin,
		size,
		Vector3.yAxis,
		amplitude,
		speed,
		phase,
		color or Color3.fromRGB(90, 170, 220),
		lethal
	)
end

function ObstacleEngine.addSpinner(
	parent: Instance,
	hubCenter: Vector3,
	armLength: number,
	hubHeight: number,
	speed: number,
	phase: number?,
	lethal: boolean?
)
	local hub = makePart(parent, {
		Name = "SpinnerHub",
		Size = Vector3.new(3.5, hubHeight, 3.5),
		CFrame = CFrame.new(hubCenter),
		Color = Color3.fromRGB(100, 40, 40),
		Material = Enum.Material.Metal,
	})
	local armThickness = 2.4
	local arm = makePart(parent, {
		Name = "SpinnerArm",
		Size = Vector3.new(armLength * 2, armThickness, armThickness),
		CFrame = CFrame.new(hubCenter + Vector3.new(0, hubHeight * 0.5 + armThickness * 0.5, 0)),
		Color = Color3.fromRGB(255, 70, 70),
		Material = Enum.Material.Neon,
	})
	if lethal ~= false then
		-- Spinners er lethal som standard
		markLethal(arm)
		hub:SetAttribute("KillsMarble", true)
	end
	table.insert(spinners, {
		hub = hub,
		arm = arm,
		speed = speed,
		phase = phase or 0,
		armHeight = hubHeight * 0.5 + armThickness * 0.5,
	})
end

function ObstacleEngine.addSwingingHammer(
	parent: Instance,
	pivot: Vector3,
	length: number,
	speed: number,
	maxAngleDeg: number,
	phase: number?,
	lethal: boolean?
)
	local thickness = 3.2
	local p = makePart(parent, {
		Name = "SwingHammer",
		Size = Vector3.new(thickness, length, thickness),
		CFrame = CFrame.new(pivot) * CFrame.new(0, -length / 2, 0),
		Color = Color3.fromRGB(200, 90, 40),
		Material = Enum.Material.Metal,
	})
	makePart(parent, {
		Name = "SwingPivot",
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(pivot),
		Color = Color3.fromRGB(80, 80, 90),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	if lethal ~= false then
		markLethal(p)
	end
	table.insert(swingers, {
		part = p,
		pivot = CFrame.new(pivot),
		speed = speed,
		phase = phase or 0,
		maxAngle = math.rad(maxAngleDeg),
		length = length,
	})
end

function ObstacleEngine.addBouncePad(parent: Instance, cf: CFrame, size: Vector3)
	local pad = makePart(parent, {
		Name = "BouncePad",
		Size = size,
		CFrame = cf,
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.Neon,
	})
	pad:SetAttribute("BouncePower", Config.Obstacles.BouncePower)
end

function ObstacleEngine.addIceStrip(parent: Instance, cf: CFrame, size: Vector3)
	local ice = makePart(parent, {
		Name = "IceStrip",
		Size = size,
		CFrame = cf,
		Color = Color3.fromRGB(180, 220, 255),
		Material = Enum.Material.Ice,
	})
	ice.CustomPhysicalProperties = PhysicalProperties.new(0.7, Config.Obstacles.IceFriction, 0.05, 1, 1)
end

function ObstacleEngine.bindBouncePads(folder: Folder)
	for _, desc in folder:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("BouncePower") then
			local power = desc:GetAttribute("BouncePower") :: number
			desc.Touched:Connect(function(hit)
				if not hit:IsA("BasePart") or hit:GetAttribute("IsMarble") ~= true then
					return
				end
				local vel = hit.AssemblyLinearVelocity
				if vel.Y > 18 then
					return
				end
				hit.AssemblyLinearVelocity = Vector3.new(vel.X, power, vel.Z)
			end)
		end
	end
end

--[[
	Binder alle KillsMarble-parts. onKill(marblePart) kaldes (med cooldown håndteret udefra anbefales).
]]
function ObstacleEngine.bindKillParts(folder: Folder, onKill: (BasePart) -> ())
	for _, desc in folder:GetDescendants() do
		if desc:IsA("BasePart") and desc:GetAttribute("KillsMarble") == true then
			desc.Touched:Connect(function(hit)
				if hit:IsA("BasePart") and hit:GetAttribute("IsMarble") == true then
					onKill(hit)
				end
			end)
		end
	end
end

function ObstacleEngine.start()
	if started then
		return
	end
	started = true

	RunService.Heartbeat:Connect(function()
		local t = os.clock()

		for _, s in sliders do
			local offset = math.sin(t * s.speed + s.phase) * s.amplitude
			s.part.CFrame = s.origin + s.axis * offset
		end

		for _, sp in spinners do
			local angle = t * sp.speed + sp.phase
			local armCenter = sp.hub.Position + Vector3.new(0, sp.armHeight, 0)
			sp.arm.CFrame = CFrame.new(armCenter) * CFrame.Angles(0, angle, 0)
		end

		for _, sw in swingers do
			local angle = math.sin(t * sw.speed + sw.phase) * sw.maxAngle
			sw.part.CFrame = sw.pivot * CFrame.Angles(angle, 0, 0) * CFrame.new(0, -sw.length / 2, 0)
		end
	end)
end

return ObstacleEngine
