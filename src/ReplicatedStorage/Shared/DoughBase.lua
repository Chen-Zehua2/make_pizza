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

	return self
end

-- Override or add any dough-specific methods here
-- For example, we can add specific behaviors for dough

-- Add a method to flatten the dough (just as an example)
function DoughBase:flatten(amount)
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
