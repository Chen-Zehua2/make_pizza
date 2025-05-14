-- SliceSystem.lua
-- Handles the slicing interface and operations for any object

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local DragSystem = require(ReplicatedStorage.Shared.DragSystem)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local PlayerGui = player:WaitForChild("PlayerGui")

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

-- Function to start slicing the target object
function SliceSystem.startSlicing(object, objectClassModule)
	print("Starting to slice object...")

	-- Make sure we have the object and its class
	if not object or not object.instance then
		print("Cannot slice: invalid object")
		return
	end

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
		for _, visual in ipairs(sliceVisuals) do
			visual:Destroy()
		end
		sliceVisuals = {}

		if drawingSurface then
			drawingSurface:Destroy()
			drawingSurface = nil
		end

		if edgeVisual then
			edgeVisual:Destroy()
			edgeVisual = nil
		end
	end

	-- Function to re-enable all click detectors
	local function reenableClickDetectors()
		for clickDetector, originalDistance in pairs(disabledClickDetectors) do
			if clickDetector and clickDetector:IsDescendantOf(game) then
				clickDetector.MaxActivationDistance = originalDistance
			end
		end
		disabledClickDetectors = {}
	end

	-- Show retry message
	local function showRetryMessage()
		local retryGui = Instance.new("ScreenGui")
		retryGui.Name = "RetryMessage"
		retryGui.ResetOnSpawn = false
		retryGui.Parent = PlayerGui

		local retryFrame = Instance.new("Frame")
		retryFrame.Size = UDim2.new(0, 350, 0, 80)
		retryFrame.Position = UDim2.new(0.5, -175, 0.7, 0)
		retryFrame.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		retryFrame.BackgroundTransparency = 0.2
		retryFrame.BorderSizePixel = 0

		local cornerRadius = Instance.new("UICorner")
		cornerRadius.CornerRadius = UDim.new(0, 10)
		cornerRadius.Parent = retryFrame

		local retryText = Instance.new("TextLabel")
		retryText.Size = UDim2.new(1, -20, 1, -20)
		retryText.Position = UDim2.new(0, 10, 0, 10)
		retryText.BackgroundTransparency = 1
		retryText.Text = "Slice too short! Try drawing a longer slice."
		retryText.TextColor3 = Color3.fromRGB(255, 255, 255)
		retryText.TextSize = 16
		retryText.Font = Enum.Font.GothamBold
		retryText.Parent = retryFrame

		retryFrame.Parent = retryGui

		-- Animate in
		retryFrame.Position = UDim2.new(0.5, -175, 1.1, 0)
		retryFrame.Transparency = 1

		-- Tween in
		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local tween = TweenService:Create(retryFrame, tweenInfo, {
			Position = UDim2.new(0.5, -175, 0.7, 0),
			BackgroundTransparency = 0.2,
		})
		tween:Play()

		-- Remove after 3 seconds
		task.delay(3, function()
			-- Tween out
			local tweenOut =
				TweenService:Create(retryFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, -175, 1.1, 0),
					BackgroundTransparency = 1,
				})
			tweenOut:Play()

			tweenOut.Completed:Connect(function()
				retryGui:Destroy()
			end)
		end)

		return retryGui
	end

	-- Process the completed slice
	local function processSlice()
		if not sliceStart or not sliceEnd or not targetObject or not targetObject.instance then
			cleanupVisuals()
			return
		end

		-- Store a local reference to targetObject to prevent it becoming nil during processing
		local currentObject = targetObject
		local currentClass = objectClass

		-- Calculate the slice vector in XZ plane (ignoring Y component)
		local sliceVector = Vector3.new(sliceEnd.X - sliceStart.X, 0, sliceEnd.Z - sliceStart.Z)
		local sliceLength = sliceVector.Magnitude

		-- Directly get the object's current size from its instance
		local currentObjectSize = currentObject.instance.Size
		-- Use the wider dimension for a more consistent slice requirement
		local objectDiameter = math.max(currentObjectSize.X, currentObjectSize.Z)

		-- Calculate distance from slice to object center
		local objectCenter = Vector3.new(currentObject.instance.Position.X, 0, currentObject.instance.Position.Z)
		local sliceStartXZ = Vector3.new(sliceStart.X, 0, sliceStart.Z)
		local sliceEndXZ = Vector3.new(sliceEnd.X, 0, sliceEnd.Z)

		-- Calculate the minimum required length based on object's current size
		local minLength = objectDiameter * MINIMUM_SLICE_LENGTH_PERCENTAGE

		-- Debug information
		print("Object Diameter:", objectDiameter)
		print("Slice Length:", sliceLength)
		print("Minimum Required:", minLength)
		print("Object Center:", objectCenter)
		print("Slice Start:", sliceStartXZ)
		print("Slice End:", sliceEndXZ)

		if sliceLength >= minLength then
			-- Valid slice, proceed with slicing
			print("Valid slice! Length:", sliceLength, "Minimum:", minLength)

			-- Wait a brief moment to show completion before processing
			task.delay(0.2, function()
				-- Ensure the object still exists
				if
					not currentObject
					or not currentObject.instance
					or not currentObject.instance:IsDescendantOf(game)
				then
					print("Object no longer exists, canceling slice operation")
					cleanupVisuals()
					reenableClickDetectors()
					DragSystem.setSlicingActive(false)

					-- Reset state
					isSlicingActive = false
					isDrawing = false
					mouseIsDown = false

					-- Restore camera
					if originalCameraType then
						camera.CameraType = originalCameraType
					end
					if originalCameraSubject then
						camera.CameraSubject = originalCameraSubject
					end

					if sliceInstructions then
						sliceInstructions:Destroy()
					end

					targetObject = nil
					objectClass = nil
					return
				end

				-- Cleanup drawing objects
				cleanupVisuals()

				-- First, stop tracking the original object in the drag system
				DragSystem.untrackObject(currentObject)

				-- Call the object's slice method using pcall to catch errors
				local success, result1, result2 = pcall(function()
					return currentObject:performSlice(sliceStart, sliceEnd)
				end)

				if not success then
					print("Error during slice operation:", result1)
					reenableClickDetectors()
					DragSystem.setSlicingActive(false)
					-- Restore camera
					if originalCameraType then
						camera.CameraType = originalCameraType
					end
					if originalCameraSubject then
						camera.CameraSubject = originalCameraSubject
					end

					isSlicingActive = false
					isDrawing = false
					mouseIsDown = false
					targetObject = nil
					objectClass = nil
					return
				end

				local newObject1, newObject2 = result1, result2

				-- Start tracking the new objects in the drag system
				if newObject1 then
					DragSystem.trackObject(newObject1)

					-- Set up click detector for the new object
					local clickDetector1 = newObject1.instance:FindFirstChild("ClickDetector")
					if clickDetector1 then
						clickDetector1.MouseClick:Connect(function()
							local UISystem = require(ReplicatedStorage.Shared.UISystem)
							local CombineSystem = require(ReplicatedStorage.Shared.CombineSystem)
							-- Prevent UI from showing if combine mode is active
							if CombineSystem.isCombineActive() then
								return
							end
							-- Use the object's built-in options
							UISystem.showObjectUI(newObject1)
						end)
					end
				end

				if newObject2 then
					DragSystem.trackObject(newObject2)

					-- Set up click detector for the new object
					local clickDetector2 = newObject2.instance:FindFirstChild("ClickDetector")
					if clickDetector2 then
						clickDetector2.MouseClick:Connect(function()
							local UISystem = require(ReplicatedStorage.Shared.UISystem)
							local CombineSystem = require(ReplicatedStorage.Shared.CombineSystem)
							-- Prevent UI from showing if combine mode is active
							if CombineSystem.isCombineActive() then
								return
							end
							-- Use the object's built-in options
							UISystem.showObjectUI(newObject2)
						end)
					end
				end

				-- Reset slicing state
				isSlicingActive = false
				isDrawing = false
				mouseIsDown = false

				-- Re-enable click detectors
				reenableClickDetectors()

				-- Inform DragSystem that slicing is no longer active
				DragSystem.setSlicingActive(false)

				-- Restore camera
				camera.CameraType = originalCameraType
				camera.CameraSubject = originalCameraSubject

				if sliceInstructions then
					sliceInstructions:Destroy()
				end

				-- Reset variables
				targetObject = nil
				objectClass = nil
			end)
		else
			-- Invalid slice, show retry message
			print("Slice too short! Length:", sliceLength, "Minimum:", minLength)
			showRetryMessage()

			-- Cleanup drawing
			for _, visual in ipairs(sliceVisuals) do
				visual:Destroy()
			end
			sliceVisuals = {}

			-- Reset for another attempt
			isDrawing = false
			mouseIsDown = false
			drawingPoints = {}
			sliceStart = nil
			sliceEnd = nil
		end
	end

	-- Connect input events for slicing
	local inputStarted = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 and isSlicingActive and not isDrawing then
			mouseIsDown = true

			-- Project mouse to object plane
			local mousePos = UserInputService:GetMouseLocation()
			local hitPosition = projectToObjectPlane(mousePos)

			if hitPosition and isPointWithinObject(hitPosition) then
				isDrawing = true
				drawingPoints = {}
				sliceStart = hitPosition

				-- Create a visual point where the drawing started
				createPointVisual(sliceStart, Color3.fromRGB(0, 255, 0)) -- Green

				-- Add the point to our drawing points
				table.insert(drawingPoints, sliceStart)
			end
		elseif input.KeyCode == Enum.KeyCode.E and isSlicingActive then
			-- Clean up and cancel
			cleanupVisuals()
			isSlicingActive = false

			-- Re-enable click detectors
			reenableClickDetectors()

			-- Inform DragSystem that slicing is no longer active
			DragSystem.setSlicingActive(false)

			-- Restore camera
			camera.CameraType = originalCameraType
			camera.CameraSubject = originalCameraSubject

			if sliceInstructions then
				sliceInstructions:Destroy()
			end

			-- Reset variables
			targetObject = nil
			objectClass = nil
		end
	end)

	local inputEnded = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 and mouseIsDown then
			mouseIsDown = false

			if isDrawing then
				-- Project mouse to object plane
				local mousePos = UserInputService:GetMouseLocation()
				local hitPosition = projectToObjectPlane(mousePos)

				if hitPosition then
					-- Use the hit position directly if within object, otherwise find intersection with edge
					if isPointWithinObject(hitPosition) then
						sliceEnd = hitPosition
					else
						-- Find intersection with object edge
						local direction = (hitPosition - sliceStart).Unit
						local objectCenter = Vector3.new(objectPosition.X, hitPosition.Y, objectPosition.Z)
						local objectRadius = math.max(objectSize.X, objectSize.Z) / 2

						-- Calculate intersection with object circle in XZ plane
						local offset = hitPosition - objectCenter
						offset = Vector3.new(offset.X, 0, offset.Z)
						local normalizedOffset = offset.Unit

						sliceEnd = objectCenter + normalizedOffset * objectRadius
					end

					-- Create visual for the end point
					createPointVisual(sliceEnd, Color3.fromRGB(255, 0, 0)) -- Red

					-- Add to drawing points
					table.insert(drawingPoints, sliceEnd)

					-- Process the completed slice
					processSlice()
				else
					-- Reset if couldn't project
					isDrawing = false
					drawingPoints = {}
				end
			end
		end
	end)

	local inputChanged = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement and isDrawing and mouseIsDown then
			-- Project mouse to object plane
			local mousePos = UserInputService:GetMouseLocation()
			local hitPosition = projectToObjectPlane(mousePos)

			if hitPosition then
				local currentPoint = hitPosition

				-- If there's a previous point, draw a line to it
				if #drawingPoints > 0 then
					local prevPoint = drawingPoints[#drawingPoints]

					-- If moving a minimum distance, create a new point
					if (currentPoint - prevPoint).Magnitude > 0.3 then -- Minimum distance between points
						-- Create line from previous point to current point
						createLineSegment(prevPoint, currentPoint)

						-- Add the new point to our drawing
						table.insert(drawingPoints, currentPoint)
					end
				end
			end
		end
	end)

	-- Store cleanup function
	slicingUI = sliceInstructions

	-- Return a cleanup function
	local function cleanup()
		-- Disconnect all events
		inputStarted:Disconnect()
		inputEnded:Disconnect()
		inputChanged:Disconnect()

		-- Cleanup visuals
		cleanupVisuals()

		-- Re-enable click detectors
		reenableClickDetectors()

		-- Remove instructions
		if sliceInstructions then
			sliceInstructions:Destroy()
		end

		-- Reset slicing state
		isSlicingActive = false
		isDrawing = false
		mouseIsDown = false

		-- Inform DragSystem that slicing is no longer active
		DragSystem.setSlicingActive(false)

		-- Restore camera
		camera.CameraType = originalCameraType
		camera.CameraSubject = originalCameraSubject

		-- Reset variables
		targetObject = nil
		objectClass = nil
	end

	return cleanup
