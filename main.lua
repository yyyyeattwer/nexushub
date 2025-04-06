local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera

local scriptStates = {
	antiAFK = false,
	fly = false,
	esp = false,
	infiniteJump = false,
	noclip = false,
	autoClicker = false,
	speedHack = false,
	jumpHack = false,
	xray = false
}

local defaultWalkSpeed = 16
local defaultJumpPower = 50

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NexusGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

local Utilities = {}

function Utilities.GetPlayerByName(name)
	name = name:lower()
	
	for _, player in pairs(Players:GetPlayers()) do
		if player.Name:lower() == name then
			return player
		end
	end
	
	for _, player in pairs(Players:GetPlayers()) do
		if player.Name:lower():find(name, 1, true) then
			return player
		end
	end
	
	return nil
end

function Utilities.SafeDestroy(instance)
	if instance and typeof(instance) == "Instance" and instance:IsDescendantOf(game) then
		instance:Destroy()
		return true
	end
	return false
end

function Utilities.GetPlayersInRadius(origin, radius)
	local playersInRadius = {}
	
	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			local character = otherPlayer.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				local distance = (character.HumanoidRootPart.Position - origin).Magnitude
				if distance <= radius then
					table.insert(playersInRadius, {
						Player = otherPlayer,
						Distance = distance
					})
				end
			end
		end
	end
	
	table.sort(playersInRadius, function(a, b)
		return a.Distance < b.Distance
	end)
	
	return playersInRadius
end

function Utilities.Clamp(value, min, max)
	return math.max(min, math.min(max, value))
end

local UI = {}

function UI.CreateButton(name, parent, position, size, text, color, callback)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Parent = parent
	button.Position = position or UDim2.new(0, 0, 0, 0)
	button.Size = size or UDim2.new(1, 0, 0, 30)
	button.Text = text or "Button"
	button.BackgroundColor3 = color or Color3.fromRGB(60, 60, 60)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.SourceSansBold
	button.TextSize = 16
	button.AutoButtonColor = false
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button
	
	local defaultColor = button.BackgroundColor3
	local hoverColor = Color3.fromRGB(
		math.min(defaultColor.R * 1.2 * 255, 255),
		math.min(defaultColor.G * 1.2 * 255, 255),
		math.min(defaultColor.B * 1.2 * 255, 255)
	)
	local pressedColor = Color3.fromRGB(
		defaultColor.R * 0.8 * 255,
		defaultColor.G * 0.8 * 255,
		defaultColor.B * 0.8 * 255
	)
	
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = hoverColor}):Play()
	end)
	
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = defaultColor}):Play()
	end)
	
	button.MouseButton1Down:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = pressedColor}):Play()
	end)
	
	button.MouseButton1Up:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = hoverColor}):Play()
	end)
	
	if callback then
		button.MouseButton1Click:Connect(callback)
	end
	
	return button
end

function UI.CreateSlider(name, parent, position, size, min, max, initialValue, callback)
	local sliderFrame = Instance.new("Frame")
	sliderFrame.Name = name
	sliderFrame.Parent = parent
	sliderFrame.Position = position or UDim2.new(0, 0, 0, 0)
	sliderFrame.Size = size or UDim2.new(1, 0, 0, 20)
	sliderFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	sliderFrame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = sliderFrame

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Parent = sliderFrame
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
	fill.BorderSizePixel = 0

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "ValueLabel"
	valueLabel.Parent = sliderFrame
	valueLabel.BackgroundTransparency = 1
	valueLabel.Position = UDim2.new(1, 10, 0, 0)
	valueLabel.Size = UDim2.new(0, 40, 1, 0)
	valueLabel.Font = Enum.Font.SourceSans
	valueLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	valueLabel.TextSize = 14
	valueLabel.Text = tostring(initialValue or min or 0)

	min = min or 0
	max = max or 100
	initialValue = initialValue or min
	
	local normalizedValue = (initialValue - min) / (max - min)
	fill.Size = UDim2.new(normalizedValue, 0, 1, 0)
	valueLabel.Text = tostring(math.floor(initialValue))
	
	local function updateSlider(input)
		local mousePosition = input.Position.X
		local sliderPosition = sliderFrame.AbsolutePosition.X
		local sliderSize = sliderFrame.AbsoluteSize.X
		
		local relativePosition = math.clamp((mousePosition - sliderPosition) / sliderSize, 0, 1)
		local value = min + relativePosition * (max - min)
		
		fill.Size = UDim2.new(relativePosition, 0, 1, 0)
		valueLabel.Text = tostring(math.floor(value))
		
		if callback then
			callback(value)
		end
		
		return value
	end
	
	sliderFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local value = updateSlider(input)
			
			local moveConnection
			local releaseConnection
			
			moveConnection = UserInputService.InputChanged:Connect(function(newInput)
				if newInput.UserInputType == Enum.UserInputType.MouseMovement then
					value = updateSlider(newInput)
				end
			end)
			
			releaseConnection = UserInputService.InputEnded:Connect(function(newInput)
				if newInput.UserInputType == Enum.UserInputType.MouseButton1 then
					if moveConnection then
						moveConnection:Disconnect()
					end
					if releaseConnection then
						releaseConnection:Disconnect()
					end
				end
			end)
		end
	end)
	
	return {
		Frame = sliderFrame,
		Fill = fill,
		ValueLabel = valueLabel,
		SetValue = function(value)
			local clampedValue = math.clamp(value, min, max)
			local normalizedValue = (clampedValue - min) / (max - min)
			fill.Size = UDim2.new(normalizedValue, 0, 1, 0)
			valueLabel.Text = tostring(math.floor(clampedValue))
			
			if callback then
				callback(clampedValue)
			end
			
			return clampedValue
		end
	}
end

