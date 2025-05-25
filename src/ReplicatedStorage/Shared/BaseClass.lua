-- BaseClass.lua
-- Base class for pizza base objects (like dough) that can sp and combine

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- Check if we're running on client or server
local isClient = RunService:IsClient()
local isServer = RunService:IsServer()

local BaseClass = {}
BaseClass.__index = BaseClass

-- Constants
local MINIMUM_SPLIT_LENGTH = 0.75 -- 75% of the base needs to be splitted
local DEFAULT_BASE_SIZE_VALUE = 1 -- Default base "size" property (for splitting)
local PERFECT_DONENESS = 600 -- Perfect cooking level
local BURNT_DONENESS = 900 -- Burnt threshold (50% over perfect)
local STEAM_DONENESS_THRESHOLD = 400 -- Doneness level at which steam effects start

-- Constructor for a new base object
function BaseClass.new(params)
	local self = setmetatable({}, BaseClass)

	-- Default parameters
	self.name = params.name or "Base"
	self.size = params.size or Vector3.new(3, 1.5, 3)
	self.position = params.position or Vector3.new(0, 3, 0)
	self.color = params.color or Color3.fromRGB(235, 213, 179)
	self.highlightColor = params.highlightColor or Color3.fromRGB(255, 255, 150)
	self.meshType = params.meshType or Enum.MeshType.Sphere
	self.material = params.material or Enum.Material.SmoothPlastic
	self.sizeValue = params.sizeValue or DEFAULT_BASE_SIZE_VALUE
	self.flattenCount = params.flattenCount or 0 -- Track number of times flattened

	-- Baking properties
	self.cookness = params.cookness or 1 -- Rate at which the object cooks
	self.doneness = params.doneness or 0 -- Current doneness level

	-- Steam effect tracking
	self.steamEffect = nil
	self.lastSteamCheck = 0

	-- Instance for the part
	self.instance = nil

	-- If an instance is directly provided, use it without creating a new one
	if params.instance then
		self.instance = params.instance
	-- Otherwise, create the physical instance if we're on the server
	elseif isServer then
		self:create()
	end

	-- Define available options for base objects with fixed colors
	-- This will be loaded by the UI system
	local SplitSystem = require(ReplicatedStorage.Shared.SplitSystem)
	self.options = {
		{
			text = "Split",
			color = Color3.fromRGB(255, 156, 156), -- Red color for Split
			callback = function()
				SplitSystem.startSplitting(self, getmetatable(self))
			end,
		},
		{
			text = "Flatten",
			color = Color3.fromRGB(156, 156, 255), -- Blue color for flatten
			callback = function()
				self:flatten()
			end,
			layout = "row", -- Indicate these buttons should be in the same row
			width = 0.48, -- Take up half of the row width
		},
		{
			text = "Unflatten",
			color = Color3.fromRGB(156, 200, 255), -- Light blue color for unflatten
			callback = function()
				self:unflatten()
			end,
			layout = "row", -- Indicate these buttons should be in the same row
			width = 0.48, -- Take up half of the row width
		},
	}

	return self
end

-- Create the physical instance of the base
function BaseClass:create()
	-- Only server should create actual instances
	if isClient and not isServer then
		warn("Attempt to create instance on client, this should only happen on server")
		return nil
	end

	-- Create the base part
	local part = Instance.new("Part")
	part.Name = self.name
	part.Size = self.size
	part.Position = self.position
	part.Anchored = true
	part.CanCollide = false -- Disable collision for baking purposes
	part.Material = self.material
	part.Color = self.color

	-- Create a mesh to make it look more rounded
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = self.meshType
	mesh.Parent = part

	-- Add highlight for hover effect (initially disabled)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = self.highlightColor
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0.7
	highlight.Adornee = part
	highlight.Enabled = false
	highlight.Parent = part
	highlight.Name = "Highlight"

	-- Add size value (for splitting calculations)
	local sizeValueObj = Instance.new("NumberValue")
	sizeValueObj.Name = "SizeValue"
	sizeValueObj.Value = self.sizeValue
	sizeValueObj.Parent = part

	-- Add flatten count value
	local flattenCountValue = Instance.new("NumberValue")
	flattenCountValue.Name = "FlattenCount"
	flattenCountValue.Value = self.flattenCount
	flattenCountValue.Parent = part

	-- Add cookness value
	local cooknessValue = Instance.new("NumberValue")
	cooknessValue.Name = "Cookness"
	cooknessValue.Value = self.cookness
	cooknessValue.Parent = part

	-- Add doneness value
	local donenessValue = Instance.new("IntValue")
	donenessValue.Name = "Doneness"
	donenessValue.Value = self.doneness
	donenessValue.Parent = part

	-- Scale the base based on its size value
	local scaleFactor = sizeValueObj.Value ^ (1 / 3) -- Cube root for 3D scaling
	part.Size = Vector3.new(self.size.X * scaleFactor, self.size.Y * scaleFactor, self.size.Z * scaleFactor)

	-- Make it clickable
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.Parent = part

	part.Parent = Workspace

	-- Store the instance
	self.instance = part

	return part
