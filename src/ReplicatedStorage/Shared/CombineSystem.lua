-- CombineSystem.lua
-- Handles the selection and combining of dough objects

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local DragSystem = require(ReplicatedStorage.Shared.DragSystem)
local UISystem = require(ReplicatedStorage.Shared.UISystem)

-- Check if we're running on client or server
local isClient = RunService:IsClient()
local isServer = RunService:IsServer()

-- Client-only variables
local player
local PlayerGui
local camera
if isClient then
	player = Players.LocalPlayer
	PlayerGui = player:WaitForChild("PlayerGui")
	camera = Workspace.CurrentCamera
end

local CombineSystem = {}

-- Variables for combine mode
local isCombineActive = false
local targetDough = nil -- The main dough object that others will combine with
local selectedDoughs = {} -- Table to store the selected dough objects
local selectionBox = nil -- Visual representation of the selection area
local selectionStartPos = nil -- Starting position of the selection box
local selectionUI = nil
local selectionHighlights = {} -- Visual highlights for the selected doughs
local combineInstructions = nil -- Instructions UI
local inputStarted = nil -- Connection for input began events
local inputEnded = nil -- Connection for input ended events
local inputChanged = nil -- Connection for input changed events
local disabledClickDetectors = {} -- Store click detectors with their original distances

-- Function to check if combine mode is active
function CombineSystem.isCombineActive()
	return isCombineActive
end

-- Function to check if an object is a dough
local function isDough(object)
	if not object or not object.instance then
		return false
	end

	-- Ensure the instance is still valid (not destroyed)
	if not object.instance.Parent then
		return false
	end

	-- Check the class name
	local objectMetatable = getmetatable(object)
	while objectMetatable do
		if objectMetatable.__index and objectMetatable.__index.name then
			local className = tostring(objectMetatable.__index.name)
			if className:find("Dough") then
				return true
			end
		end
		objectMetatable = getmetatable(objectMetatable)
	end

	-- If class name approach failed, check the name property
	return object.name and object.name:find("Dough") ~= nil
end

-- Function to check if the client owns a dough object
local function clientOwnsDough(dough)
	if not isClient or not dough or not dough.instance then
		return false
	end

	-- Ensure the instance is still valid (not destroyed)
	if not dough.instance.Parent then
		return false
	end

	-- Get the creator ID from the instance attributes
	local creatorId = dough.instance:GetAttribute("CreatorId")

	-- Check if the creator ID matches the local player's ID
	return creatorId and creatorId == player.UserId
end

-- Function to get all doughs owned by the client
local function getClientOwnedDoughs()
	local ownedDoughs = {}
	local trackedObjects = DragSystem.getTrackedObjects()

	for _, obj in ipairs(trackedObjects) do
		if obj and obj.instance and isDough(obj) and clientOwnsDough(obj) then
			table.insert(ownedDoughs, obj)
		end
	end

	return ownedDoughs
end

-- Function to create a selection highlight for a dough
local function highlightDough(dough)
	if not isClient then
		return nil
	end

	if not dough or not dough.instance or selectionHighlights[dough] then
		return nil
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "SelectionHighlight"
	highlight.FillColor = Color3.fromRGB(0, 255, 0) -- Green for selection
	highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0.3
	highlight.Adornee = dough.instance
	highlight.Parent = dough.instance

	selectionHighlights[dough] = highlight

	-- Play a small selection effect
	local original = dough.instance.Size
	TweenService:Create(dough.instance, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = original * 1.05,
	}):Play()

	task.delay(0.1, function()
		if dough.instance then
			TweenService:Create(dough.instance, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = original,
			}):Play()
		end
	end)

	return highlight
end

-- Function to remove all highlights
local function removeAllHighlights()
	if not isClient then
		return
	end

	for dough, highlight in pairs(selectionHighlights) do
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end

	selectionHighlights = {}
end