function UI.CreateToggleButton(name, parent, position, size, text, callback, initialState)
	local button = UI.CreateButton(name, parent, position, size, text)
	local isEnabled = initialState or false
	
	local function updateApperance()
		if isEnabled then
			button.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
			button.Text = text .. ": ON"
		else
			button.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
			button.Text = text .. ": OFF"
		end
	end
	
	updateApperance()
	
	button.MouseButton1Click:Connect(function()
		isEnabled = not isEnabled
		updateApperance()
		
		if callback then
			callback(isEnabled)
		end
	end)
	
	return {
		Button = button,
		SetState = function(state)
			isEnabled = state
			updateApperance()
			
			if callback then
				callback(isEnabled)
			end
		end,
		GetState = function()
			return isEnabled
		end
	}
end

function executeAdminCommand(commandString)
	local args = {}
	for arg in commandString:gmatch("%S+") do
		table.insert(args, arg)
	end

	if #args == 0 then
		return "Error: No command provided."
	end

	local command = args[1]:lower()
	if command:sub(1, 1) == "/" then
		command = command:sub(2)
	end

	
	if command == "kill" then
		if #args < 2 then
			return "Error: Missing player name. Usage: /kill [player]"
		end

		local targetPlayer = Utilities.GetPlayerByName(args[2])
		if not targetPlayer then
			return "Error: Player '" .. args[2] .. "' not found."
		end

		local character = targetPlayer.Character
		if character and character:FindFirstChild("Humanoid") then
			character.Humanoid.Health = 0
			return "Killed player: " .. targetPlayer.Name
		else
			return "Error: Player character not found."
		end
	elseif command == "tp" or command == "teleport" then
		if #args < 2 then
			return "Error: Missing player name. Usage: /tp [player]"
		end

		local targetPlayer = Utilities.GetPlayerByName(args[2])
		if not targetPlayer then
			return "Error: Player '" .. args[2] .. "' not found."
		end

		local targetCharacter = targetPlayer.Character
		if targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart") then
			local targetPosition = targetCharacter.HumanoidRootPart.Position

			if character and character:FindFirstChild("HumanoidRootPart") then
				character:SetPrimaryPartCFrame(CFrame.new(targetPosition + Vector3.new(0, 3, 0)))
				return "Teleported to " .. targetPlayer.Name
			else
				return "Error: Your character not found."
			end
		else
			return "Error: Target player's character not found."
		end
	elseif command == "speed" then
		if #args < 2 then
			return "Error: Missing speed value. Usage: /speed [value]"
		end

		local speed = tonumber(args[2])
		if not speed then
			return "Error: Invalid speed value."
		end

		
		speed = math.clamp(speed, 0, 1000)

		if character and character:FindFirstChild("Humanoid") then
			character.Humanoid.WalkSpeed = speed
			return "Set walk speed to " .. speed
		else
			return "Error: Character not found."
		end
	elseif command == "jump" then
		if #args < 2 then
			return "Error: Missing jump power value. Usage: /jump [value]"
		end

		local jumpPower = tonumber(args[2])
		if not jumpPower then
			return "Error: Invalid jump power value."
		end

		
		jumpPower = math.clamp(jumpPower, 0, 1000)

		if character and character:FindFirstChild("Humanoid") then
			character.Humanoid.JumpPower = jumpPower
			return "Set jump power to " .. jumpPower
		else
			return "Error: Character not found."
		end
	elseif command == "bring" then
		if #args < 2 then
			return "Error: Missing player name. Usage: /bring [player]"
		end

		local targetPlayer = Utilities.GetPlayerByName(args[2])
		if not targetPlayer then
			return "Error: Player '" .. args[2] .. "' not found."
		end

		local targetCharacter = targetPlayer.Character
		if targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart") and 
			character and character:FindFirstChild("HumanoidRootPart") then
			targetCharacter:SetPrimaryPartCFrame(CFrame.new(character.HumanoidRootPart.Position + Vector3.new(0, 3, 0)))
			return "Brought " .. targetPlayer.Name .. " to you"
		else
			return "Error: Character not found."
		end
	elseif command == "time" then
		if #args < 2 then
			return "Error: Missing time value. Usage: /time [value]"
		end

		local timeValue = tonumber(args[2])
		if not timeValue then
			local timeKeywords = {
				day = 14,
				noon = 12,
				midnight = 0,
				night = 0,
				morning = 8,
				evening = 18
			}

			timeValue = timeKeywords[args[2]:lower()]
			if not timeValue then
				return "Error: Invalid time value. Use a number (0-24) or keyword (day, night, etc.)"
			end
		else
			timeValue = math.clamp(timeValue, 0, 24)
		end

		Lighting.ClockTime = timeValue
		return "Set time to " .. timeValue
	elseif command == "fog" then
		if #args < 2 then
			return "Error: Missing fog density. Usage: /fog [0-1]"
		end

		local fogDensity = tonumber(args[2])
		if not fogDensity then
			return "Error: Invalid fog density value."
		end

		fogDensity = math.clamp(fogDensity, 0, 1)
		Lighting.FogEnd = 100000 * (1 - fogDensity)
		if fogDensity > 0 then
			Lighting.FogStart = 0
		else
			Lighting.FogStart = Lighting.FogEnd
		end

		return "Set fog density to " .. fogDensity
	elseif command == "help" then
		local commands = {
			"/kill [player] - Kill a player",
			"/tp [player] - Teleport to a player",
			"/bring [player] - Bring a player to you",
			"/speed [value] - Set your walk speed",
			"/jump [value] - Set your jump power",
			"/time [value] - Set the time of day (0-24)",
			"/fog [0-1] - Set fog density",
			"/help - Show this list"
		}

		return "Available commands:\n" .. table.concat(commands, "\n")
	else
		return "Unknown command: " .. command .. ". Type /help for available commands."
	end
