local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Teams = game:GetService("Teams")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ═══════════════════════════════════════════════════════
-- ⚙️ CONFIGURAÇÕES GERAIS
-- ═══════════════════════════════════════════════════════
local CONFIG = {
    -- Aimbot
    AimbotLigado = false,
    RaioFOV = 150,
    Suavidade = 0.2,
    Tecla = Enum.UserInputType.MouseButton2,
    CorCirculo = Color3.fromRGB(0, 255, 0),
    AimbotParte = "Head",        -- "Head" ou "Torso"
    
    -- ESP
    ESPEnemyLigado = false,      -- Toggle separado para inimigos
    ESPTeamLigado = false,       -- Toggle separado para aliados
    MostrarBoxes = true,
    MostrarTracers = true,
    MostrarHealth = true,
    CorEnemy = Color3.fromRGB(255, 0, 0),
    CorTeammate = Color3.fromRGB(0, 255, 0),
    EspessuraLinha = 2,
    
    -- Misc/Configs
    WalkSpeedLigado = false,
    WalkSpeedValor = 16,         -- Velocidade padrão do Roblox
}

-- ═══════════════════════════════════════════════════════
-- 🎨 VISUAL (Círculo FOV)
-- ═══════════════════════════════════════════════════════
local function criarFOVCircle()
    if player.PlayerGui:FindFirstChild("AimbotFOV") then 
        player.PlayerGui.AimbotFOV:Destroy() 
    end
    
    local gui = Instance.new("ScreenGui", player.PlayerGui)
    gui.Name = "AimbotFOV"
    gui.ResetOnSpawn = false

    local frame = Instance.new("Frame", gui)
    frame.BackgroundTransparency = 1
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.Size = UDim2.new(0, CONFIG.RaioFOV * 2, 0, CONFIG.RaioFOV * 2)
    frame.Visible = false

    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(1, 0)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = CONFIG.CorCirculo
    stroke.Thickness = 2
    stroke.Transparency = 0.3
    
    return frame
end

local fovCircle = criarFOVCircle()

-- ═══════════════════════════════════════════════════════
-- 🧠 LÓGICA DE TIMES
-- ═══════════════════════════════════════════════════════
local function isEnemy(targetPlayer)
    local myTeam = player.Team and player.Team.Name
    local targetTeam = targetPlayer.Team and targetPlayer.Team.Name

    if not myTeam or not targetTeam then return false end

    if myTeam == "Guards" then
        if targetTeam == "Inmates" or targetTeam == "Criminals" then
            return true
        end
    elseif myTeam == "Inmates" or myTeam == "Criminals" then
        if targetTeam == "Guards" then
            return true
        end
    end

    return false
end

