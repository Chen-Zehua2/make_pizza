-- UISystem.lua
-- Handles UI creation and interaction for pizza objects

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SliceSystem = require(ReplicatedStorage.Shared.SliceSystem)
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
	billboardGui.StudsOffset = Vector3.new(partSize.X + 0.2, 2, 0) -- Position above the object
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

	-- Flatten count info
	local flattenInfo = Instance.new("TextLabel")
	flattenInfo.Name = "FlattenInfo"
	flattenInfo.Size = UDim2.new(1, 0, 0, 20)
	flattenInfo.Position = UDim2.new(0, 0, 0, 48)
	flattenInfo.BackgroundTransparency = 1
	flattenInfo.Text = "Flattened: " .. flattenCount .. " times"
	flattenInfo.TextColor3 = Color3.fromRGB(200, 255, 200)
	flattenInfo.TextSize = 14
	flattenInfo.Font = Enum.Font.Gotham
	flattenInfo.Parent = mainFrame

	-- Cooking state info
	local cookingInfo = Instance.new("TextLabel")
	cookingInfo.Name = "CookingInfo"
	cookingInfo.Size = UDim2.new(1, 0, 0, 20)
	cookingInfo.Position = UDim2.new(0, 0, 0, 68)
	cookingInfo.BackgroundTransparency = 1

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

	cookingInfo.Text = "State: " .. cookingState
	cookingInfo.TextColor3 = textColor
	cookingInfo.TextSize = 14
	cookingInfo.Font = Enum.Font.GothamBold
	cookingInfo.Parent = mainFrame

	-- Options title
	local optionsTitle = Instance.new("TextLabel")
	optionsTitle.Name = "OptionsTitle"
	optionsTitle.Size = UDim2.new(1, 0, 0, 20)
	optionsTitle.Position = UDim2.new(0, 0, 0, 88) -- Adjusted position for cooking info
	optionsTitle.BackgroundTransparency = 1
	optionsTitle.Text = "OPTIONS"
	optionsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	optionsTitle.TextSize = 16
	optionsTitle.Font = Enum.Font.GothamBold
	optionsTitle.Parent = mainFrame

	-- Add buttons based on options provided by the object
	local buttonPositionY = 112 -- Adjusted position for cooking info
	local buttonHeight = 40
	local buttonSpacing = 45
	local currentRow = nil
	local rowPositionY = buttonPositionY

	-- Get options from the object or use an empty table
	local options = object.options or {}

	-- If no options provided, show message
	if #options == 0 then
		local noOptions = Instance.new("TextLabel")
		noOptions.Name = "NoOptions"
		noOptions.Size = UDim2.new(1, 0, 0, 20)
		noOptions.Position = UDim2.new(0, 0, 0, buttonPositionY)
		noOptions.BackgroundTransparency = 1
		noOptions.Text = "No options available"
		noOptions.TextColor3 = Color3.fromRGB(200, 200, 200)
		noOptions.TextSize = 14
		noOptions.Font = Enum.Font.Gotham
		noOptions.Parent = mainFrame

		billboardGui.Size = UDim2.new(0, 150, 0, 160) -- Adjusted for cooking info
	else
		-- Add each button, checking for row layout
		for i, option in ipairs(options) do
			-- Check if we need to create a new row or use the current one
			if option.layout == "row" then
				-- If this is the first button in a row, create a new container
				if not currentRow then
					currentRow = Instance.new("Frame")
					currentRow.Name = "ButtonRow"
					currentRow.Size = UDim2.new(1, 0, 0, buttonHeight)
					currentRow.Position = UDim2.new(0, 0, 0, rowPositionY)
					currentRow.BackgroundTransparency = 1
					currentRow.Parent = mainFrame
				end

				-- Create the button in the row
				local button = Instance.new("TextButton")
				button.Name = option.text .. "Button"
				button.Size = UDim2.new(option.width or 0.48, 0, 1, 0)

				-- Position based on whether it's the first or second button in row
				if option.width == 0.48 or not option.width then
					if i > 1 and options[i - 1].layout == "row" then
						button.Position = UDim2.new(0.52, 0, 0, 0) -- Second button position
					else
						button.Position = UDim2.new(0, 0, 0, 0) -- First button position
					end
				end

				button.BackgroundColor3 = option.color -- Use the fixed color defined in the option
				button.Text = option.text
				button.TextColor3 = Color3.fromRGB(0, 0, 0)
				button.TextSize = 16
				button.Font = Enum.Font.GothamSemibold
				button.Parent = currentRow

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

				-- Reset currentRow if this is the last button in the row
				if i < #options and options[i + 1].layout ~= "row" then
					currentRow = nil
					rowPositionY = rowPositionY + buttonSpacing
				end
			else
				-- Regular button (full width)
				currentRow = nil

				local button = Instance.new("TextButton")
				button.Name = option.text .. "Button"
				button.Size = UDim2.new(1, 0, 0, buttonHeight)
				button.Position = UDim2.new(0, 0, 0, rowPositionY)
				button.BackgroundColor3 = option.color -- Use the fixed color defined in the option
				button.Text = option.text
				button.TextColor3 = Color3.fromRGB(0, 0, 0)
				button.TextSize = 16
				button.Font = Enum.Font.GothamSemibold
				button.Parent = mainFrame

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
		local totalHeight = rowPositionY - buttonPositionY + buttonHeight
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