end

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Parent = screenGui
mainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
mainFrame.Size = UDim2.new(0, 400, 0, 300)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BorderSizePixel = 0
local cornerRadius = Instance.new("UICorner")
cornerRadius.CornerRadius = UDim.new(0, 8)
cornerRadius.Parent = mainFrame
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Parent = mainFrame
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.BackgroundTransparency = 1
shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
shadow.Size = UDim2.new(1, 20, 1, 20)
shadow.ZIndex = -1
shadow.Image = "rbxassetid://5554236805"
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(23, 23, 277, 277)
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Parent = mainFrame
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
titleBar.BorderSizePixel = 0
local titleCornerRadius = Instance.new("UICorner")
titleCornerRadius.CornerRadius = UDim.new(0, 8)
titleCornerRadius.Parent = titleBar
local titleText = Instance.new("TextLabel")
titleText.Name = "TitleText"
titleText.Parent = titleBar
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.Size = UDim2.new(1, -60, 1, 0)
titleText.BackgroundTransparency = 1
titleText.Font = Enum.Font.SourceSansBold
titleText.Text = "Nexus Hub"
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.TextSize = 18
titleText.TextXAlignment = Enum.TextXAlignment.Left
local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "MinimizeButton"
minimizeButton.Parent = titleBar
minimizeButton.Position = UDim2.new(1, -60, 0, 0)
minimizeButton.Size = UDim2.new(0, 30, 1, 0)
minimizeButton.BackgroundTransparency = 1
minimizeButton.Font = Enum.Font.SourceSansBold
minimizeButton.Text = "-"
minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeButton.TextSize = 24
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Parent = titleBar
closeButton.Position = UDim2.new(1, -30, 0, 0)
closeButton.Size = UDim2.new(0, 30, 1, 0)
closeButton.BackgroundTransparency = 1
closeButton.Font = Enum.Font.SourceSansBold
closeButton.Text = "×"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 24

local tabsFrame = Instance.new("Frame")
tabsFrame.Name = "TabsFrame"
tabsFrame.Parent = mainFrame
tabsFrame.Position = UDim2.new(0, 0, 0, 30)
tabsFrame.Size = UDim2.new(1, 0, 0, 30)
tabsFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
tabsFrame.BorderSizePixel = 0
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Parent = mainFrame
contentFrame.Position = UDim2.new(0, 0, 0, 60)
contentFrame.Size = UDim2.new(1, 0, 1, -60)
contentFrame.BackgroundTransparency = 1

local tabInfo = {
	{Name = "Home", Display = "Home"},
	{Name = "Movement", Display = "Movement"},
	{Name = "Visuals", Display = "Visuals"},
	{Name = "Admin", Display = "Admin"},
	{Name = "Teleport", Display = "Teleport"}
}

local tabContents = {}
for i, info in ipairs(tabInfo) do
	local tabButton = Instance.new("TextButton")
	tabButton.Name = info.Name .. "Tab"
	tabButton.Parent = tabsFrame
	tabButton.Position = UDim2.new(0, (i-1) * 80, 0, 0)
	tabButton.Size = UDim2.new(0, 80, 1, 0)
	tabButton.BackgroundColor3 = i == 1 and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(35, 35, 35)
	tabButton.BorderSizePixel = 0
	tabButton.Font = Enum.Font.SourceSansBold
	tabButton.Text = info.Display
	tabButton.TextColor3 = i == 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
	tabButton.TextSize = 14

	local content = Instance.new("ScrollingFrame")
	content.Name = info.Name .. "Content"
	content.Parent = contentFrame
	content.Size = UDim2.new(1, 0, 1, 0)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 4
	content.Visible = i == 1
	content.CanvasSize = UDim2.new(0, 0, 0, 0) -- Will be adjusted based on content
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollingDirection = Enum.ScrollingDirection.Y

	local contentPadding = Instance.new("UIPadding")
	contentPadding.Parent = content
	contentPadding.PaddingLeft = UDim.new(0, 10)
	contentPadding.PaddingRight = UDim.new(0, 10)
	contentPadding.PaddingTop = UDim.new(0, 10)
	contentPadding.PaddingBottom = UDim.new(0, 10)
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Parent = content
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 10)

	tabContents[info.Name] = content

	tabButton.MouseButton1Click:Connect(function()
		for j, tab in ipairs(tabInfo) do
			local otherButton = tabsFrame:FindFirstChild(tab.Name .. "Tab")
			if otherButton then
				otherButton.BackgroundColor3 = tab.Name == info.Name and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(35, 35, 35)
				otherButton.TextColor3 = tab.Name == info.Name and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
			end

			local otherContent = contentFrame:FindFirstChild(tab.Name .. "Content")
			if otherContent then
				otherContent.Visible = tab.Name == info.Name
			end
		end
	end)
end

local isDragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil
local function updateDrag(input)
	local delta = input.Position - dragStart
	mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end
titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDragging = true
		dragStart = input.Position
		startPos = mainFrame.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				isDragging = false
			end
		end)
	end
end)
titleBar.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		dragInput = input
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and isDragging then
		updateDrag(input)
	end
end)
-- Minimize/Maximize functionality
local isMinimized = false
minimizeButton.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	if isMinimized then
		contentFrame.Visible = false
		tabsFrame.Visible = false
		mainFrame.Size = UDim2.new(0, 400, 0, 30)
	else
		contentFrame.Visible = true
		tabsFrame.Visible = true
		mainFrame.Size = UDim2.new(0, 400, 0, 300)
	end
end)
-- Close functionality
closeButton.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
end)
-- Show UI when player presses the hotkey (Default: RightControl)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.RightControl then
		screenGui.Enabled = not screenGui.Enabled
	end
