local success_rayfield, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not success_rayfield then
    warn("Failed to load Rayfield")
    return
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    Aimbot = false,
    AimbotVisible = true,
    AimbotPart = "Head",
    FOV = 150,
    Smoothness = 0.2,
    HoldKey = Enum.UserInputType.MouseButton2,
    EnemyESP = false,
    TeamESP = false,
    HealthBar = true,
    Tracer = true,
    CustomWalkSpeed = false,
    WalkSpeed = 16,
    CustomJumpPower = false,
    JumpPower = 50,
    Fly = false,
    FlySpeed = 50
}

local COLORS = {
    Enemy = Color3.fromRGB(255, 0, 0),
    Team = Color3.fromRGB(0, 255, 0),
    FOV = Color3.fromRGB(0, 255, 0)
}

local DEFAULTS = {
    WalkSpeed = 16,
    JumpPower = 50
}

local ViewportCache = {
    CenterX = 0,
    CenterY = 0,
    SizeX = 0,
    SizeY = 0
}

local FlyConnection = nil
local BodyVelocity = nil
local BodyGyro = nil

local function UpdateViewportCache()
    ViewportCache.SizeX = Camera.ViewportSize.X
    ViewportCache.SizeY = Camera.ViewportSize.Y
    ViewportCache.CenterX = ViewportCache.SizeX / 2
    ViewportCache.CenterY = ViewportCache.SizeY / 2
end

UpdateViewportCache()

local function isEnemy(p)
    if not p or p == LocalPlayer then return false end
    local myTeam = (LocalPlayer.Team and LocalPlayer.Team.Name) or "Neutral"
    local pTeam = (p.Team and p.Team.Name) or "Neutral"
    if myTeam == "Guards" then
        return (pTeam == "Inmates" or pTeam == "Criminals")
    elseif myTeam == "Inmates" or myTeam == "Criminals" then
        return (pTeam == "Guards")
    end
    return false
end

local function getBodyPart(character, partName)
    if not character then return nil end
    
    if partName == "Head" then
        return character:FindFirstChild("Head")
    elseif partName == "Torso" then
        local torso = character:FindFirstChild("Torso")
        if torso then return torso end
        
        local upperTorso = character:FindFirstChild("UpperTorso")
        if upperTorso then return upperTorso end
        
        local lowerTorso = character:FindFirstChild("LowerTorso")
        if lowerTorso then return lowerTorso end
        
        return character:FindFirstChild("HumanoidRootPart")
    end
    
    return character:FindFirstChild("Head")
end

local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Radius = CONFIG.FOV
FOVCircle.Color = COLORS.FOV
FOVCircle.Thickness = 1.5
FOVCircle.Filled = false
FOVCircle.Transparency = 0.8

local ESP_DATA = {}

local function createESP(p)
    if p == LocalPlayer then return end
    
    local success, result = pcall(function()
        local objects = {
            Highlight = Instance.new("Highlight"),
            Billboard = Instance.new("BillboardGui"),
            Tracer = Drawing.new("Line")
        }
        
        objects.Highlight.Name = "ESP_" .. p.Name
        objects.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        objects.Highlight.FillTransparency = 0.5
        objects.Highlight.OutlineTransparency = 0
        
        objects.Billboard.Size = UDim2.new(0, 100, 0, 50)
        objects.Billboard.AlwaysOnTop = true
        objects.Billboard.StudsOffset = Vector3.new(0, 3, 0)
        
        local text = Instance.new("TextLabel", objects.Billboard)
        text.Size = UDim2.new(1, 0, 1, 0)
        text.BackgroundTransparency = 1
        text.TextStrokeTransparency = 0
        text.Font = Enum.Font.GothamBold
        text.TextSize = 12
        objects.Label = text
        
        ESP_DATA[p] = objects
    end)
    
    if not success then
        warn("Failed to create ESP for player:", p.Name)
    end
end

