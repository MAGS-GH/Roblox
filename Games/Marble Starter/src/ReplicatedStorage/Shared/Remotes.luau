--[[
	Remotes.luau — RemoteEvents mellem server og klient
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("MarbleRemotes")

return {
	AssignMarble = folder:WaitForChild("AssignMarble") :: RemoteEvent,
	RequestRespawn = folder:WaitForChild("RequestRespawn") :: RemoteEvent,
	GoalReached = folder:WaitForChild("GoalReached") :: RemoteEvent,
	CourseInfo = folder:WaitForChild("CourseInfo") :: RemoteEvent,
}