end)
-- Add Home tab content
local homeContent = tabContents.Home
-- Welcome message
local welcomeLabel = Instance.new("TextLabel")
welcomeLabel.Name = "WelcomeLabel"
welcomeLabel.Parent = homeContent
welcomeLabel.Size = UDim2.new(1, 0, 0, 50)
welcomeLabel.BackgroundTransparency = 1
welcomeLabel.Font = Enum.Font.SourceSansBold
welcomeLabel.Text = "Welcome to Script Hub!\nPress Right Ctrl to toggle the menu"
welcomeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
welcomeLabel.TextSize = 16
welcomeLabel.LayoutOrder = 1
-- Anti-AFK button
local antiAFKToggle = UI.CreateToggleButton(
	"AntiAFKButton",
	homeContent,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 40),
	"Anti-AFK",
	function(enabled)
		scriptStates.antiAFK = enabled

		if enabled then
			-- Set up anti-AFK
			local virtualUser = game:GetService("VirtualUser")

			-- Only create connection if it doesn't exist
			if not scriptStates.antiAFKConnection then
				scriptStates.antiAFKConnection = player.Idled:Connect(function()
					virtualUser:CaptureController()
					virtualUser:ClickButton2(Vector2.new())
					print("Anti-AFK: Prevented kick")
				end)
			end
		else
			-- Disconnect anti-AFK
			if scriptStates.antiAFKConnection then
				scriptStates.antiAFKConnection:Disconnect()
				scriptStates.antiAFKConnection = nil
			end
		end
	end
)
antiAFKToggle.Button.LayoutOrder = 2
-- Infinite Jump button
local infiniteJumpToggle = UI.CreateToggleButton(
	"InfiniteJumpButton",
	homeContent,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 40),
	"Infinite Jump",
	function(enabled)
		scriptStates.infiniteJump = enabled

		-- No need for connection handling here, we'll use the UserInputService event
	end
)
infiniteJumpToggle.Button.LayoutOrder = 3
-- Noclip button
local noclipToggle = UI.CreateToggleButton(
	"NoclipButton",
	homeContent,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 40),
	"Noclip",
	function(enabled)
		scriptStates.noclip = enabled

		if enabled then
			if not scriptStates.noclipConnection then
				scriptStates.noclipConnection = RunService.Stepped:Connect(function()
					if character then
						for _, part in pairs(character:GetDescendants()) do
							if part:IsA("BasePart") then
								part.CanCollide = false
							end
						end
					end
				end)
			end
		else
			if scriptStates.noclipConnection then
				scriptStates.noclipConnection:Disconnect()
				scriptStates.noclipConnection = nil

				-- Reset parts collision
				if character then
					for _, part in pairs(character:GetDescendants()) do
						if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
							part.CanCollide = true
						end
					end
				end
			end
		end
	end
)
noclipToggle.Button.LayoutOrder = 4
-- Auto-clicker button
local autoClickerToggle = UI.CreateToggleButton(
	"AutoClickerButton",
	homeContent,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 40),
	"Auto Clicker",
	function(enabled)
		scriptStates.autoClicker = enabled

		if enabled then
			if not scriptStates.autoClickerConnection then
				scriptStates.autoClickerConnection = RunService.Heartbeat:Connect(function()
					mouse1press()
					task.wait(0.01)
					mouse1release()
				end)
			end
		else
			if scriptStates.autoClickerConnection then
				scriptStates.autoClickerConnection:Disconnect()
				scriptStates.autoClickerConnection = nil
			end
		end
	end
)
autoClickerToggle.Button.LayoutOrder = 5

local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.Parent = homeContent
divider.Size = UDim2.new(1, 0, 0, 1)
divider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
divider.BorderSizePixel = 0
divider.LayoutOrder = 10
local creditsLabel = Instance.new("TextLabel")
creditsLabel.Name = "CreditsLabel"
creditsLabel.Parent = homeContent
creditsLabel.Size = UDim2.new(1, 0, 0, 30)
creditsLabel.BackgroundTransparency = 1
creditsLabel.Font = Enum.Font.SourceSans
creditsLabel.Text = "Script Hub by ANTML"
creditsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
creditsLabel.TextSize = 14
creditsLabel.LayoutOrder = 11
local movementContent = tabContents.Movement
-- Fly button
local flyToggle = UI.CreateToggleButton(
	"FlyButton",
	movementContent,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 40),
	"Fly",
	function(enabled)
		scriptStates.fly = enabled

		if enabled then
			local controls = {
				forward = false,
				backward = false,
				right = false,
				left = false,
				up = false,
				down = false
			}

			local function handleFlyInput(input, isPressed)
				if input.KeyCode == Enum.KeyCode.W then
					controls.forward = isPressed
				elseif input.KeyCode == Enum.KeyCode.S then
					controls.backward = isPressed
				elseif input.KeyCode == Enum.KeyCode.D then
					controls.right = isPressed
				elseif input.KeyCode == Enum.KeyCode.A then
					controls.left = isPressed
				elseif input.KeyCode == Enum.KeyCode.Space then
					controls.up = isPressed
				elseif input.KeyCode == Enum.KeyCode.LeftShift then
					controls.down = isPressed
				end
			end

			
			if not scriptStates.flyInputBeganConnection then
				scriptStates.flyInputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
					if not gameProcessed then
						handleFlyInput(input, true)
					end
				end)
			end

			if not scriptStates.flyInputEndedConnection then
				scriptStates.flyInputEndedConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
					if not gameProcessed then
						handleFlyInput(input, false)
					end
				end)
			end

			if character and character:FindFirstChild("Humanoid") then
				character.Humanoid.PlatformStand = true
			end

			local flySpeed = scriptStates.flySpeed or 2

			if not scriptStates.flyRenderSteppedConnection then
				scriptStates.flyRenderSteppedConnection = RunService.RenderStepped:Connect(function()
					if character and character:FindFirstChild("HumanoidRootPart") then
						local rootPart = character.HumanoidRootPart
						local camera = workspace.CurrentCamera
						local direction = Vector3.new(0, 0, 0)

						if controls.forward then
							direction = direction + camera.CFrame.LookVector
						end
						if controls.backward then
							direction = direction - camera.CFrame.LookVector
						end
						if controls.right then
							direction = direction + camera.CFrame.RightVector
						end
						if controls.left then
							direction = direction - camera.CFrame.RightVector
						end
						if controls.up then
							direction = direction + Vector3.new(0, 1, 0)
						end
						if controls.down then
							direction = direction - Vector3.new(0, 1, 0)
						end

						if direction.Magnitude > 0 then
							direction = direction.Unit * flySpeed
						end

						rootPart.Velocity = direction * 50
					end
				end)
			end
		else
			
			if scriptStates.flyInputBeganConnection then
				scriptStates.flyInputBeganConnection:Disconnect()
				scriptStates.flyInputBeganConnection = nil
			end

			if scriptStates.flyInputEndedConnection then
				scriptStates.flyInputEndedConnection:Disconnect()
				scriptStates.flyInputEndedConnection = nil
			end

			if scriptStates.flyRenderSteppedConnection then
				scriptStates.flyRenderSteppedConnection:Disconnect()
				scriptStates.flyRenderSteppedConnection = nil
			end

			
			if character and character:FindFirstChild("Humanoid") then
				character.Humanoid.PlatformStand = false
			end

			
			if character and character:FindFirstChild("HumanoidRootPart") then
				character.HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)
			end
		end
	end
)
flyToggle.Button.LayoutOrder = 1
local flySpeedLabel = Instance.new("TextLabel")
flySpeedLabel.Name = "FlySpeedLabel"
flySpeedLabel.Parent = movementContent
flySpeedLabel.Size = UDim2.new(1, 0, 0, 20)
flySpeedLabel.BackgroundTransparency = 1
flySpeedLabel.Font = Enum.Font.SourceSans
flySpeedLabel.Text = "Fly Speed"
flySpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
flySpeedLabel.TextSize = 14
flySpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
flySpeedLabel.LayoutOrder = 2
local flySpeedSlider = UI.CreateSlider(
	"FlySpeedSlider",
	movementContent,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 20),
	1,
	10,
	2,
	function(value)
		scriptStates.flySpeed = value
	end
)
flySpeedSlider.Frame.LayoutOrder = 3

