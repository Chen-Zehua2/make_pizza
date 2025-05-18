-- DragSystem.lua
-- Handles dragging of objects in the world

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Check if we're running on client or server
local isClient = RunService:IsClient()

-- Client-only variables
local player
local camera
if isClient then
	player = Players.LocalPlayer
	camera = Workspace.CurrentCamera
end

local DragSystem = {}

-- Variables
local isDragging = false
local draggedObject = nil
local hoveredObject = nil
local trackedObjects = {} -- Array of tracked objects for iteration
local trackedObjectsMap = {} -- Map of instance -> object for faster lookup
local slicingActive = false
local lastCleanupTime = os.clock()
local cleanupInterval = 3 -- Clean up every 3 seconds instead of every frame

-- Mouse event connections
local mouseHoverConn = nil
local mouseDownConn = nil
local mouseUpConn = nil
local mouseMoveConn = nil

-- Initialize the drag system
function DragSystem.init()
	-- Only run on client
	if not isClient then
		return
	end

	print("Initializing drag system")

	-- Connect mouse events for hover and dragging
	mouseHoverConn = RunService.RenderStepped:Connect(DragSystem.updateHoverEffect)
	mouseDownConn = UserInputService.InputBegan:Connect(DragSystem.onMouseDown)
	mouseUpConn = UserInputService.InputEnded:Connect(DragSystem.onMouseUp)
	mouseMoveConn = UserInputService.InputChanged:Connect(DragSystem.onMouseMove)

	-- Set up periodic cleanup
	RunService.Heartbeat:Connect(function()
		local currentTime = os.clock()
		if currentTime - lastCleanupTime >= cleanupInterval then
			DragSystem.cleanupDestroyedObjects()
			lastCleanupTime = currentTime
		end
	end)

	print("Drag system initialized successfully!")
end

-- Cleanup the drag system
function DragSystem.cleanup()
	-- Only run on client
	if not isClient then
		return
	end

	-- Disconnect all connections
	if mouseHoverConn then
		mouseHoverConn:Disconnect()
		mouseHoverConn = nil
	end
	if mouseDownConn then
		mouseDownConn:Disconnect()
		mouseDownConn = nil
	end
	if mouseUpConn then
		mouseUpConn:Disconnect()
		mouseUpConn = nil
	end
	if mouseMoveConn then
		mouseMoveConn:Disconnect()
		mouseMoveConn = nil
	end

	-- Reset state
	isDragging = false
	draggedObject = nil
	hoveredObject = nil

	-- Clear tracked objects
	trackedObjects = {}
	trackedObjectsMap = {}
end

-- Register an object to be tracked for dragging
function DragSystem.trackObject(object)
	if not object or not object.instance then
		return false
	end

	-- Skip if already tracking this object
	if trackedObjectsMap[object.instance] then
		return true
	end

	-- Store reference to the object in both array and map
	table.insert(trackedObjects, object)
	trackedObjectsMap[object.instance] = object

	return true
end

-- Unregister an object from being tracked
function DragSystem.untrackObject(object)
	if not object or not object.instance then
		return false
	end

	-- Remove from map
	trackedObjectsMap[object.instance] = nil

	-- Find and remove from array
	for i, trackedObj in ipairs(trackedObjects) do
		if trackedObj == object then
			table.remove(trackedObjects, i)
			return true
		end
	end

	return false
end

-- Function to clean up destroyed objects from the tracking list
function DragSystem.cleanupDestroyedObjects()
	local originalCount = #trackedObjects
	local validObjects = {}
	local validObjectsMap = {}

	for _, obj in ipairs(trackedObjects) do
		-- Check if the object and its instance are valid
		if obj and obj.instance and obj.instance.Parent then
			table.insert(validObjects, obj)
			validObjectsMap[obj.instance] = obj
		end
	end

	local removedCount = originalCount - #validObjects
	if removedCount > 0 then
		print("DragSystem: Cleaned up", removedCount, "destroyed objects")
		trackedObjects = validObjects
		trackedObjectsMap = validObjectsMap
	end

	return removedCount
end

