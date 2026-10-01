--[[
	CourseState.luau (klient)
	Deler mål-position mellem HUD og kamera (Enter = kig mod mål).
]]

export type CourseInfoPayload = {
	goalPosition: Vector3?,
}

local CourseState = {
	goalPosition = nil :: Vector3?,
}

function CourseState.applyCourseInfo(payload: CourseInfoPayload)
	CourseState.goalPosition = payload.goalPosition
end

return CourseState