local walkSpeedLabel = Instance.new("TextLabel")
walkSpeedLabel.Name = "WalkSpeedLabel"
walkSpeedLabel.Parent = movementContent
walkSpeedLabel.Size = UDim2.new(1, 0, 0, 20)
walkSpeedLabel.BackgroundTransparency = 1
walkSpeedLabel.Font = Enum.Font.SourceSans
walkSpeedLabel.Text = "Walk Speed"
walkSpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
walkSpeedLabel.TextSize = 14
walkSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
walkSpeedLabel.LayoutOrder = 4

local walkSpeedSlider = UI.CreateSlider(
	"WalkSpeedSlider",
	movementContent,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 20),
	16,
	500,
	16,
	function(value)
		scriptStates.walkSpeed = value
	end
)
walkSpeedSlider.Frame.LayoutOrder = 5

local walkSpeedButtonsFrame = Instance.new("Frame")
walkSpeedButtonsFrame.Name = "WalkSpeedButtonsFrame"
walkSpeedButtonsFrame.Parent = movementContent
walkSpeedButtonsFrame.Size = UDim2.new(1, 0, 0, 30)
walkSpeedButtonsFrame.BackgroundTransparency = 1
walkSpeedButtonsFrame.LayoutOrder = 6

local walkSpeedApplyButton = UI.CreateButton(
	"WalkSpeedApplyButton",
	walkSpeedButtonsFrame,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(0.48, 0, 1, 0),
	"Apply",
	Color3.fromRGB(0, 120, 255),
	function()
		if character and character:FindFirstChild("Humanoid") then
			character.Humanoid.WalkSpeed = scriptStates.walkSpeed or defaultWalkSpeed
		end
	end
)

local walkSpeedResetButton = UI.CreateButton(
	"WalkSpeedResetButton",
	walkSpeedButtonsFrame,
	UDim2.new(0.52, 0, 0, 0),
	UDim2.new(0.48, 0, 1, 0),
	"Reset",
	Color3.fromRGB(180, 0, 0),
	function()
		if character and character:FindFirstChild("Humanoid") then
			character.Humanoid.WalkSpeed = defaultWalkSpeed
			walkSpeedSlider.SetValue(defaultWalkSpeed)
		end
	end
)

local jumpPowerLabel = Instance.new("TextLabel")
jumpPowerLabel.Name = "JumpPowerLabel"
jumpPowerLabel.Parent = movementContent
jumpPowerLabel.Size = UDim2.new(1, 0, 0, 20)
jumpPowerLabel.BackgroundTransparency = 1
jumpPowerLabel.Font = Enum.Font.SourceSans
jumpPowerLabel.Text = "Jump Power"
jumpPowerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
jumpPowerLabel.TextSize = 14
jumpPowerLabel.TextXAlignment = Enum.TextXAlignment.Left
jumpPowerLabel.LayoutOrder = 7
local jumpPowerSlider = UI.CreateSlider(
	"JumpPowerSlider",
	movementContent,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 20),
	50,
	500,
	50,
	function(value)
		scriptStates.jumpPower = value
	end
)
jumpPowerSlider.Frame.LayoutOrder = 8
local jumpPowerButtonsFrame = Instance.new("Frame")
jumpPowerButtonsFrame.Name = "JumpPowerButtonsFrame"
jumpPowerButtonsFrame.Parent = movementContent
jumpPowerButtonsFrame.Size = UDim2.new(1, 0, 0, 30)
jumpPowerButtonsFrame.BackgroundTransparency = 1
jumpPowerButtonsFrame.LayoutOrder = 9

local jumpPowerApplyButton = UI.CreateButton(
	"JumpPowerApplyButton",
	jumpPowerButtonsFrame,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(0.48, 0, 1, 0),
	"Apply",
	Color3.fromRGB(0, 120, 255),
	function()
		if character and character:FindFirstChild("Humanoid") then
			character.Humanoid.JumpPower = scriptStates.jumpPower or defaultJumpPower
		end
	end
)

