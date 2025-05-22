-- ToggleButton.lua
-- Generic toggle button component using Roact

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Roact = require(ReplicatedStorage.Shared.Roact)

local ToggleButton = Roact.Component:extend("ToggleButton")

-- Initialize component
function ToggleButton:init()
	self:setState({
		isOpen = false,
	})
end

-- Render the button and associated UI
function ToggleButton:render()
	return Roact.createElement("ScreenGui", {
		ResetOnSpawn = false,
	}, {
		Button = Roact.createElement("TextButton", {
			Size = self.props.size or UDim2.new(0, 150, 0, 40),
			Position = self.props.position or UDim2.new(0.95, -150, 0.1, 0),
			AnchorPoint = self.props.anchorPoint or Vector2.new(0, 0),
			BackgroundColor3 = self.props.backgroundColor or Color3.fromRGB(255, 215, 0),
			Text = self.props.text or "TOGGLE",
			TextColor3 = self.props.textColor or Color3.fromRGB(0, 0, 0),
			TextSize = self.props.textSize or 16,
			Font = self.props.font or Enum.Font.GothamBold,
			[Roact.Event.MouseButton1Click] = function()
				self:setState({
					isOpen = true,
				})
				if self.props.onToggleOn then
					self.props.onToggleOn()
				end
			end,
		}, {
			Corner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			ButtonShadow = Roact.createElement("Frame", {
				Size = UDim2.new(1, 4, 1, 4),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.6,
				ZIndex = 0, -- Below the button
			}, {
				ShadowCorner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, 8),
				}),
			}),
		}),
		UIComponent = self.props.uiComponent and Roact.createElement(self.props.uiComponent, {
			isOpen = self.state.isOpen,
			onClose = function()
				self:setState({
					isOpen = false,
				})
				if self.props.onToggleOff then
					self.props.onToggleOff()
				end
			end,
			-- Pass any additional props to the UI component
			data = self.props.data,
		}),
	})
end

return ToggleButton