local function updateESP()
    for p, obj in pairs(ESP_DATA) do
        pcall(function()
            local char = p.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local enemy = isEnemy(p)
            local visible = (enemy and CONFIG.EnemyESP) or (not enemy and CONFIG.TeamESP)
            
            if visible and char and hum and hrp and hum.Health > 0 then
                local color = enemy and COLORS.Enemy or COLORS.Team
                
                obj.Highlight.Parent = char
                obj.Highlight.FillColor = color
                obj.Highlight.OutlineColor = color
                obj.Highlight.Enabled = true
                
                obj.Billboard.Parent = hrp
                obj.Billboard.Enabled = true
                obj.Label.TextColor3 = color
                obj.Label.Text = string.format("%s\n%d HP", p.Name, math.floor(hum.Health))
                
                if CONFIG.Tracer then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        obj.Tracer.From = Vector2.new(ViewportCache.CenterX, ViewportCache.SizeY)
                        obj.Tracer.To = Vector2.new(screenPos.X, screenPos.Y)
                        obj.Tracer.Color = color
                        obj.Tracer.Visible = true
                    else
                        obj.Tracer.Visible = false
                    end
                else
                    obj.Tracer.Visible = false
                end
            else
                obj.Highlight.Enabled = false
                obj.Billboard.Enabled = false
                obj.Tracer.Visible = false
            end
        end)
    end
end

local function getTarget()
    local target = nil
    local shortestDistance = CONFIG.FOV
    
    for _, p in ipairs(Players:GetPlayers()) do
        pcall(function()
            if isEnemy(p) and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                local aimPart = getBodyPart(p.Character, CONFIG.AimbotPart)
                
                if aimPart and hum and hum.Health > 0 then
                    local pos, onScreen = Camera:WorldToViewportPoint(aimPart.Position)
                    
                    if onScreen then
                        local mousePos = Vector2.new(ViewportCache.CenterX, ViewportCache.CenterY)
                        local targetPos = Vector2.new(pos.X, pos.Y)
                        local distance = (targetPos - mousePos).Magnitude
                        
                        if distance < shortestDistance then
                            shortestDistance = distance
                            target = aimPart
                        end
                    end
                end
            end
        end)
    end
    
    return target
end

local function StartFly()
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Velocity = Vector3.new(0, 0, 0)
    BodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    BodyVelocity.Parent = humanoidRootPart
    
    BodyGyro = Instance.new("BodyGyro")
    BodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    BodyGyro.P = 9e4
    BodyGyro.Parent = humanoidRootPart
    
    FlyConnection = RunService.RenderStepped:Connect(function()
        if not CONFIG.Fly then
            StopFly()
            return
        end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Flying)
        end
        
        local moveDirection = Vector3.new(0, 0, 0)
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDirection = moveDirection + Camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDirection = moveDirection - Camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDirection = moveDirection - Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDirection = moveDirection + Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDirection = moveDirection + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            moveDirection = moveDirection - Vector3.new(0, 1, 0)
        end
        
        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit
        end
        
        BodyVelocity.Velocity = moveDirection * CONFIG.FlySpeed
        BodyGyro.CFrame = Camera.CFrame
    end)
end

function StopFly()
    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
    end
    
    if BodyVelocity then
        BodyVelocity:Destroy()
        BodyVelocity = nil
    end
    
    if BodyGyro then
        BodyGyro:Destroy()
        BodyGyro = nil
    end
    
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
        end
    end
end

RunService.RenderStepped:Connect(function()
    pcall(function()
        UpdateViewportCache()
        
        FOVCircle.Position = Vector2.new(ViewportCache.CenterX, ViewportCache.CenterY)
        FOVCircle.Radius = CONFIG.FOV
        FOVCircle.Color = COLORS.FOV
        FOVCircle.Visible = CONFIG.Aimbot and CONFIG.AimbotVisible
        
        if CONFIG.Aimbot and UserInputService:IsMouseButtonPressed(CONFIG.HoldKey) then
            local t = getTarget()
            if t then
                local currentCF = Camera.CFrame
                local targetCF = CFrame.new(currentCF.Position, t.Position)
                Camera.CFrame = currentCF:Lerp(targetCF, CONFIG.Smoothness)
            end
        end
        
        if LocalPlayer.Character and not CONFIG.Fly then
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if hum then
                if CONFIG.CustomWalkSpeed then
                    hum.WalkSpeed = CONFIG.WalkSpeed
                end
                
                if CONFIG.CustomJumpPower then
                    hum.UseJumpPower = true
                    hum.JumpPower = CONFIG.JumpPower
                end
            end
        end
        
        updateESP()
    end)
end)

for _, p in ipairs(Players:GetPlayers()) do 
    createESP(p) 
end

Players.PlayerAdded:Connect(function(p)
    createESP(p)
end)

