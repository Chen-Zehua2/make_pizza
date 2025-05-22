-- RecipeSystem.lua
-- Manages saving and displaying recipes for cooked products

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Check if we're running on client or server
local isClient = RunService:IsClient()
local isServer = RunService:IsServer()

local RecipeSystem = {}

-- Error types
RecipeSystem.Errors = {
	INVALID_PRODUCT = "Invalid product",
	NOT_COOKED = "Product is not cooked",
	SERIALIZATION_FAILED = "Failed to serialize product",
	RECIPE_NOT_FOUND = "Recipe not found",
	INVALID_RECIPE_DATA = "Invalid recipe data",
	VIEWPORT_ERROR = "Failed to create viewport",
}

-- Temporary dictionary to store recipes
RecipeSystem.recipes = {}

-- Function to safely get instance property
local function safeGetProperty(instance, propertyName, default)
	if not instance then
		return default
	end

	local success, result = pcall(function()
		return instance[propertyName]
	end)

	if success then
		return result
	else
		return default
	end
end

-- Function to serialize a product object
function RecipeSystem.serializeProduct(product)
	if not product then
		return nil, RecipeSystem.Errors.INVALID_PRODUCT
	end

	if not product.instance or not product.instance:IsA("BasePart") then
		return nil, RecipeSystem.Errors.INVALID_PRODUCT
	end

	-- Get mesh type safely
	local meshType = Enum.MeshType.Brick -- Default mesh type
	local mesh = product.instance:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		meshType = safeGetProperty(mesh, "MeshType", Enum.MeshType.Brick)
	end

	local data = {
		name = product.name or "Unknown Product",
		size = safeGetProperty(product.instance, "Size", Vector3.new(1, 1, 1)),
		color = safeGetProperty(product.instance, "Color", Color3.fromRGB(255, 255, 255)),
		material = safeGetProperty(product.instance, "Material", Enum.Material.Plastic),
		meshType = meshType,
		flattenCount = product.flattenCount or 0,
		doneness = product.doneness or 0,
		ingredients = product.ingredients or { "Dough" }, -- Default if not specified
		feedback = product.feedback or "Looks tasty!", -- Default feedback
		recipeName = "Enter a name",
		createdAt = os.time(),
	}

	return data
end

-- Function to unserialize a product (for viewing)
function RecipeSystem.unserializeProduct(data)
	if not data then
		return nil, RecipeSystem.Errors.INVALID_RECIPE_DATA
	end

	local success, part = pcall(function()
		-- Create a part to represent the product
		local newPart = Instance.new("Part")
		newPart.Name = data.name
		newPart.Size = data.size
		newPart.Color = data.color
		newPart.Material = data.material
		newPart.Anchored = true
		newPart.CanCollide = false

		-- Create a mesh if needed and valid
		if data.meshType and typeof(data.meshType) == "EnumItem" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = data.meshType
			mesh.Parent = newPart
		end

		return newPart
	end)

	if not success then
		return nil, "Failed to create product model: " .. tostring(part)
	end

	return part
end

-- Function to save a recipe
function RecipeSystem.saveRecipe(product)
	if not product or not product.instance then
		return false, RecipeSystem.Errors.INVALID_PRODUCT
	end

	-- Check if product is cooked (doneness > 0)
	local doneness = product.doneness or 0
	if product.instance:FindFirstChild("Doneness") then
		doneness = product.instance.Doneness.Value
	end

	if doneness <= 0 then
		return false, RecipeSystem.Errors.NOT_COOKED
	end

	-- Serialize the product
	local recipeData, serializeError = RecipeSystem.serializeProduct(product)
	if not recipeData then
		return false, serializeError or RecipeSystem.Errors.SERIALIZATION_FAILED
	end

	-- Generate a unique recipe ID
	local recipeId = "recipe_" .. os.time() .. "_" .. math.random(1000, 9999)

	-- Store in temporary dictionary
	RecipeSystem.recipes[recipeId] = recipeData

	print("Recipe saved: " .. recipeId)
	return true, recipeId
end

-- Function to get a recipe by ID
function RecipeSystem.getRecipe(recipeId)
	local recipe = RecipeSystem.recipes[recipeId]
	if not recipe then
		return nil, RecipeSystem.Errors.RECIPE_NOT_FOUND
	end
	return recipe
