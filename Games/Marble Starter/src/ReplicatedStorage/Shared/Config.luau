--[[
	Config.luau
	-----------
	Justér tallene for at ændre hvordan marble'en føles.
	Elever behøver normalt IKKE ændre filen for at bygge en bane.
]]

local Config = {
	Marble = {
		Diameter = 4,
		Density = 0.85,
		Friction = 0.55,
		Elasticity = 0.05,
		JumpSpeed = 48,
		GroundCheckPadding = 0.4,

		MaxSpeed = 46,
		AccelRate = 8,
		BrakeRate = 6,
		SteerRate = 10,
		InputSmooth = 14,
	},

	Camera = {
		Distance = 24,
		Height = 11,
		TurnSpeed = 2.4,
		PitchSpeed = 1.7,
		GoalSnapSpeed = 6,
	},

	-- Fald under denne Y → respawn på start
	RespawnY = -40,

	Game = {
		RestartDelayAfterGoal = 3,
	},
}

return Config