-- Function to handle mouse hover effect
function DragSystem.updateHoverEffect()
	-- Only run on client
	if not isClient then
		return
	end

	if slicingActive then
		return
	end

	-- Cast ray from mouse position
	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Whitelist

	-- Create a list of objects to check
	local instances = {}
	for _, obj in ipairs(trackedObjects) do
		if obj.instance and obj.instance.Parent then
			table.insert(instances, obj.instance)
		end
	end

	if #instances == 0 then
		return
	end

	raycastParams.FilterDescendantsInstances = instances

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 100, raycastParams)

	-- Clear previous highlight
	if hoveredObject and hoveredObject ~= draggedObject then
		local highlight = hoveredObject.instance:FindFirstChild("Highlight")
		if highlight then
			highlight.Enabled = false
		end
		hoveredObject = nil
	end

	-- Apply new highlight if hovering over an object
	if result and result.Instance then
		local hitInstance = result.Instance

		-- Use map for faster lookup instead of iterating
		local obj = trackedObjectsMap[hitInstance]
		if obj then
			hoveredObject = obj
			local highlight = hoveredObject.instance:FindFirstChild("Highlight")
			if highlight and hoveredObject ~= draggedObject then
				highlight.Enabled = true
			end
		end
	end
end

-- Function to handle mouse down for dragging
function DragSystem.onMouseDown(input)
	-- Only run on client
	if not isClient then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseButton1 or slicingActive then
		return
	end

	-- If we're hovering over an object, start dragging it
	if hoveredObject then
		isDragging = true
		draggedObject = hoveredObject

		-- Disable highlight during drag
		local highlight = draggedObject.instance:FindFirstChild("Highlight")
		if highlight then
			highlight.Enabled = false
		end
	end
end

-- Function to handle mouse up for ending drag
function DragSystem.onMouseUp(input)
	-- Only run on client
	if not isClient then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	-- End dragging
	if isDragging and draggedObject then
		isDragging = false

		-- Re-enable highlight if still hovering
		if draggedObject == hoveredObject then
			local highlight = draggedObject.instance:FindFirstChild("Highlight")
			if highlight then
				highlight.Enabled = true
			end
		end

		draggedObject = nil
	end
end

-- Function to handle mouse movement for dragging
function DragSystem.onMouseMove(input)
	-- Only run on client
	if not isClient then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end

	-- If we're dragging, update position
	if isDragging and draggedObject and draggedObject.instance then
		-- Cast ray from mouse position to get the world position
		local mousePos = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

		-- Create a raycast to find the ground or other surfaces
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		raycastParams.FilterDescendantsInstances = { draggedObject.instance } -- Exclude the dragged object

		-- Raycast down to find ground or other surfaces
		local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)

		if result then
			local hitPoint = result.Position

			-- Calculate the new position to ensure bottom of object touches the ground
			local objectSize = draggedObject.instance.Size
			local objectHeight = objectSize.Y

			-- Position the object so its bottom touches the ground
			local newPosition = Vector3.new(
				hitPoint.X,
				hitPoint.Y + (objectHeight / 2), -- Add half the height to raise it from the ground
				hitPoint.Z
			)

			-- Get the dough ID from the instance attributes
			local doughId = draggedObject.instance:GetAttribute("DoughId")
			if doughId then
				-- Update position immediately for responsive feel
				draggedObject.instance.Position = newPosition

				-- Fire the remote event to update on server
				local DoughRemotes = require(ReplicatedStorage.Shared.DoughRemotes)
				DoughRemotes.UpdateDoughPosition:FireServer(doughId, newPosition)
			end
		end
	end
end

-- Function to get an object from its instance (now uses map for O(1) lookup)
function DragSystem.getObjectFromInstance(instance)
	return trackedObjectsMap[instance]
end

-- Function to check if there are tracked objects
function DragSystem.hasTrackedObjects()
	return #trackedObjects > 0
end

-- Function to get all tracked objects
function DragSystem.getTrackedObjects()
	-- No longer calling cleanup on every get - it's done on a timer instead
	return trackedObjects
end

-- Function to set slicing active state
function DragSystem.setSplittingActive(active)
	slicingActive = active
end

-- Function to get slicing active state
function DragSystem.isSlicingActive()
	return slicingActive
end

return DragSystem