end

-- Create steam effect
function BaseClass:createSteamEffect()
	if not self.instance or self.steamEffect then
		return -- Already has steam effect or no instance
	end

	-- Create an attachment for the steam effect
	local attachment = Instance.new("Attachment")
	attachment.Name = "SteamAttachment"
	attachment.Position = Vector3.new(0, self.instance.Size.Y / 2, 0) -- Top of the object
	attachment.Parent = self.instance

	-- Create steam particle effect
	local steam = Instance.new("ParticleEmitter")
	steam.Name = "SteamEffect"
	steam.Parent = attachment

	-- Steam properties
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Lifetime = NumberRange.new(1.0, 2.5)
	steam.Rate = 50
	steam.SpreadAngle = Vector2.new(45, 45)
	steam.Speed = NumberRange.new(2, 4)
	steam.Acceleration = Vector3.new(0, 2, 0) -- Upward acceleration
	steam.Drag = 5
	steam.VelocityInheritance = 0

	-- Size and transparency over lifetime
	local sizeSequence = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 1.2),
	})
	steam.Size = sizeSequence

	local transparencySequence = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.7, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	steam.Transparency = transparencySequence

	-- Color (white/light gray steam)
	local colorSequence = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(230, 230, 230)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200)),
	})
	steam.Color = colorSequence

	-- Store reference
	self.steamEffect = steam

	print("Created steam effect for", self.name)
end

-- Remove steam effect
function BaseClass:removeSteamEffect()
	if self.steamEffect then
		-- Find and destroy the attachment and steam effect
		if self.instance then
			local attachment = self.instance:FindFirstChild("SteamAttachment")
			if attachment then
				attachment:Destroy()
			end
		end
		self.steamEffect = nil
		print("Removed steam effect for", self.name)
	end
end

-- Update steam effect based on doneness
function BaseClass:updateSteamEffect()
	local currentTime = tick()

	-- Only check steam every 0.5 seconds to avoid excessive updates
	if currentTime - self.lastSteamCheck < 0.5 then
		return
	end
	self.lastSteamCheck = currentTime

	local shouldHaveSteam = self.doneness >= STEAM_DONENESS_THRESHOLD and self.doneness < BURNT_DONENESS

	if shouldHaveSteam and not self.steamEffect then
		self:createSteamEffect()
	elseif not shouldHaveSteam and self.steamEffect then
		self:removeSteamEffect()
	elseif self.steamEffect then
		-- Adjust steam intensity based on doneness
		local intensity =
			math.min(1, (self.doneness - STEAM_DONENESS_THRESHOLD) / (PERFECT_DONENESS - STEAM_DONENESS_THRESHOLD))

		-- Adjust rate based on intensity (more steam when hotter)
		local baseRate = 30
		local maxRate = 80
		self.steamEffect.Rate = baseRate + (maxRate - baseRate) * intensity

		-- Adjust color based on doneness (more yellow/brown when approaching burnt)
		if self.doneness > PERFECT_DONENESS then
			local burnProgress = (self.doneness - PERFECT_DONENESS) / (BURNT_DONENESS - PERFECT_DONENESS)
			local colorSequence = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 240 - burnProgress * 40, 200 - burnProgress * 50)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 180 - burnProgress * 30, 150 - burnProgress * 50)),
			})
			self.steamEffect.Color = colorSequence
		end
	end
