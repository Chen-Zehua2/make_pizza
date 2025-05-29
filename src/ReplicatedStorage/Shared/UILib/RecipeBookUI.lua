-- RecipeBookUI.lua
-- Recipe book UI component using Roact

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Roact = require(ReplicatedStorage.Shared.Roact)
local RecipeSystem = require(ReplicatedStorage.Shared.RecipeSystem)

local RecipeBookUI = Roact.Component:extend("RecipeBookUI")

function RecipeBookUI:init()
	self:setState({
		selectedRecipe = nil,
		selectedRecipeId = nil,
		recipes = {},
		isEditingName = false,
		editingName = "",
	})

	self.productViewport = Roact.createRef()
end

function RecipeBookUI:handleCloseInteraction()
	self:setState({
		isEditingName = false, -- Reset editing mode
		editingName = "",
	})
	local viewport = self.productViewport:getValue()
	if viewport then
		for _, child in pairs(viewport:GetChildren()) do
			if not child:IsA("Camera") then
				child:Destroy()
			end
		end
	end
	if self.props.onClose then
		self.props.onClose()
	end
end

function RecipeBookUI:cleanupState()
	-- Reset all state values
	self:setState({
		selectedRecipe = nil,
		selectedRecipeId = nil,
		isEditingName = false,
		editingName = "",
	})

	-- Clear the viewport
	local viewport = self.productViewport:getValue()
	if viewport then
		for _, child in pairs(viewport:GetChildren()) do
			if not child:IsA("Camera") then
				child:Destroy()
			end
		end
	end
end

function RecipeBookUI:render()
	if not self.props.isOpen then
		return nil
	end

	-- Create recipe list items
	local recipeListItems = {}
	for recipeId, recipe in pairs(self.state.recipes) do
		recipeListItems[recipeId] = Roact.createElement("TextButton", {
			Size = UDim2.new(1, -10, 0, 40),
			BackgroundColor3 = Color3.fromRGB(50, 50, 50),
			BorderSizePixel = 0,
			Text = recipe.recipeName,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextWrapped = true,
			LayoutOrder = recipe.createdAt,
			[Roact.Event.MouseButton1Click] = function()
				self:selectRecipe(recipe, recipeId)
			end,
		}, {
			Corner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			Padding = Roact.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),
		})
	end

	-- Content elements that will be reused
	local recipeListFrame = Roact.createElement("Frame", {
		Size = self.props.embedded and UDim2.new(0.4, 0, 1, 0) or UDim2.new(0.4, 0, 0.9, 0),
		Position = self.props.embedded and UDim2.new(0, 0, 0, 0) or UDim2.new(0, 0, 0.1, 0),
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BorderSizePixel = 0,
	}, {
		Corner = Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		ScrollFrame = Roact.createElement("ScrollingFrame", {
			Size = UDim2.new(1, -10, 1, -10),
			Position = UDim2.new(0, 5, 0, 5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
			CanvasSize = UDim2.new(0, 0, 0, #recipeListItems * 45), -- Adjust based on number of items
		}, {
			ListLayout = Roact.createElement("UIListLayout", {
				Padding = UDim.new(0, 5),
			}),
			RecipeList = Roact.createFragment(recipeListItems),
		}),
	})

	local recipeDetailFrame = Roact.createElement("Frame", {
		Size = self.props.embedded and UDim2.new(0.55, 0, 1, 0) or UDim2.new(0.55, 0, 0.9, 0),
		Position = self.props.embedded and UDim2.new(0.45, 0, 0, 0) or UDim2.new(0.45, 0, 0.1, 0),
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		BorderSizePixel = 0,
	}, {
		Corner = Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		RecipeName = self.state.isEditingName and Roact.createElement("Frame", {
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.new(0, 10, 0, 10),
			BackgroundTransparency = 1,
		}, {
			TextBox = Roact.createElement("TextBox", {
				Size = UDim2.new(0.8, 0, 1, 0),
				BackgroundColor3 = Color3.fromRGB(30, 30, 30),
				Text = self.state.editingName,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 20,
				Font = Enum.Font.GothamBold,
				ClearTextOnFocus = false,
				[Roact.Event.FocusLost] = function(rbx, enterPressed)
					if enterPressed then
						self:saveRecipeName()
					end
				end,
				[Roact.Event.Changed] = function(rbx)
					self:setState({
						editingName = rbx.Text,
					})
				end,
			}, {
				Corner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
				Padding = Roact.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 6),
					PaddingRight = UDim.new(0, 6),
				}),
			}),
			SaveButton = Roact.createElement("TextButton", {
				Size = UDim2.new(0.15, 0, 1, 0),
				Position = UDim2.new(0.85, 0, 0, 0),
				BackgroundColor3 = Color3.fromRGB(0, 170, 0),
				Text = "Save",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 14,
				Font = Enum.Font.GothamBold,
				[Roact.Event.MouseButton1Click] = function()
					self:saveRecipeName()
				end,
			}, {
				Corner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
			}),
		}) or Roact.createElement("Frame", {
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.new(0, 10, 0, 10),
			BackgroundTransparency = 1,
		}, {
			NameLabel = Roact.createElement("TextLabel", {
				Size = UDim2.new(0.8, 0, 1, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 0),
				BackgroundTransparency = 1,
				Text = self.state.selectedRecipe and self.state.selectedRecipe.recipeName or "Select a recipe",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 20,
				Font = Enum.Font.GothamBold,
			}),
			EditButton = self.state.selectedRecipe
					and Roact.createElement("ImageButton", {
						Size = UDim2.new(0.1, 0, 1, 0),
						Position = UDim2.new(0.9, 0, 0, 0),
						BackgroundColor3 = Color3.fromRGB(59, 138, 235),
						Image = "http://www.roblox.com/asset/?id=6034941708", -- example pencil/edit icon
						[Roact.Event.MouseButton1Click] = function()
							self:setState({
								isEditingName = true,
								editingName = self.state.selectedRecipe.recipeName,
							})
						end,
					}, {
						Corner = Roact.createElement("UICorner", {
							CornerRadius = UDim.new(0, 6),
						}),
					})
				or nil,
		}),
		ProductViewport = Roact.createElement("ViewportFrame", {
			[Roact.Ref] = self.productViewport,
			Size = UDim2.new(0, 150, 0, 150),
			Position = UDim2.new(0.5, -75, 0, 50),
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			BorderSizePixel = 0,
		}, {
			Corner = Roact.createElement("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
		}),
		RecipeDetails = self.state.selectedRecipe and Roact.createFragment({
			IngredientsLabel = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, -20, 0, 20),
				Position = UDim2.new(0, 10, 0, 210),
				BackgroundTransparency = 1,
				Text = "Ingredients:",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			IngredientsContent = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, -20, 0, 60),
				Position = UDim2.new(0, 10, 0, 235),
				BackgroundColor3 = Color3.fromRGB(30, 30, 30),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 14,
				Font = Enum.Font.Gotham,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = table.concat(self.state.selectedRecipe.ingredients, ", "),
			}, {
				Corner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
				Padding = Roact.createElement("UIPadding", {
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
					PaddingLeft = UDim.new(0, 6),
					PaddingRight = UDim.new(0, 6),
				}),
			}),
			FeedbackLabel = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, -20, 0, 20),
				Position = UDim2.new(0, 10, 0, 305),
				BackgroundTransparency = 1,
				Text = "Feedback:",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			FeedbackContent = Roact.createElement("TextLabel", {
				Size = UDim2.new(1, -20, 0, 60),
				Position = UDim2.new(0, 10, 0, 330),
				BackgroundColor3 = Color3.fromRGB(30, 30, 30),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 14,
				Font = Enum.Font.Gotham,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Text = self.state.selectedRecipe.feedback,
			}, {
				Corner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
			}),
		}) or nil,
	})

	-- If embedded, return just the content without ScreenGui wrapper
	if self.props.embedded then
		return Roact.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
		}, {
			RecipeListFrame = recipeListFrame,
			RecipeDetailFrame = recipeDetailFrame,
		})
	end

	return Roact.createElement("ScreenGui", {
		ResetOnSpawn = false,
	}, {
		MainFrame = Roact.createElement("Frame", {
			Size = UDim2.new(0, 600, 0, 500),
			Position = UDim2.new(0.5, -300, 0.5, -250),
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
				Size = UDim2.new(1, 0, 0, 30),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 1,
				Text = "RECIPE BOOK",
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
					self:handleCloseInteraction()
				end,
			}, {
				Corner = Roact.createElement("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
			}),
			RecipeListFrame = recipeListFrame,
			RecipeDetailFrame = recipeDetailFrame,
		}),
	})
