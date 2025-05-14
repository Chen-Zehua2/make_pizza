-- BaseClass.lua
-- Base class for pizza base objects (like dough) that can slice and combine

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BaseClass = {}
BaseClass.__index = BaseClass

-- Constants
local MINIMUM_SLICE_LENGTH = 0.75 -- 75% of the base needs to be sliced
local DEFAULT_BASE_SIZE_VALUE = 1 -- Default base "size" property (for splitting)

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

	-- Instance for the part
	self.instance = nil

	-- Create the physical instance
	self:create()

	-- Define available options for base objects with fixed colors
	-- This will be loaded by the UI system
	local SliceSystem = require(ReplicatedStorage.Shared.SliceSystem)
	self.options = {
		{
			text = "Slice",
			color = Color3.fromRGB(255, 156, 156), -- Red color for slice
			callback = function()
				SliceSystem.startSlicing(self, getmetatable(self))
			end,
		},
		{
			text = "Flatten",
			color = Color3.fromRGB(156, 156, 255), -- Blue color for flatten
			callback = function()
				self:flatten()
			end,
		},
	}

	return self
end

-- Create the physical instance of the base
function BaseClass:create()
	-- Create the base part
	local part = Instance.new("Part")
	part.Name = self.name
	part.Size = self.size
	part.Position = self.position
	part.Anchored = true
	part.CanCollide = true
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

-- Flatten the base
function BaseClass:flatten(amount)
	if not self.instance then
		return
	end

	amount = amount or 0.5 -- Default flatten by 50%

	local currentSize = self.instance.Size
	self.instance.Size = Vector3.new(
		currentSize.X * (1 + amount * 0.5),
		currentSize.Y * (1 - amount),
		currentSize.Z * (1 + amount * 0.5)
	)

	print("Flattened " .. self.name)
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
	}

	-- Get the class of the current object
	local objClass = getmetatable(self)

	-- Create new instances using the same class as the original object
	local newInstance1 = objClass.new(params1)
	local newInstance2 = objClass.new(params2)

	-- Destroy the original instance
	self.instance:Destroy()
	self.instance = nil

	-- Create a slicing effect
	local sliceEffect = Instance.new("Part")
	sliceEffect.Anchored = true
	sliceEffect.CanCollide = false
	sliceEffect.Size = Vector3.new(partSize.X * 2, 0.1, 0.1)
	sliceEffect.CFrame = CFrame.lookAt(sliceStart, sliceEnd) * CFrame.new(0, 0, -(sliceStart - sliceEnd).Magnitude / 2)
	sliceEffect.Material = Enum.Material.Neon
	sliceEffect.Color = Color3.fromRGB(255, 0, 0)
	sliceEffect.Transparency = 0
	sliceEffect.Parent = Workspace

	-- Animate the effect
	TweenService:Create(sliceEffect, TweenInfo.new(0.3), {
		Transparency = 1,
		Size = Vector3.new(sliceEffect.Size.X, 0.5, 0.5),
	}):Play()

	-- Remove the effect after animation
	task.delay(0.3, function()
		sliceEffect:Destroy()
	end)

	return newInstance1, newInstance2
end

-- Stub for combine functionality (not implemented as per instructions)
function BaseClass:combine(otherBase)
	print("Combine functionality not implemented yet")
	return nil
end

-- Cleanup the base object
function BaseClass:cleanup()
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
end

return BaseClass
