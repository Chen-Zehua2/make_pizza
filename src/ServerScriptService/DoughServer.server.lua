-- DoughServer.server.lua
-- Handles server-side dough creation and manipulation

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

-- Wait for RemoteEvents to be created
local DoughRemotes
local maxAttempts = 10
local attempts = 0
repeat
	attempts = attempts + 1
	DoughRemotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DoughRemotes"))
	if not DoughRemotes then
		task.wait(0.5)
	end
until DoughRemotes or attempts >= maxAttempts

if not DoughRemotes then
	error("Failed to load DoughRemotes after multiple attempts")
end

-- Load the BaseClass and DoughBase modules
local BaseClass = require(ReplicatedStorage.Shared.BaseClass)
local DoughBase = require(ReplicatedStorage.Shared.DoughBase)

-- Track server-side dough objects by their ID
local serverDoughs = {}

-- Dictionary to map instance names to their objects
local instanceToObjectMap = {}

-- Assign a unique ID to each dough
local nextDoughId = 1

-- Function to adjust dough appearance based on flatten count and doneness
local function adjustDoughAppearance(dough)
	if not dough or not dough.instance then
		return
	end

	local flattenCount = dough.flattenCount or 0
	local doneness = dough.doneness or 0

	-- Get values from instance if they exist
	if dough.instance:FindFirstChild("FlattenCount") then
		flattenCount = dough.instance.FlattenCount.Value
	end
	if dough.instance:FindFirstChild("Doneness") then
		doneness = dough.instance.Doneness.Value
	end

	-- Adjust size based on flatten count
	if flattenCount > 0 then
		-- Get original size before flattening
		local originalSize = dough.size
		local sizeValue = dough.sizeValue or 1

		-- Calculate scale factor based on size value (for volume)
		local scaleFactor = sizeValue ^ (1 / 3) -- Cube root for 3D scaling

		-- Apply flatten effect (decrease Y, increase X and Z)
		local flattenFactor = math.min(0.1 + (0.9 / (flattenCount + 1)), 1)
		local spreadFactor = math.sqrt(1 / flattenFactor) -- Preserve volume

		-- Calculate final size
		local newSize = Vector3.new(
			originalSize.X * scaleFactor * spreadFactor,
			originalSize.Y * scaleFactor * flattenFactor,
			originalSize.Z * scaleFactor * spreadFactor
		)

		-- Update instance size
		dough.instance.Size = newSize
	end

	-- Adjust color based on doneness
	if doneness > 0 then
		local baseColor = Color3.fromRGB(235, 213, 179) -- Raw dough color

		if doneness < 120 then
			-- Raw dough - no color change
			dough.instance.Color = baseColor
		elseif doneness < 300 then
			-- Slightly baked - light brown tint
			dough.instance.Color = Color3.fromRGB(226, 203, 159)
		elseif doneness < 500 then
			-- Half-baked - medium brown
			dough.instance.Color = Color3.fromRGB(218, 187, 130)
		elseif doneness < 600 then
			-- Well-baked - darker brown
			dough.instance.Color = Color3.fromRGB(200, 158, 96)
		elseif doneness <= 900 then
			-- Perfectly baked - golden brown
			dough.instance.Color = Color3.fromRGB(180, 132, 60)
		else
			-- Burnt - dark brown to black
			dough.instance.Color = Color3.fromRGB(100, 70, 30)
		end
	end
end

-- Function to create a server-side dough object
local function createServerDough(params, playerId)
	-- Create a new dough with the given parameters
	local dough = DoughBase.new(params)

	-- Assign a unique ID to the dough
	local doughId = tostring(nextDoughId)
	nextDoughId = nextDoughId + 1

	-- Store the server-side dough object
	serverDoughs[doughId] = dough

	-- Map the instance to its object
	instanceToObjectMap[dough.instance] = dough

	-- Set a special attribute on the instance to identify it
	dough.instance:SetAttribute("DoughId", doughId)
	dough.instance:SetAttribute("CreatorId", playerId)

	-- Add a ClickDetector to ensure the dough is clickable
	if not dough.instance:FindFirstChild("ClickDetector") then
		local clickDetector = Instance.new("ClickDetector")
		clickDetector.MaxActivationDistance = 20
		clickDetector.Parent = dough.instance
	end

	-- Adjust appearance based on doneness and flatten count
	adjustDoughAppearance(dough)

	return doughId, dough
