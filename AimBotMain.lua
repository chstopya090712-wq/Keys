-- LocalScript — вставь в StarterPlayerScripts
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Keys loading (for KeySystem)
local success, rawData = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/chstopya090712-wq/Keys/refs/heads/main/Keys.lua")
end)
local keysTable = {}
if success then
    for key in rawData:gmatch("[^\r\n]+") do
        local clean = key:gsub("%s+", "")
        if clean ~= "" then
            table.insert(keysTable, clean)
        end
    end
else
    keysTable = {"BACKUP_KEY_ERROR"}
end

local Window = Rayfield:CreateWindow({
   Name = "Admin Panel",
   Icon = 0,
   LoadingTitle = "Loading panel",
   LoadingSubtitle = "Advanced Aimbot & ESP",
   ShowText = "Rayfield",
   Theme = "Ocean",
   ToggleUIKeybind = "K",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "MyAdminPanel",
      FileName = "AimbotSettings"
   },
   KeySystem = true,
   KeySettings = {
        Title = "KeySystem",
        Subtitle = "Enter your key",
        Note = "Key can be obtained in our Discord: https://discord.gg/bKnnYTXw",
        FileName = "BB_Key_System_V1",
        SaveKey = true,
        GrabKeyFromSite = false,
        Key = keysTable
   }
})

