-- ProfileSystem.lua
-- Manages player profile UI and functionality

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Check if we're running on client or server
local isClient = RunService:IsClient()

local ProfileSystem = {}

-- Client-only variables
local player
local PlayerGui
local Roact
local ProfileUI
local currentProfileHandle = nil

if isClient then
	player = Players.LocalPlayer
	PlayerGui = player:WaitForChild("PlayerGui")
	Roact = require(ReplicatedStorage.Shared.Roact)
	ProfileUI = require(ReplicatedStorage.Shared.UILib.ProfileUI)
end

-- Function to show player profile
function ProfileSystem.showProfile(targetPlayer)
	-- Only run on client
	if not isClient then
		return
	end

	-- Use local player if no target specified
	targetPlayer = targetPlayer or player

	-- Close existing profile if open
	if currentProfileHandle then
		ProfileSystem.closeProfile()
	end

	-- Mount the profile UI
	currentProfileHandle = Roact.mount(
		Roact.createElement(ProfileUI, {
			isOpen = true,
			player = targetPlayer,
			onClose = function()
				ProfileSystem.closeProfile()
			end,
		}),
		PlayerGui
	)

	print("Profile opened for player:", targetPlayer.Name)
end

-- Function to close profile
function ProfileSystem.closeProfile()
	-- Only run on client
	if not isClient then
		return
	end

	if currentProfileHandle then
		Roact.unmount(currentProfileHandle)
		currentProfileHandle = nil
		print("Profile closed")
	end
end

-- Function to check if profile is open
function ProfileSystem.isProfileOpen()
	return currentProfileHandle ~= nil
end

-- Function to toggle profile
function ProfileSystem.toggleProfile(targetPlayer)
	if ProfileSystem.isProfileOpen() then
		ProfileSystem.closeProfile()
	else
		ProfileSystem.showProfile(targetPlayer)
	end
end

-- Function to get player stats (can be expanded later)
function ProfileSystem.getPlayerStats(targetPlayer)
	targetPlayer = targetPlayer or player

	-- This is a placeholder - in a real game you'd fetch from a datastore
	return {
		recipesCreated = 0,
		badgesEarned = 0,
		pizzasBaked = 0,
		perfectPizzas = 0,
		joinDate = targetPlayer.AccountAge,
	}
end

return ProfileSystem
