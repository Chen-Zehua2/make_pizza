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

local player = Players.LocalPlayer
local PlayerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

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

-- Function to check if an object is a dough
local function isDough(object)
	if not object or not object.instance then
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

-- Function to create a selection highlight for a dough
local function highlightDough(dough)
	if not dough or not dough.instance or selectionHighlights[dough] then
		return
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
	for dough, highlight in pairs(selectionHighlights) do
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end

	selectionHighlights = {}
end

-- Function to start combine mode
function CombineSystem.startCombining(dough)
	print("Starting combine mode with dough:", dough.name)

	-- Validate that we have a dough object
	if not dough or not dough.instance or not isDough(dough) then
		print("Cannot combine: invalid dough object")
		return
	end

	-- Store the target dough
	targetDough = dough

	-- Set the combine flag
	isCombineActive = true

	-- Disable all click detectors to prevent UI from showing
	disabledClickDetectors = {}
	local trackedObjects = DragSystem.getTrackedObjects()
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
		local count = 0
		for _ in pairs(selectionHighlights) do
			count = count + 1
		end

		-- Target dough is included in the count but doesn't contribute to combine
		local combineCount = count - 1

		-- Update the count text
		local countDisplay = combineInstructions:FindFirstChild("CountText", true)
		if countDisplay then
			countDisplay.Text = string.format("Selected: %d dough%s", combineCount, combineCount == 1 and "" or "s")
		end
	end

	-- Function to find doughs in selection box
	local function findDoughsInSelectionBox(startX, startY, endX, endY)
		-- Normalize the coordinates (ensure start < end)
		local x1, x2 = math.min(startX, endX), math.max(startX, endX)
		local y1, y2 = math.min(startY, endY), math.max(startY, endY)

		-- Get all doughs in the workspace
		for _, obj in pairs(Workspace:GetChildren()) do
			if obj:IsA("BasePart") and obj.Name:find("Dough") then
				-- Check if this is a valid dough object
				local viewportPos = camera:WorldToViewportPoint(obj.Position)
				local x, y = viewportPos.X, viewportPos.Y

				-- Check if the dough is within the selection box
				if x >= x1 and x <= x2 and y >= y1 and y <= y2 and viewportPos.Z > 0 then
					-- Try to find the dough object in the DragSystem tracked objects
					local foundObject = DragSystem.getObjectFromInstance(obj)

					if foundObject and isDough(foundObject) and foundObject ~= targetDough then
						-- Add to selection if not already selected
						if not selectionHighlights[foundObject] then
							selectedDoughs[foundObject] = true
							highlightDough(foundObject)
							updateSelectionCount()
						end
					end
				end
			end
		end
	end

	-- Input handling
	inputStarted = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Start selection box
			selectionStartPos = Vector2.new(input.Position.X, input.Position.Y)
			selectionBox.Position = UDim2.new(0, selectionStartPos.X, 0, selectionStartPos.Y)
			selectionBox.Size = UDim2.new(0, 0, 0, 0)
			selectionBox.Visible = true

			-- Check if clicked directly on a dough
			local mousePos = UserInputService:GetMouseLocation()
			local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

			-- Cast ray from camera through mouse position
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Whitelist

			-- Add all dough instances to the filter
			local instances = {}
			local trackedObjects = DragSystem.getTrackedObjects()
			for _, obj in ipairs(trackedObjects) do
				if obj and obj.instance and isDough(obj) then
					table.insert(instances, obj.instance)
				end
			end

			if #instances == 0 then
				return
			end

			raycastParams.FilterDescendantsInstances = instances

			-- Perform the raycast
			local result = Workspace:Raycast(ray.Origin, ray.Direction * 100, raycastParams)

			if result and result.Instance then
				-- Find the clicked object
				local clickedDough = DragSystem.getObjectFromInstance(result.Instance)

				if clickedDough and isDough(clickedDough) and clickedDough ~= targetDough then
					print("Clicked on dough:", clickedDough.name)
					-- Toggle selection
					if selectionHighlights[clickedDough] then
						-- Deselect
						selectionHighlights[clickedDough]:Destroy()
						selectionHighlights[clickedDough] = nil
						selectedDoughs[clickedDough] = nil
					else
						-- Select
						selectedDoughs[clickedDough] = true
						highlightDough(clickedDough)
					end

					updateSelectionCount()
				end
			end
		elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			-- Combine selected doughs
			local doughsToRemove = {}
			local totalSizeValue = targetDough.instance.SizeValue.Value

			-- Calculate total size and collect doughs to remove
			for dough, _ in pairs(selectedDoughs) do
				if dough and dough.instance and dough ~= targetDough then
					totalSizeValue = totalSizeValue + dough.instance.SizeValue.Value
					table.insert(doughsToRemove, dough)
				end
			end

			-- Update target dough size
			local newScaleFactor = totalSizeValue ^ (1 / 3) -- Cube root for 3D scaling
			local originalSize = targetDough.size

			-- Get the base size from targetDough definition
			targetDough.instance.SizeValue.Value = totalSizeValue
			targetDough.sizeValue = totalSizeValue

			-- Reset flatten count for combined dough
			targetDough.flattenCount = 0
			if targetDough.instance:FindFirstChild("FlattenCount") then
				targetDough.instance.FlattenCount.Value = 0
			else
				local flattenCountValue = Instance.new("IntValue")
				flattenCountValue.Name = "FlattenCount"
				flattenCountValue.Value = 0
				flattenCountValue.Parent = targetDough.instance
			end

			-- Scale the dough
			local newSize = Vector3.new(
				originalSize.X * newScaleFactor,
				originalSize.Y * newScaleFactor,
				originalSize.Z * newScaleFactor
			)

			-- Tween to new size
			TweenService
				:Create(targetDough.instance, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
					Size = newSize,
				})
				:Play()

			-- Remove all the doughs that were combined
			for _, dough in ipairs(doughsToRemove) do
				-- Play vanish effect
				local vanishTween = TweenService:Create(
					dough.instance,
					TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{
						Size = Vector3.new(0.1, 0.1, 0.1),
						Transparency = 1,
					}
				)

				vanishTween:Play()

				vanishTween.Completed:Connect(function()
					DragSystem.untrackObject(dough)
					dough:cleanup()
				end)
			end

			-- Display success message
			local successMsg = Instance.new("ScreenGui")
			successMsg.Name = "CombineSuccess"
			successMsg.ResetOnSpawn = false
			successMsg.Parent = PlayerGui

			local msgFrame = Instance.new("Frame")
			msgFrame.Size = UDim2.new(0, 300, 0, 60)
			msgFrame.Position = UDim2.new(0.5, -150, 0.7, 0)
			msgFrame.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
			msgFrame.BackgroundTransparency = 0.2
			msgFrame.BorderSizePixel = 0

			local msgCorner = Instance.new("UICorner")
			msgCorner.CornerRadius = UDim.new(0, 10)
			msgCorner.Parent = msgFrame

			local msgText = Instance.new("TextLabel")
			msgText.Size = UDim2.new(1, -20, 1, -20)
			msgText.Position = UDim2.new(0, 10, 0, 10)
			msgText.BackgroundTransparency = 1
			msgText.Text = string.format("Combined %d doughs successfully!", #doughsToRemove)
			msgText.TextColor3 = Color3.fromRGB(255, 255, 255)
			msgText.TextSize = 16
			msgText.Font = Enum.Font.GothamBold
			msgText.Parent = msgFrame

			msgFrame.Parent = successMsg

			-- Animate in and out
			msgFrame.Position = UDim2.new(0.5, -150, 1.1, 0)
			TweenService:Create(msgFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, -150, 0.7, 0),
			}):Play()

			-- Remove after 3 seconds
			task.delay(3, function()
				TweenService:Create(msgFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, -150, 1.1, 0),
				}):Play()

				task.delay(0.5, function()
					successMsg:Destroy()
				end)
			end)

			-- End combine mode
			CombineSystem.endCombine()
		elseif input.KeyCode == Enum.KeyCode.E then
			-- Cancel combine
			CombineSystem.endCombine()
		end
	end)

	inputEnded = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 and selectionStartPos then
			-- End selection box
			selectionBox.Visible = false
			selectionStartPos = nil
		end
	end)

	inputChanged = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement and selectionStartPos then
			-- Update selection box size and position
			local currentPos = Vector2.new(input.Position.X, input.Position.Y)
			local topLeft =
				Vector2.new(math.min(selectionStartPos.X, currentPos.X), math.min(selectionStartPos.Y, currentPos.Y))
			local size =
				Vector2.new(math.abs(currentPos.X - selectionStartPos.X), math.abs(currentPos.Y - selectionStartPos.Y))

			selectionBox.Position = UDim2.new(0, topLeft.X, 0, topLeft.Y)
			selectionBox.Size = UDim2.new(0, size.X, 0, size.Y)

			-- Find doughs in the box
			findDoughsInSelectionBox(selectionStartPos.X, selectionStartPos.Y, currentPos.X, currentPos.Y)
		end
	end)

	-- Make DragSystem inactive during combine
	DragSystem.setSlicingActive(true) -- Reusing the slicing active state to prevent dragging

	selectionUI = selectionBoxGui

	-- Return cleanup function
	return function()
		CombineSystem.endCombine()
	end
end

-- Function to end combine mode
function CombineSystem.endCombine()
	print("Ending combine mode")

	-- Disconnect input connections
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

	-- Re-enable all click detectors
	for clickDetector, originalDistance in pairs(disabledClickDetectors) do
		if clickDetector and clickDetector:IsDescendantOf(game) then
			clickDetector.MaxActivationDistance = originalDistance
		end
	end
	disabledClickDetectors = {}

	-- Clean up all highlights
	removeAllHighlights()

	-- Clear selected doughs
	selectedDoughs = {}

	-- Remove UI
	if selectionUI then
		selectionUI:Destroy()
		selectionUI = nil
	end

	-- Remove instructions
	if combineInstructions then
		combineInstructions:Destroy()
		combineInstructions = nil
	end

	-- Reset target dough
	targetDough = nil

	-- Reset selection state
	selectionStartPos = nil
	selectionBox = nil

	-- Re-enable dragging
	DragSystem.setSlicingActive(false)

	-- Reset combine flag
	isCombineActive = false
end

-- Check if combine mode is active
function CombineSystem.isCombineActive()
	return isCombineActive
end

return CombineSystem