local jumpPowerResetButton = UI.CreateButton(
	"JumpPowerResetButton",
	jumpPowerButtonsFrame,
	UDim2.new(0.52, 0, 0, 0),
	UDim2.new(0.48, 0, 1, 0),
	"Reset",
	Color3.fromRGB(180, 0, 0),
	function()
		if character and character:FindFirstChild("Humanoid") then
			character.Humanoid.JumpPower = defaultJumpPower
			jumpPowerSlider.SetValue(defaultJumpPower)
		end
	end
)

local visualsContent = tabContents.Visuals

local espToggle = UI.CreateToggleButton(
	"ESPButton",
	visualsContent,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 40),
	"ESP",
	function(enabled)
		scriptStates.esp = enabled
		
		if enabled then
			local function createEsp()
				for _, player in pairs(Players:GetPlayers()) do
					if player ~= Players.LocalPlayer then
						if player.Character then
							local existingEsp = player.Character:FindFirstChild("ESP")
							if existingEsp then
								existingEsp:Destroy()
							end
						end
					end
				end
				
				for _, player in pairs(Players:GetPlayers()) do
					if player ~= Players.LocalPlayer then
						if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
							local espFolder = Instance.new("Folder")
							espFolder.Name = "ESP"
							espFolder.Parent = player.Character

							local billboard = Instance.new("BillboardGui")
							billboard.Name = "ESPBillboard"
							billboard.Parent = espFolder
							billboard.Adornee = player.Character.HumanoidRootPart
							billboard.Size = UDim2.new(0, 200, 0, 50)
							billboard.StudsOffset = Vector3.new(0, 3, 0)
							billboard.AlwaysOnTop = true

							local nameLabel = Instance.new("TextLabel")
							nameLabel.Name = "NameLabel"
							nameLabel.Parent = billboard
							nameLabel.BackgroundTransparency = 1
							nameLabel.Size = UDim2.new(1, 0, 0, 20)
							nameLabel.Font = Enum.Font.SourceSansBold
							nameLabel.Text = player.Name
							nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
							nameLabel.TextStrokeTransparency = 0.5
							nameLabel.TextSize = 16

							local distanceLabel = Instance.new("TextLabel")
							distanceLabel.Name = "DistanceLabel"
							distanceLabel.Parent = billboard
							distanceLabel.BackgroundTransparency = 1
							distanceLabel.Position = UDim2.new(0, 0, 0, 20)
							distanceLabel.Size = UDim2.new(1, 0, 0, 20)
							distanceLabel.Font = Enum.Font.SourceSans
							distanceLabel.Text = "Distance: Calculating..."
							distanceLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
							distanceLabel.TextStrokeTransparency = 0.5
							distanceLabel.TextSize = 14

							local box = Instance.new("BoxHandleAdornment")
							box.Name = "ESPBox"
							box.Parent = espFolder
							box.Adornee = player.Character
							box.AlwaysOnTop = true
							box.ZIndex = 10
							box.Size = player.Character:GetExtentsSize()
							box.Transparency = 0.7
							box.Color3 = Color3.fromRGB(255, 0, 0)
						end
					end
				end
			end
			
			local function updateESP()
				for _, player in pairs(Players:GetPlayers()) do
					if player ~= Players.LocalPlayer then
						if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
							local espFolder = player.Character:FindFirstChild("ESP")
							if espFolder then
								local billboard = espFolder:FindFirstChild("ESPBillboard")
								if billboard then
									local distanceLabel = billboard:FindFirstChild("DistanceLabel")
									if distanceLabel then
										local distance = (player.Character.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
										distanceLabel.Text = "Distance: " .. math.floor(distance)
									end
								end
								
								local box = espFolder:FindFirstChild("ESPBox")
								if box then
									box.Size = player.Character:GetExtentsSize()
								end
							end
						end
					end
				end
			end
			
			createEsp()
			
			if not scriptStates.espUpdateConnection then
				scriptStates.espUpdateConnection = RunService.RenderStepped:Connect(updateESP)
			end
			
			if not scriptStates.espPlayerAddedConnection then
				scriptStates.espPlayerAddedConnection = Players.PlayerAdded:Connect(function(player)
					if player.Character then
						createEsp()
					end
					
					player.CharacterAdded:Connect(function(character)
						task.wait(1)
						createEsp()
					end)
				end)
			end
			
			if not scriptStates.espPlayerRemovingConnection then
				scriptStates.espPlayerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
					-- esp elements are parented to character
				end)
			end
			
			for _, player in pairs(Players:GetPlayers()) do
				if player ~= Players.LocalPlayer then
					player.CharacterAdded:Connect(function(character)
						task.wait(1)
						createEsp()
					end)
				end
			end
		else
			if scriptStates.espUpdateConnection then
				scriptStates.espUpdateConnection:Disconnect()
				scriptStates.espUpdateConnection = nil
			end

			if scriptStates.espPlayerAddedConnection then
				scriptStates.espPlayerAddedConnection:Disconnect()
				scriptStates.espPlayerAddedConnection = nil
			end

			if scriptStates.espPlayerRemovingConnection then
				scriptStates.espPlayerRemovingConnection:Disconnect()
				scriptStates.espPlayerRemovingConnection = nil
			end
			
			for _, player in pairs(Players:GetPlayers()) do
				if player.Character then
					local espFolder = player.Character:FindFirstChild("ESP")
					if espFolder then
						espFolder:Destroy()
					end
				end
			end
		end
	end
)
espToggle.Button.LayoutOrder = 1

