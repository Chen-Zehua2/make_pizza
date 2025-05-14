-- Main server script for the pizza making game
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

print("Server script started")

-- Set up the Shared folder in ReplicatedStorage
local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
if not sharedFolder then
	sharedFolder = Instance.new("Folder")
	sharedFolder.Name = "Shared"
	sharedFolder.Parent = ReplicatedStorage

	print("Created Shared folder. Ensure modules are placed in this folder.")
else
	print("Shared folder already exists")

	-- Verify Roact is available
	local roactSuccess, roactResult = pcall(function()
		return require(ReplicatedStorage.Shared.Roact)
	end)

	if roactSuccess then
		print("Roact loaded successfully on server")
	else
		warn("Failed to load Roact:", roactResult)
	end
end

-- Initial setup of the game
local function setupGame()
	print("Setting up pizza making game...")

	-- Create a table surface for the dough
	local table = Instance.new("Part")
	table.Name = "PizzaTable"
	table.Anchored = true
	table.Size = Vector3.new(10, 1, 10)
	table.Position = Vector3.new(0, 0, 0)
	table.Color = Color3.fromRGB(133, 94, 66) -- Brown wood color
	table.Material = Enum.Material.Wood
	table.Parent = workspace

	print("Game setup complete!")
end

-- Clean up when player leaves
local function onPlayerRemoved(player)
	print("Player left:", player.Name)
	-- Any cleanup code here
end

-- Initialize when a player joins
local function onPlayerAdded(player)
	print("Player joined:", player.Name)

	player.CharacterAdded:Connect(function(character)
		print("Character added for", player.Name)

		-- Set the player's spawn position on the table
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
		humanoidRootPart.CFrame = CFrame.new(0, 6, 0)
	end)
end

-- Run setup
setupGame()

-- Connect player events
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoved)

print("Server initialization complete")