local AimbotTab = Window:CreateTab("Aimbot", 4483362458)
local SmartAimbotTab = Window:CreateTab("Smart Aimbot", 4483362458)
local HitboxTab = Window:CreateTab("Hitboxes", 4483362458)
local ESPTab = Window:CreateTab("ESP", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

-- === Настройки Aimbot ===
local AimbotEnabled = false
local FOV = 150
local ShowFOVCircle = false
local Keybind = Enum.KeyCode.E
local AimThroughWalls = false
local TargetPartName = "Head"
local TargetPartMode = "Head" -- "Head", "Torso", "Closest" (что ближе к прицелу)
local ProjectileSpeed = 300
local AimSmoothing = 0.40
local AimShakePower = 0
local AimShakeEnabled = false
local TargetSwitchCooldownEnabled = true
local TargetSwitchCooldown = 0.25
local MaxRange = 1000
local TeamCheck = true
local LeadScaleMax = 150
local LeadPredictionEnabled = true
local PrioritizeClosest = true

-- === Smart Aimbot (auto lead/smoothing by distance, target speed, projectile speed) ===
local SmartAimbotEnabled = false
local SmartFOV = 200
local SmartProjectileSpeed = 500
local SmartTurnPredictionEnabled = true  -- account for target turn (airplanes/vehicles can't sharply turn)
local smartCurrentTarget = nil
local smartVelTable = {}

-- === Настройки ESP ===
local ESPEnabled = false
local ShowHealthBar = true
local ShowDistance = true
local ShowName = true
local ESPMaxDistance = 2000
local TeamCheckESP = true
local HighlightTeammates = false
local ESPEnemyFillColor = Color3.fromRGB(255, 0, 0)
local ESPEnemyOutlineColor = Color3.fromRGB(200, 0, 0)
local ESPTeammateFillColor = Color3.fromRGB(0, 255, 0)
local ESPTeammateOutlineColor = Color3.fromRGB(0, 200, 0)
local ESPNameColor = Color3.fromRGB(255, 255, 255)
local ESPDistanceColor = Color3.fromRGB(255, 255, 0)
local ESPHealthBarColorHigh = Color3.fromRGB(0, 255, 0)
local ESPHealthBarColorLow = Color3.fromRGB(255, 0, 0)

-- === Hitboxes (same presence check as ESP) ===
local HitboxEnabled = false
local HitboxPartsSet = { Head = true, Body = true }
local HitboxTeamCheck = true
local HitboxSize = 1.5
local HitboxTransparency = 0.6
local ShowHitboxesInESP = false  -- show hitboxes (in Hitbox tab)
local HitboxColor = Color3.fromRGB(255, 220, 0)
local hitboxObjects = {}

-- === Внутренние состояния ===
local currentTarget = nil
local lastSwitchTime = 0
local velTable = {}
local espObjects = {} -- таблица ESP объектов по игрокам
local fovCircleGui = nil -- FOV circle on screen center

-- === ESP Функции ===
local function CreateESP(player)
    local character = player.Character
    if not character then return end
    
    -- Если ESP уже есть — проверяем, тот ли это персонаж (респавн)
    local espData = espObjects[player]
    if espData then
        if espData.highlight and espData.highlight.Parent == character then
            return -- ESP уже на актуальном персонаже
        end
        RemoveESP(player) -- Старый персонаж — удаляем и создаём заново
    end
    
    local espData = {
        player = player,
        highlight = nil,
        billboard = nil,
        connection = nil
    }
    
    -- Создаём Highlight
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight"
    highlight.Adornee = character
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    if TeamCheckESP and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
        if HighlightTeammates then
            highlight.FillColor = ESPTeammateFillColor
            highlight.OutlineColor = ESPTeammateOutlineColor
        else
            highlight:Destroy()
            return
        end
    else
        highlight.FillColor = ESPEnemyFillColor
        highlight.OutlineColor = ESPEnemyOutlineColor
    end
    
    highlight.Parent = character
    espData.highlight = highlight
    
    -- Создаём Billboard GUI для информации
    if ShowHealthBar or ShowDistance or ShowName then
        local head = character:FindFirstChild("Head")
        if head then
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "ESP_Billboard"
            billboard.Adornee = head
            billboard.Size = UDim2.new(0, 200, 0, 80)
            billboard.StudsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = true
            billboard.Parent = head
            
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1, 0, 1, 0)
            frame.BackgroundTransparency = 1
            frame.Parent = billboard
            
            local yOffset = 0
            
            -- Имя игрока
            if ShowName then
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Name = "NameLabel"
                nameLabel.Size = UDim2.new(1, 0, 0, 20)
                nameLabel.Position = UDim2.new(0, 0, 0, yOffset)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = player.Name
                nameLabel.TextColor3 = ESPNameColor
                nameLabel.TextStrokeTransparency = 0.5
                nameLabel.TextScaled = true
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.Parent = frame
                yOffset = yOffset + 22
            end
            
            -- Полоска здоровья
            if ShowHealthBar then
                local healthBg = Instance.new("Frame")
                healthBg.Name = "HealthBg"
                healthBg.Size = UDim2.new(0.8, 0, 0, 8)
                healthBg.Position = UDim2.new(0.1, 0, 0, yOffset)
                healthBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
                healthBg.BorderSizePixel = 0
                healthBg.Parent = frame
                
                local healthBar = Instance.new("Frame")
                healthBar.Name = "HealthBar"
                healthBar.Size = UDim2.new(1, 0, 1, 0)
                healthBar.BackgroundColor3 = ESPHealthBarColorHigh
                healthBar.BorderSizePixel = 0
                healthBar.Parent = healthBg
                
                local healthText = Instance.new("TextLabel")
                healthText.Name = "HealthText"
                healthText.Size = UDim2.new(1, 0, 1, 0)
                healthText.BackgroundTransparency = 1
                healthText.Text = "100"
                healthText.TextColor3 = Color3.new(1, 1, 1)
                healthText.TextStrokeTransparency = 0.5
                healthText.TextScaled = true
                healthText.Font = Enum.Font.GothamBold
                healthText.Parent = healthBg
                
                yOffset = yOffset + 12
            end
            
            -- Дистанция
            if ShowDistance then
                local distLabel = Instance.new("TextLabel")
                distLabel.Name = "DistLabel"
                distLabel.Size = UDim2.new(1, 0, 0, 20)
                distLabel.Position = UDim2.new(0, 0, 0, yOffset)
                distLabel.BackgroundTransparency = 1
                distLabel.Text = "0m"
                distLabel.TextColor3 = ESPDistanceColor
                distLabel.TextStrokeTransparency = 0.5
                distLabel.TextScaled = true
                distLabel.Font = Enum.Font.Gotham
                distLabel.Parent = frame
            end
            
            espData.billboard = billboard
        end
    end
    
    espObjects[player] = espData
end

local function UpdateESP()
    if not ESPEnabled then return end
    
    for player, espData in pairs(espObjects) do
        if not player.Character or not espData.highlight or not espData.highlight.Parent then
            -- Удаляем если персонаж исчез
            if espData.highlight then espData.highlight:Destroy() end
            if espData.billboard then espData.billboard:Destroy() end
            espObjects[player] = nil
        else
            -- Проверяем дистанцию
            local char = player.Character
            local rootPart = char:FindFirstChild("HumanoidRootPart")
            if rootPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local dist = (rootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                
                if dist > ESPMaxDistance then
                    espData.highlight.Enabled = false
                    if espData.billboard then espData.billboard.Enabled = false end
                else
                    espData.highlight.Enabled = true
                    if espData.billboard then espData.billboard.Enabled = true end
                    
                    -- Обновляем информацию
                    if espData.billboard then
                        local humanoid = char:FindFirstChildOfClass("Humanoid")
                        if humanoid and ShowHealthBar then
                            local healthBar = espData.billboard:FindFirstChild("HealthBar", true)
                            local healthText = espData.billboard:FindFirstChild("HealthText", true)
                            if healthBar and healthText then
                                local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                                healthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
                                healthText.Text = tostring(math.floor(humanoid.Health))
                                
                                healthBar.BackgroundColor3 = ESPHealthBarColorHigh:Lerp(ESPHealthBarColorLow, 1 - healthPercent)
                            end
                        end
                        
                        if ShowDistance then
                            local distLabel = espData.billboard:FindFirstChild("DistLabel", true)
                            if distLabel then
                                distLabel.Text = string.format("%.0fm", dist)
                            end
                        end
                    end
                end
            end
        end
    end
end

local function RemoveESP(player)
    local espData = espObjects[player]
    if espData then
        if espData.highlight then espData.highlight:Destroy() end
        if espData.billboard then espData.billboard:Destroy() end
        espObjects[player] = nil
    end
end

local function RemoveAllESP()
    for player, espData in pairs(espObjects) do
        if espData.highlight then espData.highlight:Destroy() end
        if espData.billboard then espData.billboard:Destroy() end
    end
    espObjects = {}
end

local function RefreshESP()
    RemoveAllESP()
    if ESPEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                CreateESP(player)
            end
        end
    end
end

-- === Hitbox functions (same presence as ESP) ===
local function shouldHaveHitbox(player)
    if not player or player == LocalPlayer then return false end
    if not player.Character then return false end
    if HitboxTeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then return false end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    if (root.Position - Camera.CFrame.Position).Magnitude > ESPMaxDistance then return false end
    return true
end

local function getHitboxParts(character)
    local list = {}
    if HitboxPartsSet.Head then
        local head = character:FindFirstChild("Head")
        if head then table.insert(list, head) end
    end
    if HitboxPartsSet.Body then
        local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
        if torso then table.insert(list, torso) end
    end
    return list
end

local function RemoveHitbox(player)
    local data = hitboxObjects[player]
    if data then
        for _, p in pairs(data.parts or {}) do
            if p and p.Parent then p:Destroy() end
        end
        hitboxObjects[player] = nil
    end
end

local function CreateHitbox(player)
    local character = player.Character
    if not character then return end
    if not HitboxEnabled then return end

    local data = hitboxObjects[player]
    if data then
        RemoveHitbox(player)
    end

    if not shouldHaveHitbox(player) then return end

    local partsToAdorn = getHitboxParts(character)
    if #partsToAdorn == 0 then return end

    local created = {}
    for _, basePart in ipairs(partsToAdorn) do
        local box = Instance.new("Part")
        box.Name = "Hitbox_" .. basePart.Name
        box.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
        box.CFrame = basePart.CFrame
        box.Anchored = false
        box.CanCollide = false
        box.Transparency = ShowHitboxesInESP and HitboxTransparency or 1
        box.Color = HitboxColor
        box.Material = Enum.Material.ForceField
        box.Parent = basePart
        local w = Instance.new("WeldConstraint")
        w.Part0 = basePart
        w.Part1 = box
        w.Parent = box
        table.insert(created, box)
    end
    hitboxObjects[player] = { parts = created }
end

local function RefreshHitboxes()
    for player, _ in pairs(hitboxObjects) do
        RemoveHitbox(player)
    end
    if HitboxEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and shouldHaveHitbox(player) then
                CreateHitbox(player)
            end
        end
    end
end

local function UpdateHitboxVisibility()
    for _, data in pairs(hitboxObjects) do
        for _, box in pairs(data.parts or {}) do
            if box and box.Parent then
                box.Transparency = ShowHitboxesInESP and HitboxTransparency or 1
                box.Size = Vector3.new(HitboxSize, HitboxSize, HitboxSize)
                box.Color = HitboxColor
            end
        end
    end
end

-- === Aimbot Функции ===
local function IsVisible(targetPart)
    if AimThroughWalls then
        return true
    end

    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    params.FilterType = Enum.RaycastFilterType.Blacklist

    local result = workspace:Raycast(origin, direction, params)
    if result then
        return result.Instance:IsDescendantOf(targetPart.Parent)
    end
    return true
end

local function SolveInterceptTime(shooterPos, targetPos, targetVel, projectileSpeed)
    local toTarget = targetPos - shooterPos
    local a = targetVel:Dot(targetVel) - projectileSpeed * projectileSpeed
    local b = 2 * targetVel:Dot(toTarget)
    local c = toTarget:Dot(toTarget)

    if math.abs(a) < 1e-6 then
        if math.abs(b) < 1e-6 then return nil end
        local t = -c / b
        if t > 0 then return t end
        return nil
    end

    local disc = b * b - 4 * a * c
    if disc < 0 then return nil end

    local sqrtD = math.sqrt(disc)
    local t1 = (-b + sqrtD) / (2 * a)
    local t2 = (-b - sqrtD) / (2 * a)

    local candidates = {}
    if t1 > 0 then table.insert(candidates, t1) end
    if t2 > 0 then table.insert(candidates, t2) end
    if #candidates == 0 then return nil end
    table.sort(candidates)
    return candidates[1]
end

local function PredictPosition(part)
    local shooterPos = Camera.CFrame.Position
    local targetPos = part.Position

    local root = part.Parent and (part.Parent:FindFirstChild("HumanoidRootPart") or part.Parent:FindFirstChild("UpperTorso"))
    local rawVel = Vector3.new(0,0,0)
    if root and root:IsA("BasePart") then
        rawVel = root.AssemblyLinearVelocity or root.Velocity or Vector3.new(0,0,0)
    else
        if part:IsA("BasePart") then
            rawVel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0,0,0)
        end
    end

    local player = Players:GetPlayerFromCharacter(part.Parent)
    local key = player and tostring(player.UserId) or tostring(part:GetDebugId())
    local prev = velTable[key] or rawVel
    local smoothed = prev:Lerp(rawVel, 0.4)
    velTable[key] = smoothed

    local t = nil
    if ProjectileSpeed > 0 then
        t = SolveInterceptTime(shooterPos, targetPos, smoothed, ProjectileSpeed)
    end
    if not t then
        local dist = (targetPos - shooterPos).Magnitude
        if ProjectileSpeed > 0 then
            t = dist / ProjectileSpeed
        else
            t = 0
        end
    end

    local distNow = (targetPos - shooterPos).Magnitude
    if not LeadPredictionEnabled then
        return targetPos, 0, distNow
    end
    local norm = 0
    if MaxRange > 0 then
        norm = math.clamp(distNow / MaxRange, 0, 1)
    end
    local scaleAtMax = math.max(LeadScaleMax / 100, 0)
    local leadScale = 1 + (scaleAtMax - 1) * norm

    return targetPos + smoothed * t * leadScale, t, distNow
end

local function GetTargetPart(player)
    if TargetPartMode == "Closest" then
        local head = player.Character:FindFirstChild("Head")
        local torso = player.Character:FindFirstChild("UpperTorso") or player.Character:FindFirstChild("HumanoidRootPart") or player.Character:FindFirstChild("Torso")
        local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        local headDist, torsoDist = math.huge, math.huge
        if head then
            local pos = Camera:WorldToViewportPoint(head.Position)
            headDist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
        end
        if torso then
            local pos = Camera:WorldToViewportPoint(torso.Position)
            torsoDist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
        end
        if headDist <= torsoDist and head then return head end
        if torso then return torso end
        return player.Character:FindFirstChild("HumanoidRootPart")
    elseif TargetPartMode == "Head" then
        return player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
    else
        return player.Character:FindFirstChild(TargetPartName) or player.Character:FindFirstChild("HumanoidRootPart")
    end
end

local function PlayerIsValid(player)
    if not player or not player.Character then return false end
    if TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
        return false
    end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    local part = GetTargetPart(player)
    if not part then return false end
    
    local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
    if not onScreen then return false end
    
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local dist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
    if dist > FOV then return false end
    
    local worldDist = (part.Position - Camera.CFrame.Position).Magnitude
    if worldDist > MaxRange then return false end
    if not IsVisible(part) then return false end
    return true
end

-- УЛУЧШЕНО: Приоритизация по реальной 3D дистанции, а не по экранной
local function GetClosestPlayer()
    local best = nil
    local bestDist = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local part = GetTargetPart(player)
            if part then
                if TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
                    -- Пропускаем тиммейтов
                else
                    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        if onScreen then
                        local screenDist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                        local worldDist = (part.Position - Camera.CFrame.Position).Magnitude
                        
                        if screenDist <= FOV and worldDist <= MaxRange and IsVisible(part) then
                            -- Выбираем по 3D дистанции или экранной в зависимости от настройки
                            local dist = PrioritizeClosest and worldDist or screenDist
                            
                            if dist < bestDist then
                                bestDist = dist
                                best = player
                            end
                        end
                        end
                    end
                end
            end
        end
    end

    if best then
        return best, bestDist
    end
    return nil, nil
end

-- Rotate vector V around axis K (unit) by angle theta (radians) - Rodrigues' formula
local function RotateVector(v, axis, theta)
    if axis.Magnitude < 1e-6 or math.abs(theta) < 1e-6 then return v end
    local k = axis.Unit
    local cosT = math.cos(theta)
    local sinT = math.sin(theta)
    return v * cosT + (k:Cross(v)) * sinT + k * (k:Dot(v)) * (1 - cosT)
end

-- === Smart Aimbot: exact intercept, auto lead/smoothing, turn prediction for vehicles/airplanes ===
local function PredictPositionSmart(part, projSpeed)
    local shooterPos = Camera.CFrame.Position
    local targetPos = part.Position

    local root = part.Parent and (part.Parent:FindFirstChild("HumanoidRootPart") or part.Parent:FindFirstChild("UpperTorso"))
    local rawVel = Vector3.new(0,0,0)
    local angVel = Vector3.new(0,0,0)
    if root and root:IsA("BasePart") then
        rawVel = root.AssemblyLinearVelocity or root.Velocity or Vector3.new(0,0,0)
        angVel = root.AssemblyAngularVelocity or Vector3.new(0,0,0)
    elseif part:IsA("BasePart") then
        rawVel = part.AssemblyLinearVelocity or part.Velocity or Vector3.new(0,0,0)
        angVel = part.AssemblyAngularVelocity or Vector3.new(0,0,0)
    end

    local player = Players:GetPlayerFromCharacter(part.Parent)
    local key = player and tostring(player.UserId) or tostring(part:GetDebugId())
    local prev = smartVelTable[key] or rawVel
    local smoothed = prev:Lerp(rawVel, 0.5)
    smartVelTable[key] = smoothed

    local t = nil
    if projSpeed > 0 then
        t = SolveInterceptTime(shooterPos, targetPos, smoothed, projSpeed)
    end
    if not t then
        local dist = (targetPos - shooterPos).Magnitude
        t = projSpeed > 0 and (dist / projSpeed) or 0
    end

    -- Turn prediction: vehicles/airplanes can't sharply turn - extrapolate angular velocity
    local velToUse = smoothed
    if SmartTurnPredictionEnabled and angVel.Magnitude > 0.15 then
        local turnAngle = math.clamp(angVel.Magnitude * t, 0, math.rad(120))
        local velAtT = RotateVector(smoothed, angVel, turnAngle)
        velToUse = (smoothed + velAtT) * 0.5
    end

    return targetPos + velToUse * t, t, (targetPos - shooterPos).Magnitude
end

local function PlayerIsValidSmart(player, fov)
    if not player or not player.Character then return false end
    if TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then return false end
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    local part = GetTargetPart(player)
    if not part then return false end

    local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
    if not onScreen then return false end

    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    if (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude > fov then return false end

    local worldDist = (part.Position - Camera.CFrame.Position).Magnitude
    if worldDist > MaxRange then return false end
    if not IsVisible(part) then return false end
    return true
end

local function GetClosestPlayerSmart(fov)
    local best, bestDist = nil, math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then
        elseif not player.Character then
        else
            local part = GetTargetPart(player)
            if part and not (TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team) then
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local screenDist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                        local worldDist = (part.Position - Camera.CFrame.Position).Magnitude
                        if screenDist <= fov and worldDist <= MaxRange and IsVisible(part) then
                            local dist = PrioritizeClosest and worldDist or screenDist
                            if dist < bestDist then
                                bestDist = dist
                                best = player
                            end
                        end
                    end
                end
            end
        end
    end
    return best, bestDist
end

-- Auto smoothing: faster when target far/fast, smoother when close/slow
local function GetAutoSmoothing(dist, targetSpeed, projSpeed)
    local distNorm = math.clamp(dist / 2000, 0, 1)
    local speedNorm = math.clamp(targetSpeed / 80, 0, 1)
    local projNorm = projSpeed > 0 and math.clamp(500 / projSpeed, 0, 1) or 0
    -- Low smoothing = fast snap (0.1-0.2), high = smooth (0.5-0.6)
    local base = 0.55
    local reduction = distNorm * 0.25 + speedNorm * 0.2 + projNorm * 0.15
    return math.clamp(base - reduction, 0.12, 0.65)
end

-- === FOV circle (radius of aimbot in center of screen) ===
local function updateFOVCircle()
    if not ShowFOVCircle then
        if fovCircleGui then
            fovCircleGui:Destroy()
            fovCircleGui = nil
        end
        return
    end
    if not fovCircleGui or not fovCircleGui.Parent then
        local gui = Instance.new("ScreenGui")
        gui.Name = "AimbotFOVCircle"
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = game:GetService("CoreGui")
        local frame = Instance.new("Frame")
        frame.Name = "FOVCircle"
        frame.BackgroundTransparency = 1
        frame.BorderSizePixel = 0
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.Parent = gui
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(0, 200, 255)
        stroke.Thickness = 2
        stroke.Transparency = 0.3
        stroke.Parent = frame
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = frame
        fovCircleGui = gui
    end
    local circle = fovCircleGui:FindFirstChild("FOVCircle")
    if circle then
        local r = math.max(10, SmartAimbotEnabled and SmartFOV or FOV)
        circle.Size = UDim2.new(0, r * 2, 0, r * 2)
        circle.Position = UDim2.new(0.5, 0, 0.5, 0)
    end
end

-- === Основной цикл ===
RunService.RenderStepped:Connect(function()
    -- FOV circle (shows active aimbot's FOV: SmartFOV when Smart on, else FOV)
    if ShowFOVCircle then updateFOVCircle() end
    -- ESP обновление
    UpdateESP()
    
    -- Smart Aimbot (priority over main aimbot)
    if SmartAimbotEnabled then
        if smartCurrentTarget == nil or not PlayerIsValidSmart(smartCurrentTarget, SmartFOV) then
            local candidate, _ = GetClosestPlayerSmart(SmartFOV)
            smartCurrentTarget = candidate
        else
            local candidate, _ = GetClosestPlayerSmart(SmartFOV)
            if candidate and candidate ~= smartCurrentTarget then
                smartCurrentTarget = candidate
            end
        end

        if smartCurrentTarget and PlayerIsValidSmart(smartCurrentTarget, SmartFOV) then
            local part = GetTargetPart(smartCurrentTarget)
            if part then
                local root = part.Parent and (part.Parent:FindFirstChild("HumanoidRootPart") or part.Parent:FindFirstChild("UpperTorso"))
                local targetSpeed = 0
                if root and root:IsA("BasePart") then
                    targetSpeed = (root.AssemblyLinearVelocity or root.Velocity or Vector3.zero).Magnitude
                end

                local aimPos, t, distNow = PredictPositionSmart(part, SmartProjectileSpeed)
                if not SmartTurnPredictionEnabled then
                    local floorY = root and root.Position.Y - 1.5 or part.Position.Y - 0.5
                    if aimPos.Y < floorY then
                        aimPos = Vector3.new(aimPos.X, floorY, aimPos.Z)
                    end
                end
                local autoSmooth = GetAutoSmoothing(distNow, targetSpeed, SmartProjectileSpeed)
                local targetCFrame = CFrame.new(Camera.CFrame.Position, aimPos)
                Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, math.clamp(autoSmooth, 0, 1))
            end
        end
        return
    end

    -- Main Aimbot
    if not AimbotEnabled then return end

    if currentTarget == nil or not PlayerIsValid(currentTarget) then
        local candidate, d = GetClosestPlayer()
        if candidate then
            currentTarget = candidate
            lastSwitchTime = tick()
        else
            currentTarget = nil
        end
    else
        local candidate, candDist = GetClosestPlayer()
        if candidate and candidate ~= currentTarget then
            local cooldown = TargetSwitchCooldownEnabled and TargetSwitchCooldown or 0
            if tick() - lastSwitchTime >= cooldown then
                currentTarget = candidate
                lastSwitchTime = tick()
            end
        end
    end

    if currentTarget and PlayerIsValid(currentTarget) then
        local part = GetTargetPart(currentTarget)
        if part then
            local aimPos, t, distNow = PredictPosition(part)
            local root = part.Parent and (part.Parent:FindFirstChild("HumanoidRootPart") or part.Parent:FindFirstChild("UpperTorso"))
            local floorY = root and root.Position.Y - 1.5 or part.Position.Y - 0.5
            if aimPos.Y < floorY then
                aimPos = Vector3.new(aimPos.X, floorY, aimPos.Z)
            end
            local dirToTarget = (aimPos - Camera.CFrame.Position).Unit
            local alignment = math.max(0, Camera.CFrame.LookVector:Dot(dirToTarget))
            local targetCFrame = CFrame.new(Camera.CFrame.Position, aimPos)
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, math.clamp(AimSmoothing, 0, 1))
            if AimShakeEnabled and AimShakePower > 0 and alignment < 0.95 then
                local shakeMult = 1 - alignment
                local rad = (AimShakePower * 0.006) * shakeMult
                local shakeX = (math.random() - 0.5) * 2 * rad
                local shakeY = (math.random() - 0.5) * 2 * rad
                Camera.CFrame = Camera.CFrame * CFrame.Angles(shakeY, shakeX, 0)
            end
        end
    end
end)

-- === Автообновление ESP и Hitboxes (проверка каждую секунду, та же логика наличия) ===
task.spawn(function()
    while true do
        task.wait(1)
        if ESPEnabled then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    CreateESP(player)
                end
            end
        end
        if HitboxEnabled then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and shouldHaveHitbox(player) then
                    CreateHitbox(player)
                end
            end
        end
    end
end)

-- === События игроков ===
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        task.wait(0.5)
        if ESPEnabled and player ~= LocalPlayer then
            CreateESP(player)
        end
        if HitboxEnabled and player ~= LocalPlayer and shouldHaveHitbox(player) then
            CreateHitbox(player)
        end
    end)
