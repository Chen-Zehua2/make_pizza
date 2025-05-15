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

-- Function to show UI when an object is clicked
function UISystem.showObjectUI(object)
	-- Only run on client
	if not isClient then
		return
	end

	-- Clean up previous UI if it exists
	if currentUI then
		if uiClickHandler then
			uiClickHandler:Disconnect()
			uiClickHandler = nil
		end
		currentUI:Destroy()
		currentUI = nil
	end

	if not object or not object.instance then
		return
	end

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
		-- Add each button
		for i, option in ipairs(options) do
			local button = Instance.new("TextButton")
			button.Name = option.text .. "Button"
			button.Size = UDim2.new(1, 0, 0, buttonHeight)
			button.Position = UDim2.new(0, 0, 0, buttonPositionY + (i - 1) * buttonSpacing)
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
		end

		-- Resize the frame height based on number of buttons
		local totalHeight = 132 + (#options * buttonSpacing) -- Adjusted for cooking info
		billboardGui.Size = UDim2.new(0, 150, 0, totalHeight)
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
end

-- Close any open UI
function UISystem.closeUI()
	if currentUI then
		if uiClickHandler then
			uiClickHandler:Disconnect()
			uiClickHandler = nil
		end
		currentUI:Destroy()
		currentUI = nil
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