end

-- Function to get a server dough by its ID
local function getServerDough(doughId)
	return serverDoughs[doughId]
end

-- Function to get a dough from its instance
local function getDoughFromInstance(instance)
	return instanceToObjectMap[instance]
end

-- Function to check if a player owns a dough
local function playerOwnsDough(player, doughId)
	local dough = getServerDough(doughId)
	if not dough or not dough.instance then
		return false
	end

	local creatorId = dough.instance:GetAttribute("CreatorId")
	return creatorId == player.UserId
end

-- Function to validate player ownership for a collection of doughs
local function validateDoughOwnership(player, doughIds)
	if type(doughIds) ~= "table" then
		doughIds = { doughIds }
	end

	local invalidDoughs = {}
	for _, doughId in ipairs(doughIds) do
		if not playerOwnsDough(player, doughId) then
			table.insert(invalidDoughs, doughId)
		end
	end

	return #invalidDoughs == 0, invalidDoughs
end

-- Handle initial dough creation
DoughRemotes.CreateDough.OnServerEvent:Connect(function(player, position, sizeValue)
	local params = {
		position = position,
		sizeValue = sizeValue or 1,
	}

	-- Create the server-side dough
	local doughId, dough = createServerDough(params, player.UserId)

	-- Notify the client about the created dough
	DoughRemotes.CreateDough:FireClient(player, doughId)

	print("Server: Created dough", doughId, "for player", player.Name)
end)

-- Handle dough slicing
DoughRemotes.SliceDough.OnServerEvent:Connect(function(player, doughId, sliceData)
	-- Verify ownership
	if not playerOwnsDough(player, doughId) then
		warn("Server: Player", player.Name, "attempted to slice dough", doughId, "which they don't own")
		return
	end

	-- Get the server-side dough
	local dough = getServerDough(doughId)
	if not dough then
		warn("Server: Dough not found for slicing", doughId)
		return
	end

	-- Remove the dough from our tracking
	serverDoughs[doughId] = nil
	instanceToObjectMap[dough.instance] = nil

	-- Get necessary properties from the original dough
	local originalDoughProps = {
		color = dough.instance.Color,
		material = dough.instance.Material,
		meshType = dough.instance:FindFirstChildOfClass("SpecialMesh") and dough.instance:FindFirstChildOfClass(
			"SpecialMesh"
		).MeshType or Enum.MeshType.Sphere,
		size = dough.size,
		highlightColor = dough.highlightColor or Color3.fromRGB(255, 255, 150),
		flattenCount = dough.flattenCount or 0,
		doneness = dough.doneness or 0,
		cookness = dough.cookness or 1,
	}

	-- Get values from instance if they exist
	if dough.instance:FindFirstChild("FlattenCount") then
		originalDoughProps.flattenCount = dough.instance.FlattenCount.Value
	end
	if dough.instance:FindFirstChild("Doneness") then
		originalDoughProps.doneness = dough.instance.Doneness.Value
	end
	if dough.instance:FindFirstChild("Cookness") then
		originalDoughProps.cookness = dough.instance.Cookness.Value
	end

	-- Create the two new pieces using data from client
	local params1 = {
		name = dough.name,
		position = sliceData.pos1,
		sizeValue = sliceData.sizeValue1,
		color = originalDoughProps.color,
		size = originalDoughProps.size,
		material = originalDoughProps.material,
		meshType = originalDoughProps.meshType,
		highlightColor = originalDoughProps.highlightColor,
		flattenCount = originalDoughProps.flattenCount, -- Preserve flatten count
		doneness = originalDoughProps.doneness, -- Preserve doneness
		cookness = originalDoughProps.cookness, -- Preserve cookness
	}

	local params2 = {
		name = dough.name,
		position = sliceData.pos2,
		sizeValue = sliceData.sizeValue2,
		color = originalDoughProps.color,
		size = originalDoughProps.size,
		material = originalDoughProps.material,
		meshType = originalDoughProps.meshType,
		highlightColor = originalDoughProps.highlightColor,
		flattenCount = originalDoughProps.flattenCount, -- Preserve flatten count
		doneness = originalDoughProps.doneness, -- Preserve doneness
		cookness = originalDoughProps.cookness, -- Preserve cookness
	}

	-- Create the new dough objects
	local newDough1 = DoughBase.new(params1)
	local newDough2 = DoughBase.new(params2)

	-- Destroy the original instance
	dough.instance:Destroy()

	-- Assign IDs to the new doughs
	local doughId1 = tostring(nextDoughId)
	nextDoughId = nextDoughId + 1

	local doughId2 = tostring(nextDoughId)
	nextDoughId = nextDoughId + 1

	-- Store the new doughs
	serverDoughs[doughId1] = newDough1
	serverDoughs[doughId2] = newDough2
	instanceToObjectMap[newDough1.instance] = newDough1
	instanceToObjectMap[newDough2.instance] = newDough2

	-- Set attributes
	newDough1.instance:SetAttribute("DoughId", doughId1)
	newDough1.instance:SetAttribute("CreatorId", player.UserId)
	newDough2.instance:SetAttribute("DoughId", doughId2)
	newDough2.instance:SetAttribute("CreatorId", player.UserId)

	-- Add ClickDetectors to the new dough pieces
	if not newDough1.instance:FindFirstChild("ClickDetector") then
		local clickDetector1 = Instance.new("ClickDetector")
		clickDetector1.MaxActivationDistance = 20
		clickDetector1.Parent = newDough1.instance
	end

	if not newDough2.instance:FindFirstChild("ClickDetector") then
		local clickDetector2 = Instance.new("ClickDetector")
		clickDetector2.MaxActivationDistance = 20
		clickDetector2.Parent = newDough2.instance
	end

	-- Adjust appearance based on doneness and flatten count
	adjustDoughAppearance(newDough1)
	adjustDoughAppearance(newDough2)

	-- Notify the client about the sliced doughs
	DoughRemotes.SliceDough:FireClient(player, doughId, doughId1, doughId2)

	print("Server: Sliced dough", doughId, "into", doughId1, "and", doughId2, "with client-computed values")
end)

