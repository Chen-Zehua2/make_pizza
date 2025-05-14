-- SliceSystem.lua
-- Handles the slicing interface and operations for any object

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local DragSystem = require(ReplicatedStorage.Shared.DragSystem)

-- Check if we're running on client or server
local isClient = RunService:IsClient()
local isServer = RunService:IsServer()

-- Client-only code
local player
local camera
local PlayerGui
if isClient then
	player = Players.LocalPlayer
	camera = Workspace.CurrentCamera
	PlayerGui = player:WaitForChild("PlayerGui")
end

local SliceSystem = {}

-- Constants
local MINIMUM_SLICE_LENGTH_PERCENTAGE = 0.4 -- Require slices to go through at least 40% of the diameter

-- Variables for slice mode
local isSlicingActive = false
local sliceStart = nil
local sliceEnd = nil
local slicingUI = nil
local drawingSurface = nil
local edgeVisual = nil
local sliceVisuals = {}
local targetObject = nil
local objectClass = nil
local originalCameraType = nil
local originalCameraSubject = nil
local disabledClickDetectors = {} -- Store click detectors with their original distances
local sliceComplete = false -- Flag to prevent multiple slice attempts

-- Function to start slicing the target object
function SliceSystem.startSlicing(object, objectClassModule)
	if not isClient then
		return -- Only run on client
	end

	print("Starting to slice object...")

	-- Make sure we have the object and its class
	if not object or not object.instance then
		print("Cannot slice: invalid object")
		return
	end

	-- Reset the slicing state
	sliceComplete = false

	-- Store the object and its class
	targetObject = object
	objectClass = objectClassModule

	-- Notify DragSystem that slicing is active to prevent dragging
	DragSystem.setSlicingActive(true)

	-- Set slicing active flag to control input
	isSlicingActive = true

	-- Disable click detectors for all objects in the workspace
	for _, part in pairs(Workspace:GetDescendants()) do
		if part:IsA("BasePart") then
			local clickDetector = part:FindFirstChild("ClickDetector")
			if clickDetector and clickDetector.MaxActivationDistance > 0 then
				-- Store the original distance to restore later
				disabledClickDetectors[clickDetector] = clickDetector.MaxActivationDistance
				-- Set to 0 to disable click detection
				clickDetector.MaxActivationDistance = 0
			end
		end
	end

	-- Store the current camera settings to restore later
	originalCameraType = camera.CameraType
	originalCameraSubject = camera.CameraSubject

	-- Set camera to fixed and position it directly above the object
	camera.CameraType = Enum.CameraType.Scriptable

	-- Position camera directly above object, looking down
	local objectPosition = object.instance.Position
	local objectSize = object.instance.Size
	local cameraHeight = 15 -- Increased height for better perspective
	local cameraPosition = objectPosition + Vector3.new(0, cameraHeight, 0)
	camera.CFrame = CFrame.new(cameraPosition, objectPosition)

	-- Create a drawing surface on top of the object but much larger to catch all mouse events
	drawingSurface = Instance.new("Part")
	drawingSurface.Name = "DrawingSurface"
	drawingSurface.Transparency = 1 -- Invisible
	drawingSurface.CanCollide = false
	drawingSurface.Anchored = true

	-- Make the drawing surface much larger than the object
	local surfaceSize = Vector3.new(
		50, -- Very wide to catch all mouse events
		0.1, -- Very thin
		50 -- Very deep to catch all mouse events
	)
	drawingSurface.Size = surfaceSize
	drawingSurface.Position = Vector3.new(
		objectPosition.X,
		objectPosition.Y + (objectSize.Y / 2) + 0.05, -- Slightly above the object
		objectPosition.Z
	)
	drawingSurface.Parent = Workspace

	-- Create a visual representation of the object edge
	edgeVisual = Instance.new("Part")
	edgeVisual.Name = "ObjectEdgeVisual"
	edgeVisual.Shape = Enum.PartType.Cylinder
	edgeVisual.Orientation = Vector3.new(0, 0, 90) -- Lay flat
	edgeVisual.Size = Vector3.new(0.1, objectSize.X, objectSize.X) -- Very thin disc
	edgeVisual.Position = objectPosition
	edgeVisual.Transparency = 0.5
	edgeVisual.Color = Color3.fromRGB(255, 255, 255)
	edgeVisual.Material = Enum.Material.Neon
	edgeVisual.CanCollide = false
	edgeVisual.Anchored = true
	edgeVisual.Parent = Workspace

	-- Create UI to show slicing instructions
	local sliceInstructions = Instance.new("ScreenGui")
	sliceInstructions.Name = "SliceInstructions"
	sliceInstructions.ResetOnSpawn = false
	sliceInstructions.Parent = PlayerGui

	local instructionFrame = Instance.new("Frame")
	instructionFrame.Size = UDim2.new(0, 400, 0, 80)
	instructionFrame.Position = UDim2.new(0.5, -200, 0, 20)
	instructionFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	instructionFrame.BackgroundTransparency = 0.5
	instructionFrame.BorderSizePixel = 0

	local cornerRadius = Instance.new("UICorner")
	cornerRadius.CornerRadius = UDim.new(0, 10)
	cornerRadius.Parent = instructionFrame

	local instructionText = Instance.new("TextLabel")
	instructionText.Size = UDim2.new(1, -20, 1, -20)
	instructionText.Position = UDim2.new(0, 10, 0, 10)
	instructionText.BackgroundTransparency = 1
	instructionText.Text = "SLICE MODE: Click and drag to slice\nPress E to cancel"
	instructionText.TextColor3 = Color3.fromRGB(255, 255, 255)
	instructionText.TextSize = 16
	instructionText.Font = Enum.Font.GothamBold
	instructionText.Parent = instructionFrame

	instructionFrame.Parent = sliceInstructions

	slicingUI = sliceInstructions

	-- Variables for slice drawing
	local isDrawing = false
	local drawingPoints = {}
	local mouseIsDown = false

	-- Create visual representation of a point
	local function createPointVisual(position, color)
		local point = Instance.new("Part")
		point.Name = "SlicePoint"
		point.Shape = Enum.PartType.Ball
		point.Size = Vector3.new(0.2, 0.2, 0.2) -- Smaller points
		point.Position = position
		point.Color = color or Color3.fromRGB(255, 100, 100)
		point.Material = Enum.Material.Neon
		point.CanCollide = false
		point.Anchored = true
		point.Parent = Workspace

		table.insert(sliceVisuals, point)
		return point
	end

	-- Create a line segment with thinner line
	local function createLineSegment(fromPos, toPos)
		local direction = (toPos - fromPos)
		local distance = direction.Magnitude

		local line = Instance.new("Part")
		line.Name = "SliceLine"
		line.Size = Vector3.new(0.05, 0.05, distance) -- Thinner line
		line.CFrame = CFrame.lookAt(fromPos, toPos) * CFrame.new(0, 0, -distance / 2)
		line.Anchored = true
		line.CanCollide = false
		line.Color = Color3.fromRGB(255, 0, 0)
		line.Material = Enum.Material.Neon
		line.Parent = Workspace

		table.insert(sliceVisuals, line)
		return line
	end

	-- Function to project a screen point onto the object plane
	local function projectToObjectPlane(screenPoint)
		local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)

		-- Create a raycast params
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Include
		raycastParams.FilterDescendantsInstances = { drawingSurface }

		-- Perform raycast directly onto the drawing surface
		local result = Workspace:Raycast(ray.Origin, ray.Direction * 100, raycastParams)

		if result then
			return result.Position
		end

		-- Fallback to plane intersection math if raycast fails
		local planeNormal = Vector3.new(0, 1, 0) -- Up vector
		local planeOrigin = Vector3.new(objectPosition.X, objectPosition.Y + (objectSize.Y / 2), objectPosition.Z)

		local denom = ray.Direction:Dot(planeNormal)
		if math.abs(denom) > 0.0001 then -- Avoid division by near-zero
			local t = (planeOrigin - ray.Origin):Dot(planeNormal) / denom
			if t > 0 then
				local hitPoint = ray.Origin + ray.Direction * t
				return hitPoint
			end
		end

		return nil
	end

	-- Function to calculate distance from a point to the object center in XZ plane
	local function distanceToObjectCenter(point)
		local xzPoint = Vector3.new(point.X, 0, point.Z)
		local xzCenter = Vector3.new(objectPosition.X, 0, objectPosition.Z)
		return (xzPoint - xzCenter).Magnitude
	end

	-- Check if a point is within the object's radius
	local function isPointWithinObject(point)
		local objectRadius = math.max(objectSize.X, objectSize.Z) / 2
		return distanceToObjectCenter(point) <= objectRadius
	end

	-- Function to cleanup all visuals
	local function cleanupVisuals()
		-- Clear all stored visuals
		for _, visual in ipairs(sliceVisuals) do
			if visual and visual.Parent then
				visual:Destroy()
			end
		end
		sliceVisuals = {}

		-- Clear drawing surface
		if drawingSurface and drawingSurface.Parent then
			drawingSurface:Destroy()
			drawingSurface = nil
		end

		-- Clear edge visual
		if edgeVisual and edgeVisual.Parent then
			edgeVisual:Destroy()
			edgeVisual = nil
		end
	end

	-- Function to re-enable all click detectors
	local function restoreClickDetectors()
		for clickDetector, distance in pairs(disabledClickDetectors) do
			if clickDetector and clickDetector.Parent then
				clickDetector.MaxActivationDistance = distance
			end
		end
		disabledClickDetectors = {}
	end

	-- Function to clean up the slice mode
	local function exitSliceMode()
		-- Reset slice flags and data
		isSlicingActive = false
		sliceStart = nil
		sliceEnd = nil

		-- Restore the player's camera
		if originalCameraType and camera then
			camera.CameraType = originalCameraType
		end
		if originalCameraSubject and camera then
			camera.CameraSubject = originalCameraSubject
		end

		-- Clean up connections
		if mouseDown then
			mouseDown:Disconnect()
			mouseDown = nil
		end
		if mouseUp then
			mouseUp:Disconnect()
			mouseUp = nil
		end
		if mouseMove then
			mouseMove:Disconnect()
			mouseMove = nil
		end

		-- Clean up all visuals
		cleanupVisuals()

		-- Make sure the slice drawings are removed
		for _, obj in pairs(Workspace:GetChildren()) do
			if
				obj:IsA("BasePart")
				and (
					obj.Name == "SlicePoint"
					or obj.Name == "SliceLine"
					or obj.Name == "DrawingSurface"
					or obj.Name == "ObjectEdgeVisual"
				)
			then
				obj:Destroy()
			end
		end

		-- Re-enable click detectors
		restoreClickDetectors()

		-- Notify DragSystem that slicing is no longer active
		DragSystem.setSlicingActive(false)

		-- Remove the slicing UI
		if slicingUI then
			slicingUI:Destroy()
			slicingUI = nil
		end

		-- Clear the target object
		targetObject = nil
		print("Exited slice mode")
	end

	-- Function to finalize and perform the slice
	local function finalizeSlice()
		-- Prevent multiple slice attempts
		if sliceComplete then
			print("Slice already completed, ignoring additional slice attempt")
			return
		end

		-- Make sure we have valid target object
		if not targetObject or not targetObject.instance then
			print("Invalid slice: missing target object or instance")
			exitSliceMode()
			return
		end

		-- Make sure we have valid start and end points for the slice
		if not sliceStart or not sliceEnd then
			print("Invalid slice: missing start or end point")
			exitSliceMode()
			return
		end

		-- Set slice as complete to prevent multiple attempts
		sliceComplete = true

		-- Check if the slice is long enough (considering the object's radius)
		local objectRadius = math.max(objectSize.X, objectSize.Z) / 2
		local sliceLength = (sliceEnd - sliceStart).Magnitude
		local sliceLengthRatio = sliceLength / (objectRadius * 2)

		if sliceLengthRatio < MINIMUM_SLICE_LENGTH_PERCENTAGE then
			print(
				"Slice too short, must be at least " .. (MINIMUM_SLICE_LENGTH_PERCENTAGE * 100) .. "% of the diameter"
			)
			exitSliceMode()
			return
		end

		-- Get the dough ID to slice server-side
		local doughId = targetObject.instance:GetAttribute("DoughId")
		if not doughId then
			warn("Cannot slice: missing DoughId attribute")
			exitSliceMode()
			return
		end

		-- Stop receiving input immediately to prevent further slice actions
		if mouseDown then
			mouseDown:Disconnect()
			mouseDown = nil
		end
		if mouseUp then
			mouseUp:Disconnect()
			mouseUp = nil
		end
		if mouseMove then
			mouseMove:Disconnect()
			mouseMove = nil
		end

		-- Calculate slice direction and perform client-side calculations
		-- This is now done client-side instead of sending raw slice points to server

		-- Get all the necessary values for the calculation
		local part = targetObject.instance
		local partPosition = part.Position
		local partSize = part.Size
		local sizeValue = part:FindFirstChild("SizeValue") and part.SizeValue.Value or 1

		-- Calculate the slice direction and normalize it to XZ plane
		local sliceDir = Vector3.new(sliceEnd.X - sliceStart.X, 0, sliceEnd.Z - sliceStart.Z).Unit

		-- Calculate perpendicular vector to the slice (for offsetting the new bases)
		local perpDir = Vector3.new(-sliceDir.Z, 0, sliceDir.X)

		-- Calculate part center in XZ plane
		local partCenterXZ = Vector3.new(partPosition.X, 0, partPosition.Z)

		-- Calculate slice center in XZ plane
		local sliceCenter = Vector3.new((sliceStart.X + sliceEnd.X) / 2, 0, (sliceStart.Z + sliceEnd.Z) / 2)

		-- Calculate distance from slice center to part center
		local centerToSlice = (sliceCenter - partCenterXZ).Magnitude

		-- Calculate the ratio for splitting (0.5 means perfect middle, closer to 0 or 1 means uneven)
		local splitRatio = math.clamp(centerToSlice / objectRadius, 0.01, 0.99)

		-- Calculate size values for the two halves
		local largerSideRatio = 0.5 + (splitRatio * 0.5) -- Ranges from 0.5 to 1.0
		local smallerSideRatio = 1 - largerSideRatio -- Ranges from 0.5 to 0.0

		-- Determine which side is smaller (the one the slice is closer to)
		local sideSign = perpDir:Dot(sliceCenter - partCenterXZ)

		-- Assign size values based on which side is smaller
		local sizeValue1, sizeValue2
		if sideSign >= 0 then
			-- Slice is closer to side 2
			sizeValue1 = sizeValue * largerSideRatio
			sizeValue2 = sizeValue * smallerSideRatio
		else
			-- Slice is closer to side 1
			sizeValue1 = sizeValue * smallerSideRatio
			sizeValue2 = sizeValue * largerSideRatio
		end

		-- Calculate positions for the two new pieces
		local offsetRatio1 = sizeValue1 / sizeValue
		local offsetRatio2 = sizeValue2 / sizeValue

		local pos1 = Vector3.new(
			partPosition.X + perpDir.X * objectRadius * offsetRatio2 * 0.5,
			partPosition.Y,
			partPosition.Z + perpDir.Z * objectRadius * offsetRatio2 * 0.5
		)

		local pos2 = Vector3.new(
			partPosition.X - perpDir.X * objectRadius * offsetRatio1 * 0.5,
			partPosition.Y,
			partPosition.Z - perpDir.Z * objectRadius * offsetRatio1 * 0.5
		)

		print("Slicing with computed values:", string.format("%.2f/%.2f", sizeValue1, sizeValue2))

		-- Clear all visuals before sending to server
		cleanupVisuals()

		-- Store slicing data
		local sliceData = {
			pos1 = pos1,
			pos2 = pos2,
			sizeValue1 = sizeValue1,
			sizeValue2 = sizeValue2,
			sliceStart = sliceStart,
			sliceEnd = sliceEnd,
		}

		-- Store relevant variables locally since they'll be wiped when exiting slice mode
		local localTargetObjectId = doughId

		-- Exit slice mode (cleanup will be handled by remote event response)
		exitSliceMode()

		-- Make sure we don't have any lingering visuals
		task.defer(function()
			-- Do a double check for any visuals that might have been missed
			for _, obj in pairs(Workspace:GetChildren()) do
				if
					obj:IsA("BasePart")
					and (
						obj.Name == "SlicePoint"
						or obj.Name == "SliceLine"
						or obj.Name == "DrawingSurface"
						or obj.Name == "ObjectEdgeVisual"
					)
				then
					obj:Destroy()
				end
			end
		end)

		-- Send the computed slice data to the server
		local DoughRemotes = require(ReplicatedStorage.Shared.DoughRemotes)
		DoughRemotes.SliceDough:FireServer(localTargetObjectId, sliceData)
	end

	-- Handle mouse button down
	local mouseDown = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Check if slicing is still active
			if not isSlicingActive or sliceComplete then
				return
			end

			-- Project the mouse position to the object plane using GetMouseLocation for accuracy
			local mousePos = UserInputService:GetMouseLocation()
			local projectedPosition = projectToObjectPlane(mousePos)

			if projectedPosition and isPointWithinObject(projectedPosition) then
				-- Start drawing the slice
				isDrawing = true
				mouseIsDown = true
				sliceStart = projectedPosition

				-- Create a visual point where the slice starts
				createPointVisual(sliceStart, Color3.fromRGB(0, 255, 0))
			end
		elseif input.KeyCode == Enum.KeyCode.E then
			-- User pressed E to cancel slicing
			exitSliceMode()
		end
	end)

	-- Handle mouse button up
	local mouseUp = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 and mouseIsDown then
			-- Check if slicing is still active
			if not isSlicingActive or sliceComplete then
				return
			end

			-- End drawing the slice
			mouseIsDown = false
			isDrawing = false

			-- Only finalize the slice if we have a valid end point
			if sliceEnd then
				finalizeSlice()
			else
				exitSliceMode()
			end
		end
	end)

	-- Handle mouse movement
	local mouseMove = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement and isDrawing then
			-- Check if slicing is still active
			if not isSlicingActive or sliceComplete then
				return
			end

			-- Project the mouse position to the object plane using GetMouseLocation for accuracy
			local mousePos = UserInputService:GetMouseLocation()
			local projectedPosition = projectToObjectPlane(mousePos)

			if projectedPosition then
				-- Update the slice end point
				sliceEnd = projectedPosition

				-- Clear existing visuals (except the start point)
				for i = #sliceVisuals, 2, -1 do
					sliceVisuals[i]:Destroy()
					table.remove(sliceVisuals, i)
				end

				-- Create a visual point where the slice currently ends
				createPointVisual(sliceEnd, Color3.fromRGB(255, 0, 0))

				-- Draw a line connecting the points
				if sliceStart then
					createLineSegment(sliceStart, sliceEnd)
				end
			end
		end
	end)

	-- Clean up connections and visuals when done
	local cleanupConnections = function()
		if mouseDown then
			mouseDown:Disconnect()
		end
		if mouseUp then
			mouseUp:Disconnect()
		end
		if mouseMove then
			mouseMove:Disconnect()
		end
	end

	-- Store cleanup function to be called when the object is destroyed
	targetObject.cleanupSlice = cleanupConnections
end

return SliceSystem
