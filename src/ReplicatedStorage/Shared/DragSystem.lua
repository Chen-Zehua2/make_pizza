-- DragSystem.lua
-- Handles dragging of objects in the world

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local DragSystem = {}

-- Variables
local isDragging = false
local draggedObject = nil
local hoveredObject = nil
local trackedObjects = {}
local slicingActive = false

-- Mouse event connections
local mouseHoverConn = nil
local mouseDownConn = nil
local mouseUpConn = nil
local mouseMoveConn = nil

-- Initialize the drag system
function DragSystem.init()
	print("Initializing drag system")

	-- Connect mouse events for hover and dragging
	mouseHoverConn = RunService.RenderStepped:Connect(DragSystem.updateHoverEffect)
	mouseDownConn = UserInputService.InputBegan:Connect(DragSystem.onMouseDown)
	mouseUpConn = UserInputService.InputEnded:Connect(DragSystem.onMouseUp)
	mouseMoveConn = UserInputService.InputChanged:Connect(DragSystem.onMouseMove)

	print("Drag system initialized successfully!")
end

-- Cleanup the drag system
function DragSystem.cleanup()
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
end

-- Register an object to be tracked for dragging
function DragSystem.trackObject(object)
	if not object or not object.instance then
		return
	end

	-- Store reference to the object
	table.insert(trackedObjects, object)

	return true
end

-- Unregister an object from being tracked
function DragSystem.untrackObject(object)
	if not object then
		return
	end

	-- Find the object in our tracking table
	for i, trackedObj in ipairs(trackedObjects) do
		if trackedObj == object then
			table.remove(trackedObjects, i)
			return true
		end
	end

	return false
end

-- Function to handle mouse hover effect
function DragSystem.updateHoverEffect()
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
		if obj.instance then
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

		-- Find which object this instance belongs to
		for _, obj in ipairs(trackedObjects) do
			if obj.instance == hitInstance then
				hoveredObject = obj
				local highlight = hoveredObject.instance:FindFirstChild("Highlight")
				if highlight and hoveredObject ~= draggedObject then
					highlight.Enabled = true
				end
				break
			end
		end
	end
end

-- Function to handle mouse down for dragging
function DragSystem.onMouseDown(input)
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
	if input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end

	-- Update hover effect
	DragSystem.updateHoverEffect()

	-- Handle dragging
	if isDragging and draggedObject and draggedObject.instance then
		-- Get current mouse position
		local mousePos = UserInputService:GetMouseLocation()
		local mouseRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

		-- Cast ray to find where the mouse is pointing in the world
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		raycastParams.FilterDescendantsInstances = { draggedObject.instance } -- Ignore the dragged object

		local result = Workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 500, raycastParams)

		if result then
			-- Place the object directly at the hit position
			-- The bottom of the object should touch the surface
			local hitPosition = result.Position
			local objectHalfHeight = draggedObject.instance.Size.Y / 2

			-- Position the object so its bottom exactly touches the surface
			draggedObject.instance.Position =
				Vector3.new(hitPosition.X, hitPosition.Y + objectHalfHeight, hitPosition.Z)
		else
			-- If no hit, use a plane at a fixed height (like the floor or table)
			-- Find a default surface (like the workspace floor or the pizza table)
			local defaultY = 0 -- Default workspace floor

			-- Try to find the pizza table
			local pizzaTable = Workspace:FindFirstChild("PizzaTable")
			if pizzaTable and pizzaTable:IsA("BasePart") then
				defaultY = pizzaTable.Position.Y + pizzaTable.Size.Y / 2
			end

			-- Project the mouse ray onto a horizontal plane at the default height
			local planeNormal = Vector3.new(0, 1, 0)
			local pointOnPlane = Vector3.new(0, defaultY, 0)

			local rayDirection = mouseRay.Direction
			local denominator = rayDirection:Dot(planeNormal)

			if math.abs(denominator) > 0.0001 then
				local t = (pointOnPlane - mouseRay.Origin):Dot(planeNormal) / denominator
				local hitPosition = mouseRay.Origin + rayDirection * t

				-- Set the object position with the object bottom at the plane
				draggedObject.instance.Position =
					Vector3.new(hitPosition.X, defaultY + draggedObject.instance.Size.Y / 2, hitPosition.Z)
			end
		end
	end
end

-- Set the slicing active flag (to disable dragging during slicing)
function DragSystem.setSlicingActive(active)
	slicingActive = active
end

-- Get the currently hovered object
function DragSystem.getHoveredObject()
	return hoveredObject
end

-- Get an object from its instance
function DragSystem.getObjectFromInstance(instance)
	if not instance then
		return nil
	end

	for _, obj in ipairs(trackedObjects) do
		if obj.instance == instance then
			return obj
		end
	end

	return nil
end

-- Get all tracked objects
function DragSystem.getTrackedObjects()
	return trackedObjects
end

return DragSystem
