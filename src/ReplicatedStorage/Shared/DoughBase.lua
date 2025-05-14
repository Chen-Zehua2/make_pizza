-- DoughBase.lua
-- Dough object that inherits from BaseClass

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseClass = require(ReplicatedStorage.Shared.BaseClass)

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

	-- Create the base object using BaseClass constructor
	local self = BaseClass.new(params)

	-- Convert to DoughBase
	setmetatable(self, DoughBase)

	-- Override the options with dough-specific options
	-- Add combine option specifically for dough
	local SliceSystem = require(ReplicatedStorage.Shared.SliceSystem)
	local CombineSystem = require(ReplicatedStorage.Shared.CombineSystem)
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
	-- Call the parent class's flatten method for consistent behavior
	BaseClass.flatten(self, amount)
end

-- Create a factory function for easy creation of dough objects
function DoughBase.createDough(position, sizeValue)
	local params = {
		position = position,
		sizeValue = sizeValue,
	}
	return DoughBase.new(params)
end

return DoughBase