-- Handle dough combining
DoughRemotes.CombineDoughs.OnServerEvent:Connect(function(player, targetDoughId, doughsToRemoveIds, totalSizeValue)
	-- Verify ownership of target dough
	if not playerOwnsDough(player, targetDoughId) then
		warn(
			"Server: Player",
			player.Name,
			"attempted to combine into target dough",
			targetDoughId,
			"which they don't own"
		)
		return
	end

	-- Verify ownership of all doughs to be combined
	local allDoughsValid, invalidDoughs = validateDoughOwnership(player, doughsToRemoveIds)
	if not allDoughsValid then
		warn(
			"Server: Player",
			player.Name,
			"attempted to combine doughs they don't own:",
			table.concat(invalidDoughs, ", ")
		)
		return
	end

	-- Get the target server-side dough
	local targetDough = getServerDough(targetDoughId)
	if not targetDough then
		warn("Server: Target dough not found for combining", targetDoughId)
		return
	end

	-- Update the target dough's size
	targetDough.sizeValue = totalSizeValue
	targetDough.instance.SizeValue.Value = totalSizeValue

	-- Calculate the new scale factor
	local newScaleFactor = totalSizeValue ^ (1 / 3) -- Cube root for 3D scaling
	local originalSize = targetDough.size

	-- Update the size
	local newSize =
		Vector3.new(originalSize.X * newScaleFactor, originalSize.Y * newScaleFactor, originalSize.Z * newScaleFactor)
	targetDough.instance.Size = newSize

	-- Calculate the highest doneness value from all doughs being combined
	local highestDoneness = targetDough.doneness or 0
	if targetDough.instance:FindFirstChild("Doneness") then
		highestDoneness = targetDough.instance.Doneness.Value
	end

	-- Set flatten count to 0 when combining doughs
	local flattenCount = 0

	-- Find the highest doneness among all doughs being combined
	for _, doughId in ipairs(doughsToRemoveIds) do
		local dough = getServerDough(doughId)
		if dough and dough.instance then
			-- Check doneness
			local doughDoneness = 0
			if dough.instance:FindFirstChild("Doneness") then
				doughDoneness = dough.instance.Doneness.Value
			end
			if doughDoneness > highestDoneness then
				highestDoneness = doughDoneness
			end

			-- We're not checking flatten count anymore as we're setting it to 0
		end
	end

	-- Update target dough's properties with the highest values
	targetDough.doneness = highestDoneness
	if targetDough.instance:FindFirstChild("Doneness") then
		targetDough.instance.Doneness.Value = highestDoneness
	end

	-- Update flatten count to 0
	targetDough.flattenCount = flattenCount
	if targetDough.instance:FindFirstChild("FlattenCount") then
		targetDough.instance.FlattenCount.Value = flattenCount
	else
		local flattenCountValue = Instance.new("IntValue")
		flattenCountValue.Name = "FlattenCount"
		flattenCountValue.Value = flattenCount
		flattenCountValue.Parent = targetDough.instance
	end

	-- Adjust appearance based on the updated doneness and flatten values
	adjustDoughAppearance(targetDough)

	-- Remove the doughs that were combined
	for _, doughId in ipairs(doughsToRemoveIds) do
		local dough = getServerDough(doughId)
		if dough then
			-- Clean up tracking
			serverDoughs[doughId] = nil
			instanceToObjectMap[dough.instance] = nil

			-- Destroy the instance
			dough.instance:Destroy()
		end
	end

	-- Notify clients about the combined dough
	DoughRemotes.CombineDoughs:FireAllClients(targetDoughId, doughsToRemoveIds, totalSizeValue)

	print("Server: Combined doughs into", targetDoughId)
end)

