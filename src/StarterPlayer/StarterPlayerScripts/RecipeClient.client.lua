-- RecipeClient.lua
-- Client script to initialize the Recipe System

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Roact = require(ReplicatedStorage.Shared.Roact)
local ToggleButton = require(ReplicatedStorage.Shared.UILib.Shared.ToggleButton)
local RecipeBookUI = nil -- We'll try to require this in a pcall

-- Try to require the RecipeBookUI component
local success, result = pcall(function()
	return require(ReplicatedStorage.Shared.UILib.RecipeBookUI)
end)

if success then
	RecipeBookUI = result
else
	warn("Failed to require RecipeBookUI: " .. tostring(result))
end

local player = game.Players.LocalPlayer

-- Initialize the recipe book toggle button
if RecipeBookUI then
	local handle = Roact.mount(
		Roact.createElement(ToggleButton, {
			text = "RECIPE BOOK",
			backgroundColor = Color3.fromRGB(255, 215, 0), -- Gold color
			position = UDim2.new(0.95, -150, 0.1, 0),
			size = UDim2.new(0, 150, 0, 40),
			uiComponent = RecipeBookUI,
			onToggleOn = function()
				print("Recipe Book opened")
			end,
			onToggleOff = function()
				print("Recipe Book closed")
			end,
		}),
		player.PlayerGui,
		"RecipeBookToggle"
	)

	print("Recipe System initialized with UI")
else
	print("Recipe System initialized without UI (RecipeBookUI not found)")
end
