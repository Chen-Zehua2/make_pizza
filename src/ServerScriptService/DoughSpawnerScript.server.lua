-- DoughSpawnerScript.server.lua
-- Script to be placed inside the DoughSpawner model
-- Handles click detection and spawns dough when clicked

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

-- Wait for the DoughRemotes module to be available
local DoughRemotes
local maxAttempts = 10
local attempts = 0
repeat
	attempts = attempts + 1
	DoughRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DoughRemotes"))
	if not DoughRemotes then
		task.wait(0.5)
	end
until DoughRemotes or attempts >= maxAttempts

if not DoughRemotes then
	error("Failed to load DoughRemotes after multiple attempts")
end

local CollectionService = game:GetService("CollectionService")

-- Load the BaseClass and DoughBase modules
local BaseClass = require(ReplicatedStorage.Shared.BaseClass)
local DoughBase = require(ReplicatedStorage.Shared.DoughBase)

-- Get the DoughSpawner model (this script should be inside it)
local doughSpawner = CollectionService:GetTagged("DoughSpawner")[1]
if not doughSpawner then
	error("DoughSpawner not found!")
end

-- Find the Spawn part inside the DoughSpawner model
local spawnPart = doughSpawner:FindFirstChild("Spawn")
if not spawnPart then
	error("DoughSpawner model must contain a part named 'Spawn'")
end

-- Create a ProximityPrompt for better UX (shows pickup prompt when nearby)
local proximityPrompt = Instance.new("ProximityPrompt")
proximityPrompt.ActionText = "Spawn Dough"
proximityPrompt.ObjectText = "Dough Spawner"
proximityPrompt.MaxActivationDistance = 20
proximityPrompt.HoldDuration = 1
proximityPrompt.KeyboardKeyCode = Enum.KeyCode.E
proximityPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
proximityPrompt.Parent = spawnPart

-- Track spawned dough objects
local spawnedDoughs = {}
local nextDoughId = 1

-- Function to create a server-side dough object (similar to DoughServer)
local function createServerDough(params, playerId)
	-- Create a new dough with the given parameters
	local dough = DoughBase.new(params)

	-- Assign a unique ID to the dough
	local doughId = "spawner_" .. tostring(nextDoughId)
	nextDoughId = nextDoughId + 1

	-- Store the spawned dough
	spawnedDoughs[doughId] = dough

	-- Set a special attribute on the instance to identify it
	dough.instance:SetAttribute("DoughId", doughId)
	dough.instance:SetAttribute("CreatorId", playerId)

	-- Add a ClickDetector to ensure the dough is clickable
	if not dough.instance:FindFirstChild("ClickDetector") then
		local clickDetector = Instance.new("ClickDetector")
		clickDetector.MaxActivationDistance = 20
		clickDetector.Parent = dough.instance
	end

	return doughId, dough
end

-- Function to spawn dough at the spawn location
local function spawnDough(player)
	if not player or not player.Character then
		return
	end

	-- Get spawn position (slightly above the spawn part to prevent clipping)
	local spawnPosition = spawnPart.Position + Vector3.new(0, spawnPart.Size.Y / 2 + 2, 0)

	-- Create dough parameters
	local params = {
		position = spawnPosition,
		sizeValue = 1, -- Default size
	}

	-- Create the server-side dough directly
	local doughId, dough = createServerDough(params, player.UserId)

	-- Send notification to the player
	DoughRemotes.ShowNotification:FireClient(player, "Dough spawned!", "success", 2)

	print("DoughSpawner: Created dough", doughId, "for player", player.Name, "at position", spawnPosition)
end

-- Connect the proximity prompt
proximityPrompt.Triggered:Connect(function(player)
	spawnDough(player)
end)

print("DoughSpawner script initialized successfully!")
print("Spawn part found at position:", spawnPart.Position)
