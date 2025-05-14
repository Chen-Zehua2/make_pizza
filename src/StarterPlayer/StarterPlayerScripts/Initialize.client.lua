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

print("Roact loaded successfully:", Roact ~= nil)

-- Wait for the player to be ready
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Function to set up click detector for an object
local function setupClickDetector(object)
	local clickDetector = object.instance:FindFirstChild("ClickDetector")
	if clickDetector then
		clickDetector.MouseClick:Connect(function()
			print(object.name .. " clicked!")

			-- Show options UI using the object's options
			UISystem.showObjectUI(object)
		end)
	end
end

-- This function will be called once the game is loaded
local function init()
	print("Initializing pizza making game...")

	-- Initialize the drag system
	DragSystem.init()

	-- Create initial dough object
	local dough = DoughBase.createDough(Vector3.new(0, 3, 0))

	-- Track the dough object for dragging
	DragSystem.trackObject(dough)

	-- Set up click detector for the dough
	setupClickDetector(dough)

	print("Pizza making game initialized successfully!")
end

-- Start the game
init()