end

-- Flatten the base
function BaseClass:flatten(amount)
	if not self.instance then
		return
	end

	amount = amount or 0.5 -- Default flatten by 50%

	-- Update flatten count
	self.flattenCount = self.flattenCount + 1

	-- If on server, update the IntValue
	if isServer then
		-- Store flatten count in instance for persistence
		if not self.instance:FindFirstChild("FlattenCount") then
			local flattenCountValue = Instance.new("NumberValue")
			flattenCountValue.Name = "FlattenCount"
			flattenCountValue.Value = self.flattenCount
			flattenCountValue.Parent = self.instance
		else
			self.instance.FlattenCount.Value = self.flattenCount
		end
	end

	local currentSize = self.instance.Size
	self.instance.Size = Vector3.new(
		currentSize.X * (1 + amount * 0.5),
		currentSize.Y * (1 - amount),
		currentSize.Z * (1 + amount * 0.5)
	)

	print("Flattened " .. self.name .. " (Flatten count: " .. self.flattenCount .. ")")
end

-- Unflatten the base (reduce flatten count by 1)
function BaseClass:unflatten(amount)
	if not self.instance then
		return
	end

	-- Don't unflatten if flatten count is already 0
	if self.flattenCount <= 0 then
		return
	end

	amount = amount or 0.5 -- Default unflatten amount (same as flatten)

	-- Update flatten count
	self.flattenCount = self.flattenCount - 1

	-- If on server, update the IntValue
	if isServer then
		if self.instance:FindFirstChild("FlattenCount") then
			self.instance.FlattenCount.Value = self.flattenCount
		end
	end

	-- Invert the flattening effect
	local currentSize = self.instance.Size
	self.instance.Size = Vector3.new(
		currentSize.X / (1 + amount * 0.5),
		currentSize.Y / (1 - amount),
		currentSize.Z / (1 + amount * 0.5)
	)

	print("Unflattened " .. self.name .. " (Flatten count: " .. self.flattenCount .. ")")
end

-- Update the doneness value
function BaseClass:updateDoneness(value)
	local oldDoneness = self.doneness
	self.doneness = value

	if isServer and self.instance then
		if not self.instance:FindFirstChild("Doneness") then
			local donenessValue = Instance.new("IntValue")
			donenessValue.Name = "Doneness"
			donenessValue.Value = self.doneness
			donenessValue.Parent = self.instance
		else
			self.instance.Doneness.Value = self.doneness
		end
	end

	-- Update steam effect when doneness changes significantly
	if math.abs(self.doneness - oldDoneness) > 10 then
		self:updateSteamEffect()
	end
end

-- Get cooking state as string
function BaseClass:getCookingState()
	local doneness = self.doneness

	if doneness < 120 then
		return "Raw"
	elseif doneness < 300 then
		return "Slightly Cooked"
	elseif doneness < 500 then
		return "Cooked"
	elseif doneness < PERFECT_DONENESS then
		return "Well Cooked"
	elseif doneness <= BURNT_DONENESS then
		return "Perfectly Cooked"
	else
		return "Burnt"
	end
end

-- Check if the object is burnt
function BaseClass:isBurnt()
	return self.doneness > BURNT_DONENESS
end

