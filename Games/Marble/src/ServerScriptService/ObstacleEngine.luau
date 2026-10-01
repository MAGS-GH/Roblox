--[[
	ObstacleEngine.luau (server)
	----------------------------
	Bygger og animerer forhindringer:
	- Bevægelige platforme (sinusbølge)
	- Roterende arme ("spinners")
	- Hop-plader og is (via part-attributter)

	Kald ObstacleEngine.start() én gang efter banen er bygget.
]]

local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local ObstacleEngine = {}

type Mover = {
	part: BasePart,
	origin: Vector3,
	axis: "X" | "Z",
	amplitude: number,
	speed: number,
	phase: number,
}

type Spinner = {
	hub: BasePart,
	arm: BasePart,
	armReach: number,
	speed: number,
}

local movers: { Mover } = {}
local spinners: { Spinner } = {}
local started = false

local function makePart(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- Platform der glider frem og tilbage — marble skal time sit hop
function ObstacleEngine.addMovingPlatform(
	parent: Instance,
	center: Vector3,
	size: Vector3,
	axis: "X" | "Z",
	amplitude: number,
	speed: number,
	color: Color3?
): Part
	local part = makePart(parent, {
		Name = "MovingPlatform",
		Size = size,
		CFrame = CFrame.new(center),
		Color = color or Color3.fromRGB(200, 120, 60),
		Material = Enum.Material.Metal,
	})
	table.insert(movers, {
		part = part,
		origin = center,
		axis = axis,
		amplitude = amplitude,
		speed = speed,
		phase = math.random() * math.pi * 2,
	})
	return part
end

-- Horisontal arm der drejer — undgå midten!
function ObstacleEngine.addSpinner(parent: Instance, center: Vector3, armLength: number, height: number, speed: number)
	local hub = makePart(parent, {
		Name = "SpinnerHub",
		Size = Vector3.new(3, height, 3),
		CFrame = CFrame.new(center),
		Color = Color3.fromRGB(180, 60, 60),
		Material = Enum.Material.Metal,
	})
	local arm = makePart(parent, {
		Name = "SpinnerArm",
		Size = Vector3.new(armLength * 2, 2.5, 2.5),
		CFrame = CFrame.new(center + Vector3.new(0, height * 0.5 + 1.25, 0)),
		Color = Color3.fromRGB(220, 80, 80),
		Material = Enum.Material.Neon,
	})
	table.insert(spinners, {
		hub = hub,
		arm = arm,
		armReach = armLength,
		speed = speed,
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
				if vel.Y > 20 then
					return
				end
				hit.AssemblyLinearVelocity = Vector3.new(vel.X, power, vel.Z)
			end)
		end
	end
end

function ObstacleEngine.start()
	if started then
		return
	end
	started = true

	RunService.Heartbeat:Connect(function(dt)
		local t = os.clock()
		for _, mover in movers do
			local offset = math.sin(t * mover.speed + mover.phase) * mover.amplitude
			local pos = mover.origin
			if mover.axis == "X" then
				pos += Vector3.new(offset, 0, 0)
			else
				pos += Vector3.new(0, 0, offset)
			end
			mover.part.CFrame = CFrame.new(pos)
		end

		for _, spinner in spinners do
			local angle = t * spinner.speed
			local hubPos = spinner.hub.Position + Vector3.new(0, spinner.hub.Size.Y * 0.5 + 1.25, 0)
			spinner.arm.CFrame = CFrame.new(hubPos) * CFrame.Angles(0, angle, 0) * CFrame.new(spinner.armReach, 0, 0)
		end
	end)
end

return ObstacleEngine