local function getClosestTarget()
    local closest = nil
    local shortestDist = CONFIG.RaioFOV
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

    for _, v in ipairs(Players:GetPlayers()) do
        if v ~= player and v.Character then
            if isEnemy(v) then
                local hum = v.Character:FindFirstChild("Humanoid")
                
                -- Seleciona a parte do corpo baseado na config
                local targetPart = nil
                if CONFIG.AimbotParte == "Head" then
                    targetPart = v.Character:FindFirstChild("Head")
                else -- Torso
                    targetPart = v.Character:FindFirstChild("UpperTorso") or v.Character:FindFirstChild("Torso")
                end

                if hum and hum.Health > 0 and targetPart then
                    local screenPos, onScreen = camera:WorldToScreenPoint(targetPart.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if dist < shortestDist then
                            shortestDist = dist
                            closest = targetPart
                        end
                    end
                end
            end
        end
    end
    return closest
end

-- ═══════════════════════════════════════════════════════
-- 📦 ESP SYSTEM (CORRIGIDO)
-- ═══════════════════════════════════════════════════════
local function createDrawing(type, properties)
    local drawing = Drawing.new(type)
    for prop, value in pairs(properties) do
        drawing[prop] = value
    end
    return drawing
end

local ESPObjects = {}

local function createESP(targetPlayer)
    if ESPObjects[targetPlayer] then return end
    
    local espData = {
        Player = targetPlayer,
        
        -- Box (4 linhas formando um retângulo)
        BoxOutline = {
            createDrawing("Line", {Thickness = 3, Color = Color3.new(0, 0, 0), Transparency = 1, Visible = false}),
            createDrawing("Line", {Thickness = 3, Color = Color3.new(0, 0, 0), Transparency = 1, Visible = false}),
            createDrawing("Line", {Thickness = 3, Color = Color3.new(0, 0, 0), Transparency = 1, Visible = false}),
            createDrawing("Line", {Thickness = 3, Color = Color3.new(0, 0, 0), Transparency = 1, Visible = false}),
        },
        Box = {
            createDrawing("Line", {Thickness = CONFIG.EspessuraLinha, Transparency = 1, Visible = false}),
            createDrawing("Line", {Thickness = CONFIG.EspessuraLinha, Transparency = 1, Visible = false}),
            createDrawing("Line", {Thickness = CONFIG.EspessuraLinha, Transparency = 1, Visible = false}),
            createDrawing("Line", {Thickness = CONFIG.EspessuraLinha, Transparency = 1, Visible = false}),
        },
        
        -- Tracer
        TracerOutline = createDrawing("Line", {Thickness = 3, Color = Color3.new(0, 0, 0), Transparency = 1, Visible = false}),
        Tracer = createDrawing("Line", {Thickness = CONFIG.EspessuraLinha, Transparency = 1, Visible = false}),
        
        -- Health Bar
        HealthBarOutline = createDrawing("Line", {Thickness = 5, Color = Color3.new(0, 0, 0), Transparency = 1, Visible = false}),
        HealthBarBackground = createDrawing("Line", {Thickness = 3, Color = Color3.new(0.2, 0.2, 0.2), Transparency = 1, Visible = false}),
        HealthBar = createDrawing("Line", {Thickness = 3, Transparency = 1, Visible = false}),
    }
    
    ESPObjects[targetPlayer] = espData
end

local function removeESP(targetPlayer)
    local espData = ESPObjects[targetPlayer]
    if not espData then return end
    
    -- Remove Box
    for _, line in ipairs(espData.BoxOutline) do 
        line.Visible = false
        line:Remove() 
    end
    for _, line in ipairs(espData.Box) do 
        line.Visible = false
        line:Remove() 
    end
    
    -- Remove Tracer
    espData.TracerOutline.Visible = false
    espData.TracerOutline:Remove()
    espData.Tracer.Visible = false
    espData.Tracer:Remove()
    
    -- Remove Health Bar
    espData.HealthBarOutline.Visible = false
    espData.HealthBarOutline:Remove()
    espData.HealthBarBackground.Visible = false
    espData.HealthBarBackground:Remove()
    espData.HealthBar.Visible = false
    espData.HealthBar:Remove()
    
    ESPObjects[targetPlayer] = nil
end

local function hideESP(espData)
    -- Esconde todos os elementos do ESP
    for _, line in ipairs(espData.BoxOutline) do 
        line.Visible = false 
    end
    for _, line in ipairs(espData.Box) do 
        line.Visible = false 
    end
    espData.TracerOutline.Visible = false
    espData.Tracer.Visible = false
    espData.HealthBarOutline.Visible = false
    espData.HealthBarBackground.Visible = false
    espData.HealthBar.Visible = false
end

local function updateESP()
    for targetPlayer, espData in pairs(ESPObjects) do
        local char = targetPlayer.Character
        local isEnemyPlayer = isEnemy(targetPlayer)
        
        -- Verifica se deve mostrar ESP baseado nos toggles
        local shouldShow = false
        if isEnemyPlayer and CONFIG.ESPEnemyLigado then
            shouldShow = true
        elseif not isEnemyPlayer and CONFIG.ESPTeamLigado then
            shouldShow = true
        end
        
        -- Se não deve mostrar, esconde tudo
        if not shouldShow then
            hideESP(espData)
        else
            -- Verifica se o personagem existe e está vivo
            if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
                local hrp = char.HumanoidRootPart
                local hum = char.Humanoid
                
                -- Se morreu, esconde
                if hum.Health <= 0 then
                    hideESP(espData)
                else
                    -- Calcula posições na tela
                    local headPos = char:FindFirstChild("Head") and char.Head.Position or hrp.Position + Vector3.new(0, 2, 0)
                    local legPos = hrp.Position - Vector3.new(0, 3, 0)
                    
                    local topScreen, topOnScreen = camera:WorldToViewportPoint(headPos + Vector3.new(0, 0.5, 0))
                    local bottomScreen, bottomOnScreen = camera:WorldToViewportPoint(legPos)
                    
                    if topOnScreen and bottomOnScreen then
                        local height = (Vector2.new(bottomScreen.X, bottomScreen.Y) - Vector2.new(topScreen.X, topScreen.Y)).Magnitude
                        local width = height / 2
                        
                        local topLeft = Vector2.new(topScreen.X - width / 2, topScreen.Y)
                        local topRight = Vector2.new(topScreen.X + width / 2, topScreen.Y)
                        local bottomLeft = Vector2.new(bottomScreen.X - width / 2, bottomScreen.Y)
                        local bottomRight = Vector2.new(bottomScreen.X + width / 2, bottomScreen.Y)
                        
                        -- Define a cor baseado no time
                        local espColor = isEnemyPlayer and CONFIG.CorEnemy or CONFIG.CorTeammate
                        
                        -- ═══════════════ BOX ═══════════════
                        if CONFIG.MostrarBoxes then
                            -- Outline (preto)
                            espData.BoxOutline[1].From = topLeft
                            espData.BoxOutline[1].To = topRight
                            espData.BoxOutline[1].Visible = true
                            
                            espData.BoxOutline[2].From = topRight
                            espData.BoxOutline[2].To = bottomRight
                            espData.BoxOutline[2].Visible = true
                            
                            espData.BoxOutline[3].From = bottomRight
                            espData.BoxOutline[3].To = bottomLeft
                            espData.BoxOutline[3].Visible = true
                            
                            espData.BoxOutline[4].From = bottomLeft
                            espData.BoxOutline[4].To = topLeft
                            espData.BoxOutline[4].Visible = true
                            
                            -- Box colorido
                            espData.Box[1].From = topLeft
                            espData.Box[1].To = topRight
                            espData.Box[1].Color = espColor
                            espData.Box[1].Visible = true
                            
                            espData.Box[2].From = topRight
                            espData.Box[2].To = bottomRight
                            espData.Box[2].Color = espColor
                            espData.Box[2].Visible = true
                            
                            espData.Box[3].From = bottomRight
                            espData.Box[3].To = bottomLeft
                            espData.Box[3].Color = espColor
                            espData.Box[3].Visible = true
                            
                            espData.Box[4].From = bottomLeft
                            espData.Box[4].To = topLeft
                            espData.Box[4].Color = espColor
                            espData.Box[4].Visible = true
                        else
                            for _, line in ipairs(espData.BoxOutline) do line.Visible = false end
                            for _, line in ipairs(espData.Box) do line.Visible = false end
                        end
                        
                        -- ═══════════════ TRACER ═══════════════
                        if CONFIG.MostrarTracers then
                            local tracerStart = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
                            local tracerEnd = Vector2.new(bottomScreen.X, bottomScreen.Y)
                            
                            espData.TracerOutline.From = tracerStart
                            espData.TracerOutline.To = tracerEnd
                            espData.TracerOutline.Visible = true
                            
                            espData.Tracer.From = tracerStart
                            espData.Tracer.To = tracerEnd
                            espData.Tracer.Color = espColor
                            espData.Tracer.Visible = true
                        else
                            espData.TracerOutline.Visible = false
                            espData.Tracer.Visible = false
                        end
                        
                        -- ═══════════════ HEALTH BAR ═══════════════
                        if CONFIG.MostrarHealth then
                            local healthPercent = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                            local barHeight = height
                            local barX = topLeft.X - 7
                            
                            local barTop = Vector2.new(barX, topLeft.Y)
                            local barBottom = Vector2.new(barX, bottomLeft.Y)
                            local barCurrent = Vector2.new(barX, topLeft.Y + (barHeight * (1 - healthPercent)))
                            
                            -- Outline
                            espData.HealthBarOutline.From = barTop
                            espData.HealthBarOutline.To = barBottom
                            espData.HealthBarOutline.Visible = true
                            
                            -- Background
                            espData.HealthBarBackground.From = barTop
                            espData.HealthBarBackground.To = barBottom
                            espData.HealthBarBackground.Visible = true
                            
                            -- Health (varia do verde ao vermelho)
                            local healthColor = Color3.new(1 - healthPercent, healthPercent, 0)
                            espData.HealthBar.From = barCurrent
                            espData.HealthBar.To = barBottom
                            espData.HealthBar.Color = healthColor
                            espData.HealthBar.Visible = true
                        else
                            espData.HealthBarOutline.Visible = false
                            espData.HealthBarBackground.Visible = false
                            espData.HealthBar.Visible = false
                        end
                    else
                        -- Player fora da tela
                        hideESP(espData)
                    end
                end
            else
                -- Personagem não existe
                hideESP(espData)
            end
        end
    end
end

-- Gerencia criação/remoção de ESP para players
Players.PlayerAdded:Connect(function(targetPlayer)
    if targetPlayer ~= player then
        createESP(targetPlayer)
    end
end)

Players.PlayerRemoving:Connect(function(targetPlayer)
    removeESP(targetPlayer)
end)

-- Cria ESP para players já no jogo
for _, targetPlayer in ipairs(Players:GetPlayers()) do
    if targetPlayer ~= player then
        createESP(targetPlayer)
    end
end

-- ═══════════════════════════════════════════════════════
-- 🔄 LOOP PRINCIPAL
-- ═══════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    -- Aimbot FOV Circle
    fovCircle.Visible = CONFIG.AimbotLigado
    
    -- Aimbot Logic
    if CONFIG.AimbotLigado then
        if UserInputService:IsMouseButtonPressed(CONFIG.Tecla) then
            local alvo = getClosestTarget()
            if alvo then
                local look = CFrame.new(camera.CFrame.Position, alvo.Position)
                camera.CFrame = camera.CFrame:Lerp(look, CONFIG.Suavidade)
            end
        end
    end
    
    -- WalkSpeed
    if CONFIG.WalkSpeedLigado and player.Character then
        local humanoid = player.Character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = CONFIG.WalkSpeedValor
        end
    end
    
    -- ESP Update
    updateESP()
end)

