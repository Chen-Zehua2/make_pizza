-- DoughClient.client.lua
-- Handles client-side interactions with the dough system

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Reference to the local player
local player = Players.LocalPlayer

-- Determine if we're running on the client
local isClient = RunService:IsClient()

-- Ensure we're only running this on the client
if not isClient then
	error("DoughClient should only run on the client!")
	return
end

-- Wait for RemoteEvents to be created
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

-- Load modules
local BaseClass = require(ReplicatedStorage.Shared.BaseClass)
local DoughBase = require(ReplicatedStorage.Shared.DoughBase)
local DragSystem = require(ReplicatedStorage.Shared.DragSystem)
local UISystem = require(ReplicatedStorage.Shared.UISystem)
local CombineSystem = require(ReplicatedStorage.Shared.CombineSystem)

-- Client-side dough tracking
local clientDoughs = {}

-- Function to set up click detector for a dough object
local function setupClickDetector(dough)
	if not dough or not dough.instance then
		return
	end

	-- Create a ClickDetector if it doesn't exist
	local clickDetector = dough.instance:FindFirstChild("ClickDetector")
	if not clickDetector then
		clickDetector = Instance.new("ClickDetector")
		clickDetector.MaxActivationDistance = 20
		clickDetector.Parent = dough.instance
	end

	-- Connect the click event
	clickDetector.MouseClick:Connect(function()
		-- Prevent UI from showing if combine mode is active
		if CombineSystem and CombineSystem.isCombineActive and CombineSystem.isCombineActive() then
			return
		end

		print(dough.name .. " clicked!")
		-- Show options UI using the object's options
		UISystem.showObjectUI(dough)
	end)

	return clickDetector
end

-- Function to create dough through the server
local function createDough(position, sizeValue)
	-- Request server to create dough
	DoughRemotes.CreateDough:FireServer(position, sizeValue)
end

local CREATE_RE_MAX_ATTEMPTS = 10
local create_re_attempts = 0
-- Connect remote event handlers
DoughRemotes.CreateDough.OnClientEvent:Connect(function(doughId)
	print("Client: Creating dough", doughId)
	while create_re_attempts < CREATE_RE_MAX_ATTEMPTS do
		-- Server has created a dough, we need to track it
		scanWorkspaceForDough()

		create_re_attempts += 1
		task.wait(0.05)

		-- local doughInstance = workspace:WaitForChild(doughId, 5)

		-- if doughInstance then
		-- 	-- Create a client-side representation without creating the actual instance
		-- 	local params = {
		-- 		position = doughInstance.Position,
		-- 		sizeValue = doughInstance:FindFirstChild("SizeValue") and doughInstance.SizeValue.Value or 1,
		-- 		flattenCount = doughInstance:FindFirstChild("FlattenCount") and doughInstance.FlattenCount.Value or 0,
		-- 		instance = doughInstance, -- Use the existing instance instead of creating a new one
		-- 	}

		-- 	-- Create the dough object referencing the existing instance
		-- 	local dough = DoughBase.new(params)

		-- 	-- Store it in our tracking table
		-- 	clientDoughs[doughId] = dough

		-- 	-- Set up for dragging
		-- 	DragSystem.trackObject(dough)

		-- 	-- Set up click detector
		-- 	setupClickDetector(dough)

		-- 	print("Client: Tracking server dough", doughId)
		-- else
		-- 	warn("Client: Failed to find dough instance with ID", doughId)
		-- end
	end

	create_re_attempts = 0
end)