local fullbrightToggle = UI.CreateToggleButton(
	"FullbrightButton",
	visualsContent,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 40),
	"Fullbright",
	function(enabled)
		scriptStates.fullbright = enabled

		if enabled then
			-- Store original lighting properties
			if not scriptStates.originalLightingProperties then
				scriptStates.originalLightingProperties = {
					Brightness = Lighting.Brightness,
					ClockTime = Lighting.ClockTime,
					FogEnd = Lighting.FogEnd,
					GlobalShadows = Lighting.GlobalShadows,
					Ambient = Lighting.Ambient
				}
			end

			-- Set fullbright
			Lighting.Brightness = 2
			Lighting.ClockTime = 14
			Lighting.FogEnd = 100000
			Lighting.GlobalShadows = false
			Lighting.Ambient = Color3.fromRGB(178, 178, 178)
		else
			-- Restore original lighting properties
			if scriptStates.originalLightingProperties then
				Lighting.Brightness = scriptStates.originalLightingProperties.Brightness
				Lighting.ClockTime = scriptStates.originalLightingProperties.ClockTime
				Lighting.FogEnd = scriptStates.originalLightingProperties.FogEnd
				Lighting.GlobalShadows = scriptStates.originalLightingProperties.GlobalShadows
				Lighting.Ambient = scriptStates.originalLightingProperties.Ambient
			end
		end
	end
)
fullbrightToggle.Button.LayoutOrder = 2
-- Xray button
local xrayToggle = UI.CreateToggleButton(
	"XrayButton",
	visualsContent,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 40),
	"X-Ray",
	function(enabled)
		scriptStates.xray = enabled

		if enabled then
			-- Store original transparency values
			scriptStates.originalTransparency = {}

			-- Set transparency for all parts in workspace
			for _, part in pairs(workspace:GetDescendants()) do
				if part:IsA("BasePart") and not part:IsDescendantOf(character) and not (part.Name == "HumanoidRootPart") then
					scriptStates.originalTransparency[part] = part.Transparency
					part.Transparency = 0.8
				end
			end
		else
			-- Restore original transparency values
			if scriptStates.originalTransparency then
				for part, transparency in pairs(scriptStates.originalTransparency) do
					if part:IsA("BasePart") then
						part.Transparency = transparency
					end
				end
				scriptStates.originalTransparency = nil
			end
		end
	end
)
xrayToggle.Button.LayoutOrder = 3

local adminContent = tabContents.Admin
local commandLabel = Instance.new("TextLabel")
commandLabel.Name = "CommandLabel"
commandLabel.Parent = adminContent
commandLabel.Size = UDim2.new(1, 0, 0, 20)
commandLabel.BackgroundTransparency = 1
commandLabel.Font = Enum.Font.SourceSans
commandLabel.Text = "Command (e.g. /kill player)"
commandLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
commandLabel.TextSize = 14
commandLabel.TextXAlignment = Enum.TextXAlignment.Left
commandLabel.LayoutOrder = 1
local commandInput = Instance.new("TextBox")
commandInput.Name = "CommandInput"
commandInput.Parent = adminContent
commandInput.Size = UDim2.new(1, 0, 0, 30)
commandInput.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
commandInput.BorderSizePixel = 0
commandInput.Font = Enum.Font.SourceSans
commandInput.PlaceholderText = "Enter command here..."
commandInput.Text = ""
commandInput.TextColor3 = Color3.fromRGB(255, 255, 255)
commandInput.TextSize = 14
commandInput.LayoutOrder = 2
local outputLabel = Instance.new("TextLabel")
outputLabel.Name = "OutputLabel"
outputLabel.Parent = adminContent
outputLabel.Size = UDim2.new(1, 0, 0, 20)
outputLabel.BackgroundTransparency = 1
outputLabel.Font = Enum.Font.SourceSans
outputLabel.Text = "Output"
outputLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
outputLabel.TextSize = 14
outputLabel.TextXAlignment = Enum.TextXAlignment.Left
outputLabel.LayoutOrder = 4
local outputFrame = Instance.new("Frame")
outputFrame.Name = "OutputFrame"
outputFrame.Parent = adminContent
outputFrame.Size = UDim2.new(1, 0, 0, 100)
outputFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
outputFrame.BorderSizePixel = 0
outputFrame.LayoutOrder = 5
local outputFrameCorner = Instance.new("UICorner")
outputFrameCorner.CornerRadius = UDim.new(0, 4)
outputFrameCorner.Parent = outputFrame
local outputBox = Instance.new("TextLabel")
outputBox.Name = "OutputBox"
outputBox.Parent = outputFrame
outputBox.Size = UDim2.new(1, -10, 1, -10)
outputBox.Position = UDim2.new(0, 5, 0, 5)
outputBox.BackgroundTransparency = 1
outputBox.Font = Enum.Font.SourceSans
outputBox.Text = "Command output will appear here."
outputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
outputBox.TextSize = 14
outputBox.TextWrapped = true
outputBox.TextXAlignment = Enum.TextXAlignment.Left
outputBox.TextYAlignment = Enum.TextYAlignment.Top
local commandInputCorner = Instance.new("UICorner")
commandInputCorner.CornerRadius = UDim.new(0, 4)
commandInputCorner.Parent = commandInput

local executeButton = UI.CreateButton(
	"ExecuteButton",
	adminContent,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 30),
	"Execute Command",
	Color3.fromRGB(0, 120, 255),
	function()
		local commandText = commandInput.Text
		if commandText and commandText ~= "" then
			local response = executeAdminCommand(commandText)
			outputBox.Text = response
			commandInput.Text = ""
		else
			outputBox.Text = "Please enter a command."
		end
	end
)
executeButton.LayoutOrder = 3
local helpButton = UI.CreateButton(
	"HelpButton",
	adminContent,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 30),
	"Show Available Commands",
	Color3.fromRGB(60, 60, 60),
	function()
		local response = executeAdminCommand("/help")
		outputBox.Text = response
	end
)
helpButton.LayoutOrder = 6