-- Function to start combine mode
function CombineSystem.startCombining(dough)
	if not isClient then
		return
	end

	print("Starting combine mode with dough:", dough.name)

	-- Validate that we have a dough object
	if not dough or not dough.instance or not isDough(dough) then
		print("Cannot combine: invalid dough object")
		return
	end

	-- Verify that the dough is owned by the client
	if not clientOwnsDough(dough) then
		print("Cannot combine: you don't own this dough")
		return
	end

	-- Check doneness value before allowing combine
	local doneness = 0
	if dough.instance:FindFirstChild("Doneness") then
		doneness = dough.instance.Doneness.Value
	elseif dough.doneness then
		doneness = dough.doneness
	end

	if doneness > 0 then
		print("Cannot combine: dough has already started cooking (doneness > 0)")
		return
	end

	-- Store the target dough
	targetDough = dough

	-- Set the combine flag
	isCombineActive = true

	-- Pre-fetch all dough objects for faster selection
	local trackedObjects = DragSystem.getTrackedObjects()
	local allDoughObjects = {}
	for _, obj in ipairs(trackedObjects) do
		if obj and obj.instance and isDough(obj) and obj ~= targetDough then
			table.insert(allDoughObjects, obj)
		end
	end

	-- Disable all click detectors to prevent UI from showing
	disabledClickDetectors = {}
	for _, obj in ipairs(trackedObjects) do
		if obj and obj.instance then
			local clickDetector = obj.instance:FindFirstChild("ClickDetector")
			if clickDetector and clickDetector.MaxActivationDistance > 0 then
				-- Store the original distance to restore later
				disabledClickDetectors[clickDetector] = clickDetector.MaxActivationDistance
				-- Set to 0 to disable click detection
				clickDetector.MaxActivationDistance = 0
			end
		end
	end

	-- Add highlight to target dough
	local targetHighlight = Instance.new("Highlight")
	targetHighlight.Name = "TargetHighlight"
	targetHighlight.FillColor = Color3.fromRGB(255, 215, 0) -- Gold for target
	targetHighlight.OutlineColor = Color3.fromRGB(255, 215, 0)
	targetHighlight.FillTransparency = 0.7
	targetHighlight.OutlineTransparency = 0.3
	targetHighlight.Adornee = dough.instance
	targetHighlight.Parent = dough.instance

	selectionHighlights[dough] = targetHighlight

	-- Create UI to show instructions
	local instructions = Instance.new("ScreenGui")
	instructions.Name = "CombineInstructions"
	instructions.ResetOnSpawn = false
	instructions.Parent = PlayerGui

	local instructionFrame = Instance.new("Frame")
	instructionFrame.Size = UDim2.new(0, 400, 0, 100)
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
	instructionText.Text =
		"COMBINE MODE\n\nClick on doughs or drag to select multiple doughs\nPress ENTER to combine all selected doughs\nPress E to cancel"
	instructionText.TextColor3 = Color3.fromRGB(255, 255, 255)
	instructionText.TextSize = 16
	instructionText.Font = Enum.Font.GothamBold
	instructionText.Parent = instructionFrame

	-- Selection count display
	local countFrame = Instance.new("Frame")
	countFrame.Size = UDim2.new(0, 200, 0, 40)
	countFrame.Position = UDim2.new(0.5, -100, 0, 130)
	countFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	countFrame.BackgroundTransparency = 0.5
	countFrame.BorderSizePixel = 0

	local countCorner = Instance.new("UICorner")
	countCorner.CornerRadius = UDim.new(0, 10)
	countCorner.Parent = countFrame

	local countText = Instance.new("TextLabel")
	countText.Name = "CountText"
	countText.Size = UDim2.new(1, -20, 1, -10)
	countText.Position = UDim2.new(0, 10, 0, 5)
	countText.BackgroundTransparency = 1
	countText.Text = "Selected: 0 doughs"
	countText.TextColor3 = Color3.fromRGB(255, 255, 255)
	countText.TextSize = 16
	countText.Font = Enum.Font.GothamSemibold
	countText.Parent = countFrame

	instructionFrame.Parent = instructions
	countFrame.Parent = instructions

	combineInstructions = instructions

	-- Initialize selection box for drag selection
	local selectionBoxGui = Instance.new("ScreenGui")
	selectionBoxGui.Name = "SelectionBoxGui"
	selectionBoxGui.ResetOnSpawn = false
	selectionBoxGui.Parent = PlayerGui

	local selectionBoxFrame = Instance.new("Frame")
	selectionBoxFrame.Name = "SelectionBox"
	selectionBoxFrame.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	selectionBoxFrame.BackgroundTransparency = 0.7
	selectionBoxFrame.BorderColor3 = Color3.fromRGB(0, 200, 0)
	selectionBoxFrame.BorderSizePixel = 2
	selectionBoxFrame.Visible = false
	selectionBoxFrame.Parent = selectionBoxGui

	selectionBox = selectionBoxFrame

	-- Connect input events
	-- Disconnect existing connections if any
	if inputStarted then
		inputStarted:Disconnect()
	end
	if inputEnded then
		inputEnded:Disconnect()
	end
	if inputChanged then
		inputChanged:Disconnect()
	end

	-- Function to update selection count display
	local function updateSelectionCount()
		-- Update the count text based on actually selected doughs, not highlights
		local combineCount = #selectedDoughs

		-- Update the count text
		local countDisplay = combineInstructions:FindFirstChild("CountText", true)
		if countDisplay then
			countDisplay.Text = string.format("Selected: %d dough%s", combineCount, combineCount == 1 and "" or "s")
		end
	end

	-- Function to exit combine mode
	local function exitCombineMode()
		-- Reset combine flag
		isCombineActive = false

		-- Clear all highlights
		removeAllHighlights()

		-- Restore click detectors
		for clickDetector, distance in pairs(disabledClickDetectors) do
			if clickDetector and clickDetector.Parent then
				clickDetector.MaxActivationDistance = distance
			end
		end
		disabledClickDetectors = {}

		-- Remove UIs
		if combineInstructions then
			combineInstructions:Destroy()
			combineInstructions = nil
		end

		if selectionBox and selectionBox.Parent then
			selectionBox.Parent:Destroy()
			selectionBox = nil
		end

		-- Disconnect input events
		if inputStarted then
			inputStarted:Disconnect()
			inputStarted = nil
		end
		if inputEnded then
			inputEnded:Disconnect()
			inputEnded = nil
		end
		if inputChanged then
			inputChanged:Disconnect()
			inputChanged = nil
		end

		-- Reset variables
		targetDough = nil
		selectionStartPos = nil
		selectedDoughs = {}

		print("Exited combine mode")
	end

	-- Function to find doughs in selection box
	local function findDoughsInSelectionBox(startX, startY, endX, endY)
		-- Normalize the coordinates (ensure start < end)
		local x1, x2 = math.min(startX, endX), math.max(startX, endX)
		local y1, y2 = math.min(startY, endY), math.max(startY, endY)

		-- Clear existing highlights (except target) and reset selected doughs
		selectedDoughs = {} -- Reset the selected doughs array completely
		for dough, highlight in pairs(selectionHighlights) do
			if dough ~= targetDough then
				if highlight and highlight.Parent then
					highlight:Destroy()
				end
				selectionHighlights[dough] = nil
			end
		end

		-- Track dough IDs to prevent duplicates
		local processedDoughIds = {}

		-- Get all tracked objects from the drag system
		local trackedObjects = DragSystem.getTrackedObjects()
		local selectedCount = 0

		-- Create a camera-based selection filter
		local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
		local maxDistance = Vector2.new(camera.ViewportSize.X, camera.ViewportSize.Y).Magnitude / 2

		-- Fast early filter based on screen position
		-- Create a table to cache screen positions to avoid recomputing
		local screenPositions = {}

		-- For faster position calculations
		local function getScreenPosition(obj)
			if not screenPositions[obj] and obj.instance and obj.instance.Parent then
				screenPositions[obj] = camera:WorldToScreenPoint(obj.instance.Position)
			end
			return screenPositions[obj]
		end

		print("Starting box selection with box coordinates:", x1, y1, "to", x2, y2)

		-- Process all objects at once instead of nested loops
		for _, obj in ipairs(trackedObjects) do
			-- Skip invalid objects
			if not obj or not obj.instance or not obj.instance.Parent then
				continue
			end

			-- Skip target dough and non-client owned doughs
			if obj == targetDough or not isDough(obj) or not clientOwnsDough(obj) then
				continue
			end

			-- Get the dough ID to prevent duplicates
			local doughId = obj.instance:GetAttribute("DoughId")
			if not doughId or processedDoughIds[doughId] then
				continue
			end

			-- Mark this dough ID as processed
			processedDoughIds[doughId] = true

			-- Get screen position (with caching)
			local screenPos = getScreenPosition(obj)
			if not screenPos or screenPos.Z <= 0 then
				continue
			end

			-- Check if the object is within the selection box
			if screenPos.X >= x1 and screenPos.X <= x2 and screenPos.Y >= y1 and screenPos.Y <= y2 then
				-- Add to selectedDoughs array
				table.insert(selectedDoughs, obj)
				selectedCount = selectedCount + 1

				-- Highlight the dough
				highlightDough(obj)
			end
		end

		print("Selected", selectedCount, "unique doughs in box selection")

		-- Update the selection count display
		updateSelectionCount()
	end

	-- Create an efficient set of client-owned dough instances for raycasting
	local function getClientOwnedDoughInstances()
		local result = {}
		local processedIds = {}

		for _, obj in ipairs(DragSystem.getTrackedObjects()) do
			-- Skip invalid objects, the target, and non-client owned
			if not obj or not obj.instance or not obj.instance.Parent then
				continue
			end

			if obj == targetDough or not isDough(obj) or not clientOwnsDough(obj) then
				continue
			end

			-- Get the dough ID
			local doughId = obj.instance:GetAttribute("DoughId")
			if not doughId or processedIds[doughId] then
				continue
			end

			-- Mark as processed
			processedIds[doughId] = true

			-- Add to instances for raycast
			table.insert(result, obj.instance)
		end

		return result
	end

	-- Function to combine all selected dough objects with the target
	local function combineSelectedDoughs()
		if not isClient then
			return
		end

		-- Make sure we have a target and at least one selected dough
		if not targetDough or #selectedDoughs == 0 then
			print("Nothing to combine")
			return
		end

		-- Verify that the target dough is owned by the client
		if not clientOwnsDough(targetDough) then
			print("Cannot combine: target dough is not owned by you")
			exitCombineMode()
			return
		end

		-- Check target dough doneness
		local targetDoneness = 0
		if targetDough.instance:FindFirstChild("Doneness") then
			targetDoneness = targetDough.instance.Doneness.Value
		elseif targetDough.doneness then
			targetDoneness = targetDough.doneness
		end

		if targetDoneness > 0 then
			print("Cannot combine: target dough has already started cooking (doneness > 0)")
			exitCombineMode()
			return
		end

		print("Combining", #selectedDoughs, "doughs into", targetDough.name)

		-- Create a table to track dough IDs we've already processed
		local processedDoughIds = {}
		local doughIds = {}
		local totalSizeValue = targetDough.sizeValue or 1

		-- Target dough ID for validation
		local targetDoughId = targetDough.instance and targetDough.instance:GetAttribute("DoughId")
		if not targetDoughId then
			print("Cannot combine: target dough has no ID")
			exitCombineMode()
			return
		end

		-- Track the target dough ID to prevent selecting it
		processedDoughIds[targetDoughId] = true

		-- Optimize validation by using a single pass through the selected doughs
		for _, dough in ipairs(selectedDoughs) do
			-- Skip invalid objects or the target
			if not dough or not dough.instance or not dough.instance.Parent or dough == targetDough then
				continue
			end

			-- Get dough ID and check validity
			local doughId = dough.instance:GetAttribute("DoughId")
			if not doughId or doughId == targetDoughId or processedDoughIds[doughId] or not clientOwnsDough(dough) then
				continue
			end

			-- Check doneness value
			local doughDoneness = 0
			if dough.instance:FindFirstChild("Doneness") then
				doughDoneness = dough.instance.Doneness.Value
			elseif dough.doneness then
				doughDoneness = dough.doneness
			end

			if doughDoneness > 0 then
				print("Skipping dough ID " .. doughId .. ": already cooking (doneness > 0)")
				continue
			end

			-- Add to the combine list
			processedDoughIds[doughId] = true
			table.insert(doughIds, doughId)
			totalSizeValue = totalSizeValue + (dough.sizeValue or 1)
		end

		-- Check if we have any doughs to combine
		if #doughIds == 0 then
			print("No valid doughs to combine after validation")
			exitCombineMode()
			return
		end

		print("Combining", #doughIds, "doughs into target ID =", targetDoughId)

		-- Send to server with optimized data
		local DoughRemotes = require(ReplicatedStorage.Shared.DoughRemotes)
		DoughRemotes.CombineDoughs:FireServer(targetDoughId, doughIds, totalSizeValue)

		-- Immediately update the target dough size value locally for responsiveness
		targetDough.sizeValue = totalSizeValue

		-- Exit combine mode
		exitCombineMode()
	end

	-- Handle mouse button down for selection
	inputStarted = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Start selection box
			selectionStartPos = Vector2.new(input.Position.X, input.Position.Y)
			selectionBox.Position = UDim2.fromOffset(selectionStartPos.X, selectionStartPos.Y)
			selectionBox.Size = UDim2.fromOffset(0, 0)
			selectionBox.Visible = true
		elseif input.KeyCode == Enum.KeyCode.E then
			-- Cancel combine mode
			exitCombineMode()
		elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			-- Complete the combine operation
			combineSelectedDoughs()
		end
	end)

	-- Handle mouse button up for selection
	inputEnded = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 and selectionStartPos then
			-- Hide the selection box
			selectionBox.Visible = false

			-- If the selection box is very small, treat it as a click
			local endPos = Vector2.new(input.Position.X, input.Position.Y)
			local deltaSize = (endPos - selectionStartPos).Magnitude

			if deltaSize < 10 then
				-- Cast a ray to see if a dough was clicked
				local ray = camera:ScreenPointToRay(endPos.X, endPos.Y)
				local raycastParams = RaycastParams.new()
				raycastParams.FilterType = Enum.RaycastFilterType.Whitelist

				-- Get valid dough instances efficiently using the helper function
				raycastParams.FilterDescendantsInstances = getClientOwnedDoughInstances()

				local result = Workspace:Raycast(ray.Origin, ray.Direction * 100, raycastParams)

				if result and result.Instance then
					-- Get the owner object using the optimized map lookup
					local obj = DragSystem.getObjectFromInstance(result.Instance)

					if obj and obj ~= targetDough and clientOwnsDough(obj) then
						local doughId = obj.instance:GetAttribute("DoughId")
						if doughId then
							print("Click-selecting client-owned dough ID:", doughId)

							-- Toggle the highlight for this dough
							if selectionHighlights[obj] then
								-- Remove highlight
								if selectionHighlights[obj].Parent then
									selectionHighlights[obj]:Destroy()
								end
								selectionHighlights[obj] = nil

								-- Remove from selectedDoughs array
								for i, selectedDough in ipairs(selectedDoughs) do
									if selectedDough == obj then
										table.remove(selectedDoughs, i)
										break
									end
								end

								print("Unselected dough ID:", doughId)
							else
								-- Add highlight
								highlightDough(obj)

								-- Check if dough is already in the selected list
								local alreadySelected = false
								for _, selectedDough in ipairs(selectedDoughs) do
									if selectedDough == obj then
										alreadySelected = true
										break
									end
								end

								-- Add to selectedDoughs array only if not already there
								if not alreadySelected then
									table.insert(selectedDoughs, obj)
									print("Selected dough ID:", doughId)
								else
									print("Dough already selected, ignoring")
								end
							end

							-- Update the selection count
							updateSelectionCount()
						end
					end
				end
			else
				-- Process the selection box results
				findDoughsInSelectionBox(selectionStartPos.X, selectionStartPos.Y, endPos.X, endPos.Y)
			end

			-- Reset the selection start position
			selectionStartPos = nil
		end
	end)

	-- Handle mouse movement for selection box
	inputChanged = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement and selectionStartPos then
			-- Update the selection box size and position
			local currentPos = Vector2.new(input.Position.X, input.Position.Y)
			local topLeft =
				Vector2.new(math.min(selectionStartPos.X, currentPos.X), math.min(selectionStartPos.Y, currentPos.Y))
			local size =
				Vector2.new(math.abs(currentPos.X - selectionStartPos.X), math.abs(currentPos.Y - selectionStartPos.Y))

			selectionBox.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
			selectionBox.Size = UDim2.fromOffset(size.X, size.Y)
		end
	end)

	-- Store the UI for cleanup
	selectionUI = selectionBoxGui
end

return CombineSystem
