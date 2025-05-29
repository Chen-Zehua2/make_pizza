-- ProfileUI.lua
-- Player Profile UI component using Roact

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Roact = require(ReplicatedStorage.Shared.Roact)
local RecipeBookUI = require(ReplicatedStorage.Shared.UILib.RecipeBookUI)
local BadgesUI = require(ReplicatedStorage.Shared.UILib.BadgesUI)

local ProfileUI = Roact.Component:extend("ProfileUI")

function ProfileUI:init()
	self:setState({
		activeTab = "recipes", -- "recipes" or "badges"
		player = self.props.player or Players.LocalPlayer,
	})
end

function ProfileUI:render()
	if not self.props.isOpen then
		return nil
	end

	local activeTab = self.state.activeTab
	local player = self.state.player

	return Roact.createElement("ScreenGui", {
		ResetOnSpawn = false,
	}, {
		MainFrame = Roact.createElement("Frame", {
			Size = UDim2.new(0.9, 0, 0.9, 0),
			Position = UDim2.new(0.05, 0, 0.05, 0),
			BackgroundColor3 = Color3.fromRGB(59, 138, 235),
			BorderSizePixel = 0,
		}, {
			Corner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, 12),
			}),
			Padding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			-- Header Section
			HeaderFrame = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 80),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 1,
			}, {
				PlayerAvatar = Roact.createElement("ImageLabel", {
					Size = UDim2.new(0, 60, 0, 60),
					Position = UDim2.new(0, 10, 0, 10),
					BackgroundColor3 = Color3.fromRGB(40, 40, 40),
					Image = "https://www.roblox.com/headshot-thumbnail/image?userId="
						.. player.UserId
						.. "&width=60&height=60&format=png",
				}, {
					Corner = Roact.createElement("UICorner", {
						CornerRadius = UDim.new(0, 30),
					}),
				}),
				PlayerName = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.6, 0, 0, 30),
					Position = UDim2.new(0, 80, 0, 10),
					BackgroundTransparency = 1,
					Text = player.DisplayName,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 24,
					Font = Enum.Font.GothamBold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				PlayerUsername = Roact.createElement("TextLabel", {
					Size = UDim2.new(0.6, 0, 0, 20),
					Position = UDim2.new(0, 80, 0, 40),
					BackgroundTransparency = 1,
					Text = "@" .. player.Name,
					TextColor3 = Color3.fromRGB(200, 200, 200),
					TextSize = 16,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				CloseButton = Roact.createElement("TextButton", {
					Size = UDim2.new(0, 30, 0, 30),
					Position = UDim2.new(1, -30, 0, 0),
					BackgroundColor3 = Color3.fromRGB(255, 100, 100),
					Text = "X",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 18,
					Font = Enum.Font.GothamBold,
					[Roact.Event.MouseButton1Click] = function()
						if self.props.onClose then
							self.props.onClose()
						end
					end,
				}, {
					Corner = Roact.createElement("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),
				}),
			}),
			-- Tab Navigation
			TabFrame = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 50),
				Position = UDim2.new(0, 0, 0, 90),
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				BorderSizePixel = 0,
			}, {
				Corner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, 8),
				}),
				RecipesTab = Roact.createElement("TextButton", {
					Size = UDim2.new(0.5, -5, 1, -10),
					Position = UDim2.new(0, 5, 0, 5),
					BackgroundColor3 = activeTab == "recipes" and Color3.fromRGB(59, 138, 235)
						or Color3.fromRGB(60, 60, 60),
					Text = "RECIPES",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 18,
					Font = Enum.Font.GothamBold,
					[Roact.Event.MouseButton1Click] = function()
						self:setState({
							activeTab = "recipes",
						})
					end,
				}, {
					Corner = Roact.createElement("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),
				}),
				BadgesTab = Roact.createElement("TextButton", {
					Size = UDim2.new(0.5, -5, 1, -10),
					Position = UDim2.new(0.5, 0, 0, 5),
					BackgroundColor3 = activeTab == "badges" and Color3.fromRGB(59, 138, 235)
						or Color3.fromRGB(60, 60, 60),
					Text = "BADGES",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 18,
					Font = Enum.Font.GothamBold,
					[Roact.Event.MouseButton1Click] = function()
						self:setState({
							activeTab = "badges",
						})
					end,
				}, {
					Corner = Roact.createElement("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),
				}),
			}),
			-- Content Area
			ContentFrame = Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 1, -150),
				Position = UDim2.new(0, 0, 0, 150),
				BackgroundTransparency = 1,
			}, {
				-- Recipes Content
				RecipesContent = activeTab == "recipes"
						and Roact.createElement(RecipeBookUI, {
							isOpen = true,
							onClose = function() end, -- Don't close the profile when recipe book closes
							embedded = true, -- Flag to indicate this is embedded in profile
						})
					or nil,
				-- Badges Content
				BadgesContent = activeTab == "badges"
						and Roact.createElement("Frame", {
							Size = UDim2.new(1, 0, 1, 0),
							BackgroundTransparency = 1,
						}, {
							BadgesUI = Roact.createElement(BadgesUI, {
								isOpen = true,
								player = player,
								onClose = function() end, -- Don't close the profile when badges closes
								embedded = true, -- Flag to indicate this is embedded in profile
							}),
						})
					or nil,
			}),
		}),
	})
end

return ProfileUI