DoughRemotes.SliceDough.OnClientEvent:Connect(function(oldDoughId, newDoughId1, newDoughId2)
	print("Client: Creating dough", doughId)
	while create_re_attempts < CREATE_RE_MAX_ATTEMPTS do
		-- Server has created a dough, we need to track it
		scanWorkspaceForDough()

		create_re_attempts += 1
		task.wait(0.05)

		-- local doughInstance = workspace:WaitForChild(doughId, 5)

		-- if doughInstance then
		-- 	-- Create a client-side representation without creating the actual instance
		-- 	local params = {
		-- 		position = doughInstance.Position,
		-- 		sizeValue = doughInstance:FindFirstChild("SizeValue") and doughInstance.SizeValue.Value or 1,
		-- 		flattenCount = doughInstance:FindFirstChild("FlattenCount") and doughInstance.FlattenCount.Value or 0,
		-- 		instance = doughInstance, -- Use the existing instance instead of creating a new one
		-- 	}

		-- 	-- Create the dough object referencing the existing instance
		-- 	local dough = DoughBase.new(params)

		-- 	-- Store it in our tracking table
		-- 	clientDoughs[doughId] = dough

		-- 	-- Set up for dragging
		-- 	DragSystem.trackObject(dough)

		-- 	-- Set up click detector
		-- 	setupClickDetector(dough)

		-- 	print("Client: Tracking server dough", doughId)
		-- else
		-- 	warn("Client: Failed to find dough instance with ID", doughId)
		-- end
	end

	create_re_attempts = 0
	-- Remove the old dough from tracking
	-- clientDoughs[oldDoughId] = nil

	-- -- Setup function to create and track dough from an instance
	-- local function setupDoughInstance(doughInstance, doughId)
	-- 	if not doughInstance then
	-- 		return
	-- 	end

	-- 	-- Create client-side representation
	-- 	local params = {
	-- 		position = doughInstance.Position,
	-- 		sizeValue = doughInstance:FindFirstChild("SizeValue") and doughInstance.SizeValue.Value or 1,
	-- 		instance = doughInstance,
	-- 	}

	-- 	-- Create the dough object
	-- 	local dough = DoughBase.new(params)

	-- 	-- Store in tracking table
	-- 	clientDoughs[doughId] = dough

	-- 	-- Set up for dragging immediately
	-- 	DragSystem.trackObject(dough)

	-- 	-- Set up click detector
	-- 	setupClickDetector(dough)

	-- 	print("Client: Successfully tracked sliced dough", doughId)
	-- end

	-- -- Server has created two new doughs from slicing, we need to track them
	-- -- Use a more aggressive approach to find the new instances quickly
	-- local function findAndSetupDough(doughId, maxAttempts)
	-- 	maxAttempts = maxAttempts or 5
	-- 	local attempts = 0

	-- 	-- Try to find immediately first
	-- 	local instance = workspace:FindFirstChild(doughId)
	-- 	if instance then
	-- 		setupDoughInstance(instance, doughId)
	-- 		return true
	-- 	end

	-- 	-- If not found, wait and retry a few times
	-- 	local success = false
	-- 	task.spawn(function()
	-- 		while attempts < maxAttempts and not success do
	-- 			attempts = attempts + 1
	-- 			instance = workspace:FindFirstChild(doughId) or workspace:WaitForChild(doughId, 0.2)
	-- 			if instance then
	-- 				setupDoughInstance(instance, doughId)
	-- 				success = true
	-- 				return
	-- 			end
	-- 			task.wait(0.1) -- Short wait between attempts
	-- 		end

	-- 		if not success then
	-- 			warn("Client: Failed to find sliced dough instance with ID", doughId, "after multiple attempts")
	-- 		end
	-- 	end)
	-- end

	-- -- Try to find and setup both new dough pieces
	-- findAndSetupDough(newDoughId1, 10)
	-- findAndSetupDough(newDoughId2, 10)
end)

DoughRemotes.CombineDoughs.OnClientEvent:Connect(function(targetDoughId, doughsToRemoveIds, totalSizeValue)
	-- Update the target dough's size value
	local targetDough = clientDoughs[targetDoughId]
	if targetDough then
		targetDough.sizeValue = totalSizeValue
		targetDough.flattenCount = 0
	end

	-- Remove the combined doughs from tracking
	for _, doughId in ipairs(doughsToRemoveIds) do
		clientDoughs[doughId] = nil
	end

	print("Client: Updated combined dough", targetDoughId)
end)

DoughRemotes.FlattenDough.OnClientEvent:Connect(function(doughId, amount)
	-- Update the flatten count on the client
	local dough = clientDoughs[doughId]
	if dough then
		dough.flattenCount = (dough.flattenCount or 0) + 1
	end

	print("Client: Updated flattened dough", doughId)
end)

DoughRemotes.UpdateDoughPosition.OnClientEvent:Connect(function(doughId, position)
	-- Update the position of the dough if it's from another client
	local dough = clientDoughs[doughId]
	if dough and dough.instance then
		dough.instance.Position = position
	end
end)

DoughRemotes.DestroyDough.OnClientEvent:Connect(function(doughId)
	-- Remove the dough from tracking
	clientDoughs[doughId] = nil

	print("Client: Removed destroyed dough", doughId)
end)

-- Create functions to expose to other scripts
local function getDough(doughId)
	return clientDoughs[doughId]
end

local function getDoughFromInstance(instance)
	for id, dough in pairs(clientDoughs) do
		if dough.instance == instance then
			return dough, id
		end
	end
	return nil
end

local function sliceDough(doughId, sliceStart, sliceEnd)
	DoughRemotes.SliceDough:FireServer(doughId, sliceStart, sliceEnd)