end)

-- Очистка ESP и Hitbox при смерти/респавне
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.CharacterRemoving:Connect(function()
            RemoveESP(player)
            RemoveHitbox(player)
        end)
    end
end
Players.PlayerAdded:Connect(function(player)
    player.CharacterRemoving:Connect(function()
        RemoveESP(player)
        RemoveHitbox(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
    RemoveHitbox(player)
end)

-- === Кнопка активации ===
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Keybind then
        AimbotEnabled = not AimbotEnabled
        Rayfield:Notify({
            Title = "Aimbot",
            Content = AimbotEnabled and "Aimbot enabled" or "Aimbot disabled",
            Duration = 2
        })
    end
end)

-- === UI Aimbot ===
local Toggle = AimbotTab:CreateToggle({
   Name = "Aimbot",
   CurrentValue = AimbotEnabled,
   Flag = "AimbotToggle",
   Callback = function(Value)
      AimbotEnabled = Value
   end,
})

local PriorityToggle = AimbotTab:CreateToggle({
   Name = "Prioritize closest target (3D distance)",
   CurrentValue = PrioritizeClosest,
   Flag = "PriorityToggle",
   Callback = function(Value)
      PrioritizeClosest = Value
   end,
})

local FOVCircleToggle = AimbotTab:CreateToggle({
   Name = "Show FOV circle (aimbot radius)",
   CurrentValue = ShowFOVCircle,
   Flag = "ShowFOVCircle",
   Callback = function(Value)
      ShowFOVCircle = Value
      updateFOVCircle()
   end,
})

local Slider = AimbotTab:CreateSlider({
   Name = "Capture radius (FOV)",
   Range = {50, 500},
   Increment = 10,
   Suffix = "px",
   CurrentValue = FOV,
   Flag = "FOVSlider",
   Callback = function(Value)
      FOV = Value
   end,
})

local SpeedSlider = AimbotTab:CreateSlider({
   Name = "Projectile speed (stud/s)",
   Range = {50, 2000},
   Increment = 10,
   Suffix = "stud/s",
   CurrentValue = ProjectileSpeed,
   Flag = "ProjectileSpeed",
   Callback = function(Value)
      ProjectileSpeed = Value
   end,
})

local MaxRangeSlider = AimbotTab:CreateSlider({
   Name = "Max target distance (stud)",
   Range = {50, 5000},
   Increment = 25,
   Suffix = "stud",
   CurrentValue = MaxRange,
   Flag = "MaxRange",
   Callback = function(Value)
      MaxRange = Value
   end,
})

local LeadPredictionToggle = AimbotTab:CreateToggle({
   Name = "Lead prediction",
   CurrentValue = LeadPredictionEnabled,
   Flag = "LeadPredictionEnabled",
   Callback = function(Value)
      LeadPredictionEnabled = Value
   end,
})

local LeadScaleSlider = AimbotTab:CreateSlider({
   Name = "Lead scale at max distance (%)",
   Range = {50, 300},
   Increment = 5,
   Suffix = "%",
   CurrentValue = LeadScaleMax,
   Flag = "LeadScaleMax",
   Callback = function(Value)
      LeadScaleMax = Value
   end,
})

local SmoothSlider = AimbotTab:CreateSlider({
   Name = "Aim smoothing",
   Range = {0, 100},
   Increment = 1,
   Suffix = "%",
   CurrentValue = math.floor(AimSmoothing * 100),
   Flag = "AimSmooth",
   Callback = function(Value)
      AimSmoothing = math.clamp(Value / 100, 0, 1)
   end,
})

local ShakeToggle = AimbotTab:CreateToggle({
   Name = "Aim shake (while moving to target)",
   CurrentValue = AimShakeEnabled,
   Flag = "AimShakeEnabled",
   Callback = function(Value)
      AimShakeEnabled = Value
   end,
})

local ShakeSlider = AimbotTab:CreateSlider({
   Name = "Aim shake strength",
   Range = {0, 50},
   Increment = 1,
   Suffix = "",
   CurrentValue = AimShakePower,
   Flag = "AimShakePower",
   Callback = function(Value)
      AimShakePower = Value
   end,
})

local SwitchCooldownToggle = AimbotTab:CreateToggle({
   Name = "Target switch delay",
   CurrentValue = TargetSwitchCooldownEnabled,
   Flag = "TargetSwitchCooldownEnabled",
   Callback = function(Value)
      TargetSwitchCooldownEnabled = Value
   end,
})

local SwitchSlider = AimbotTab:CreateSlider({
   Name = "Target switch delay (ms)",
   Range = {0, 1000},
   Increment = 25,
   Suffix = "ms",
   CurrentValue = math.floor(TargetSwitchCooldown * 1000),
   Flag = "TargetSwitchCooldown",
   Callback = function(Value)
      TargetSwitchCooldown = math.clamp(Value / 1000, 0, 2)
   end,
})

local WallToggle = AimbotTab:CreateToggle({
   Name = "Aim through walls",
   CurrentValue = AimThroughWalls,
   Flag = "WallToggle",
   Callback = function(Value)
      AimThroughWalls = Value
   end,
})

local TeamToggle = AimbotTab:CreateToggle({
   Name = "Ignore teammates",
   CurrentValue = TeamCheck,
   Flag = "TeamToggle",
   Callback = function(Value)
      TeamCheck = Value
   end,
})

local KeyPicker = AimbotTab:CreateKeybind({
   Name = "Activation key",
   CurrentKeybind = "E",
   HoldToInteract = false,
   Flag = "AimbotKey",
   Callback = function(Key)
      if typeof(Key) == "string" then
         local upper = string.upper(Key)
         if Enum.KeyCode[upper] then
            Keybind = Enum.KeyCode[upper]
         end
      elseif typeof(Key) == "EnumItem" then
         Keybind = Key
      else
         pcall(function() Keybind = Enum.KeyCode[Key] end)
      end
   end,
})

local Dropdown = AimbotTab:CreateDropdown({
   Name = "Aim target",
   Options = {"Head", "Torso", "Head/Torso (closest to crosshair)"},
   CurrentOption = {TargetPartMode == "Closest" and "Head/Torso (closest to crosshair)" or TargetPartMode},
   MultipleOptions = false,
   Flag = "TargetPartDropdown",
   Callback = function(Options)
      local choice = Options[1]
      if choice == "Head" then
         TargetPartMode = "Head"
         TargetPartName = "Head"
      elseif choice == "Torso" then
         TargetPartMode = "Torso"
         if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("UpperTorso") then
            TargetPartName = "UpperTorso"
         elseif LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            TargetPartName = "HumanoidRootPart"
         else
            TargetPartName = "Torso"
         end
      elseif choice == "Head/Torso (closest to crosshair)" then
         TargetPartMode = "Closest"
      end
   end,
})

-- === UI Smart Aimbot (auto lead/smoothing by distance, target speed, projectile speed) ===
local SmartAimbotToggle = SmartAimbotTab:CreateToggle({
   Name = "Smart Aimbot",
   CurrentValue = SmartAimbotEnabled,
   Flag = "SmartAimbotToggle",
   Callback = function(Value)
      SmartAimbotEnabled = Value
   end,
})

local SmartFOVSlider = SmartAimbotTab:CreateSlider({
   Name = "Capture radius (FOV)",
   Range = {50, 500},
   Increment = 10,
   Suffix = "px",
   CurrentValue = SmartFOV,
   Flag = "SmartFOV",
   Callback = function(Value)
      SmartFOV = Value
   end,
})

local SmartProjectileSpeedSlider = SmartAimbotTab:CreateSlider({
   Name = "Projectile speed (stud/s)",
   Range = {50, 2000},
   Increment = 10,
   Suffix = "stud/s",
   CurrentValue = SmartProjectileSpeed,
   Flag = "SmartProjectileSpeed",
   Callback = function(Value)
      SmartProjectileSpeed = Value
   end,
})

local SmartTurnPredictionToggle = SmartAimbotTab:CreateToggle({
   Name = "Turn prediction (airplanes/vehicles)",
   CurrentValue = SmartTurnPredictionEnabled,
   Flag = "SmartTurnPredictionEnabled",
   Callback = function(Value)
      SmartTurnPredictionEnabled = Value
   end,
})

-- === UI Hitboxes (same presence as ESP) ===
local HitboxToggle = HitboxTab:CreateToggle({
   Name = "Enable hitboxes",
   CurrentValue = HitboxEnabled,
   Flag = "HitboxEnabled",
   Callback = function(Value)
      HitboxEnabled = Value
      RefreshHitboxes()
   end,
})

local HitboxDropdown = HitboxTab:CreateDropdown({
   Name = "Hitbox parts",
   Options = {"Head", "Body"},
   CurrentOption = {"Head", "Body"},
   MultipleOptions = true,
   Flag = "HitboxParts",
   Callback = function(Options)
      HitboxPartsSet.Head = false
      HitboxPartsSet.Body = false
      for _, opt in ipairs(Options) do
         if opt == "Head" then HitboxPartsSet.Head = true
         elseif opt == "Body" then HitboxPartsSet.Body = true
         end
      end
      RefreshHitboxes()
   end,
})

HitboxTab:CreateToggle({
   Name = "Team check (no hitboxes for teammates)",
   CurrentValue = HitboxTeamCheck,
   Flag = "HitboxTeamCheck",
   Callback = function(Value)
      HitboxTeamCheck = Value
      RefreshHitboxes()
   end,
})

HitboxTab:CreateSlider({
   Name = "Hitbox size",
   Range = {0.5, 20},
   Increment = 0.5,
   Suffix = " stud",
   CurrentValue = HitboxSize,
   Flag = "HitboxSize",
   Callback = function(Value)
      HitboxSize = Value
      UpdateHitboxVisibility()
   end,
})

HitboxTab:CreateSlider({
   Name = "Hitbox transparency",
   Range = {0, 100},
   Increment = 5,
   Suffix = "%",
   CurrentValue = math.floor(HitboxTransparency * 100),
   Flag = "HitboxTransparency",
   Callback = function(Value)
      HitboxTransparency = math.clamp(Value / 100, 0, 1)
      UpdateHitboxVisibility()
   end,
})

HitboxTab:CreateToggle({
   Name = "Show hitboxes",
   CurrentValue = ShowHitboxesInESP,
   Flag = "ShowHitboxesInESP",
   Callback = function(Value)
      ShowHitboxesInESP = Value
      UpdateHitboxVisibility()
   end,
})

HitboxTab:CreateColorPicker({
   Name = "Hitbox color",
   Color = HitboxColor,
   Flag = "HitboxColor",
   Callback = function(Value)
      HitboxColor = Value
      UpdateHitboxVisibility()
   end,
})

-- === UI ESP ===
local ESPToggle = ESPTab:CreateToggle({
   Name = "Enable ESP",
   CurrentValue = ESPEnabled,
   Flag = "ESPToggle",
   Callback = function(Value)
      ESPEnabled = Value
      if Value then
         RefreshESP()
      else
         RemoveAllESP()
      end
   end,
})

local HealthBarToggle = ESPTab:CreateToggle({
   Name = "Show health bar",
   CurrentValue = ShowHealthBar,
   Flag = "HealthBarToggle",
   Callback = function(Value)
      ShowHealthBar = Value
      RefreshESP()
   end,
})

local DistanceToggle = ESPTab:CreateToggle({
   Name = "Show distance",
   CurrentValue = ShowDistance,
   Flag = "DistanceToggle",
   Callback = function(Value)
      ShowDistance = Value
      RefreshESP()
   end,
})

local NameToggle = ESPTab:CreateToggle({
   Name = "Show name",
   CurrentValue = ShowName,
   Flag = "NameToggle",
   Callback = function(Value)
      ShowName = Value
      RefreshESP()
   end,
})

local ESPDistSlider = ESPTab:CreateSlider({
   Name = "Max ESP distance (stud)",
   Range = {100, 5000},
   Increment = 50,
   Suffix = "stud",
   CurrentValue = ESPMaxDistance,
   Flag = "ESPMaxDist",
   Callback = function(Value)
      ESPMaxDistance = Value
   end,
})

local TeamESPToggle = ESPTab:CreateToggle({
   Name = "Team check",
   CurrentValue = TeamCheckESP,
   Flag = "TeamESPToggle",
   Callback = function(Value)
      TeamCheckESP = Value
      RefreshESP()
   end,
})

local TeammatesESPToggle = ESPTab:CreateToggle({
   Name = "Highlight teammates",
   CurrentValue = HighlightTeammates,
   Flag = "TeammatesESPToggle",
   Callback = function(Value)
      HighlightTeammates = Value
      RefreshESP()
   end,
})

ESPTab:CreateColorPicker({
   Name = "Enemy fill color",
   Color = ESPEnemyFillColor,
   Flag = "ESPEnemyFillColor",
   Callback = function(Value)
      ESPEnemyFillColor = Value
      RefreshESP()
   end,
})

ESPTab:CreateColorPicker({
   Name = "Enemy outline color",
   Color = ESPEnemyOutlineColor,
   Flag = "ESPEnemyOutlineColor",
   Callback = function(Value)
      ESPEnemyOutlineColor = Value
      RefreshESP()
   end,
})

ESPTab:CreateColorPicker({
   Name = "Teammate fill color",
   Color = ESPTeammateFillColor,
   Flag = "ESPTeammateFillColor",
   Callback = function(Value)
      ESPTeammateFillColor = Value
      RefreshESP()
   end,
})

ESPTab:CreateColorPicker({
   Name = "Teammate outline color",
   Color = ESPTeammateOutlineColor,
   Flag = "ESPTeammateOutlineColor",
   Callback = function(Value)
      ESPTeammateOutlineColor = Value
      RefreshESP()
   end,
})

ESPTab:CreateColorPicker({
   Name = "Name color",
   Color = ESPNameColor,
   Flag = "ESPNameColor",
   Callback = function(Value)
      ESPNameColor = Value
      RefreshESP()
   end,
})

ESPTab:CreateColorPicker({
   Name = "Distance color",
   Color = ESPDistanceColor,
   Flag = "ESPDistanceColor",
   Callback = function(Value)
      ESPDistanceColor = Value
      RefreshESP()
   end,
})

ESPTab:CreateColorPicker({
   Name = "Health bar (high HP)",
   Color = ESPHealthBarColorHigh,
   Flag = "ESPHealthBarColorHigh",
   Callback = function(Value)
      ESPHealthBarColorHigh = Value
      RefreshESP()
   end,
})

ESPTab:CreateColorPicker({
   Name = "Health bar (low HP)",
   Color = ESPHealthBarColorLow,
   Flag = "ESPHealthBarColorLow",
   Callback = function(Value)
      ESPHealthBarColorLow = Value
      RefreshESP()
   end,
})

local RefreshButton = ESPTab:CreateButton({
   Name = "Refresh ESP",
   Callback = function()
      RefreshESP()
   end,
})

-- === UI Settings (theme, Discord) ===
local ThemeIds = {
   ["Default"] = "Default",
   ["Amber Glow"] = "AmberGlow",
   ["Amethyst"] = "Amethyst",
   ["Bloom"] = "Bloom",
   ["Dark Blue"] = "DarkBlue",
   ["Green"] = "Green",
   ["Light"] = "Light",
   ["Ocean"] = "Ocean",
   ["Serenity"] = "Serenity"
}

SettingsTab:CreateDropdown({
   Name = "Menu theme",
   Options = {"Default", "Amber Glow", "Amethyst", "Bloom", "Dark Blue", "Green", "Light", "Ocean", "Serenity"},
   CurrentOption = {"Ocean"},
   MultipleOptions = false,
   Flag = "MenuTheme",
   Callback = function(Options)
      local choice = Options[1]
      local themeId = ThemeIds[choice] or "Ocean"
      if type(Window.ModifyTheme) == "function" then
         Window:ModifyTheme(themeId)
      end
   end,
})

SettingsTab:CreateButton({
   Name = "Discord: https://discord.gg/bKnnYTXw",
   Callback = function()
      pcall(function()
         setclipboard("https://discord.gg/bKnnYTXw")
      end)
      Rayfield:Notify({
         Title = "Discord",
         Content = "Link copied to clipboard",
         Duration = 2
      })
   end,
})

-- Load saved configuration at the very end (Rayfield docs: add LoadConfiguration at the end of entire code)
task.defer(function()
   Rayfield:LoadConfiguration()
   -- Apply loaded state after config is applied
   if ESPEnabled then RefreshESP() end
   if HitboxEnabled then RefreshHitboxes() end
   if ShowFOVCircle then updateFOVCircle() end
end)
