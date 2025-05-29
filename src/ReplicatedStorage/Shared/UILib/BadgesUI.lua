-- BadgesUI.lua
-- Badges UI component using Roact

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")

local Roact = require(ReplicatedStorage.Shared.Roact)

local BadgesUI = Roact.Component:extend("BadgesUI")

function BadgesUI:init()
	self:setState({
		badges = {},
		playerBadges = {},
		isLoading = true,
	})
end

function BadgesUI:render()
	if not self.props.isOpen then
		return nil
	end

	-- Create badge items
	local badgeItems = {}
	for i, badge in ipairs(self.state.badges) do
		local isOwned = self.state.playerBadges[badge.Id] or false

		badgeItems["Badge_" .. badge.Id] = Roact.createElement("Frame", {
			Size = UDim2.new(0, 120, 0, 140),
			BackgroundColor3 = isOwned and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(30, 30, 30),
			BorderSizePixel = 0,
			LayoutOrder = i,
		}, {
			Corner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			Padding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 8),
				PaddingBottom = UDim.new(0, 8),
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
			BadgeIcon = Roact.createElement("ImageLabel", {
				Size = UDim2.new(0, 64, 0, 64),
				Position = UDim2.new(0.5, -32, 0, 0),
				BackgroundTransparency = 1,
				Image = badge.IconImageId and "rbxassetid://" .. badge.IconImageId or "",
				ImageTransparency = isOwned and 0 or 0.6,
			}, {
				Corner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
			}),
			BadgeName = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 20),
				Position = UDim2.new(0, 0, 0, 70),
				BackgroundTransparency = 1,
				Text = badge.Name,
				TextColor3 = isOwned and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150),
				TextSize = 12,
				Font = Enum.Font.GothamBold,
				TextWrapped = true,
				TextScaled = true,
			}),
			BadgeDescription = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0, 40),
				Position = UDim2.new(0, 0, 0, 92),
				BackgroundTransparency = 1,
				Text = badge.Description,
				TextColor3 = isOwned and Color3.fromRGB(200, 200, 200) or Color3.fromRGB(120, 120, 120),
				TextSize = 10,
				Font = Enum.Font.Gotham,
				TextWrapped = true,
				TextScaled = true,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
		})
	end

	-- If embedded, return just the content without ScreenGui wrapper
	if self.props.embedded then
		return Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			BorderSizePixel = 0,
		}, {
			Corner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			LoadingFrame = self.state.isLoading and Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
			}, {
				LoadingText = Roact.createElement("TextLabel", {
					Size = UDim2.new(1, 0, 0, 30),
					Position = UDim2.new(0, 0, 0.5, -15),
					BackgroundTransparency = 1,
					Text = "Loading badges...",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 18,
					Font = Enum.Font.Gotham,
				}),
			}) or nil,
			BadgesScrollFrame = not self.state.isLoading
					and Roact.createElement("ScrollingFrame", {
						Size = UDim2.new(1, -10, 1, -10),
						Position = UDim2.new(0, 5, 0, 5),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						ScrollBarThickness = 8,
						ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
						CanvasSize = UDim2.new(0, 0, 0, math.ceil(#self.state.badges / 4) * 160), -- 4 badges per row, 160 height per row
					}, {
						Padding = Roact.createElement("UIPadding", {
							PaddingTop = UDim.new(0, 10),
							PaddingBottom = UDim.new(0, 10),
							PaddingLeft = UDim.new(0, 10),
							PaddingRight = UDim.new(0, 10),
						}),
						GridLayout = Roact.createElement("UIGridLayout", {
							CellSize = UDim2.new(0, 120, 0, 140),
							CellPadding = UDim2.new(0, 10, 0, 10),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						BadgesList = Roact.createFragment(badgeItems),
					})
				or nil,
		})
	end

	return Roact.createElement("ScreenGui", {
		ResetOnSpawn = false,
	}, {
		MainFrame = Roact.createElement("Frame", {
			Size = UDim2.new(0.8, 0, 0.8, 0),
			Position = UDim2.new(0.1, 0, 0.1, 0),
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
			Title = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, -40, 0, 30),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 1,
				Text = "BADGES",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 22,
				Font = Enum.Font.GothamBold,
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
			LoadingFrame = self.state.isLoading and Roact.createElement("Frame", {
				Size = UDim2.new(1, 0, 1, -40),
				Position = UDim2.new(0, 0, 0, 40),
				BackgroundTransparency = 1,
			}, {
				LoadingText = Roact.createElement("TextLabel", {
					Size = UDim2.new(1, 0, 0, 30),
					Position = UDim2.new(0, 0, 0.5, -15),
					BackgroundTransparency = 1,
					Text = "Loading badges...",
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 18,
					Font = Enum.Font.Gotham,
				}),
			}) or nil,
			BadgesScrollFrame = not self.state.isLoading
					and Roact.createElement("ScrollingFrame", {
						Size = UDim2.new(1, 0, 1, -40),
						Position = UDim2.new(0, 0, 0, 40),
						BackgroundColor3 = Color3.fromRGB(40, 40, 40),
						BorderSizePixel = 0,
						ScrollBarThickness = 8,
						ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
						CanvasSize = UDim2.new(0, 0, 0, math.ceil(#self.state.badges / 4) * 160), -- 4 badges per row, 160 height per row
					}, {
						Corner = Roact.createElement("UICorner", {
							CornerRadius = UDim.new(0, 8),
						}),
						Padding = Roact.createElement("UIPadding", {
							PaddingTop = UDim.new(0, 10),
							PaddingBottom = UDim.new(0, 10),
							PaddingLeft = UDim.new(0, 10),
							PaddingRight = UDim.new(0, 10),
						}),
						GridLayout = Roact.createElement("UIGridLayout", {
							CellSize = UDim2.new(0, 120, 0, 140),
							CellPadding = UDim2.new(0, 10, 0, 10),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						BadgesList = Roact.createFragment(badgeItems),
					})
				or nil,
		}),
	})
end

function BadgesUI:didMount()
	-- Load badges when component mounts
	self:loadBadges()
end

function BadgesUI:loadBadges()
	spawn(function()
		local success, gameInfo = pcall(function()
			return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
		end)

		if not success then
			warn("Failed to get game info for badges")
			self:setState({
				isLoading = false,
				badges = {},
			})
			return
		end

		-- Get game badges
		local success2, badges = pcall(function()
			return BadgeService:GetBadgeInfoAsync(game.PlaceId)
		end)

		if not success2 then
			-- Fallback: create some example badges for demonstration
			badges = {
				{
					Id = 1,
					Name = "First Pizza",
					Description = "Create your first pizza!",
					IconImageId = "6031068421", -- Example icon
				},
				{
					Id = 2,
					Name = "Master Baker",
					Description = "Bake 10 perfect pizzas",
					IconImageId = "6031068421",
				},
				{
					Id = 3,
					Name = "Recipe Creator",
					Description = "Save your first recipe",
					IconImageId = "6031068421",
				},
				{
					Id = 4,
					Name = "Perfectionist",
					Description = "Create a perfectly baked pizza",
					IconImageId = "6031068421",
				},
				{
					Id = 5,
					Name = "Speed Baker",
					Description = "Bake a pizza in under 30 seconds",
					IconImageId = "6031068421",
				},
				{
					Id = 6,
					Name = "Experimenter",
					Description = "Try 5 different cooking levels",
					IconImageId = "6031068421",
				},
			}
		end

		-- Get player's owned badges
		local playerBadges = {}
		if self.props.player then
			for _, badge in ipairs(badges) do
				local success3, hasBadge = pcall(function()
					return BadgeService:UserHasBadgeAsync(self.props.player.UserId, badge.Id)
				end)

				if success3 then
					playerBadges[badge.Id] = hasBadge
				end
			end
		end

		self:setState({
			badges = badges,
			playerBadges = playerBadges,
			isLoading = false,
		})
	end)
end

return BadgesUI
