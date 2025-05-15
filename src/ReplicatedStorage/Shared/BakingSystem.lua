-- BakingSystem.lua
-- Handles baking of objects in furnaces

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- Check if we're running on client or server
local isClient = RunService:IsClient()
local isServer = RunService:IsServer()

-- Constants
local PERFECT_DONENESS = 600
local BURNT_DONENESS = 900
local CHECK_INTERVAL = 0.5 -- Check for objects every 0.5 seconds
local MAX_BAKE_HEIGHT = 5 -- Maximum height above furnace base to check for objects

local BakingSystem = {}

-- Create a remote event for syncing doneness updates
local DonenessUpdateEvent
if isServer then
	DonenessUpdateEvent = Instance.new("RemoteEvent")
	DonenessUpdateEvent.Name = "DonenessUpdate"
	DonenessUpdateEvent.Parent = ReplicatedStorage
else
	DonenessUpdateEvent = ReplicatedStorage:WaitForChild("DonenessUpdate")
end

-- Variables
local objectsBeingBaked = {}
local furnaceBases = {}
local bakingConnection = nil
local checkObjectsConnection = nil
local lastCheckTime = 0

-- Function to initialize the baking system
function BakingSystem.init()
	print("Initializing baking system...")

	-- Find all furnaces in the workspace
	if Workspace:FindFirstChild("Furnaces") then
		local furnacesFolder = Workspace.Furnaces
		for _, furnace in ipairs(furnacesFolder:GetChildren()) do
			local basePart = furnace:WaitForChild("Base")
			if basePart then
				table.insert(furnaceBases, basePart)
				print("Found furnace base:", basePart:GetFullName())
			else
				warn("Furnace model does not have a Base part:", furnace.Name)
			end
		end

		print("Found " .. #furnaceBases .. " furnace bases")
	else
		warn("Furnaces folder not found in workspace")
	end

	-- Set up periodic check for objects above furnaces (server only)
	if isServer then
		checkObjectsConnection = RunService.Heartbeat:Connect(function(deltaTime)
			-- Only check periodically to save performance
			lastCheckTime = lastCheckTime + deltaTime
			if lastCheckTime >= CHECK_INTERVAL then
				BakingSystem.checkObjectsAboveFurnaces()
				lastCheckTime = 0
			end
		end)

		-- Set up heartbeat connection for baking objects
		bakingConnection = RunService.Heartbeat:Connect(function(deltaTime)
			BakingSystem.updateBaking(deltaTime)
		end)
	end

	-- Set up client-side doneness updates
	if isClient then
		DonenessUpdateEvent.OnClientEvent:Connect(function(part, doneness)
			BakingSystem.updateClientDoneness(part, doneness)
		end)
	end

	print("Baking system initialized")
end

-- Function to clean up the baking system
function BakingSystem.cleanup()
	if bakingConnection then
		bakingConnection:Disconnect()
		bakingConnection = nil
	end

	if checkObjectsConnection then
		checkObjectsConnection:Disconnect()
		checkObjectsConnection = nil
	end

	objectsBeingBaked = {}
	furnaceBases = {}
end

-- Function to check if an object is above a furnace base
function BakingSystem.isObjectAboveFurnaceBase(part, basePart)
	-- Check if the part is within the XZ bounds of the base
	local baseSize = basePart.Size
	local basePosition = basePart.Position
	local baseXMin = basePosition.X - baseSize.X / 2
	local baseXMax = basePosition.X + baseSize.X / 2
	local baseZMin = basePosition.Z - baseSize.Z / 2
	local baseZMax = basePosition.Z + baseSize.Z / 2

	local partPosition = part.Position

	-- Check if part is within XZ bounds of the base
	if
		partPosition.X >= baseXMin
		and partPosition.X <= baseXMax
		and partPosition.Z >= baseZMin
		and partPosition.Z <= baseZMax
	then
		-- Check if part is above the base but within the maximum baking height
		local baseTopY = basePosition.Y + (baseSize.Y / 2)
		return (partPosition.Y > baseTopY) and (partPosition.Y <= baseTopY + MAX_BAKE_HEIGHT)
	end

	return false
end

-- Function to check for objects above all furnaces
function BakingSystem.checkObjectsAboveFurnaces()
	if not isServer then
		return
	end

	-- Create a list of objects that should be baking
	local shouldBeBaking = {}

	-- Check all parts in workspace
	for _, part in pairs(Workspace:GetChildren()) do
		if part:IsA("BasePart") then
			-- Check if the part has Cookness and Doneness values
			if part:FindFirstChild("Cookness") and part:FindFirstChild("Doneness") then
				-- Check if part is above any furnace base
				for _, basePart in ipairs(furnaceBases) do
					if BakingSystem.isObjectAboveFurnaceBase(part, basePart) then
						shouldBeBaking[part] = true
						break
					end
				end
			end
		end
	end

	-- Start baking objects that should be baking but aren't yet
	for part, _ in pairs(shouldBeBaking) do
		if not objectsBeingBaked[part] then
			print("Object now above furnace: " .. part.Name)
			objectsBeingBaked[part] = true

			-- Immediately notify clients about the current doneness to ensure color synchronization
			if part:FindFirstChild("Doneness") then
				DonenessUpdateEvent:FireAllClients(part, part.Doneness.Value)
			end
		end
	end

	-- Stop baking objects that should no longer be baking
	for part, _ in pairs(objectsBeingBaked) do
		if not shouldBeBaking[part] then
			print("Object no longer above furnace: " .. part.Name)
			objectsBeingBaked[part] = nil
		end
	end
end

-- Function to update baking for all objects in furnaces
function BakingSystem.updateBaking(deltaTime)
	if not isServer then
		return
	end

	for part, _ in pairs(objectsBeingBaked) do
		-- Check if part still exists
		if part and part.Parent then
			local cookness = part.Cookness.Value
			local doneness = part.Doneness.Value

			-- Increase doneness by cookness value
			doneness = doneness + cookness

			-- Update the doneness value on the part
			part.Doneness.Value = doneness

			-- Notify clients about the doneness update - pass the part directly
			DonenessUpdateEvent:FireAllClients(part, doneness)
		else
			-- Remove the object if it no longer exists
			objectsBeingBaked[part] = nil
		end
	end
end

-- Function to update object appearance on client based on doneness
function BakingSystem.updateClientDoneness(part, doneness)
	if not isClient then
		return
	end

	-- Make sure part is valid
	if not part or not part.Parent then
		warn("Part is not valid or has no parent")
		return
	end

	-- Update the appearance
	-- Update local doneness value first so color update uses correct value
	if part:FindFirstChild("Doneness") then
		part.Doneness.Value = doneness
	end

	-- Now update the appearance with the new doneness value
	BakingSystem.updateObjectAppearance(part, doneness)
end

-- Function to update a part's appearance based on doneness
function BakingSystem.updateObjectAppearance(part, doneness)
	-- Define color gradients based on doneness levels
	local rawColor = Color3.fromRGB(235, 213, 179) -- Raw dough color
	local cookedColor = Color3.fromRGB(200, 130, 50) -- Cooked color (golden brown)
	local burntColor = Color3.fromRGB(80, 50, 30) -- Burnt color (dark brown)

	local targetColor

	if doneness < PERFECT_DONENESS then
		-- Interpolate between raw and cooked colors based on doneness
		local t = math.clamp(doneness / PERFECT_DONENESS, 0, 1)
		targetColor = Color3.new(
			rawColor.R + (cookedColor.R - rawColor.R) * t,
			rawColor.G + (cookedColor.G - rawColor.G) * t,
			rawColor.B + (cookedColor.B - rawColor.B) * t
		)
	elseif doneness <= BURNT_DONENESS then
		-- Perfectly cooked
		targetColor = cookedColor
	else
		-- Interpolate between cooked and burnt colors for burnt objects
		local t = math.clamp((doneness - BURNT_DONENESS) / 300, 0, 1)
		targetColor = Color3.new(
			cookedColor.R + (burntColor.R - cookedColor.R) * t,
			cookedColor.G + (burntColor.G - cookedColor.G) * t,
			cookedColor.B + (burntColor.B - cookedColor.B) * t
		)
	end

	-- Apply the color change immediately first
	part.Color = targetColor

	-- Then create a smooth tween for subtle animation
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(part, tweenInfo, { Color = targetColor })

	-- Use pcall in case tween fails for any reason
	pcall(function()
		tween:Play()
	end)
end

-- Initialize the system if we're on the client or server
if isClient or isServer then
	BakingSystem.init()
end

return BakingSystem