end

function RecipeBookUI:didMount()
	-- Load recipes when mounted
	self:updateRecipeList()
end

function RecipeBookUI:didUpdate(prevProps, prevState)
	if not prevProps.isOpen and self.props.isOpen then
		-- UI was just opened
		if self.state.selectedRecipe then
			local productViewport = self.productViewport:getValue()
			if productViewport then
				RecipeSystem.createRecipeViewport(productViewport, self.state.selectedRecipe)
			end
		end
	end

	if prevState.recipes ~= self.state.recipes and self.state.selectedRecipeId then
		if not self.state.recipes[self.state.selectedRecipeId] then
			self:setState({
				selectedRecipe = nil,
				selectedRecipeId = nil,
				isEditingName = false,
				editingName = "",
			})
			local viewport = self.productViewport:getValue()
			if viewport then
				for _, child in pairs(viewport:GetChildren()) do
					if not child:IsA("Camera") then
						child:Destroy()
					end
				end
			end
		end
	end
end

function RecipeBookUI:willUnmount()
	-- Clean up when component is unmounted
	self:cleanupState()
end

function RecipeBookUI:updateRecipeList()
	local recipes = RecipeSystem.getAllRecipes()
	self:setState({
		recipes = recipes,
	})
end

function RecipeBookUI:saveRecipeName()
	if self.state.selectedRecipe and self.state.selectedRecipeId then
		-- Update the recipe name in the system
		local success = RecipeSystem.updateRecipeName(self.state.selectedRecipeId, self.state.editingName)

		if success then
			-- Update local state
			local newRecipe = table.clone(self.state.selectedRecipe)
			newRecipe.recipeName = self.state.editingName

			self:setState({
				isEditingName = false,
				selectedRecipe = newRecipe,
			})

			-- Refresh recipe list
			self:updateRecipeList()
		else
			warn("Failed to update recipe name")
		end
	end
end

function RecipeBookUI:selectRecipe(recipe, recipeId)
	self:setState({
		selectedRecipe = recipe,
		selectedRecipeId = recipeId,
		isEditingName = false,
	})

	-- Update viewport with recipe model
	local productViewport = self.productViewport:getValue()
	if productViewport then
		RecipeSystem.createRecipeViewport(productViewport, recipe)
	end
end

return RecipeBookUI
