-- SplitSystem.lua
-- Handles the splitting interface and operations for any object

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local DragSystem = require(ReplicatedStorage.Shared.DragSystem)
local NotificationSystem = require(ReplicatedStorage.Shared.UILib.Shared.NotificationSystem)

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

local SplitSystem = {}

-- Constants
local MINIMUM_SPLIT_LENGTH_PERCENTAGE = 0.4 -- Require splits to go through at least 40% of the diameter
local MINIMUM_SPLIT_RATIO = 0.01 -- Minimum ratio for a split piece

-- Variables for split mode
local isSplittingActive = false
local splitStart = nil
local splitEnd = nil
local splittingUI = nil
local drawingSurface = nil
local edgeVisual = nil
local splitVisuals = {}
local targetObject = nil
local objectClass = nil
local originalCameraType = nil
local originalCameraSubject = nil
local disabledClickDetectors = {} -- Store click detectors with their original distances
local splitComplete = false -- Flag to prevent multiple split attempts

-- Variables for split drawing
local isDrawing = false
local drawingPoints = {}
local mouseIsDown = false

-- Mouse event connections
local mouseDown = nil
local mouseUp = nil
local mouseMove = nil

-- Forward declaration of finalizeSplit function
local finalizeSplit

-- Function to start splitting the target object
function SplitSystem.startSplitting(object, objectClassModule)
	if not isClient then
		return -- Only run on client
	end

	print("Starting to split object...")

	-- Make sure we have the object and its class
	if not object or not object.instance then
		print("Cannot split: invalid object")
		NotificationSystem.showError("Cannot split: invalid object")
		return
	end

	-- Check if the object's size value is too small to split
	local currentSizeValue = object.sizeValue or 1
	if currentSizeValue <= MINIMUM_SPLIT_RATIO then
		NotificationSystem.showError("Cannot split: object is too small (minimum size: " .. MINIMUM_SPLIT_RATIO .. ")")
		return
	end

	-- Reset the splitting state
	splitComplete = false

	-- Store the object and its class
	targetObject = object
	objectClass = objectClassModule

	-- Notify DragSystem that splitting is active to prevent dragging
	DragSystem.setSplittingActive(true)

	-- Set splitting active flag to control input
	isSplittingActive = true

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

	-- Create UI to show splitting instructions
	local splitInstructions = Instance.new("ScreenGui")
	splitInstructions.Name = "SplitInstructions"
	splitInstructions.ResetOnSpawn = false
	splitInstructions.Parent = PlayerGui

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
	instructionText.Text = "SPLIT MODE: Click and drag to split\nPress E to cancel"
	instructionText.TextColor3 = Color3.fromRGB(255, 255, 255)
	instructionText.TextSize = 16
	instructionText.Font = Enum.Font.GothamBold
	instructionText.Parent = instructionFrame

	instructionFrame.Parent = splitInstructions

	splittingUI = splitInstructions

	-- Create visual representation of a point
	local function createPointVisual(position, color)
		local point = Instance.new("Part")
		point.Name = "SplitPoint"
		point.Shape = Enum.PartType.Ball
		point.Size = Vector3.new(0.2, 0.2, 0.2) -- Smaller points
		point.Position = position
		point.Color = color or Color3.fromRGB(255, 100, 100)
		point.Material = Enum.Material.Neon
		point.CanCollide = false
		point.Anchored = true
		point.Parent = Workspace

		table.insert(splitVisuals, point)
		return point
	end

	-- Create a line segment with thinner line
	local function createLineSegment(fromPos, toPos)
		local direction = (toPos - fromPos)
		local distance = direction.Magnitude

		local line = Instance.new("Part")
		line.Name = "SplitLine"
		line.Size = Vector3.new(0.05, 0.05, distance) -- Thinner line
		line.CFrame = CFrame.lookAt(fromPos, toPos) * CFrame.new(0, 0, -distance / 2)
		line.Anchored = true
		line.CanCollide = false
		line.Color = Color3.fromRGB(255, 0, 0)
		line.Material = Enum.Material.Neon
		line.Parent = Workspace

		table.insert(splitVisuals, line)
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
		for _, visual in ipairs(splitVisuals) do
			if visual and visual.Parent then
				visual:Destroy()
			end
		end
		splitVisuals = {}

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

	-- Function to clean up the split mode
	local function exitSplitMode()
		-- Reset split flags and data
		isSplittingActive = false
		splitStart = nil
		splitEnd = nil

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

		-- Make sure the split drawings are removed
		for _, obj in pairs(Workspace:GetChildren()) do
			if
				obj:IsA("BasePart")
				and (
					obj.Name == "SplitPoint"
					or obj.Name == "SplitLine"
					or obj.Name == "DrawingSurface"
					or obj.Name == "ObjectEdgeVisual"
				)
			then
				obj:Destroy()
			end
		end

		-- Re-enable click detectors
		restoreClickDetectors()

		-- Notify DragSystem that splitting is no longer active
		DragSystem.setSplittingActive(false)

		-- Remove the splitting UI
		if splittingUI then
			splittingUI:Destroy()
			splittingUI = nil
		end

		-- Clear the target object
		targetObject = nil
		print("Exited split mode")
	end

	-- Function to connect input handlers (extracted for reuse)
	local function connectInputHandlers()
		-- Disconnect existing connections if any
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

		-- Handle mouse button down for selection
		mouseDown = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				-- Check if splitting is still active
				if not isSplittingActive or splitComplete then
					return
				end

				-- Project the mouse position to the object plane using GetMouseLocation for accuracy
				local mousePos = UserInputService:GetMouseLocation()
				local projectedPosition = projectToObjectPlane(mousePos)

				if projectedPosition and isPointWithinObject(projectedPosition) then
					-- Start drawing the split
					isDrawing = true
					mouseIsDown = true
					splitStart = projectedPosition

					-- Create a visual point where the split starts
					createPointVisual(splitStart, Color3.fromRGB(0, 255, 0))
				end
			elseif input.KeyCode == Enum.KeyCode.E then
				-- User pressed E to cancel splitting
				exitSplitMode()
			end
		end)

		-- Handle mouse button up for selection
		mouseUp = UserInputService.InputEnded:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseButton1 and mouseIsDown then
				-- Check if splitting is still active
				if not isSplittingActive or splitComplete then
					return
				end

				-- End drawing the split
				mouseIsDown = false
				isDrawing = false

				-- Only finalize the split if we have a valid end point
				if splitEnd then
					finalizeSplit()
				else
					-- No drag occurred (only green dot), clean up visuals and reset for retry
					cleanupVisuals()
					splitComplete = false
					splitStart = nil
					splitEnd = nil
				end
			end
		end)

		-- Handle mouse movement for selection
		mouseMove = UserInputService.InputChanged:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end

			if input.UserInputType == Enum.UserInputType.MouseMovement and isDrawing then
				-- Check if splitting is still active
				if not isSplittingActive or splitComplete then
					return
				end

				-- Project the mouse position to the object plane using GetMouseLocation for accuracy
				local mousePos = UserInputService:GetMouseLocation()
				local projectedPosition = projectToObjectPlane(mousePos)

				if projectedPosition then
					-- Update the split end point
					splitEnd = projectedPosition

					-- Clear existing visuals (except the start point)
					for i = #splitVisuals, 2, -1 do
						splitVisuals[i]:Destroy()
						table.remove(splitVisuals, i)
					end

					-- Create a visual point where the split currently ends
					createPointVisual(splitEnd, Color3.fromRGB(255, 0, 0))

					-- Draw a line connecting the points
					if splitStart then
						createLineSegment(splitStart, splitEnd)
					end
				end
			end
		end)
	end

	-- Function to finalize and perform the split
	finalizeSplit = function()
		-- Prevent multiple split attempts
		if splitComplete then
			print("Split already completed, ignoring additional split attempt")
			return
		end

		-- Make sure we have valid target object
		if not targetObject or not targetObject.instance then
			print("Invalid split: missing target object or instance")
			NotificationSystem.showError("Invalid split: missing target object")
			-- Clear visuals and reset split complete flag to allow retry
			cleanupVisuals()
			splitComplete = false
			splitStart = nil
			splitEnd = nil
			return
		end

		-- Make sure we have valid start and end points for the split
		if not splitStart or not splitEnd then
			print("Invalid split: missing start or end point")
			NotificationSystem.showError("Invalid split: incomplete split line")
			-- Clear visuals and reset split complete flag to allow retry
			cleanupVisuals()
			splitComplete = false
			splitStart = nil
			splitEnd = nil
			return
		end

		-- Set split as complete to prevent multiple attempts
		splitComplete = true

		-- Check if the split is long enough (considering the object's radius)
		local objectRadius = math.max(objectSize.X, objectSize.Z) / 2
		local splitLength = (splitEnd - splitStart).Magnitude
		local splitLengthRatio = splitLength / (objectRadius * 2)

		if splitLengthRatio < MINIMUM_SPLIT_LENGTH_PERCENTAGE then
			print(
				"Split too short, must be at least " .. (MINIMUM_SPLIT_LENGTH_PERCENTAGE * 100) .. "% of the diameter"
			)
			NotificationSystem.showError(
				"Split too short, must be at least " .. (MINIMUM_SPLIT_LENGTH_PERCENTAGE * 100) .. "% of the diameter"
			)
			-- Clear visuals and reset split complete flag to allow retry
			cleanupVisuals()
			splitComplete = false
			splitStart = nil
			splitEnd = nil
			return
		end

		-- Get the dough ID to split server-side
		local doughId = targetObject.instance:GetAttribute("DoughId")
		if not doughId then
			warn("Cannot split: missing DoughId attribute")
			NotificationSystem.showError("Cannot split: missing object ID")
			-- Clear visuals and reset split complete flag to allow retry
			cleanupVisuals()
			splitComplete = false
			splitStart = nil
			splitEnd = nil
			return
		end

		-- Stop receiving input immediately to prevent further split actions
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

		-- Calculate split direction and perform client-side calculations
		-- This is now done client-side instead of sending raw split points to server

		-- Get all the necessary values for the calculation
		local part = targetObject.instance
		local partPosition = part.Position
		local partSize = part.Size
		local sizeValue = part:FindFirstChild("SizeValue") and part.SizeValue.Value or 1

		-- Calculate the split direction and normalize it to XZ plane
		local splitDir = Vector3.new(splitEnd.X - splitStart.X, 0, splitEnd.Z - splitStart.Z).Unit

		-- Calculate perpendicular vector to the split (for offsetting the new bases)
		local perpDir = Vector3.new(-splitDir.Z, 0, splitDir.X)

		-- Calculate part center in XZ plane
		local partCenterXZ = Vector3.new(partPosition.X, 0, partPosition.Z)

		-- Calculate split center in XZ plane
		local splitCenter = Vector3.new((splitStart.X + splitEnd.X) / 2, 0, (splitStart.Z + splitEnd.Z) / 2)

		-- Calculate distance from split center to part center
		local centerToSplit = (splitCenter - partCenterXZ).Magnitude

		-- Calculate the ratio for splitting (0.5 means perfect middle, closer to 0 or 1 means uneven)
		local splitRatio = math.clamp(centerToSplit / objectRadius, 0.01, 0.99)

		-- Calculate size values for the two halves
		local largerSideRatio = 0.5 + (splitRatio * 0.5) -- Ranges from 0.5 to 1.0
		local smallerSideRatio = 1 - largerSideRatio -- Ranges from 0.5 to 0.0

		-- Determine which side is smaller (the one the split is closer to)
		local sideSign = perpDir:Dot(splitCenter - partCenterXZ)

		-- Assign size values based on which side is smaller
		local sizeValue1, sizeValue2
		if sideSign >= 0 then
			-- Split is closer to side 2
			sizeValue1 = sizeValue * largerSideRatio
			sizeValue2 = sizeValue * smallerSideRatio
		else
			-- Split is closer to side 1
			sizeValue1 = sizeValue * smallerSideRatio
			sizeValue2 = sizeValue * largerSideRatio
		end

		-- Check minimum split ratio and adjust if necessary
		if sizeValue1 < MINIMUM_SPLIT_RATIO or sizeValue2 < MINIMUM_SPLIT_RATIO then
			-- Determine which piece is too small
			if sizeValue1 < MINIMUM_SPLIT_RATIO then
				-- Adjust sizeValue1 to minimum and reduce sizeValue2 accordingly
				local deficit = MINIMUM_SPLIT_RATIO - sizeValue1
				sizeValue1 = MINIMUM_SPLIT_RATIO
				sizeValue2 = sizeValue2 - deficit

				-- Check if sizeValue2 is still valid
				if sizeValue2 < MINIMUM_SPLIT_RATIO then
					NotificationSystem.showError(
						"Cannot split: would result in pieces too small (minimum: " .. MINIMUM_SPLIT_RATIO .. ")"
					)
					-- Clear visuals and reset split complete flag to allow retry
					cleanupVisuals()
					splitComplete = false
					splitStart = nil
					splitEnd = nil
					-- Reconnect input handlers to allow retry
					connectInputHandlers()
					return
				end
			elseif sizeValue2 < MINIMUM_SPLIT_RATIO then
				-- Adjust sizeValue2 to minimum and reduce sizeValue1 accordingly
				local deficit = MINIMUM_SPLIT_RATIO - sizeValue2
				sizeValue2 = MINIMUM_SPLIT_RATIO
				sizeValue1 = sizeValue1 - deficit

				-- Check if sizeValue1 is still valid
				if sizeValue1 < MINIMUM_SPLIT_RATIO then
					NotificationSystem.showError(
						"Cannot split: would result in pieces too small (minimum: " .. MINIMUM_SPLIT_RATIO .. ")"
					)
					-- Clear visuals and reset split complete flag to allow retry
					cleanupVisuals()
					splitComplete = false
					splitStart = nil
					splitEnd = nil
					-- Reconnect input handlers to allow retry
					connectInputHandlers()
					return
				end
			end
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

		print("Splitting with computed values:", string.format("%.2f/%.2f", sizeValue1, sizeValue2))

		-- Clear all visuals before sending to server
		cleanupVisuals()

		-- Store splitting data
		local splitData = {
			pos1 = pos1,
			pos2 = pos2,
			sizeValue1 = sizeValue1,
			sizeValue2 = sizeValue2,
			splitStart = splitStart,
			splitEnd = splitEnd,
		}

		-- Store relevant variables locally since they'll be wiped when exiting split mode
		local localTargetObjectId = doughId

		-- Exit split mode (cleanup will be handled by remote event response)
		exitSplitMode()

		-- Make sure we don't have any lingering visuals
		task.defer(function()
			-- Do a double check for any visuals that might have been missed
			for _, obj in pairs(Workspace:GetChildren()) do
				if
					obj:IsA("BasePart")
					and (
						obj.Name == "SplitPoint"
						or obj.Name == "SplitLine"
						or obj.Name == "DrawingSurface"
						or obj.Name == "ObjectEdgeVisual"
					)
				then
					obj:Destroy()
				end
			end
		end)

		-- Send the computed split data to the server
		local DoughRemotes = require(ReplicatedStorage.Shared.DoughRemotes)
		DoughRemotes.SplitDough:FireServer(localTargetObjectId, splitData)
	end

	-- Connect input events using the extracted function
	connectInputHandlers()

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
	targetObject.cleanupSplit = cleanupConnections
end

return SplitSystem
