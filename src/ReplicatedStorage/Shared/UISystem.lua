-- UISystem.lua
-- Handles UI creation and interaction for pizza objects

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SplitSystem = require(ReplicatedStorage.Shared.SplitSystem)
local BaseClass = require(ReplicatedStorage.Shared.BaseClass)

-- Check if we're running on client or server
local isClient = RunService:IsClient()

-- Client-only variables
local player
local PlayerGui
if isClient then
	player = Players.LocalPlayer
	PlayerGui = player:WaitForChild("PlayerGui")
end

local UISystem = {}

-- Variables
local currentUI = nil
local uiClickHandler = nil
local uiUpdateConnection = nil -- Connection for UI updates
local currentUIObject = nil -- Reference to the current object whose UI is shown

-- Function to show UI when an object is clicked
function UISystem.showObjectUI(object)
	-- Only run on client
	if not isClient then
		return
	end

	-- Clean up previous UI if it exists
	if currentUI then
		UISystem.closeUI()
	end

	if not object or not object.instance then
		return
	end

	currentUIObject = object -- Store reference to the current object
	local part = object.instance
	local partSize = part.Size
	local sizeValue = part:FindFirstChild("SizeValue") and part.SizeValue.Value or 1
	local formattedSize = string.format("%.2f", sizeValue)
	local flattenCount = object.flattenCount or 0
	local doneness = object.doneness or 0
	local cookingState = "Raw"

	-- Get the doneness value from the instance if available
	if part:FindFirstChild("Doneness") then
		doneness = part.Doneness.Value
		-- Update the object's doneness property to ensure consistency
		object.doneness = doneness
	end

	-- Get cooking state
	if object.getCookingState then
		cookingState = object:getCookingState()
	end

	-- Also check if the instance has a FlattenCount value
	if not object.flattenCount and part:FindFirstChild("FlattenCount") then
		flattenCount = part.FlattenCount.Value
		-- Update the object's flattenCount property to ensure consistency
		object.flattenCount = flattenCount
	end

	-- Create a BillboardGui attached to the object in world space
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "ObjectOptionsUI"
	billboardGui.Active = true
	billboardGui.AlwaysOnTop = true
	billboardGui.Size = UDim2.new(0, 150, 0, 170) -- Increase height for cooking info
	billboardGui.StudsOffset = Vector3.new(0, partSize.Y + 5, 0) -- Position above the object
	billboardGui.Adornee = part
	billboardGui.Parent = PlayerGui

	-- Create the UI elements
	-- Main frame with rounded corners and blue background
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(1, 0, 1, 0)
	mainFrame.BackgroundColor3 = Color3.fromRGB(59, 138, 235) -- Blue background
	mainFrame.BorderSizePixel = 0

	-- Rounded corners using UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = mainFrame

	-- Add padding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = mainFrame

	-- Title with shadow effect
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 24)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = string.upper(object.name)
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.Parent = mainFrame

	-- Add text shadow effect for title
	local titleShadow = Instance.new("TextLabel")
	titleShadow.Name = "Shadow"
	titleShadow.Size = UDim2.new(1, 0, 1, 0)
	titleShadow.Position = UDim2.new(0, 1, 0, 1)
	titleShadow.BackgroundTransparency = 1
	titleShadow.Text = title.Text
	titleShadow.TextColor3 = Color3.fromRGB(0, 0, 0)
	titleShadow.TextSize = title.TextSize
	titleShadow.Font = title.Font
	titleShadow.TextTransparency = 0.6
	titleShadow.ZIndex = title.ZIndex - 1
	titleShadow.Parent = title

	-- Size info
	local sizeInfo = Instance.new("TextLabel")
	sizeInfo.Name = "SizeInfo"
	sizeInfo.Size = UDim2.new(1, 0, 0, 20)
	sizeInfo.Position = UDim2.new(0, 0, 0, 28)
	sizeInfo.BackgroundTransparency = 1
	sizeInfo.Text = "Size: " .. formattedSize
	sizeInfo.TextColor3 = Color3.fromRGB(255, 255, 255)
	sizeInfo.TextSize = 14
	sizeInfo.Font = Enum.Font.Gotham
	sizeInfo.Parent = mainFrame

	-- Cooking state info
	local cookingInfo = Instance.new("TextLabel")
	cookingInfo.Name = "CookingInfo"
	cookingInfo.Size = UDim2.new(1, 0, 0, 20)
	cookingInfo.Position = UDim2.new(0, 0, 0, 48)
	cookingInfo.BackgroundTransparency = 1

	-- Set text color based on cooking state
	local textColor
	if cookingState == "Raw Dough" then
		textColor = Color3.fromRGB(200, 200, 200) -- Light gray
	elseif cookingState == "Slightly Cooked" then
		textColor = Color3.fromRGB(220, 220, 150) -- Light yellow
	elseif cookingState == "Half-Baked" then
		textColor = Color3.fromRGB(230, 190, 100) -- Light brown
	elseif cookingState == "Well-Baked" then
		textColor = Color3.fromRGB(210, 160, 70) -- Darker brown
	elseif cookingState == "Perfectly Baked" then
		textColor = Color3.fromRGB(200, 130, 50) -- Perfect brown
	else -- Burnt
		textColor = Color3.fromRGB(80, 50, 30) -- Dark brown/black
	end

	cookingInfo.Text = "State: " .. cookingState
	cookingInfo.TextColor3 = textColor
	cookingInfo.TextSize = 14
	cookingInfo.Font = Enum.Font.GothamBold
	cookingInfo.Parent = mainFrame

	-- Options title
	local optionsTitle = Instance.new("TextLabel")
	optionsTitle.Name = "OptionsTitle"
	optionsTitle.Size = UDim2.new(1, 0, 0, 20)
	optionsTitle.Position = UDim2.new(0, 0, 0, 68) -- Adjusted position for cooking info
	optionsTitle.BackgroundTransparency = 1
	optionsTitle.Text = "OPTIONS"
	optionsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	optionsTitle.TextSize = 16
	optionsTitle.Font = Enum.Font.GothamBold
	optionsTitle.Parent = mainFrame

	-- Add buttons based on options provided by the object
	local buttonPositionY = 92 -- Adjusted position for cooking info
	local buttonHeight = 40
	local buttonSpacing = 45
	local currentRow = nil
	local rowPositionY = buttonPositionY

	-- Get options from the object or use an empty table
	local options = object.options or {}

	-- Check if object can be manipulated based on doneness
	local canBeManipulated = true
	if object.canBeManipulated then
		canBeManipulated = object:canBeManipulated()
	else
		-- Fallback check if doneness > 0
		canBeManipulated = (doneness <= 0)
	end

	-- Filter out split, flatten, unflatten, and combine options if doneness > 0
	local filteredOptions = {}
	for _, option in ipairs(options) do
		if
			not canBeManipulated
			and (option.text == "Split" or option.text == "Flatten Scale" or option.text == "Combine")
		then
			-- Skip these options
		else
			table.insert(filteredOptions, option)
		end
	end

	-- Create container for option buttons - will be useful for dynamic updates
	local buttonsContainer = Instance.new("Frame")
	buttonsContainer.Name = "ButtonsContainer"
	buttonsContainer.Size = UDim2.new(1, 0, 0, 0) -- Will be resized based on content
	buttonsContainer.Position = UDim2.new(0, 0, 0, buttonPositionY)
	buttonsContainer.BackgroundTransparency = 1
	buttonsContainer.Parent = mainFrame

	local UIListLayout = Instance.new("UIListLayout")
	UIListLayout.Name = "UIListLayout"
	UIListLayout.Padding = UDim.new(0, 5)
	UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	UIListLayout.Parent = buttonsContainer

	-- If no options provided, show message
	if #filteredOptions == 0 then
		local noOptions = Instance.new("TextLabel")
		noOptions.Name = "NoOptions"
		noOptions.Size = UDim2.new(1, 0, 0, 20)
		noOptions.Position = UDim2.new(0, 0, 0, 0)
		noOptions.BackgroundTransparency = 1
		noOptions.Text = "No options available"
		noOptions.TextColor3 = Color3.fromRGB(200, 200, 200)
		noOptions.TextSize = 14
		noOptions.Font = Enum.Font.Gotham
		noOptions.Parent = buttonsContainer

		buttonsContainer.Size = UDim2.new(1, 0, 0, 20)
		billboardGui.Size = UDim2.new(0, 150, 0, 160) -- Adjusted for cooking info
	else
		-- Add each button or scale control
		for i, option in ipairs(filteredOptions) do
			if option.type == "scale" then
				-- Create scale control container
				local scaleContainer = Instance.new("Frame")
				scaleContainer.Name = option.text .. "Container"
				scaleContainer.Size = UDim2.new(1, 0, 0, 80) -- Increased height
				scaleContainer.Position = UDim2.new(0, 0, 0, rowPositionY - buttonPositionY)
				scaleContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
				scaleContainer.BorderSizePixel = 0
				scaleContainer.Parent = buttonsContainer

				-- Add rounded corners to container
				local containerCorner = Instance.new("UICorner")
				containerCorner.CornerRadius = UDim.new(0, 8)
				containerCorner.Parent = scaleContainer

				-- Add label
				local label = Instance.new("TextLabel")
				label.Name = "Label"
				label.Size = UDim2.new(1, -20, 0, 20)
				label.Position = UDim2.new(0, 10, 0, 10) -- Adjusted padding
				label.BackgroundTransparency = 1
				label.Text = option.text
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
				label.TextSize = 14
				label.Font = Enum.Font.GothamBold
				label.Parent = scaleContainer

				-- Create slider background
				local sliderBg = Instance.new("Frame")
				sliderBg.Name = "SliderBackground"
				sliderBg.Size = UDim2.new(1, -20, 0, 30) -- Increased height
				sliderBg.Position = UDim2.new(0, 10, 0, 35) -- Adjusted position
				sliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
				sliderBg.BorderSizePixel = 0
				sliderBg.Parent = scaleContainer

				-- Add rounded corners to slider background
				local sliderCorner = Instance.new("UICorner")
				sliderCorner.CornerRadius = UDim.new(0, 15) -- Increased corner radius
				sliderCorner.Parent = sliderBg

				-- Create slider knob
				local sliderKnob = Instance.new("Frame")
				sliderKnob.Name = "SliderKnob"
				sliderKnob.Size = UDim2.new(0, 30, 1, 0) -- Increased width
				sliderKnob.BackgroundColor3 = option.color
				sliderKnob.BorderSizePixel = 0
				sliderKnob.AnchorPoint = Vector2.new(0.5, 0)
				sliderKnob.Parent = sliderBg

				-- Add rounded corners to knob
				local knobCorner = Instance.new("UICorner")
				knobCorner.CornerRadius = UDim.new(0.5, 0)
				knobCorner.Parent = sliderKnob

				-- Function to update slider position and value
				local function updateSliderToValue(value)
					-- Clamp and round the value
					value = math.clamp(value, option.min, option.max)
					value = math.floor(value * 10) / 10 -- Round to 1 decimal place

					-- Calculate normalized position (0 to 1)
					local normalizedValue = (value - option.min) / (option.max - option.min)

					-- Update knob position
					sliderKnob.Position = UDim2.new(normalizedValue, 0, 0, 0)

					return value
				end

				-- Set initial value
				local lastValidValue = updateSliderToValue(flattenCount)

				-- Variables for dragging
				local isDragging = false

				-- Function to handle mouse movement while dragging
				local function updateFromMousePosition(inputPosition)
					-- Get relative position within slider background
					local relativeX = inputPosition.X - sliderBg.AbsolutePosition.X
					local sliderWidth = sliderBg.AbsoluteSize.X

					-- Calculate normalized position (0-1) directly from mouse position
					local normalizedValue = math.clamp(relativeX / sliderWidth, 0, 1)
					local newValue = option.min + (normalizedValue * (option.max - option.min))

					-- Update slider and get the actual (clamped) value
					newValue = updateSliderToValue(newValue)

					-- Only call callback if value changed
					if newValue ~= lastValidValue then
						lastValidValue = newValue
						if option.callback then
							option.callback(newValue)
						end
					end
				end

				-- Handle slider interaction
				sliderBg.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						isDragging = true
						updateFromMousePosition(input.Position)
					end
				end)

				sliderBg.InputChanged:Connect(function(input)
					if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
						updateFromMousePosition(input.Position)
					end
				end)

				-- Also handle knob input separately for better responsiveness
				sliderKnob.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						isDragging = true
						updateFromMousePosition(input.Position)
					end
				end)

				sliderKnob.InputChanged:Connect(function(input)
					if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
						updateFromMousePosition(input.Position)
					end
				end)

				-- Also connect to UserInputService for global mouse release
				UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						isDragging = false
					end
				end)

				rowPositionY = rowPositionY + 65 -- Increase more for scale control
			else
				-- Regular button (full width)
				currentRow = nil

				local button = Instance.new("TextButton")
				button.Name = option.text .. "Button"
				button.Size = UDim2.new(1, 0, 0, buttonHeight)
				button.Position = UDim2.new(0, 0, 0, rowPositionY - buttonPositionY)
				button.BackgroundColor3 = option.color -- Use the fixed color defined in the option
				button.Text = option.text
				button.TextColor3 = Color3.fromRGB(0, 0, 0)
				button.TextSize = 16
				button.Font = Enum.Font.GothamSemibold
				button.Parent = buttonsContainer

				-- Rounded corners for button
				local buttonCorner = Instance.new("UICorner")
				buttonCorner.CornerRadius = UDim.new(0, 8)
				buttonCorner.Parent = button

				-- Button click action
				button.MouseButton1Click:Connect(function()
					print(option.text .. " button clicked!")
					-- Disconnect the UI click handler before destroying
					if uiClickHandler then
						uiClickHandler:Disconnect()
						uiClickHandler = nil
					end
					billboardGui:Destroy() -- Remove UI
					currentUI = nil

					-- Call the provided callback function
					if option.callback then
						option.callback()
					end
				end)

				rowPositionY = rowPositionY + buttonSpacing
			end
		end

		-- Reset currentRow at the end
		currentRow = nil

		-- Calculate total height based on the final rowPositionY
		local totalHeight = rowPositionY - buttonPositionY
		buttonsContainer.Size = UDim2.new(1, 0, 0, totalHeight)
		billboardGui.Size = UDim2.new(0, 150, 0, 132 + totalHeight) -- Adjusted for cooking info
	end

	mainFrame.Parent = billboardGui

	-- Store reference to the UI
	currentUI = billboardGui

	-- Use a direct UserInputService connection to handle UI closing
	uiClickHandler = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Check if we clicked on the UI itself
			local mousePos = UserInputService:GetMouseLocation()
			local objects = PlayerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)

			local clickedOnUI = false
			for _, obj in ipairs(objects) do
				if obj:IsDescendantOf(billboardGui) then
					clickedOnUI = true
					break
				end
			end

			-- If we didn't click on the UI, close it
			if not clickedOnUI then
				print("Clicked outside UI, closing options")
				UISystem.closeUI()
			end
		elseif input.KeyCode == Enum.KeyCode.E then
			-- Also allow closing with E key
			print("E pressed, closing options")
			UISystem.closeUI()
		end
	end)

	-- Ensure the connection is cleaned up when the UI is destroyed
	billboardGui.AncestryChanged:Connect(function(_, newParent)
		if not newParent and uiClickHandler then
			uiClickHandler:Disconnect()
			uiClickHandler = nil
		end
	end)

	-- Setup update connection for dynamic UI updates
	UISystem.setupUpdateConnection(object, mainFrame)
