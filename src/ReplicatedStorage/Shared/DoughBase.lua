-- DoughBase.lua
-- Dough object that inherits from BaseClass

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local BaseClass = require(ReplicatedStorage.Shared.BaseClass)

-- Check if we're running on client or server
local isClient = RunService:IsClient()
local isServer = RunService:IsServer()

local DoughBase = {}
DoughBase.__index = DoughBase

-- Inherit from BaseClass
setmetatable(DoughBase, {
	__index = BaseClass,
})

-- Constructor for a new dough object
function DoughBase.new(params)
	params = params or {}

	-- Set dough specific defaults
	params.name = params.name or "Dough"
	params.size = params.size or Vector3.new(3, 1.5, 3)
	params.color = params.color or Color3.fromRGB(235, 213, 179) -- Doughy color
	params.meshType = params.meshType or Enum.MeshType.Sphere
	params.material = params.material or Enum.Material.SmoothPlastic
	params.cookness = params.cookness or 1 -- Default cookness for dough

	-- Create the base object using BaseClass constructor
	local self = BaseClass.new(params)

	-- Convert to DoughBase
	setmetatable(self, DoughBase)

	-- Override the options with dough-specific options
	-- Add combine option specifically for dough
	local SplitSystem = require(ReplicatedStorage.Shared.SplitSystem)
	local CombineSystem = require(ReplicatedStorage.Shared.CombineSystem)
	self.options = {
		{
			text = "Split",
			color = Color3.fromRGB(255, 156, 156), -- Red color for Split
			callback = function()
				SplitSystem.startSplitting(self, getmetatable(self))
			end,
		},
		{
			text = "Flatten Scale",
			color = Color3.fromRGB(156, 156, 255), -- Blue color for flatten
			type = "scale", -- New type to indicate this is a scale control
			min = 0,
			max = 3,
			callback = function(value)
				self:setFlattenValue(value)
			end,
		},
		{
			text = "Combine",
			color = Color3.fromRGB(156, 255, 156), -- Green color for combine
			callback = function()
				CombineSystem.startCombining(self)
			end,
		},
	}

	return self
end

-- Keep flatten method for backward compatibility and clean inheritance
function DoughBase:flatten(amount)
	-- If we're on the client, only use the remote event and don't call BaseClass.flatten
	if isClient then
		-- Get the DoughId from the instance attributes
		local doughId = self.instance and self.instance:GetAttribute("DoughId")
		if doughId then
			-- Require DoughRemotes only when needed
			local DoughRemotes = require(ReplicatedStorage.Shared.DoughRemotes)
			DoughRemotes.FlattenDough:FireServer(doughId, amount)

			-- Don't call BaseClass.flatten on client - let the server flatten and sync back
			-- This avoids the double flattening issue
			return
		end
	end

	-- Only server should actually flatten the dough
	if isServer then
		-- Check doneness value before allowing flatten
		local doneness = 0
		if self.instance and self.instance:FindFirstChild("Doneness") then
			doneness = self.instance.Doneness.Value
		end

		if doneness > 0 then
			print("Cannot flatten dough with doneness > 0")
			return
		end

		-- Call the parent class's flatten method for consistent behavior
		BaseClass.flatten(self, amount)
	end
end

-- Add unflatten method that uses remote event
function DoughBase:unflatten(amount)
	-- If we're on the client, use the remote event
	if isClient then
		-- Get the DoughId from the instance attributes
		local doughId = self.instance and self.instance:GetAttribute("DoughId")
		if doughId then
			-- Require DoughRemotes only when needed
			local DoughRemotes = require(ReplicatedStorage.Shared.DoughRemotes)
			DoughRemotes.UnflattenDough:FireServer(doughId, amount)

			-- Don't call BaseClass.unflatten on client - let the server handle it
			return
		end
	end

	-- Only server should actually unflatten the dough
	if isServer then
		-- Check doneness value before allowing unflatten
		local doneness = 0
		if self.instance and self.instance:FindFirstChild("Doneness") then
			doneness = self.instance.Doneness.Value
		end

		if doneness > 0 then
			print("Cannot unflatten dough with doneness > 0")
			return
		end

		-- Call the parent class's unflatten method
		BaseClass.unflatten(self, amount)
	end