-- ═══════════════════════════════════════════════════════
-- 🖥️ INTERFACE RAYFIELD
-- ═══════════════════════════════════════════════════════
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Coffee Hub",
   Icon = 0,
   LoadingTitle = "Coffee Hub Loading",
   LoadingSubtitle = "by Coffee Studios",
   Theme = "Default",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = nil,
      FileName = "CoffeeHub"
   },
   KeySystem = false,
})

-- ═══════════════ TAB AIMBOT ═══════════════
local TabAimbot = Window:CreateTab("Aimbot", 4483362458) 

TabAimbot:CreateToggle({
   Name = "Aimbot (Team Check)",
   CurrentValue = false,
   Flag = "AimbotToggle", 
   Callback = function(Value)
       CONFIG.AimbotLigado = Value
   end,
})

TabAimbot:CreateButton({
   Name = "Aimbot Head",
   Callback = function()
       CONFIG.AimbotParte = "Head"
       Rayfield:Notify({
          Title = "Aimbot Target",
          Content = "Alvo alterado para: Cabeça",
          Duration = 2,
          Image = 4483362458,
       })
   end,
})

TabAimbot:CreateButton({
   Name = "Aimbot Torso",
   Callback = function()
       CONFIG.AimbotParte = "Torso"
       Rayfield:Notify({
          Title = "Aimbot Target",
          Content = "Alvo alterado para: Torso",
          Duration = 2,
          Image = 4483362458,
       })
   end,
})