end

-- Function to setup dynamic UI update connection
function UISystem.setupUpdateConnection(object, mainFrame)
	-- Clean up existing connection if it exists
	if uiUpdateConnection then
		uiUpdateConnection:Disconnect()
		uiUpdateConnection = nil
	end

	-- Connect to RunService.Heartbeat for regular updates
	uiUpdateConnection = RunService.Heartbeat:Connect(function()
		-- Make sure UI and object still exist
		if not currentUI or not currentUI.Parent or not object or not object.instance or not object.instance.Parent then
			UISystem.closeUI()
			return
		end

		local part = object.instance
		local flattenInfo = mainFrame:FindFirstChild("FlattenInfo")
		local cookingInfo = mainFrame:FindFirstChild("CookingInfo")
		local buttonsContainer = mainFrame:FindFirstChild("ButtonsContainer")

		if flattenInfo then
			-- Check for updated flatten count
			local currentFlattenCount = object.flattenCount or 0

			-- Get the flatten count from the instance if available
			if part:FindFirstChild("FlattenCount") then
				currentFlattenCount = part.FlattenCount.Value
				-- Update the object's property for consistency
				object.flattenCount = currentFlattenCount
			end

			-- Update flatten count text
			flattenInfo.Text = "Flattened: " .. currentFlattenCount .. " times"
		end

		if cookingInfo then
			-- Check for updated doneness
			local currentDoneness = object.doneness or 0

			-- Get the doneness value from the instance if available
			if part:FindFirstChild("Doneness") then
				currentDoneness = part.Doneness.Value
				-- Update the object's property for consistency
				object.doneness = currentDoneness
			end

			-- Get cooking state
			local cookingState = "Raw"
			if object.getCookingState then
				cookingState = object:getCookingState()
			end

			-- Set text color based on cooking state
			local textColor
			if cookingState == "Raw" then
				textColor = Color3.fromRGB(200, 200, 200) -- Light gray
			elseif cookingState == "Slightly Cooked" then
				textColor = Color3.fromRGB(220, 220, 150) -- Light yellow
			elseif cookingState == "Cooked" then
				textColor = Color3.fromRGB(230, 190, 100) -- Light brown
			elseif cookingState == "Well Cooked" then
				textColor = Color3.fromRGB(210, 160, 70) -- Darker brown
			elseif cookingState == "Perfectly Cooked" then
				textColor = Color3.fromRGB(200, 130, 50) -- Perfect brown
			else -- Burnt
				textColor = Color3.fromRGB(80, 50, 30) -- Dark brown/black
			end

			-- Update cooking state text and color
			cookingInfo.Text = "State: " .. cookingState
			cookingInfo.TextColor3 = textColor

			-- Check if we need to update buttons based on doneness change
			if buttonsContainer and currentDoneness > 0 then
				-- If doneness is > 0, we need to remove flatten/unflatten/combine buttons
				local splitButton = buttonsContainer:FindFirstChild("SplitButton", true)
				local flattenButton = buttonsContainer:FindFirstChild("FlattenButton", true)
				local unflattenButton = buttonsContainer:FindFirstChild("UnflattenButton", true)
				local combineButton = buttonsContainer:FindFirstChild("CombineButton", true)

				-- Remove buttons if they exist
				if splitButton then
					splitButton:Destroy()
				end

				if flattenButton then
					-- Check if it's in a row
					local buttonRow = flattenButton.Parent
					if buttonRow and buttonRow.Name == "ButtonRow" then
						buttonRow:Destroy() -- Remove the entire row
					else
						flattenButton:Destroy()
					end
				end

				if unflattenButton and unflattenButton.Parent then
					-- Only destroy if it wasn't already destroyed with the row
					if unflattenButton.Parent.Name ~= "ButtonRow" or unflattenButton.Parent.Parent then
						unflattenButton:Destroy()
					end
				end

				if combineButton then
					combineButton:Destroy()
				end

				-- Check if we need to add "No options" message
				local hasButtons = false
				for _, child in ipairs(buttonsContainer:GetChildren()) do
					if child:IsA("TextButton") or child:IsA("Frame") and #child:GetChildren() > 0 then
						hasButtons = true
						break
					end
				end

				if not hasButtons and not buttonsContainer:FindFirstChild("NoOptions") then
					local noOptions = Instance.new("TextLabel")
					noOptions.Name = "NoOptions"
					noOptions.Size = UDim2.new(1, 0, 0, 20)
					noOptions.Position = UDim2.new(0, 0, 0, 0)
					noOptions.BackgroundTransparency = 1
					noOptions.Text = "No options available"
					noOptions.TextColor3 = Color3.fromRGB(200, 200, 200)
					noOptions.TextSize = 14
					noOptions.Font = Enum.Font.Gotham
					noOptions.Parent = buttonsContainer

					-- Resize the container and billboardGui
					buttonsContainer.Size = UDim2.new(1, 0, 0, 20)
					currentUI.Size = UDim2.new(0, 150, 0, 160)
				end
			end
		end
	end)

	-- Also connect to DonenessUpdate remote event if it exists
	if isClient then
		local DonenessUpdateEvent = ReplicatedStorage:FindFirstChild("DonenessUpdate")
		if DonenessUpdateEvent then
			-- Connect to doneness updates directly
			DonenessUpdateEvent.OnClientEvent:Connect(function(updatedPart, newDoneness)
				-- Check if this update is for our current object
				if currentUIObject and currentUIObject.instance == updatedPart then
					-- Update object's doneness value
					currentUIObject.doneness = newDoneness
				end
			end)
		end
	end
end

-- Close any open UI
function UISystem.closeUI()
	if currentUI then
		if uiClickHandler then
			uiClickHandler:Disconnect()
			uiClickHandler = nil
		end

		if uiUpdateConnection then
			uiUpdateConnection:Disconnect()
			uiUpdateConnection = nil
		end

		currentUI:Destroy()
		currentUI = nil
		currentUIObject = nil
	end
end

-- Check if UI is currently open
function UISystem.isUIOpen()
	return currentUI ~= nil
end

-- Get the current UI
function UISystem.getCurrentUI()
	return currentUI
end

return UISystem