Players.PlayerRemoving:Connect(function(p)
    pcall(function()
        if ESP_DATA[p] then 
            ESP_DATA[p].Highlight:Destroy()
            ESP_DATA[p].Billboard:Destroy()
            ESP_DATA[p].Tracer:Remove()
            ESP_DATA[p] = nil 
        end
    end)
end)

LocalPlayer.CharacterAdded:Connect(function()
    wait(0.5)
    if CONFIG.Fly then
        StopFly()
        wait(0.5)
        StartFly()
    end
end)

local Window = Rayfield:CreateWindow({
    Name = "Prison Life Hub", 
    LoadingTitle = "Carregando...", 
    ConfigurationSaving = {Enabled = false}
})

local TabAim = Window:CreateTab("Combat")

TabAim:CreateToggle({
    Name = "Enable Aimbot", 
    Callback = function(v) 
        CONFIG.Aimbot = v 
    end
})

TabAim:CreateToggle({
    Name = "Show FOV Circle", 
    CurrentValue = true,
    Callback = function(v) 
        CONFIG.AimbotVisible = v 
    end
})

TabAim:CreateSlider({
    Name = "FOV Radius", 
    Range = {50, 500}, 
    Increment = 10, 
    CurrentValue = 150, 
    Callback = function(v) 
        CONFIG.FOV = v 
    end
})

TabAim:CreateSlider({
    Name = "Smoothness", 
    Range = {0.05, 1}, 
    Increment = 0.05, 
    CurrentValue = 0.2, 
    Callback = function(v) 
        CONFIG.Smoothness = v 
    end
})

TabAim:CreateDropdown({
    Name = "Target Part", 
    Options = {"Head", "Torso"}, 
    CurrentOption = "Head", 
    Callback = function(v) 
        CONFIG.AimbotPart = (type(v) == "table" and v[1]) or v
    end
})

TabAim:CreateColorPicker({
    Name = "FOV Color",
    Color = COLORS.FOV,
    Callback = function(v)
        COLORS.FOV = v
    end
})

local TabVis = Window:CreateTab("Visuals")

TabVis:CreateToggle({
    Name = "Enemy ESP", 
    Callback = function(v) 
        CONFIG.EnemyESP = v 
    end
})

TabVis:CreateToggle({
    Name = "Team ESP", 
    Callback = function(v) 
        CONFIG.TeamESP = v 
    end
})

TabVis:CreateToggle({
    Name = "Tracers", 
    CurrentValue = true, 
    Callback = function(v) 
        CONFIG.Tracer = v 
    end
})

TabVis:CreateColorPicker({
    Name = "Enemy Color",
    Color = COLORS.Enemy,
    Callback = function(v)
        COLORS.Enemy = v
    end
})

TabVis:CreateColorPicker({
    Name = "Team Color",
    Color = COLORS.Team,
    Callback = function(v)
        COLORS.Team = v
    end
})

local TabMov = Window:CreateTab("Movement")

TabMov:CreateToggle({
    Name = "Custom WalkSpeed", 
    Callback = function(v) 
        CONFIG.CustomWalkSpeed = v 
    end
})

TabMov:CreateSlider({
    Name = "Speed Value", 
    Range = {16, 100}, 
    Increment = 1, 
    CurrentValue = CONFIG.WalkSpeed, 
    Callback = function(v) 
        CONFIG.WalkSpeed = v 
    end
})

TabMov:CreateToggle({
    Name = "Custom Jump Power", 
    Callback = function(v) 
        CONFIG.CustomJumpPower = v 
    end
})

TabMov:CreateSlider({
    Name = "Jump Force", 
    Range = {50, 150}, 
    Increment = 5, 
    CurrentValue = CONFIG.JumpPower, 
    Callback = function(v) 
        CONFIG.JumpPower = v 
    end
})

TabMov:CreateToggle({
    Name = "Fly",
    CurrentValue = false,
    Callback = function(v)
        CONFIG.Fly = v
        if v then
            StartFly()
        else
            StopFly()
        end
    end
})

TabMov:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 200},
    Increment = 5,
    CurrentValue = 50,
    Callback = function(v)
        CONFIG.FlySpeed = v
    end
})

Rayfield:Notify({
    Title = "Pronto!", 
    Content = "Sprint nativo funcionando - Left Shift para correr", 
    Duration = 3
})