TabAimbot:CreateSlider({
   Name = "FOV Radius",
   Range = {50, 500},
   Increment = 10,
   CurrentValue = 150,
   Flag = "FOVSlider",
   Callback = function(Value)
       CONFIG.RaioFOV = Value
       fovCircle.Size = UDim2.new(0, Value * 2, 0, Value * 2)
   end,
})

TabAimbot:CreateSlider({
   Name = "Smoothness",
   Range = {0.1, 1},
   Increment = 0.05,
   CurrentValue = 0.2,
   Flag = "SmoothnessSlider",
   Callback = function(Value)
       CONFIG.Suavidade = Value
   end,
})

-- ═══════════════ TAB ESP ═══════════════
local TabESP = Window:CreateTab("ESP", 4483362458)

TabESP:CreateToggle({
   Name = "ESP Enemy",
   CurrentValue = false,
   Flag = "ESPEnemyToggle", 
   Callback = function(Value)
       CONFIG.ESPEnemyLigado = Value
   end,
})

TabESP:CreateToggle({
   Name = "ESP Team",
   CurrentValue = false,
   Flag = "ESPTeamToggle", 
   Callback = function(Value)
       CONFIG.ESPTeamLigado = Value
   end,
})

TabESP:CreateToggle({
   Name = "Show Boxes",
   CurrentValue = true,
   Flag = "BoxesToggle",
   Callback = function(Value)
       CONFIG.MostrarBoxes = Value
   end,
})

TabESP:CreateToggle({
   Name = "Show Tracers",
   CurrentValue = true,
   Flag = "TracersToggle",
   Callback = function(Value)
       CONFIG.MostrarTracers = Value
   end,
})

TabESP:CreateToggle({
   Name = "Show Health Bars",
   CurrentValue = true,
   Flag = "HealthToggle",
   Callback = function(Value)
       CONFIG.MostrarHealth = Value
   end,
})

TabESP:CreateLabel("Enemy Color: Red | Teammate: Green")

-- ═══════════════ TAB CONFIGS ═══════════════
local TabConfigs = Window:CreateTab("Configs", 4483362458)

TabConfigs:CreateToggle({
   Name = "Custom WalkSpeed",
   CurrentValue = false,
   Flag = "WalkSpeedToggle",
   Callback = function(Value)
       CONFIG.WalkSpeedLigado = Value
       
       -- Restaura velocidade padrão quando desligado
       if not Value and player.Character then
           local humanoid = player.Character:FindFirstChild("Humanoid")
           if humanoid then
               humanoid.WalkSpeed = 16
           end
       end
   end,
})

TabConfigs:CreateSlider({
   Name = "WalkSpeed Value",
   Range = {16, 200},
   Increment = 1,
   CurrentValue = 16,
   Flag = "WalkSpeedSlider",
   Callback = function(Value)
       CONFIG.WalkSpeedValor = Value
   end,
})

TabConfigs:CreateLabel("Default WalkSpeed: 16")
