-- Main client entry point for the pizza making game
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Import the modules
local Roact = require(ReplicatedStorage.Shared.Roact)
local DoughBase = require(ReplicatedStorage.Shared.DoughBase)
local SliceSystem = require(ReplicatedStorage.Shared.SliceSystem)
local DragSystem = require(ReplicatedStorage.Shared.DragSystem)
local UISystem = require(ReplicatedStorage.Shared.UISystem)
local CombineSystem = require(ReplicatedStorage.Shared.CombineSystem)
local DoughClientModule = require(ReplicatedStorage.Shared.DoughClientModule)
local DoughRemotes = require(ReplicatedStorage.Shared.DoughRemotes)
local BakingSystem = require(ReplicatedStorage.Shared.BakingSystem)

print("Roact loaded successfully:", Roact ~= nil)

-- Wait for the player to be ready
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Function to set up click detector for an object
local function setupClickDetector(object)
	local clickDetector = object.instance:FindFirstChild("ClickDetector")
	if clickDetector then
		clickDetector.MouseClick:Connect(function()
			-- Prevent UI from showing if combine mode is active
			if CombineSystem.isCombineActive() then
				return
			end

			print(object.name .. " clicked!")

			-- Show options UI using the object's options
			UISystem.showObjectUI(object)
		end)
	end
end

-- Function to set up object with proper tracking and UI
local function setupObject(object)
	-- Track the object for dragging
	DragSystem.trackObject(object)

	-- Set up click detector for the object
	setupClickDetector(object)

	return object
end

-- Listen for new instances in workspace to set up click detectors
workspace.ChildAdded:Connect(function(child)
	-- Check if this is a dough object by looking for the DoughId attribute
	if child:GetAttribute("DoughId") then
		-- Give it a moment to fully set up
		task.wait(0.1)

		-- Get the object from the client functions
		local doughId = child:GetAttribute("DoughId")
		local dough = DoughClientModule.getDough(doughId)

		if dough then
			-- Set up click detector
			setupClickDetector(dough)

			-- Make sure it's tracked for dragging
			DragSystem.trackObject(dough)

			print("Set up interaction for dough ID", doughId)
		else
			-- This might happen if the client system hasn't registered the dough yet
			print("Dough ID", doughId, "detected but not found in client tracking - will be handled by DoughClient")

			-- Ensure click detector exists
			if not child:FindFirstChild("ClickDetector") then
				local clickDetector = Instance.new("ClickDetector")
				clickDetector.MaxActivationDistance = 20
				clickDetector.Parent = child
				print("Added ClickDetector to dough ID", doughId)
			end
		end
	end
end)

-- Function to scan workspace for existing dough and set them up
local function scanWorkspaceForDough()
	for _, child in pairs(workspace:GetChildren()) do
		if child:IsA("Part") or child:IsA("MeshPart") then
			local doughId = child:GetAttribute("DoughId")
			if doughId then
				-- See if we already have this dough registered
				local dough = DoughClientModule.getDough(doughId)

				if dough then
					-- Ensure it's set up
					setupClickDetector(dough)
					DragSystem.trackObject(dough)
					print("Found existing dough ID", doughId, "in workspace and set up interactions")
				else
					-- Ensure it has a click detector for when it gets registered
					if not child:FindFirstChild("ClickDetector") then
						local clickDetector = Instance.new("ClickDetector")
						clickDetector.MaxActivationDistance = 20
						clickDetector.Parent = child
						print("Added ClickDetector to existing dough ID", doughId)
					end

					-- Force the DoughClient module to scan for it
					print("Requesting DoughClient to scan for dough ID", doughId)
					-- This will be picked up by the periodic scan in DoughClient
				end
			end
		end
	end
end

-- Set up the UI system to close UI when clicking elsewhere
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- Only close UI if we're not clicking on the UI itself
		local mousePos = UserInputService:GetMouseLocation()
		local guiObjects = player.PlayerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)

		local clickedOnUI = false
		for _, obj in ipairs(guiObjects) do
			if obj:IsDescendantOf(UISystem.getCurrentUI()) then
				clickedOnUI = true
				break
			end
		end

		if not clickedOnUI and UISystem.isUIOpen() then
			UISystem.closeUI()
		end
	end
end)

-- This function will be called once the game is loaded
local function init()
	print("Initializing pizza making game...")

	-- Initialize the drag system
	DragSystem.init()

	-- Initialize the baking system
	if not BakingSystem then
		warn("BakingSystem module not found!")
	end

	-- Wait for the DoughClientFunctions folder to be created
	local maxAttempts = 10
	local attempts = 0
	repeat
		attempts = attempts + 1
		task.wait(0.5)

		if attempts >= maxAttempts then
			print("Warning: Could not find DoughClientFunctions folder. Creating a new dough might fail.")
			break
		end
	until ReplicatedStorage:FindFirstChild("DoughClientFunctions")

	-- Scan workspace for any existing dough objects
	scanWorkspaceForDough()

	-- Create initial dough object via the server after a short delay if none found
	if workspace:FindFirstChild("1") then
		print("Found existing dough with ID 1, not creating new dough")
	else
		task.wait(1)
		print("Creating initial dough...")
		DoughClientModule.createDough(Vector3.new(0, 3, 0))
	end

	-- Add fallback system to create dough if initial creation failed
	local doughCreated = false
	workspace.ChildAdded:Connect(function(child)
		if child:GetAttribute("DoughId") then
			doughCreated = true
		end
	end)

	-- If no dough appears after 5 seconds, try again
	task.spawn(function()
		task.wait(5)
		if not doughCreated and not workspace:FindFirstChild("1") then
			print("No dough detected after 5 seconds, creating one again...")
			DoughRemotes.CreateDough:FireServer(Vector3.new(0, 3, 0))
		end
	end)

	print("Pizza making game initialized successfully!")
end

-- Start the game
init()