end

-- Function to get all recipes
function RecipeSystem.getAllRecipes()
	return RecipeSystem.recipes
end

-- Function to update recipe name
function RecipeSystem.updateRecipeName(recipeId, newName)
	if not RecipeSystem.recipes[recipeId] then
		return false, RecipeSystem.Errors.RECIPE_NOT_FOUND
	end

	if type(newName) ~= "string" or newName == "" then
		return false, "Invalid recipe name"
	end

	RecipeSystem.recipes[recipeId].recipeName = newName
	return true
end

-- Function to display recipe in a ViewportFrame
function RecipeSystem.createRecipeViewport(viewportFrame, recipeData)
	if not viewportFrame or not viewportFrame:IsA("ViewportFrame") then
		return false, "Invalid viewport frame"
	end

	if not recipeData then
		return false, RecipeSystem.Errors.INVALID_RECIPE_DATA
	end

	-- Clear existing children
	for _, child in pairs(viewportFrame:GetChildren()) do
		if child:IsA("Camera") then
			continue
		end
		child:Destroy()
	end

	-- Create camera if it doesn't exist
	local camera = viewportFrame:FindFirstChildOfClass("Camera")
	if not camera then
		camera = Instance.new("Camera")
		camera.Parent = viewportFrame
		viewportFrame.CurrentCamera = camera
	end

	-- Create the product model
	local productModel, error = RecipeSystem.unserializeProduct(recipeData)
	if not productModel then
		return false, error or RecipeSystem.Errors.VIEWPORT_ERROR
	end

	-- Position the product in the viewport
	productModel.Position = Vector3.new(0, 0, 0)
	productModel.Parent = viewportFrame

	-- Position camera to view the product
	camera.CFrame = CFrame.new(Vector3.new(0, 0, 5), productModel.Position)

	return true
end

-- Create remote events for client-server communication
if isServer then
	-- Create RemoteEvents if they don't exist
	local saveRecipeEvent = Instance.new("RemoteEvent")
	saveRecipeEvent.Name = "SaveRecipe"
	saveRecipeEvent.Parent = ReplicatedStorage

	local updateRecipeNameEvent = Instance.new("RemoteEvent")
	updateRecipeNameEvent.Name = "UpdateRecipeName"
	updateRecipeNameEvent.Parent = ReplicatedStorage

	local getRecipesEvent = Instance.new("RemoteFunction")
	getRecipesEvent.Name = "GetRecipes"
	getRecipesEvent.Parent = ReplicatedStorage

	-- Handle recipe save requests from clients
	saveRecipeEvent.OnServerEvent:Connect(function(player, objectId)
		local success, result = pcall(function()
			return RecipeSystem.saveRecipe(objectId)
		end)

		if success then
			-- Fire a success event back to the client
			ReplicatedStorage.RecipeResult:FireClient(player, true, result)
		else
			-- Fire an error event back to the client
			ReplicatedStorage.RecipeResult:FireClient(player, false, "Failed to save recipe: " .. tostring(result))
		end
	end)

	-- Handle recipe name updates
	updateRecipeNameEvent.OnServerEvent:Connect(function(player, recipeId, newName)
		local success, result = pcall(function()
			return RecipeSystem.updateRecipeName(recipeId, newName)
		end)

		if success then
			-- Fire a success event back to the client
			ReplicatedStorage.RecipeResult:FireClient(player, true, "Recipe name updated")
		else
			-- Fire an error event back to the client
			ReplicatedStorage.RecipeResult:FireClient(
				player,
				false,
				"Failed to update recipe name: " .. tostring(result)
			)
		end
	end)

	-- Return all recipes when requested
	getRecipesEvent.OnServerInvoke = function(player)
		local success, recipes = pcall(function()
			return RecipeSystem.getAllRecipes()
		end)

		if success then
			return recipes
		else
			return {}
		end
	end

	-- Create result event for client feedback
	local resultEvent = Instance.new("RemoteEvent")
	resultEvent.Name = "RecipeResult"
	resultEvent.Parent = ReplicatedStorage
end

return RecipeSystem