-- Perform the actual slice operation
function BaseClass:performSlice(sliceStart, sliceEnd)
	if not self.instance then
		return nil, nil
	end

	local part = self.instance
	local partPosition = part.Position
	local partSize = part.Size
	local sizeValue = part:FindFirstChild("SizeValue") and part.SizeValue.Value or DEFAULT_BASE_SIZE_VALUE

	-- Calculate the slice direction and normalize it to XZ plane
	local sliceDir = Vector3.new(sliceEnd.X - sliceStart.X, 0, sliceEnd.Z - sliceStart.Z).Unit

	-- Calculate perpendicular vector to the slice (for offsetting the new bases)
	local perpDir = Vector3.new(-sliceDir.Z, 0, sliceDir.X)

	-- Calculate part center in XZ plane
	local partCenterXZ = Vector3.new(partPosition.X, 0, partPosition.Z)

	-- Calculate slice center in XZ plane
	local sliceCenter = Vector3.new((sliceStart.X + sliceEnd.X) / 2, 0, (sliceStart.Z + sliceEnd.Z) / 2)

	-- Calculate distance from slice center to part center
	local centerToSlice = (sliceCenter - partCenterXZ).Magnitude

	-- Calculate the ratio for splitting (0.5 means perfect middle, closer to 0 or 1 means uneven)
	local partRadius = math.max(partSize.X, partSize.Z) / 2
	local splitRatio = math.clamp(centerToSlice / partRadius, 0.01, 0.99)

	-- Calculate size values for the two halves
	-- The further from center, the more uneven the split
	local largerSideRatio = 0.5 + (splitRatio * 0.5) -- Ranges from 0.5 to 1.0
	local smallerSideRatio = 1 - largerSideRatio -- Ranges from 0.5 to 0.0

	-- Determine which side is smaller (the one the slice is closer to)
	local sideSign = perpDir:Dot(sliceCenter - partCenterXZ)

	-- Assign size values based on which side is smaller
	local sizeValue1, sizeValue2
	if sideSign >= 0 then
		-- Slice is closer to side 2
		sizeValue1 = sizeValue * largerSideRatio
		sizeValue2 = sizeValue * smallerSideRatio
	else
		-- Slice is closer to side 1
		sizeValue1 = sizeValue * smallerSideRatio
		sizeValue2 = sizeValue * largerSideRatio
	end

	-- Calculate offset distances proportional to the split
	local offsetRatio1 = sizeValue1 / sizeValue
	local offsetRatio2 = sizeValue2 / sizeValue

	-- Calculate positions for the two new pieces
	local pos1 = Vector3.new(
		partPosition.X + perpDir.X * partRadius * offsetRatio2 * 0.5,
		partPosition.Y,
		partPosition.Z + perpDir.Z * partRadius * offsetRatio2 * 0.5
	)

	local pos2 = Vector3.new(
		partPosition.X - perpDir.X * partRadius * offsetRatio1 * 0.5,
		partPosition.Y,
		partPosition.Z - perpDir.Z * partRadius * offsetRatio1 * 0.5
	)

	print("Slicing " .. self.name .. " with ratio:", string.format("%.2f/%.2f", sizeValue1, sizeValue2))

	-- Only server should actually create new pieces
	if not isServer then
		return nil, nil
	end

	-- Create the two new pieces
	local params1 = {
		name = self.name,
		position = pos1,
		sizeValue = sizeValue1,
		color = self.color,
		size = self.size,
		material = self.material,
		meshType = self.meshType,
		highlightColor = self.highlightColor,
		flattenCount = self.flattenCount, -- Preserve flatten count from original object
		cookness = self.cookness, -- Preserve cookness
		doneness = self.doneness, -- Preserve doneness
	}

	local params2 = {
		name = self.name,
		position = pos2,
		sizeValue = sizeValue2,
		color = self.color,
		size = self.size,
		material = self.material,
		meshType = self.meshType,
		highlightColor = self.highlightColor,
		flattenCount = self.flattenCount, -- Preserve flatten count from original object
		cookness = self.cookness, -- Preserve cookness
		doneness = self.doneness, -- Preserve doneness
	}

	-- Get the class of the current object
	local objClass = getmetatable(self)

	-- Create new instances using the same class as the original object
	local newInstance1 = objClass.new(params1)
	local newInstance2 = objClass.new(params2)

	-- Remove steam effect from original before destroying
	self:removeSteamEffect()

	-- Destroy the original instance
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end

	return newInstance1, newInstance2
end

-- Stub for combine functionality (not implemented as per instructions)
function BaseClass:combine(otherBase)
	print("Combine functionality not implemented yet")
	return nil
end

-- Cleanup the base object
function BaseClass:cleanup()
	-- Remove steam effect
	self:removeSteamEffect()

	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
end

return BaseClass
