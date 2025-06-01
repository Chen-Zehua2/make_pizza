-- DoughRemotes.lua
-- Centralized module for all dough-related RemoteEvents

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Check if we're running on client or server
local isServer = RunService:IsServer()

-- Create the module
local DoughRemotes = {}

-- Helper function to create or get a RemoteEvent
local function getRemoteEvent(name)
	local event = ReplicatedStorage:FindFirstChild(name)
	if event then
		return event
	end

	if isServer then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = ReplicatedStorage
	else
		event = ReplicatedStorage:WaitForChild(name)
	end

	return event
end

-- Create/get all the RemoteEvents
DoughRemotes.CreateDough = getRemoteEvent("CreateDough")
DoughRemotes.SplitDough = getRemoteEvent("SplitDough")
DoughRemotes.CombineDoughs = getRemoteEvent("CombineDoughs")
DoughRemotes.SetFlattenValue = getRemoteEvent("SetFlattenValue")
DoughRemotes.DestroyDough = getRemoteEvent("DestroyDough")
DoughRemotes.ShowNotification = getRemoteEvent("ShowNotification")

return DoughRemotes