end

-- New method to set flatten value directly using a scale
function DoughBase:setFlattenValue(value)
	-- If we're on the client, use the remote event
	if isClient then
		-- Get the DoughId from the instance attributes
		local doughId = self.instance and self.instance:GetAttribute("DoughId")
		if doughId then
			-- Require DoughRemotes only when needed
			local DoughRemotes = require(ReplicatedStorage.Shared.DoughRemotes)
			DoughRemotes.SetFlattenValue:FireServer(doughId, value)
			return
		end
	end

	-- Only server should actually set the flatten value
	if isServer then
		-- Check doneness value before allowing flatten adjustment
		local doneness = 0
		if self.instance and self.instance:FindFirstChild("Doneness") then
			doneness = self.instance.Doneness.Value
		end

		if doneness > 0 then
			print("Cannot adjust flatten value with doneness > 0")
			return
		end

		-- Validate the value is within bounds
		value = math.clamp(value, 0, 3)

		-- Update the flatten count
		self.flattenCount = value
		if self.instance:FindFirstChild("FlattenCount") then
			self.instance.FlattenCount.Value = value
		else
			local flattenCountValue = Instance.new("NumberValue")
			flattenCountValue.Name = "FlattenCount"
			flattenCountValue.Value = value
			flattenCountValue.Parent = self.instance
		end

		-- Get original size before flattening
		local originalSize = self.size
		local sizeValue = self.sizeValue or 1

		-- Calculate scale factor based on size value (for volume)
		local scaleFactor = sizeValue ^ (1 / 3) -- Cube root for 3D scaling

		-- Calculate flattening effect (0 = no flattening, 3 = maximum flattening)
		local flattenFactor = math.max(0.1, 1 - (value * 0.3)) -- At value 3, height is 10% of original
		local spreadFactor = math.sqrt(1 / flattenFactor) -- Preserve volume

		-- Calculate final size
		local newSize = Vector3.new(
			originalSize.X * scaleFactor * spreadFactor,
			originalSize.Y * scaleFactor * flattenFactor,
			originalSize.Z * scaleFactor * spreadFactor
		)

		-- Update instance size
		self.instance.Size = newSize
	end
end

-- Override getCookingState to provide custom dough-specific cooking states
function DoughBase:getCookingState()
	local doneness = self.doneness

	if doneness <= 0 then
		return "Raw Dough"
	elseif doneness < 300 then
		return "Slightly Cooked"
	elseif doneness < 500 then
		return "Half-Baked"
	elseif doneness < 600 then
		return "Well-Baked"
	elseif doneness <= 900 then
		return "Perfectly Baked"
	else
		return "Burnt"
	end
end

-- Create a factory function for easy creation of dough objects
function DoughBase.createDough(position, sizeValue)
	if isClient then
		-- On client, don't create the actual instance, just request it from server
		-- Use the DoughClientModule
		local DoughClientModule = require(ReplicatedStorage.Shared.DoughClientModule)
		DoughClientModule.createDough(position, sizeValue)
		return -- Return nil as the dough is created asynchronously
	elseif isServer then
		-- On server, create the dough directly
		local params = {
			position = position,
			sizeValue = sizeValue,
		}
		return DoughBase.new(params)
	end
end

-- Helper function to check if dough can be manipulated
function DoughBase:canBeManipulated()
	local doneness = 0
	if self.instance and self.instance:FindFirstChild("Doneness") then
		doneness = self.instance.Doneness.Value
	elseif self.doneness then
		doneness = self.doneness
	end

	return doneness <= 0
end

return DoughBase
