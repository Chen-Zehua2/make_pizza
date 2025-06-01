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
local UISystem = require(ReplicatedStorage.Shared.UISystem)
local CombineSystem = require(ReplicatedStorage.Shared.CombineSystem)
local NotificationSystem = require(ReplicatedStorage.Shared.UILib.Shared.NotificationSystem)

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

-- Function to update dough doneness from instance values
local function updateDoughFromInstance(dough)
	if not dough or not dough.instance then
		return
	end

	-- Update doneness from instance
	local donenessValue = dough.instance:FindFirstChild("Doneness")
	if donenessValue then
		local newDoneness = donenessValue.Value
		if newDoneness ~= dough.doneness then
			dough:updateDoneness(newDoneness)
		end
	end

	-- Update flatten count from instance
	local flattenCountValue = dough.instance:FindFirstChild("FlattenCount")
	if flattenCountValue then
		dough.flattenCount = flattenCountValue.Value
	end

	-- Update size value from instance
	local sizeValueObj = dough.instance:FindFirstChild("SizeValue")
	if sizeValueObj then
		dough.sizeValue = sizeValueObj.Value
	end
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
	end

	create_re_attempts = 0
end)

DoughRemotes.SplitDough.OnClientEvent:Connect(function(oldDoughId, newDoughId1, newDoughId2)
	print("Client: Handling sliced dough", oldDoughId, "into", newDoughId1, "and", newDoughId2)
	while create_re_attempts < CREATE_RE_MAX_ATTEMPTS do
		-- Server has created new doughs, we need to track them
		scanWorkspaceForDough()

		create_re_attempts += 1
		task.wait(0.05)
	end

	create_re_attempts = 0
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
		local dough = clientDoughs[doughId]
		if dough then
			-- Clean up steam effects before removing
			dough:removeSteamEffect()
		end
		clientDoughs[doughId] = nil
	end

	print("Client: Updated combined dough", targetDoughId)
end)

DoughRemotes.SetFlattenValue.OnClientEvent:Connect(function(doughId, value)
	-- Update the flatten value on the client
	local dough = clientDoughs[doughId]
	if dough then
		dough.flattenCount = value
	end

	print("Client: Updated flatten value for dough", doughId, "to", value)
end)

DoughRemotes.DestroyDough.OnClientEvent:Connect(function(doughId)
	-- Clean up steam effects before removing
	local dough = clientDoughs[doughId]
	if dough then
		dough:removeSteamEffect()
	end

	-- Remove the dough from tracking
	clientDoughs[doughId] = nil

	print("Client: Removed destroyed dough", doughId)
end)

-- Handle server-sent notifications
DoughRemotes.ShowNotification.OnClientEvent:Connect(function(message, notificationType, duration)
	NotificationSystem.showNotification(message, notificationType, duration)
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

local function splitDough(doughId, sliceStart, sliceEnd)
	DoughRemotes.SplitDough:FireServer(doughId, sliceStart, sliceEnd)
end

local function combineDoughs(targetDoughId, doughsToRemoveIds, totalSizeValue)
	DoughRemotes.CombineDoughs:FireServer(targetDoughId, doughsToRemoveIds, totalSizeValue)
end

local function setFlattenValue(doughId, value)
	DoughRemotes.SetFlattenValue:FireServer(doughId, value)
end

local function destroyDough(doughId)
	DoughRemotes.DestroyDough:FireServer(doughId)
end

-- Make existing dough objects draggable and clickable
local function ensureAllDoughsInteractive()
	for doughId, dough in pairs(clientDoughs) do
		if dough and dough.instance then
			-- Make sure it has a click detector
			setupClickDetector(dough)
			-- Update from instance values
			updateDoughFromInstance(dough)
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
					doneness = child:FindFirstChild("Doneness") and child.Doneness.Value or 0,
					instance = child, -- Provide the existing instance to prevent creating a new one
				}

				local dough = DoughBase.new(params)

				-- Store in tracking table
				clientDoughs[doughId] = dough

				-- Make interactive
				setupClickDetector(dough)

				-- Update steam effects based on current doneness
				dough:updateSteamEffect()
			end
		end
	end
end

-- Periodic update for steam effects and doneness tracking
local function updateDoughEffects()
	for doughId, dough in pairs(clientDoughs) do
		if dough and dough.instance and dough.instance.Parent then
			-- Update dough properties from instance
			updateDoughFromInstance(dough)

			-- Update steam effects
			dough:updateSteamEffect()
		else
			-- Clean up invalid doughs
			if dough then
				dough:removeSteamEffect()
			end
			clientDoughs[doughId] = nil
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

-- Start periodic steam effect updates
task.spawn(function()
	while true do
		task.wait(1) -- Update steam effects every second
		updateDoughEffects()
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

local splitDoughBindable = Instance.new("BindableFunction")
splitDoughBindable.Name = "SplitDough"
splitDoughBindable.OnInvoke = splitDough
splitDoughBindable.Parent = clientFolder

local combineDoughsBindable = Instance.new("BindableFunction")
combineDoughsBindable.Name = "CombineDoughs"
combineDoughsBindable.OnInvoke = combineDoughs
combineDoughsBindable.Parent = clientFolder

local setFlattenValueBindable = Instance.new("BindableFunction")
setFlattenValueBindable.Name = "SetFlattenValue"
setFlattenValueBindable.OnInvoke = setFlattenValue
setFlattenValueBindable.Parent = clientFolder

local destroyDoughBindable = Instance.new("BindableFunction")
destroyDoughBindable.Name = "DestroyDough"
destroyDoughBindable.OnInvoke = destroyDough
destroyDoughBindable.Parent = clientFolder

print("DoughClient initialized successfully!")