-- Handle dough flattening
DoughRemotes.FlattenDough.OnServerEvent:Connect(function(player, doughId, amount)
	-- Verify ownership
	if not playerOwnsDough(player, doughId) then
		warn("Server: Player", player.Name, "attempted to flatten dough", doughId, "which they don't own")
		return
	end

	-- Get the server-side dough
	local dough = getServerDough(doughId)
	if not dough then
		warn("Server: Dough not found for flattening", doughId)
		return
	end

	-- Perform the flatten operation
	dough:flatten(amount)

	-- Adjust appearance based on updated flatten count
	adjustDoughAppearance(dough)

	-- Notify all clients
	DoughRemotes.FlattenDough:FireAllClients(doughId, amount)

	print("Server: Flattened dough", doughId)
end)

-- Handle dough unflattening
DoughRemotes.UnflattenDough.OnServerEvent:Connect(function(player, doughId, amount)
	-- Verify ownership
	if not playerOwnsDough(player, doughId) then
		warn("Server: Player", player.Name, "attempted to unflatten dough", doughId, "which they don't own")
		return
	end

	-- Get the server-side dough
	local dough = getServerDough(doughId)
	if not dough then
		warn("Server: Dough not found for unflattening", doughId)
		return
	end

	-- Perform the unflatten operation
	dough:unflatten(amount)

	-- Adjust appearance based on updated flatten count
	adjustDoughAppearance(dough)

	-- Notify all clients
	DoughRemotes.UnflattenDough:FireAllClients(doughId, amount)

	print("Server: Unflattened dough", doughId)
end)

-- Handle dough position updates
DoughRemotes.UpdateDoughPosition.OnServerEvent:Connect(function(player, doughId, position)
	-- Verify ownership
	if not playerOwnsDough(player, doughId) then
		warn("Server: Player", player.Name, "attempted to move dough", doughId, "which they don't own")
		return
	end

	-- Get the server-side dough
	local dough = getServerDough(doughId)
	if not dough then
		warn("Server: Dough not found for position update", doughId)
		return
	end

	-- Update the position
	dough.instance.Position = position

	-- Notify all other clients (except the one who moved it)
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			DoughRemotes.UpdateDoughPosition:FireClient(otherPlayer, doughId, position)
		end
	end
end)

-- Handle dough destruction
DoughRemotes.DestroyDough.OnServerEvent:Connect(function(player, doughId)
	-- Verify ownership
	if not playerOwnsDough(player, doughId) then
		warn("Server: Player", player.Name, "attempted to destroy dough", doughId, "which they don't own")
		return
	end

	-- Get the server-side dough
	local dough = getServerDough(doughId)
	if not dough then
		warn("Server: Dough not found for destruction", doughId)
		return
	end

	-- Clean up tracking
	serverDoughs[doughId] = nil
	instanceToObjectMap[dough.instance] = nil

	-- Destroy the instance
	dough.instance:Destroy()

	-- Notify all clients
	DoughRemotes.DestroyDough:FireAllClients(doughId)

	print("Server: Destroyed dough", doughId)
end)

print("DoughServer initialized successfully!")
