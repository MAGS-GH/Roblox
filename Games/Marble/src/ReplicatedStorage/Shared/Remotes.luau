--[[
	Remotes.luau — referencer til RemoteEvents i ReplicatedStorage/MarbleRemotes
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("MarbleRemotes")

return {
	Folder = folder,
	AssignMarble = folder:WaitForChild("AssignMarble") :: RemoteEvent,
	RequestRespawn = folder:WaitForChild("RequestRespawn") :: RemoteEvent,
	GoalReached = folder:WaitForChild("GoalReached") :: RemoteEvent,
	CourseInfo = folder:WaitForChild("CourseInfo") :: RemoteEvent,
	CheckpointUpdated = folder:WaitForChild("CheckpointUpdated") :: RemoteEvent,
	RunComplete = folder:WaitForChild("RunComplete") :: RemoteEvent,
	PlayerInput = folder:WaitForChild("PlayerInput") :: RemoteEvent,
}
