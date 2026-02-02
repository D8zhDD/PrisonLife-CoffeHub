-- Rayfield Sirius
local success_rayfield, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)

if not success_rayfield then
    warn("Failed to load Rayfield")
    return
end

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- =========================
-- CONFIGURATION
-- =========================
local CONFIG = {
    Aimbot = false,
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
    JumpPower = 50
}

local COLORS = {
    Enemy = Color3.fromRGB(255, 0, 0),
    Team = Color3.fromRGB(0, 255, 0),
    FOV = Color3.fromRGB(0, 255, 0)
}

-- =========================
-- DEFAULTS (PARA RESET)
-- =========================
local DEFAULTS = {
    WalkSpeed = 16,
    JumpPower = 50
}

-- =========================
-- CACHE VALUES
-- =========================
local ViewportCache = {
    CenterX = 0,
    CenterY = 0,
    SizeX = 0,
    SizeY = 0
}

local function UpdateViewportCache()
    ViewportCache.SizeX = Camera.ViewportSize.X
    ViewportCache.SizeY = Camera.ViewportSize.Y
    ViewportCache.CenterX = ViewportCache.SizeX / 2
    ViewportCache.CenterY = ViewportCache.SizeY / 2
end

UpdateViewportCache()

-- =========================
-- TEAM SYSTEM (PRISON LIFE FIX)
-- =========================
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

-- =========================
-- GET BODY PART (R6/R15 COMPATIBLE)
-- =========================
local function getBodyPart(character, partName)
    if not character then return nil end
    
    if partName == "Head" then
        return character:FindFirstChild("Head")
    elseif partName == "Torso" then
        -- Prioridade R6
        local torso = character:FindFirstChild("Torso")
        if torso then return torso end
        
        -- Prioridade R15
        local upperTorso = character:FindFirstChild("UpperTorso")
        if upperTorso then return upperTorso end
        
        local lowerTorso = character:FindFirstChild("LowerTorso")
        if lowerTorso then return lowerTorso end
        
        return character:FindFirstChild("HumanoidRootPart")
    end
    
    return character:FindFirstChild("Head") -- Fallback padrão
end

-- =========================
-- FOV CIRCLE
-- =========================
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Radius = CONFIG.FOV
FOVCircle.Color = COLORS.FOV
FOVCircle.Thickness = 1.5
FOVCircle.Filled = false
FOVCircle.Transparency = 0.8

-- =========================
-- ESP MANAGER
-- =========================
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

-- =========================
-- AIMBOT LOGIC (CORRIGIDA)
-- =========================
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

-- =========================
-- LOOPS
-- =========================
RunService.RenderStepped:Connect(function()
    pcall(function()
        -- Update viewport cache
        UpdateViewportCache()
        
        FOVCircle.Position = Vector2.new(ViewportCache.CenterX, ViewportCache.CenterY)
        FOVCircle.Radius = CONFIG.FOV
        FOVCircle.Visible = CONFIG.Aimbot
        
        if CONFIG.Aimbot and UserInputService:IsMouseButtonPressed(CONFIG.HoldKey) then
            local t = getTarget()
            if t then
                local currentCF = Camera.CFrame
                local targetCF = CFrame.new(currentCF.Position, t.Position)
                Camera.CFrame = currentCF:Lerp(targetCF, CONFIG.Smoothness)
            end
        end
        
        -- WalkSpeed (COM RESET)
        if LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if hum then
                if CONFIG.CustomWalkSpeed then
                    hum.WalkSpeed = CONFIG.WalkSpeed
                else
                    hum.WalkSpeed = DEFAULTS.WalkSpeed
                end
            end
        end
        
        -- JumpPower (COM RESET - BUG CORRIGIDO)
        if LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if hum then
                if CONFIG.CustomJumpPower then
                    -- Aplica JumpPower customizado
                    hum.UseJumpPower = true
                    hum.JumpPower = CONFIG.JumpPower
                else
                    -- RESET: Volta para o padrão
                    hum.UseJumpPower = true
                    hum.JumpPower = DEFAULTS.JumpPower
                end
            end
        end
        
        updateESP()
    end)
end)

-- Initialize
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

-- =========================
-- UI INTERFACE
-- =========================
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

-- Color Pickers
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

local TabMisc = Window:CreateTab("Movement")

TabMisc:CreateToggle({
    Name = "Custom WalkSpeed", 
    Callback = function(v) 
        CONFIG.CustomWalkSpeed = v 
    end
})

TabMisc:CreateSlider({
    Name = "Speed Value", 
    Range = {16, 100}, 
    Increment = 1, 
    CurrentValue = CONFIG.WalkSpeed, 
    Callback = function(v) 
        CONFIG.WalkSpeed = v 
    end
})

TabMisc:CreateToggle({
    Name = "Custom Jump Power", 
    Callback = function(v) 
        CONFIG.CustomJumpPower = v 
    end
})

TabMisc:CreateSlider({
    Name = "Jump Force", 
    Range = {50, 150}, 
    Increment = 5, 
    CurrentValue = CONFIG.JumpPower, 
    Callback = function(v) 
        CONFIG.JumpPower = v 
    end
})

Rayfield:Notify({
    Title = "Pronto", 
    Content = "BUG DO RESET CORRIGIDO - Agora volta ao padrão!", 
    Duration = 3
})