local teleportContent = tabContents.Teleport
local playersLabel = Instance.new("TextLabel")
playersLabel.Name = "PlayersLabel"
playersLabel.Parent = teleportContent
playersLabel.Size = UDim2.new(1, 0, 0, 20)
playersLabel.BackgroundTransparency = 1
playersLabel.Font = Enum.Font.SourceSans
playersLabel.Text = "Select a player to teleport to"
playersLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
playersLabel.TextSize = 14
playersLabel.TextXAlignment = Enum.TextXAlignment.Left
playersLabel.LayoutOrder = 1
local playerListFrame = Instance.new("Frame")
playerListFrame.Name = "PlayerListFrame"
playerListFrame.Parent = teleportContent
playerListFrame.Size = UDim2.new(1, 0, 0, 200)
playerListFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
playerListFrame.BorderSizePixel = 0
playerListFrame.LayoutOrder = 2
local playerListFrameCorner = Instance.new("UICorner")
playerListFrameCorner.CornerRadius = UDim.new(0, 4)
playerListFrameCorner.Parent = playerListFrame
local playerList = Instance.new("ScrollingFrame")
playerList.Name = "PlayerList"
playerList.Parent = playerListFrame
playerList.Size = UDim2.new(1, -10, 1, -10)
playerList.Position = UDim2.new(0, 5, 0, 5)
playerList.BackgroundTransparency = 1
playerList.BorderSizePixel = 0
playerList.ScrollBarThickness = 4
playerList.CanvasSize = UDim2.new(0, 0, 0, 0)
playerList.AutomaticCanvasSize = Enum.AutomaticSize.Y
playerList.ScrollingDirection = Enum.ScrollingDirection.Y
local playerListLayout = Instance.new("UIListLayout")
playerListLayout.Parent = playerList
playerListLayout.SortOrder = Enum.SortOrder.Name
playerListLayout.Padding = UDim.new(0, 5)
local selectedPlayer = nil
local function updatePlayerList()
	for _, child in pairs(playerList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for _, otherPlayer in pairs(Players:GetPlayers()) do
		if otherPlayer ~= player then
			local playerButton = Instance.new("TextButton")
			playerButton.Name = otherPlayer.Name .. "Button"
			playerButton.Parent = playerList
			playerButton.Size = UDim2.new(1, 0, 0, 30)
			playerButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			playerButton.BorderSizePixel = 0
			playerButton.Font = Enum.Font.SourceSans
			playerButton.Text = otherPlayer.Name
			playerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			playerButton.TextSize = 14

			local playerButtonCorner = Instance.new("UICorner")
			playerButtonCorner.CornerRadius = UDim.new(0, 4)
			playerButtonCorner.Parent = playerButton

			playerButton.MouseButton1Click:Connect(function()
				selectedPlayer = otherPlayer

				for _, child in pairs(playerList:GetChildren()) do
					if child:IsA("TextButton") then
						if child.Name == otherPlayer.Name .. "Button" then
							child.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
						else
							child.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
						end
					end
				end
			end)
		end
	end
end
updatePlayerList()
local teleportButton = UI.CreateButton(
	"TeleportButton",
	teleportContent,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 40),
	"Teleport to Selected Player",
	Color3.fromRGB(0, 120, 255),
	function()
		if selectedPlayer and selectedPlayer.Character and selectedPlayer.Character:FindFirstChild("HumanoidRootPart") then
			local targetPosition = selectedPlayer.Character.HumanoidRootPart.Position

			if character and character:FindFirstChild("HumanoidRootPart") then
				character:SetPrimaryPartCFrame(CFrame.new(targetPosition + Vector3.new(0, 3, 0)))
			end
		else
			local notification = Instance.new("Frame")
			notification.Name = "Notification"
			notification.Parent = screenGui
			notification.Position = UDim2.new(0.5, -150, 0, -50)
			notification.Size = UDim2.new(0, 300, 0, 50)
			notification.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			notification.BorderSizePixel = 0

			local notificationCorner = Instance.new("UICorner")
			notificationCorner.CornerRadius = UDim.new(0, 8)
			notificationCorner.Parent = notification


			local notificationText = Instance.new("TextLabel")
			notificationText.Name = "NotificationText"
			notificationText.Parent = notification
			notificationText.Size = UDim2.new(1, 0, 1, 0)
			notificationText.BackgroundTransparency = 1
			notificationText.Font = Enum.Font.SourceSansBold
			notificationText.Text = "Please select a player first."
			notificationText.TextColor3 = Color3.fromRGB(255, 255, 255)
			notificationText.TextSize = 16

			notification:TweenPosition(UDim2.new(0.5, -150, 0, 20), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.5, true)

			task.delay(2, function()
				notification:TweenPosition(UDim2.new(0.5, -150, 0, -50), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.5, true, function()
					notification:Destroy()
				end)
			end)
		end
	end
)
teleportButton.LayoutOrder = 3
local refreshButton = UI.CreateButton(
	"RefreshButton",
	teleportContent,
	UDim2.new(0, 0, 0, 0),
	UDim2.new(1, 0, 0, 30),
	"Refresh Player List",
	Color3.fromRGB(60, 60, 60),
	function()
		updatePlayerList()
	end
)
refreshButton.LayoutOrder = 4
Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(updatePlayerList)
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	rootPart = character:WaitForChild("HumanoidRootPart")

	if not scriptStates.fly then
		humanoid.PlatformStand = false
	end

	if scriptStates.walkSpeed then
		humanoid.WalkSpeed = scriptStates.walkSpeed
	end

	if scriptStates.jumpPower then
		humanoid.JumpPower = scriptStates.jumpPower
	end

	if scriptStates.noclip and scriptStates.noclipConnection then
		scriptStates.noclipConnection:Disconnect()
		scriptStates.noclipConnection = RunService.Stepped:Connect(function()
			if character then
				for _, part in pairs(character:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
					end
				end
			end
		end)
	end
end)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.KeyCode == Enum.KeyCode.Space and scriptStates.infiniteJump then
		if character and character:FindFirstChild("Humanoid") then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)
game.Loaded:Wait()
print("Nexus hub loaded successfully!")
print("Press Right Ctrl to toggle the UI")
