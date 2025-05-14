-- DoughRemotes.lua
-- Centralizes all RemoteEvents for the dough system

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create a folder to organize our RemoteEvents
local remoteFolder = ReplicatedStorage:FindFirstChild("DoughRemotes")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "DoughRemotes"
	remoteFolder.Parent = ReplicatedStorage
end

-- Create RemoteEvents if they don't exist
local function createRemoteIfNeeded(name)
	local remote = remoteFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remoteFolder
	end
	return remote
end

local DoughRemotes = {
	-- Create initial dough
	CreateDough = createRemoteIfNeeded("CreateDough"),

	-- Slice a dough into two pieces
	SliceDough = createRemoteIfNeeded("SliceDough"),

	-- Combine multiple doughs into one
	CombineDoughs = createRemoteIfNeeded("CombineDoughs"),

	-- Flatten a dough
	FlattenDough = createRemoteIfNeeded("FlattenDough"),

	-- Update a dough's position (for dragging)
	UpdateDoughPosition = createRemoteIfNeeded("UpdateDoughPosition"),

	-- Destroy a dough
	DestroyDough = createRemoteIfNeeded("DestroyDough"),
}

return DoughRemotes
