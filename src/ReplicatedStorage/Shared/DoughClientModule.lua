-- DoughClientModule.lua
-- A wrapper module to access DoughClientFunctions through a more traditional API

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Check if we're running on client
local isClient = RunService:IsClient()

-- This module should only be used on the client
if not isClient then
	return {
		createDough = function()
			warn("DoughClientModule can only be used on the client")
		end,
		getDough = function()
			warn("DoughClientModule can only be used on the client")
		end,
		getDoughFromInstance = function()
			warn("DoughClientModule can only be used on the client")
		end,
		splitDough = function()
			warn("DoughClientModule can only be used on the client")
		end,
		combineDoughs = function()
			warn("DoughClientModule can only be used on the client")
		end,
		flattenDough = function()
			warn("DoughClientModule can only be used on the client")
		end,
		destroyDough = function()
			warn("DoughClientModule can only be used on the client")
		end,
	}
end

-- Wait for DoughClientFunctions to be ready
local doughClientFunctions
local attempts = 0
local maxAttempts = 10
repeat
	attempts = attempts + 1
	task.wait(0.5)

	-- Try to find the DoughClientFunctions folder
	doughClientFunctions = ReplicatedStorage:FindFirstChild("DoughClientFunctions")
until doughClientFunctions or attempts >= maxAttempts

if not doughClientFunctions then
	error("Failed to find DoughClientFunctions folder after multiple attempts")
end

-- Helper function to invoke a function from doughClientFunctions
local function invokeClientFunction(functionName, ...)
	local bindableFunc = doughClientFunctions:FindFirstChild(functionName)
	if bindableFunc and bindableFunc:IsA("BindableFunction") then
		return bindableFunc:Invoke(...)
	else
		warn("Function " .. functionName .. " not found in DoughClientFunctions")
		return nil
	end
end

-- Create the module API
local DoughClientModule = {
	createDough = function(position, sizeValue)
		return invokeClientFunction("CreateDough", position, sizeValue)
	end,

	getDough = function(doughId)
		return invokeClientFunction("GetDough", doughId)
	end,

	getDoughFromInstance = function(instance)
		return invokeClientFunction("GetDoughFromInstance", instance)
	end,

	splitDough = function(doughId, sliceStart, sliceEnd)
		return invokeClientFunction("SplitDough", doughId, sliceStart, sliceEnd)
	end,

	combineDoughs = function(targetDoughId, doughsToRemoveIds, totalSizeValue)
		return invokeClientFunction("CombineDoughs", targetDoughId, doughsToRemoveIds, totalSizeValue)
	end,

	flattenDough = function(doughId, amount)
		return invokeClientFunction("FlattenDough", doughId, amount)
	end,

	destroyDough = function(doughId)
		return invokeClientFunction("DestroyDough", doughId)
	end,
}

return DoughClientModule
