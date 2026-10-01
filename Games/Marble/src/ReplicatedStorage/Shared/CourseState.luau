--[[
	CourseState.luau (klient)
	-------------------------
	Lille state bag som HUD og kontrol-script deler.
]]

export type CourseInfoPayload = {
	goalPosition: Vector3,
	checkpointCount: number,
}

local CourseState = {
	goalPosition = Vector3.zero,
	checkpointCount = 0,
	currentCheckpoint = 0,
	raceStartTime = nil :: number?,
	lastFinishTime = nil :: number?,
}

function CourseState.applyCourseInfo(payload: CourseInfoPayload)
	CourseState.goalPosition = payload.goalPosition
	CourseState.checkpointCount = payload.checkpointCount
	CourseState.currentCheckpoint = 0
end

function CourseState.beginRace()
	CourseState.raceStartTime = os.clock()
	CourseState.lastFinishTime = nil
	CourseState.currentCheckpoint = 0
end

function CourseState.setCheckpoint(index: number)
	CourseState.currentCheckpoint = index
end

function CourseState.finishRace(elapsed: number)
	CourseState.lastFinishTime = elapsed
	CourseState.raceStartTime = nil
end

function CourseState.getElapsed(): number?
	if not CourseState.raceStartTime then
		return nil
	end
	return os.clock() - CourseState.raceStartTime
end

return CourseState
