-- NotificationSystem.lua
-- Reusable notification system for showing error and success messages

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Check if we're running on client
local isClient = RunService:IsClient()

-- Client-only variables
local player
local PlayerGui
if isClient then
	player = Players.LocalPlayer
	PlayerGui = player:WaitForChild("PlayerGui")
end

local NotificationSystem = {}

-- Constants
local NOTIFICATION_DURATION = 3 -- seconds
local FADE_DURATION = 0.5 -- seconds

-- Active notifications tracking
local activeNotifications = {}
local notificationCount = 0

-- Function to create a notification
function NotificationSystem.showNotification(message, notificationType, duration)
	if not isClient then
		return
	end

	notificationType = notificationType or "info"
	duration = duration or NOTIFICATION_DURATION

	-- Increment notification count for unique IDs
	notificationCount = notificationCount + 1
	local notificationId = "Notification_" .. notificationCount

	-- Color scheme based on notification type
	local colors = {
		error = {
			background = Color3.fromRGB(220, 53, 69),
			text = Color3.fromRGB(255, 255, 255),
			border = Color3.fromRGB(183, 28, 28),
		},
		success = {
			background = Color3.fromRGB(40, 167, 69),
			text = Color3.fromRGB(255, 255, 255),
			border = Color3.fromRGB(27, 94, 32),
		},
		warning = {
			background = Color3.fromRGB(255, 193, 7),
			text = Color3.fromRGB(0, 0, 0),
			border = Color3.fromRGB(255, 143, 0),
		},
		info = {
			background = Color3.fromRGB(23, 162, 184),
			text = Color3.fromRGB(255, 255, 255),
			border = Color3.fromRGB(13, 110, 253),
		},
	}

	local colorScheme = colors[notificationType] or colors.info

	-- Create notification GUI
	local notificationGui = Instance.new("ScreenGui")
	notificationGui.Name = notificationId
	notificationGui.ResetOnSpawn = false
	notificationGui.DisplayOrder = 100 -- High display order to appear on top
	notificationGui.Parent = PlayerGui

	-- Calculate position based on existing notifications
	local yOffset = 20 + (#activeNotifications * 70)

	-- Main notification frame
	local notificationFrame = Instance.new("Frame")
	notificationFrame.Name = "NotificationFrame"
	notificationFrame.Size = UDim2.new(0, 350, 0, 60)
	notificationFrame.Position = UDim2.new(1, -370, 0, yOffset) -- Start off-screen to the right
	notificationFrame.BackgroundColor3 = colorScheme.background
	notificationFrame.BorderSizePixel = 0
	notificationFrame.Parent = notificationGui

	-- Corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = notificationFrame

	-- Border/stroke effect
	local stroke = Instance.new("UIStroke")
	stroke.Color = colorScheme.border
	stroke.Thickness = 2
	stroke.Parent = notificationFrame

	-- Drop shadow
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 6, 1, 6)
	shadow.Position = UDim2.new(0, 3, 0, 3)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.7
	shadow.ZIndex = -1
	shadow.Parent = notificationFrame

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 8)
	shadowCorner.Parent = shadow

	-- Icon based on type
	local iconText = {
		error = "⚠",
		success = "✓",
		warning = "⚠",
		info = "ℹ",
	}

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 30, 1, 0)
	icon.Position = UDim2.new(0, 10, 0, 0)
	icon.BackgroundTransparency = 1
	icon.Text = iconText[notificationType] or iconText.info
	icon.TextColor3 = colorScheme.text
	icon.TextSize = 24
	icon.Font = Enum.Font.GothamBold
	icon.TextXAlignment = Enum.TextXAlignment.Center
	icon.TextYAlignment = Enum.TextYAlignment.Center
	icon.Parent = notificationFrame

	-- Message text
	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "Message"
	messageLabel.Size = UDim2.new(1, -90, 1, -10)
	messageLabel.Position = UDim2.new(0, 45, 0, 5)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = message
	messageLabel.TextColor3 = colorScheme.text
	messageLabel.TextSize = 14
	messageLabel.Font = Enum.Font.Gotham
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextYAlignment = Enum.TextYAlignment.Center
	messageLabel.TextWrapped = true
	messageLabel.Parent = notificationFrame

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -35, 0, 15)
	closeButton.BackgroundTransparency = 1
	closeButton.Text = "×"
	closeButton.TextColor3 = colorScheme.text
	closeButton.TextSize = 20
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = notificationFrame

	-- Store notification reference
	local notificationData = {
		gui = notificationGui,
		frame = notificationFrame,
		id = notificationId,
		startTime = tick(),
	}
	table.insert(activeNotifications, notificationData)

	-- Slide in animation
	local slideInTween = TweenService:Create(
		notificationFrame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(1, -370, 0, yOffset) }
	)

	-- Start from off-screen
	notificationFrame.Position = UDim2.new(1, 0, 0, yOffset)
	slideInTween:Play()

	-- Function to remove notification
	local function removeNotification()
		-- Find and remove from active notifications
		for i, notification in ipairs(activeNotifications) do
			if notification.id == notificationId then
				table.remove(activeNotifications, i)
				break
			end
		end

		-- Slide out animation
		local slideOutTween = TweenService:Create(
			notificationFrame,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(1, 0, 0, yOffset) }
		)

		slideOutTween:Play()
		slideOutTween.Completed:Connect(function()
			notificationGui:Destroy()
			-- Reposition remaining notifications
			NotificationSystem.repositionNotifications()
		end)
	end

	-- Close button functionality
	closeButton.MouseButton1Click:Connect(removeNotification)

	-- Auto-remove after duration
	task.delay(duration, removeNotification)

	return notificationData
end

-- Function to reposition all active notifications
function NotificationSystem.repositionNotifications()
	for i, notification in ipairs(activeNotifications) do
		local newYOffset = 20 + ((i - 1) * 70)
		local repositionTween = TweenService:Create(
			notification.frame,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.new(1, -370, 0, newYOffset) }
		)
		repositionTween:Play()
	end
end

-- Convenience functions for different notification types
function NotificationSystem.showError(message, duration)
	return NotificationSystem.showNotification(message, "error", duration)
end

function NotificationSystem.showSuccess(message, duration)
	return NotificationSystem.showNotification(message, "success", duration)
end

function NotificationSystem.showWarning(message, duration)
	return NotificationSystem.showNotification(message, "warning", duration)
end

function NotificationSystem.showInfo(message, duration)
	return NotificationSystem.showNotification(message, "info", duration)
end

-- Function to clear all notifications
function NotificationSystem.clearAll()
	for _, notification in ipairs(activeNotifications) do
		if notification.gui then
			notification.gui:Destroy()
		end
	end
	activeNotifications = {}
end

return NotificationSystem
