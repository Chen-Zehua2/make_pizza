-- RecipeCreationUI.lua
-- Recipe creation UI component using Roact

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Roact = require(ReplicatedStorage.Shared.Roact)
local RecipeSystem = require(ReplicatedStorage.Shared.RecipeSystem)

local RecipeCreationUI = Roact.Component:extend("RecipeCreationUI")

function RecipeCreationUI:init()
	self:setState({
		recipeName = "Enter a name",
	})

	self.mainFrame = Roact.createRef()
	self.productViewport = Roact.createRef()
end

function RecipeCreationUI:render()
	if not self.props.isOpen or not self.props.product then
		return nil
	end

	local product = self.props.product
	local ingredients = product.ingredients or { "Dough" }
	local feedback = product.feedback or "Default Feedback Here..."

	return Roact.createElement("ScreenGui", {
		ResetOnSpawn = false,
	}, {
		MainFrame = Roact.createElement("Frame", {
			[Roact.Ref] = self.mainFrame,
			Size = UDim2.new(0.4, 0, 0.7, 0), -- Changed to scale-based sizing
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5), -- Center the frame
			BackgroundColor3 = Color3.fromRGB(59, 138, 235),
			BorderSizePixel = 0,
		}, {
			Corner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, 12),
			}),
			Padding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0.02, 0),
				PaddingBottom = UDim.new(0.02, 0),
				PaddingLeft = UDim.new(0.03, 0),
				PaddingRight = UDim.new(0.03, 0),
			}),
			Title = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0.06, 0),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 1,
				Text = "CREATE RECIPE",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 22,
				Font = Enum.Font.GothamBold,
			}),
			CloseButton = Roact.createElement("TextButton", {
				Size = UDim2.new(0.08, 0, 0.06, 0),
				Position = UDim2.new(0.92, 0, 0, 0),
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

			SaveButton = Roact.createElement("TextButton", {
				Size = UDim2.new(0.15, 0, 0.06, 0),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundColor3 = Color3.fromRGB(76, 175, 80), -- Green
				Text = "SAVE",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
				ZIndex = 100,
				[Roact.Event.MouseButton1Click] = function()
					-- Save the recipe
					local success, recipeId = RecipeSystem.saveRecipe(product)
					if success then
						-- Update recipe name
						RecipeSystem.updateRecipeName(recipeId, self.state.recipeName)
						-- Close the UI
						if self.props.onClose then
							self.props.onClose()
						end
					end
				end,
			}, {
				Corner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
			}),
			NameLabel = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0.04, 0),
				Position = UDim2.new(0, 0, 0.08, 0),
				BackgroundTransparency = 1,
				Text = "Recipe Name:",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			NameInput = Roact.createElement("TextBox", {
				Size = UDim2.new(1, 0, 0.06, 0),
				Position = UDim2.new(0, 0, 0.13, 0),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				Text = self.state.recipeName,
				TextColor3 = Color3.fromRGB(0, 0, 0),
				TextSize = 16,
				Font = Enum.Font.Gotham,
				ClearTextOnFocus = true,
				[Roact.Event.FocusLost] = function(rbx)
					self:setState({
						recipeName = rbx.Text,
					})
				end,
			}, {
				Corner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
			}),
			PreviewLabel = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0.04, 0),
				Position = UDim2.new(0, 0, 0.21, 0),
				BackgroundTransparency = 1,
				Text = "Product Preview:",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			ProductViewport = Roact.createElement("ViewportFrame", {
				[Roact.Ref] = self.productViewport,
				Size = UDim2.new(0.4, 0, 0.3, 0),
				Position = UDim2.new(0.3, 0, 0.26, 0),
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				BorderSizePixel = 0,
			}, {
				Corner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
			}),
			IngredientsLabel = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0.04, 0),
				Position = UDim2.new(0, 0, 0.58, 0),
				BackgroundTransparency = 1,
				Text = "Ingredients:",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			IngredientsList = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0.12, 0),
				Position = UDim2.new(0, 0, 0.63, 0),
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 14,
				Font = Enum.Font.Gotham,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = table.concat(ingredients, ", "),
			}, {
				Corner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
				Padding = Roact.createElement("UIPadding", {
					PaddingTop = UDim.new(0.1, 0),
					PaddingBottom = UDim.new(0.1, 0),
					PaddingLeft = UDim.new(0.02, 0),
					PaddingRight = UDim.new(0.02, 0),
				}),
			}),
			FeedbackLabel = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0.04, 0),
				Position = UDim2.new(0, 0, 0.77, 0),
				BackgroundTransparency = 1,
				Text = "Feedback:",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			FeedbackText = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 0.12, 0),
				Position = UDim2.new(0, 0, 0.82, 0),
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 14,
				Font = Enum.Font.Gotham,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = feedback,
			}, {
				Corner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
				Padding = Roact.createElement("UIPadding", {
					PaddingTop = UDim.new(0.1, 0),
					PaddingBottom = UDim.new(0.1, 0),
					PaddingLeft = UDim.new(0.02, 0),
					PaddingRight = UDim.new(0.02, 0),
				}),
			}),
		}),
	})
end

function RecipeCreationUI:didMount()
	-- Set up viewport
	local productViewport = self.productViewport:getValue()
	if productViewport and self.props.product then
		-- Clone the product part and put it in the viewport
		local productClone = self.props.product.instance:Clone()
		productClone.Position = Vector3.new(0, 0, 0)
		productClone.Parent = productViewport

		-- Create camera
		local camera = Instance.new("Camera")
		camera.CFrame = CFrame.new(Vector3.new(0, 0, 5), Vector3.new(0, 0, 0))
		camera.Parent = productViewport
		productViewport.CurrentCamera = camera
	end
end

function RecipeCreationUI:willUnmount()
	-- Clean up viewport
	local productViewport = self.productViewport:getValue()
	if productViewport then
		for _, child in pairs(productViewport:GetChildren()) do
			child:Destroy()
		end
	end
end

return RecipeCreationUI
