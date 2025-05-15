-- BakingInit.server.lua
-- Server-side initialization for the baking system

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import and initialize the baking system
local BakingSystem = require(ReplicatedStorage.Shared.BakingSystem)

print("Server-side BakingSystem initialized")
