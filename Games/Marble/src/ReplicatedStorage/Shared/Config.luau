--[[
	Config.luau — tuning for smooth marble-kørsel
]]

local Config = {
	Marble = {
		Diameter = 4,
		Density = 0.85,
		Friction = 0.55,
		Elasticity = 0.05,
		JumpSpeed = 48,
		GroundCheckPadding = 0.4,

		-- Hastighed & glathed (arcade-velocity, ikke rå force)
		MaxSpeed = 46,
		-- Hvor hurtigt vi accelererer op mod MaxSpeed (højere = snappier)
		AccelRate = 8,
		-- Hvor hurtigt vi bremser uden input
		BrakeRate = 6,
		-- Hvor hurtigt retning ændres mens vi kører (drejning)
		SteerRate = 10,
		-- Input softens (tastetryk glattes før de bruges)
		InputSmooth = 14,
	},

	Camera = {
		Distance = 24,
		Height = 11,
		Smoothness = 0.14,
		TurnSpeed = 2.4,
		PitchSpeed = 1.7,
		GoalSnapSpeed = 6,
	},

	RespawnY = -80,

	Game = {
		RestartDelayAfterGoal = 4,
	},

	Obstacles = {
		BouncePower = 70,
		IceFriction = 0.08,
	},
}

return Config
