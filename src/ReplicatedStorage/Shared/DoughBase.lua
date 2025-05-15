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
		-- Call the parent class's flatten method for consistent behavior
		BaseClass.flatten(self, amount)
	end
end

-- Override getCookingState to provide custom dough-specific cooking states
function DoughBase:getCookingState()
	local doneness = self.doneness

	if doneness < 120 then
		return "Raw Dough"
	elseif doneness < 300 then
		return "Slightly Baked"
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

return DoughBase