end

local function combineDoughs(targetDoughId, doughsToRemoveIds, totalSizeValue)
	DoughRemotes.CombineDoughs:FireServer(targetDoughId, doughsToRemoveIds, totalSizeValue)
end

local function flattenDough(doughId, amount)
	DoughRemotes.FlattenDough:FireServer(doughId, amount)
end

local function updateDoughPosition(doughId, position)
	DoughRemotes.UpdateDoughPosition:FireServer(doughId, position)
end

local function destroyDough(doughId)
	DoughRemotes.DestroyDough:FireServer(doughId)
end

-- Make existing dough objects draggable and clickable
local function ensureAllDoughsInteractive()
	for doughId, dough in pairs(clientDoughs) do
		if dough and dough.instance then
			-- Make sure it's tracked for dragging
			DragSystem.trackObject(dough)
			-- Make sure it has a click detector
			setupClickDetector(dough)
		end
	end
end

-- Scan workspace for existing dough objects and track them
function scanWorkspaceForDough()
	for _, child in pairs(workspace:GetChildren()) do
		if child:IsA("Part") or child:IsA("MeshPart") then
			local doughId = child:GetAttribute("DoughId")
			if doughId and not clientDoughs[doughId] then
				print("Found untracked dough with ID", doughId, "- adding to client tracking")

				-- Create client-side object with existing instance
				local params = {
					position = child.Position,
					sizeValue = child:FindFirstChild("SizeValue") and child.SizeValue.Value or 1,
					flattenCount = child:FindFirstChild("FlattenCount") and child.FlattenCount.Value or 0,
					instance = child, -- Provide the existing instance to prevent creating a new one
				}

				local dough = DoughBase.new(params)

				-- Store in tracking table
				clientDoughs[doughId] = dough

				-- Make interactive
				DragSystem.trackObject(dough)
				setupClickDetector(dough)
			end
		end
	end
end

-- Try to ensure all existing dough objects are interactive
task.spawn(function()
	task.wait(1) -- Give system time to initialize
	ensureAllDoughsInteractive()
	scanWorkspaceForDough()

	-- Scan more frequently at first to ensure quick tracking
	for i = 1, 5 do
		task.wait(1)
		scanWorkspaceForDough()
	end

	-- Then scan periodically for any dough that might have been missed
	while true do
		task.wait(5) -- Scan every 5 seconds instead of 10
		scanWorkspaceForDough()
	end
end)

-- Create a folder in ReplicatedStorage to hold our function references
local clientFolder = Instance.new("Folder")
clientFolder.Name = "DoughClientFunctions"
clientFolder.Parent = ReplicatedStorage

-- Use BindableFunction objects to expose our functions
local createDoughBindable = Instance.new("BindableFunction")
createDoughBindable.Name = "CreateDough"
createDoughBindable.OnInvoke = createDough
createDoughBindable.Parent = clientFolder

local getDoughBindable = Instance.new("BindableFunction")
getDoughBindable.Name = "GetDough"
getDoughBindable.OnInvoke = getDough
getDoughBindable.Parent = clientFolder

local getDoughFromInstanceBindable = Instance.new("BindableFunction")
getDoughFromInstanceBindable.Name = "GetDoughFromInstance"
getDoughFromInstanceBindable.OnInvoke = getDoughFromInstance
getDoughFromInstanceBindable.Parent = clientFolder

local sliceDoughBindable = Instance.new("BindableFunction")
sliceDoughBindable.Name = "SliceDough"
sliceDoughBindable.OnInvoke = sliceDough
sliceDoughBindable.Parent = clientFolder

local combineDoughsBindable = Instance.new("BindableFunction")
combineDoughsBindable.Name = "CombineDoughs"
combineDoughsBindable.OnInvoke = combineDoughs
combineDoughsBindable.Parent = clientFolder

local flattenDoughBindable = Instance.new("BindableFunction")
flattenDoughBindable.Name = "FlattenDough"
flattenDoughBindable.OnInvoke = flattenDough
flattenDoughBindable.Parent = clientFolder

local updateDoughPositionBindable = Instance.new("BindableFunction")
updateDoughPositionBindable.Name = "UpdateDoughPosition"
updateDoughPositionBindable.OnInvoke = updateDoughPosition
updateDoughPositionBindable.Parent = clientFolder

local destroyDoughBindable = Instance.new("BindableFunction")
destroyDoughBindable.Name = "DestroyDough"
destroyDoughBindable.OnInvoke = destroyDough
destroyDoughBindable.Parent = clientFolder

print("DoughClient initialized successfully!")