end

-- Function to cancel slicing process
function SliceSystem.cancelSlicing()
	if not isSlicingActive then
		return
	end

	print("Cancelled slicing")

	-- Reset camera
	camera.CameraType = originalCameraType or Enum.CameraType.Custom
	camera.CameraSubject = originalCameraSubject or player.Character:FindFirstChild("Humanoid")

	-- Cleanup slicing state
	if slicingUI then
		if typeof(slicingUI) == "function" then
			slicingUI() -- Call cleanup function if it's a function
		elseif slicingUI.Destroy then
			slicingUI:Destroy()
		end

		slicingUI = nil
	end

	-- Cleanup visuals
	if drawingSurface then
		drawingSurface:Destroy()
		drawingSurface = nil
	end

	if edgeVisual then
		edgeVisual:Destroy()
		edgeVisual = nil
	end

	for _, visual in ipairs(sliceVisuals) do
		visual:Destroy()
	end
	sliceVisuals = {}

	-- Re-enable click detectors
	for clickDetector, originalDistance in pairs(disabledClickDetectors) do
		if clickDetector and clickDetector:IsDescendantOf(game) then
			clickDetector.MaxActivationDistance = originalDistance
		end
	end
	disabledClickDetectors = {}

	-- Inform DragSystem that slicing is no longer active
	DragSystem.setSlicingActive(false)

	isSlicingActive = false
	sliceStart = nil
	sliceEnd = nil
	targetObject = nil
	objectClass = nil
end

return SliceSystem
