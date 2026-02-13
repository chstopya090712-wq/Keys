local Rayfield, Window

local function loadRayfield()
	local success, err = pcall(function()
		Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield', true))()
	end)
	if not success then
		warn("Rayfield loading error:", err)
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Error",
			Text = "Failed to load Rayfield UI",
			Duration = 10
		})
		return false
	end
	return true
end

if not loadRayfield() then return end
local success, result = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/chstopya090712-wq/Keys/refs/heads/main/Keys.lua")
end)

if success then
    print("Данные с GitHub получены:")
    print(result)
else
    warn("Ошибка подключения к GitHub: " .. tostring(result))
end
local rawKey = game:HttpGet("https://raw.githubusercontent.com/chstopya090712-wq/Keys/refs/heads/main/Keys.lua")
local cleanKey = rawKey:gsub("%s+", "") 
local Window = Rayfield:CreateWindow({
    Name = "blockaded battlefront",
    LoadingTitle = "Initializing system...",
    LoadingSubtitle = "Version 1",
    ConfigurationSaving = { 
        Enabled = true, 
        FolderName = "blockaded battlefrontConfig", 
        FileName = "Settings" 
    }, 
    KeySystem = true,
    KeySettings = {
        Title = "KeySystem",
        Subtitle = "Введите ваш ключ",
        Note = "Ключ можно получить в нашем Discord/Telegram",
        FileName = "KeySystem_Working_Final", -- Сменил имя для сброса кэша
        SaveKey = true, 
        GrabKeyFromSite = false, -- Мы уже скачали его сами строкой выше
        Key = {cleanKey} -- Подставляем чистый ключ
    }
})

-- Main services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

-- Create invisible part on load
local function createInvisiblePart()
	local part = Instance.new("Part")
	part.Name = "InvisiblePart"
	part.Size = Vector3.new(1300.4530029296875, 0.05900000408291817, 1300.70703125)
	part.CFrame = CFrame.new(-19.9382629, 0.184179679, -2.24523926, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Parent = Workspace
end

createInvisiblePart()

-- Stats and settings
local Stats = {
	TotalAttacks = 0,
	Active = false,
	CurrentTarget = nil,
	LastAction = "Ready",
	AttackCooldown = 0,
	Invincible = false,
	AttackSpeed = 0.1,
	MoveSpeed = 50,
	NoTargetTime = 0,
	CurrentMode = "zombie",
	MaxHpLimit = 300,
	AutoHealEnabled = false,
	HealPart = nil,
	LowHpThreshold = 50,
	AutoBuyHealth = false,
	AutoTeleportToShop = false,
	RadiantEventName = "",
	AutoVoteEnabled = false,
	VoteMode = "Normal",
	TargetPriority = "LowestHP",
	AttackHeight = 6,
	ShopActionDelay = 1,
	CircularFlightEnabled = false,
	CircularFlightSpeed = 60
}

-- Global variable for auto-heal state
local AutoHealState = { WasEnabled = false }

-- Circular flight system
local CircularFlight = {
	Active = false,
	Conn = nil,
	CurrentPoint = 1,
	Points = {
		Vector3.new(493.56573486328125, 395.08209228515625, -520.0994262695312),    -- Point 1
		Vector3.new(482.989501953125, 395.9943542480469, 425.8323669433594),        -- Point 2
		Vector3.new(-674.6990966796875, 395.39581298828125, 439.9954833984375),     -- Point 3
		Vector3.new(-676.624755859375, 395.0023193359375, -547.8704223632812),      -- Point 4
		Vector3.new(493.56573486328125, 285.144933700561523, -520.0994262695312),   -- Point 5
		Vector3.new(482.989501953125, 285.144933700561523, 425.8323669433594),      -- Point 6
		Vector3.new(-674.6990966796875, 285.144933700561523, 439.9954833984375),    -- Point 7
		Vector3.new(-676.624755859375, 285.144933700561523, -547.8704223632812)     -- Point 8
	},
	LastMoveTime = 0
}

-- Modes (for info)
local TargetModes = {
	zombie = { name = "Zombie Mode", maxHealth = math.huge },
	normal = { name = "Normal Mode", maxHealth = 5000 }
}

-- Tabs - Reorganized
local MainTab = Window:CreateTab("Control")
local FarmTab = Window:CreateTab("Farming")
local ShopTab = Window:CreateTab("Shop")
local ESPTab = Window:CreateTab("ESP")
local VisualTab = Window:CreateTab("Visual")
local TeleportTab = Window:CreateTab("Teleport")
local SettingsTab = Window:CreateTab("Settings")
local StatsTab = Window:CreateTab("Statistics")

-- Statistics elements
local AttackCounter = StatsTab:CreateLabel("Attacks: 0")
local StatusLabel = StatsTab:CreateLabel("Status: Inactive")
local TargetLabel = StatsTab:CreateLabel("Target: None")
local ActionLabel = StatsTab:CreateLabel("Last action: " .. Stats.LastAction)
local ModeLabel = StatsTab:CreateLabel("Mode: " .. TargetModes[Stats.CurrentMode].name)
local HealLabel = StatsTab:CreateLabel("Auto-heal: Disabled")
local WaveLabel = StatsTab:CreateLabel("Wave: Loading...")
local CircularFlightLabel = StatsTab:CreateLabel("Circular flight: Disabled")

-- Control references (for syncing with inputs)
local Controls = {
	AttackSpeedSlider = nil,
	MoveSpeedSlider = nil,
	LowHpSlider = nil,
	MaxHpSlider = nil,
	AttackHeightSlider = nil
}

-- Update wave
local function updateWave()
	local waveValue = Workspace:FindFirstChild("Wave")
	if waveValue and waveValue:IsA("NumberValue") then
		WaveLabel:Set("Wave: " .. waveValue.Value)
	else
		WaveLabel:Set("Wave: Not found")
	end
end

RunService.Heartbeat:Connect(function()
	if time() % 2 < 0.1 then
		updateWave()
	end
end)

-- Notifications (minimal - only for critical errors)
local function Notify(title, message)
	pcall(function()
		Rayfield:Notify({ Title = title, Content = message, Duration = 6 })
	end)
	Stats.LastAction = message
	ActionLabel:Set("Last action: " .. message)
end

-- Check if player is in Living
local function isPlayerInLiving()
	local character = LocalPlayer.Character
	if not character then return false end
	local livingFolder = Workspace:FindFirstChild("Living")
	if not livingFolder then return false end
	for _, model in ipairs(livingFolder:GetChildren()) do
		if model == character then
			return true
		end
	end
	return false
end

local function isCharacterInWorkspaceOrLiving()
	local character = LocalPlayer.Character
	if not character then return false end
	if character.Parent == Workspace then return true end
	return isPlayerInLiving()
end

-- Circular flight (always one direction, no turning)
local function setCircularFlight(state)
	if state then
		if CircularFlight.Active then return end
		CircularFlight.Active = true
		Stats.CircularFlightEnabled = true
		CircularFlight.CurrentPoint = math.clamp(CircularFlight.CurrentPoint or 1, 1, #CircularFlight.Points)
		local arrivalRadius = 2
		if CircularFlight.Conn then CircularFlight.Conn:Disconnect() CircularFlight.Conn = nil end
		CircularFlight.Conn = RunService.Heartbeat:Connect(function(dt)
			if not CircularFlight.Active then return end
			local character = LocalPlayer.Character
			if not character or not isPlayerInLiving() then return end
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not rootPart or not humanoid then return end
			local targetPos = CircularFlight.Points[CircularFlight.CurrentPoint]
			if not targetPos then return end
			local speed = math.max(1, tonumber(Stats.CircularFlightSpeed) or 60)
			local currentPos = rootPart.Position
			local toTarget = targetPos - currentPos
			local dist = toTarget.Magnitude
			if dist <= arrivalRadius then
				CircularFlight.CurrentPoint = (CircularFlight.CurrentPoint % #CircularFlight.Points) + 1
				targetPos = CircularFlight.Points[CircularFlight.CurrentPoint]
			end
			if toTarget.Magnitude > 1e-6 then
				local step = math.min(speed * dt, toTarget.Magnitude)
				local newPos = currentPos + toTarget.Unit * step
				local lookTarget = targetPos
				if (lookTarget - newPos).Magnitude < 1e-6 then
					lookTarget = newPos + Vector3.new(0, 0, -1)
				end
				rootPart.CFrame = CFrame.new(newPos, lookTarget)
				rootPart.AssemblyLinearVelocity = Vector3.zero
				rootPart.AssemblyAngularVelocity = Vector3.zero
				humanoid.AutoRotate = false
			end
		end)
		CircularFlightLabel:Set("Circular flight: Enabled")
	else
		CircularFlight.Active = false
		Stats.CircularFlightEnabled = false
		if CircularFlight.Conn then CircularFlight.Conn:Disconnect() CircularFlight.Conn = nil end
		local character = LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.AutoRotate = true end
		CircularFlightLabel:Set("Circular flight: Disabled")
	end
end

-- Invincibility
local function setInvincible(state)
	Stats.Invincible = state
	if LocalPlayer.Character then
		local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
		if humanoid then
			if state then
				humanoid:SetAttribute("Invincible", true)
				for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
						part.Transparency = 0.5
					end
				end
			else
				humanoid:SetAttribute("Invincible", false)
				for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = true
						part.Transparency = 0.9
					end
				end
			end
		end
	end
end

-- Heal lock on heal part
local HealLock = { Active = false, Conn = nil, Offset = Vector3.new(0, 6, 0) }

local function setHealLock(state)
	if state then
		if HealLock.Active then return end
		HealLock.Active = true
		if HealLock.Conn then HealLock.Conn:Disconnect() HealLock.Conn = nil end
		HealLock.Conn = RunService.Heartbeat:Connect(function()
			if not HealLock.Active then return end
			local part = Stats.HealPart
			local char = LocalPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not part or not part.Parent or not char or not root then
				return
			end
			local targetCF = part.CFrame + HealLock.Offset
			local pos = targetCF.Position
			root.CFrame = CFrame.new(root.Position:Lerp(pos, 0.5), pos - Vector3.new(0, 10, 0))
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end)
	else
		HealLock.Active = false
		if HealLock.Conn then HealLock.Conn:Disconnect() HealLock.Conn = nil end
	end
end

-- Create/remove/teleport to heal part
local function createHealPart()
	if Stats.HealPart and Stats.HealPart.Parent then
		Stats.HealPart:Destroy()
	end
	local part = Instance.new("Part")
	part.Name = "AutoHealPart"
	part.Size = Vector3.new(50, 50, 50)
	part.CFrame = CFrame.new(-23.3440018, 350.940002, 0.342000008, 0, -1, 0, 1, 0, -0, 0, 0, 1)
	part.Anchored = true
	part.CanCollide = true
	part.Transparency = 0.8
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(0, 255, 0)
	part.Parent = Workspace
	Stats.HealPart = part
end

local function removeHealPart()
	if Stats.HealPart and Stats.HealPart.Parent then
		Stats.HealPart:Destroy()
		Stats.HealPart = nil
	end
end

local function teleportToHealPart()
	if not Stats.HealPart or not Stats.HealPart.Parent then
		createHealPart()
	end
	local character = LocalPlayer.Character
	if not character then return false end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not rootPart or not humanoid then return false end
	local targetCF = Stats.HealPart.CFrame + HealLock.Offset
	rootPart.CFrame = CFrame.new(targetCF.Position, targetCF.Position - Vector3.new(0, 10, 0))
	setHealLock(true)
	humanoid.WalkSpeed = 16
	return true
end

local function checkHealthAndHeal()
	if not Stats.AutoHealEnabled then return false end
	local character = LocalPlayer.Character
	if not character then return false end
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return false end

	if character.Parent == Workspace then return false end

	if humanoid.Health <= Stats.LowHpThreshold then
		teleportToHealPart()
		return true
	end
	return false
end

-- Helper: is model tagged with owner?
local function hasOwnerTag(model)
	local ov = model and model:FindFirstChild("Owner")
	return ov and ov:IsA("ObjectValue")
end

-- Attack
local function performAttack()
	local ok, err = pcall(function()
		ReplicatedStorage:WaitForChild("LMB"):FireServer()
	end)
	if ok then
		Stats.TotalAttacks += 1
		AttackCounter:Set("Attacks: " .. Stats.TotalAttacks)
		return true
	else
		warn("Attack error:", err)
		return false
	end
end

-- VISUALS
local Visuals = { Enabled = false, Original = {}, Atmosphere = nil, Bloom = nil, ColorCorrection = nil }

local function storeLighting()
	Visuals.Original = {
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ClockTime = Lighting.ClockTime,
		ExposureCompensation = Lighting.ExposureCompensation,
		ColorShift_Top = Lighting.ColorShift_Top,
		ColorShift_Bottom = Lighting.ColorShift_Bottom
	}
	Visuals.Atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	Visuals.Bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	Visuals.ColorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
end

local function applyClearVisuals()
	if not next(Visuals.Original) then storeLighting() end
	Lighting.FogStart = 0
	Lighting.FogEnd = 100000
	Lighting.Brightness = 2.25
	Lighting.ClockTime = 13.5
	Lighting.ExposureCompensation = 0.1
	Lighting.Ambient = Color3.fromRGB(120, 120, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 140)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
	Lighting.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)

	local atmos = Visuals.Atmosphere or Instance.new("Atmosphere")
	atmos.Density = 0.03
	atmos.Offset = 0
	atmos.Color = Color3.fromRGB(200, 210, 220)
	atmos.Decay = Color3.fromRGB(210, 220, 230)
	atmos.Glare = 0
	atmos.Haze = 0.1
	if not atmos.Parent then atmos.Parent = Lighting end
	Visuals.Atmosphere = atmos

	local bloom = Visuals.Bloom or Instance.new("BloomEffect")
	bloom.Intensity = 0.1
	bloom.Threshold = 1
	bloom.Size = 12
	if not bloom.Parent then bloom.Parent = Lighting end
	Visuals.Bloom = bloom

	local cc = Visuals.ColorCorrection or Instance.new("ColorCorrectionEffect")
	cc.Brightness = 0.05
	cc.Contrast = 0.05
	cc.Saturation = 0.05
	cc.TintColor = Color3.fromRGB(255, 255, 255)
	if not cc.Parent then cc.Parent = Lighting end
	Visuals.ColorCorrection = cc
end

local function restoreVisuals()
	if not next(Visuals.Original) then return end
	Lighting.FogStart = Visuals.Original.FogStart
	Lighting.FogEnd = Visuals.Original.FogEnd
	Lighting.Brightness = Visuals.Original.Brightness
	Lighting.ClockTime = Visuals.Original.ClockTime
	Lighting.ExposureCompensation = Visuals.Original.ExposureCompensation
	Lighting.Ambient = Visuals.Original.Ambient
	Lighting.OutdoorAmbient = Visuals.Original.OutdoorAmbient
	Lighting.ColorShift_Top = Visuals.Original.ColorShift_Top
	Lighting.ColorShift_Bottom = Visuals.Original.ColorShift_Bottom
	if Visuals.Atmosphere and Visuals.Atmosphere.Parent then Visuals.Atmosphere:Destroy() end
	if Visuals.Bloom and Visuals.Bloom.Parent then Visuals.Bloom:Destroy() end
	if Visuals.ColorCorrection and Visuals.ColorCorrection.Parent then Visuals.ColorCorrection:Destroy() end
	Visuals.Atmosphere, Visuals.Bloom, Visuals.ColorCorrection = nil, nil, nil
end

local function setClearVisuals(enabled)
	Visuals.Enabled = enabled
	if enabled then
		applyClearVisuals()
	else
		restoreVisuals()
	end
end

-- ESP
local ESP = {
	PlayersEnabled = false,
	TargetsEnabled = false,
	SpecialEnabled = false,
	UpdateConn = nil,
	LivingAddedConn = nil,
	LivingRemovedConn = nil,
	SelfHealConn = nil,
	Tracked = { players = {}, targets = {}, special = {} },
	LastUpdate = 0
}

local function isAliveModel(model)
	local hum = model and model:FindFirstChild("Humanoid")
	local root = model and model:FindFirstChild("HumanoidRootPart")
	return hum and root and hum.Health > 0
end

local function isTargetModel(model)
	if not model or not model:IsA("Model") then return false end
	if not isAliveModel(model) then return false end
	if model.Name:find("VillanArc") then return false end
	if model == LocalPlayer.Character then return false end
	if model:FindFirstChild("AIFolders") or model:FindFirstChild("AI") or model:FindFirstChild("AIScript") then
		return true
	end
	if model:FindFirstChildOfClass("Animator") or model:FindFirstChild("Animate") then
		return true
	end
	return false
end

local function isPlayerModel(model)
	if not model or not model:IsA("Model") then return false end
	if not isAliveModel(model) then return false end
	if model:FindFirstChild("AIFolders") or model:FindFirstChild("AI") or model:FindFirstChild("AIScript") then
		return false
	end
	local plr = Players:GetPlayerFromCharacter(model)
	if not plr then return false end
	if plr == LocalPlayer then return false end
	return true
end

local function isSpecialModel(model)
	if not model or not model:IsA("Model") then return false end
	if model.Name == "Clock Spider" then return true end
	local name = model.Name:lower()
	return name:find("drive") ~= nil
end

local function getBillboardAdornee(model)
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then return head end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then return root end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function computeStudsOffset(model)
	local size = Vector3.new(0, 0, 0)
	local ok = pcall(function()
		local _, s = model:GetBoundingBox()
		size = s
	end)
	if not ok then
		pcall(function()
			size = model:GetExtentsSize()
		end)
	end
	local y = size and size.Y or 6
	return Vector3.new(0, math.clamp(y + 2, 4, 20), 0)
end

local function ensureHighlight(model, kind)
	local h = model:FindFirstChild("ESP_Highlight")
	if not h then
		h = Instance.new("Highlight")
		h.Name = "ESP_Highlight"
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.FillTransparency = 0.85
		h.OutlineTransparency = 0
		h.Parent = model
	end
	if kind == "player" then
		h.FillColor = Color3.fromRGB(100, 255, 140)
		h.OutlineColor = Color3.fromRGB(0, 200, 80)
	elseif kind == "special" then
		h.FillColor = Color3.fromRGB(255, 255, 100)
		h.OutlineColor = Color3.fromRGB(255, 200, 0)
	else
		h.FillColor = Color3.fromRGB(255, 100, 100)
		h.OutlineColor = Color3.fromRGB(255, 0, 0)
	end
	return h
end

local function ensureBillboard(model, kind)
	local adornee = getBillboardAdornee(model)
	if not adornee then return nil end
	local existing = nil
	for _, child in ipairs(model:GetDescendants()) do
		if child:IsA("BillboardGui") and child.Name == "ESP_Billboard" then
			if child.Adornee and child.Adornee ~= adornee then
				child:Destroy()
			else
				existing = child
			end
		end
	end
	local gui = existing
	if not gui or not gui.Parent or not gui:IsDescendantOf(game) then
		gui = Instance.new("BillboardGui")
		gui.Name = "ESP_Billboard"
		gui.AlwaysOnTop = true
		gui.Size = UDim2.new(0, 240, 0, 54)
		gui.StudsOffset = computeStudsOffset(model)
		gui.MaxDistance = 10000
		gui.Adornee = adornee
		gui.Parent = adornee

		local tl = Instance.new("TextLabel")
		tl.Name = "ESP_Text"
		tl.BackgroundTransparency = 1
		tl.Size = UDim2.new(1, 0, 1, 0)
		tl.Font = Enum.Font.SourceSansBold
		tl.TextScaled = true
		if kind == "player" then
			tl.TextColor3 = Color3.fromRGB(0, 255, 120)
		elseif kind == "special" then
			tl.TextColor3 = Color3.fromRGB(255, 255, 0)
		else
			tl.TextColor3 = Color3.fromRGB(255, 80, 80)
		end
		tl.TextStrokeTransparency = 0.5
		tl.TextStrokeColor3 = Color3.new(0, 0, 0)
		tl.Parent = gui
	end
	return gui
end

local function updateESPTextAndOffset(model, kind)
	if kind == "special" then
		local nameText = model.Name
		local adornee = getBillboardAdornee(model)
		if not adornee then return end
		local gui = adornee:FindFirstChild("ESP_Billboard")
		if not gui then
			gui = ensureBillboard(model, kind)
		end
		if not gui then return end
		if gui.Adornee ~= adornee then
			gui.Adornee = adornee
			gui.Parent = adornee
		end
		local tl = gui:FindFirstChild("ESP_Text")
		if not tl then
			gui:Destroy()
			gui = ensureBillboard(model, kind)
			if not gui then return end
			tl = gui:FindFirstChild("ESP_Text")
			if not tl then return end
		end
		tl.Text = nameText
		gui.StudsOffset = computeStudsOffset(model)
	else
		if not isAliveModel(model) then return end
		local hum = model:FindFirstChild("Humanoid")
		local nameText = model.Name
		local hpText = ""
		if hum then
			hpText = " | HP: " .. math.max(0, math.floor(hum.Health)) .. "/" .. math.floor(hum.MaxHealth or 0)
		end
		local adornee = getBillboardAdornee(model)
		if not adornee then return end
		local gui = adornee:FindFirstChild("ESP_Billboard")
		if not gui then
			gui = ensureBillboard(model, kind)
		end
		if not gui then return end
		if gui.Adornee ~= adornee then
			gui.Adornee = adornee
			gui.Parent = adornee
		end
		local tl = gui:FindFirstChild("ESP_Text")
		if not tl then
			gui:Destroy()
			gui = ensureBillboard(model, kind)
			if not gui then return end
			tl = gui:FindFirstChild("ESP_Text")
			if not tl then return end
		end
		tl.Text = nameText .. hpText
		gui.StudsOffset = computeStudsOffset(model)
	end
end

local function attachESP(model, kind)
	if kind == "special" or isAliveModel(model) then
		ensureHighlight(model, kind)
		ensureBillboard(model, kind)
		updateESPTextAndOffset(model, kind)
	end
end

local function detachESP(model)
	if not model then return end
	local h = model:FindFirstChild("ESP_Highlight")
	if h then h:Destroy() end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BillboardGui") and part.Name == "ESP_Billboard" then
			part:Destroy()
		end
	end
end

local function clearTracked(kind)
	for model in pairs(ESP.Tracked[kind]) do
		detachESP(model)
	end
	ESP.Tracked[kind] = {}
end

local function startESPUpdater()
	if ESP.UpdateConn then return end
	ESP.UpdateConn = RunService.Heartbeat:Connect(function()
		if time() - (ESP.LastUpdate or 0) < 0.2 then return end
		ESP.LastUpdate = time()
		if ESP.PlayersEnabled then
			for model in pairs(ESP.Tracked.players) do
				if model and model.Parent and isPlayerModel(model) then
					updateESPTextAndOffset(model, "player")
				else
					ESP.Tracked.players[model] = nil
					detachESP(model)
				end
			end
		end
		if ESP.TargetsEnabled then
			for model in pairs(ESP.Tracked.targets) do
				if model and model.Parent and isTargetModel(model) then
					updateESPTextAndOffset(model, "target")
				else
					ESP.Tracked.targets[model] = nil
					detachESP(model)
				end
			end
		end
		if ESP.SpecialEnabled then
			for model in pairs(ESP.Tracked.special) do
				if model and model.Parent and isSpecialModel(model) then
					updateESPTextAndOffset(model, "special")
				else
					ESP.Tracked.special[model] = nil
					detachESP(model)
				end
			end
		end
	end)
end

local function stopESPUpdater()
	if ESP.UpdateConn then
		ESP.UpdateConn:Disconnect()
		ESP.UpdateConn = nil
	end
end

local function startESPSelfHeal()
	if ESP.SelfHealConn then return end
	ESP.SelfHealConn = RunService.Stepped:Connect(function()
		if not (ESP.PlayersEnabled or ESP.TargetsEnabled or ESP.SpecialEnabled) then return end
		if ESP.PlayersEnabled then
			for model in pairs(ESP.Tracked.players) do
				if model and model.Parent and isPlayerModel(model) then
					ensureBillboard(model, "player")
				end
			end
		end
		if ESP.TargetsEnabled then
			for model in pairs(ESP.Tracked.targets) do
				if model and model.Parent and isTargetModel(model) then
					ensureBillboard(model, "target")
				end
			end
		end
		if ESP.SpecialEnabled then
			for model in pairs(ESP.Tracked.special) do
				if model and model.Parent and isSpecialModel(model) then
					ensureBillboard(model, "special")
				end
			end
		end
	end)
end

local function stopESPSelfHeal()
	if ESP.SelfHealConn then
		ESP.SelfHealConn:Disconnect()
		ESP.SelfHealConn = nil
	end
end

local function connectLivingFolder()
	if ESP.LivingAddedConn or ESP.LivingRemovedConn then return end
	local livingFolder = Workspace:FindFirstChild("Living")
	if not livingFolder then return end
	ESP.LivingAddedConn = livingFolder.ChildAdded:Connect(function(model)
		task.defer(function()
			if ESP.PlayersEnabled and isPlayerModel(model) then
				if not ESP.Tracked.players[model] then
					attachESP(model, "player")
					ESP.Tracked.players[model] = true
				end
			end
			if ESP.TargetsEnabled and isTargetModel(model) then
				if not ESP.Tracked.targets[model] then
					attachESP(model, "target")
					ESP.Tracked.targets[model] = true
				end
			end
		end)
	end)
	ESP.LivingRemovedConn = livingFolder.ChildRemoved:Connect(function(model)
		if ESP.Tracked.players[model] then
			ESP.Tracked.players[model] = nil
			detachESP(model)
		end
		if ESP.Tracked.targets[model] then
			ESP.Tracked.targets[model] = nil
			detachESP(model)
		end
	end)
end

local function disconnectLivingFolder()
	if ESP.LivingAddedConn then ESP.LivingAddedConn:Disconnect() ESP.LivingAddedConn = nil end
	if ESP.LivingRemovedConn then ESP.LivingRemovedConn:Disconnect() ESP.LivingRemovedConn = nil end
end

local function rescanLiving(kind)
	local livingFolder = Workspace:FindFirstChild("Living")
	if not livingFolder then return end
	for _, model in ipairs(livingFolder:GetChildren()) do
		if kind == "players" and ESP.PlayersEnabled and isPlayerModel(model) then
			if not ESP.Tracked.players[model] then
				attachESP(model, "player")
				ESP.Tracked.players[model] = true
			end
		elseif kind == "targets" and ESP.TargetsEnabled and isTargetModel(model) then
			if not ESP.Tracked.targets[model] then
				attachESP(model, "target")
				ESP.Tracked.targets[model] = true
			end
		end
	end
end

local function rescanWorkspaceForSpecial()
	if not ESP.SpecialEnabled then return end
	for _, model in ipairs(Workspace:GetChildren()) do
		if isSpecialModel(model) then
			if not ESP.Tracked.special[model] then
				attachESP(model, "special")
				ESP.Tracked.special[model] = true
			end
		end
	end
end

local function enablePlayersESP()
	if ESP.PlayersEnabled then return end
	ESP.PlayersEnabled = true
	connectLivingFolder()
	rescanLiving("players")
	startESPUpdater()
	startESPSelfHeal()
end

local function disablePlayersESP()
	if not ESP.PlayersEnabled then return end
	ESP.PlayersEnabled = false
	clearTracked("players")
	if not ESP.TargetsEnabled and not ESP.SpecialEnabled then
		disconnectLivingFolder()
		stopESPUpdater()
		stopESPSelfHeal()
	end
end

local function enableTargetsESP()
	if ESP.TargetsEnabled then return end
	ESP.TargetsEnabled = true
	connectLivingFolder()
	rescanLiving("targets")
	startESPUpdater()
	startESPSelfHeal()
end

local function disableTargetsESP()
	if not ESP.TargetsEnabled then return end
	ESP.TargetsEnabled = false
	clearTracked("targets")
	if not ESP.PlayersEnabled and not ESP.SpecialEnabled then
		disconnectLivingFolder()
		stopESPUpdater()
		stopESPSelfHeal()
	end
end

local function enableSpecialESP()
	if ESP.SpecialEnabled then return end
	ESP.SpecialEnabled = true
	rescanWorkspaceForSpecial()
	startESPUpdater()
	startESPSelfHeal()
end

local function disableSpecialESP()
	if not ESP.SpecialEnabled then return end
	ESP.SpecialEnabled = false
	clearTracked("special")
	if not ESP.PlayersEnabled and not ESP.TargetsEnabled then
		stopESPUpdater()
		stopESPSelfHeal()
	end
end

-- Ignore targets
local Ignore = { NamesSet = {}, Options = {}, Dropdown = nil }

local function collectTargetNames()
	local livingFolder = Workspace:FindFirstChild("Living")
	if not livingFolder then return {} end
	local unique = {}
	for _, model in ipairs(livingFolder:GetChildren()) do
		if isTargetModel(model) then unique[model.Name] = true end
	end
	local list = {}
	for name in pairs(unique) do table.insert(list, name) end
	table.sort(list)
	return list
end

local function refreshIgnoreOptions()
	Ignore.Options = collectTargetNames()
	if Ignore.Dropdown then
		Ignore.Dropdown:Refresh(Ignore.Options)
		local selected = {}
		for _, name in ipairs(Ignore.Options) do if Ignore.NamesSet[name] then table.insert(selected, name) end end
		if #selected > 0 then Ignore.Dropdown:Set(selected) end
	end
end

local function setIgnored(namesTable)
	Ignore.NamesSet = {}
	for _, name in ipairs(namesTable) do Ignore.NamesSet[name] = true end
end

-- Find target
local function findTarget()
	local livingFolder = workspace:FindFirstChild("Living")
	if not livingFolder then
		return nil
	end
	local targets = {}
	local character = LocalPlayer.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart")

	local corePos = nil
	local coreModel = Workspace:FindFirstChild("Core")
	if coreModel then
		local pp = coreModel.PrimaryPart
		if not pp then
			pcall(function() coreModel.PrimaryPart = coreModel:FindFirstChild("HumanoidRootPart") end)
			pp = coreModel.PrimaryPart
		end
		if pp then
			corePos = pp.Position
		else
			local cf = coreModel:GetPivot()
			corePos = cf and cf.Position or nil
		end
	end

	local transmitterToilet = nil
	for _, model in ipairs(livingFolder:GetChildren()) do
		if model.Name == "Transmitter toilet" and isTargetModel(model) and not Ignore.NamesSet[model.Name] and not hasOwnerTag(model) then
			local humanoid = model:FindFirstChild("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			if humanoid and root and humanoid.Health > 0 then
				if humanoid.MaxHealth <= (Stats.MaxHpLimit or 300) then
					transmitterToilet = model
					break
				end
			end
		end
	end
	if transmitterToilet then
		return transmitterToilet
	end

	for _, model in ipairs(livingFolder:GetChildren()) do
		if isTargetModel(model) and not Ignore.NamesSet[model.Name] and not hasOwnerTag(model) then
			local humanoid = model:FindFirstChild("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			if humanoid and root and humanoid.Health > 0 then
				if humanoid.MaxHealth <= (Stats.MaxHpLimit or 300) then
					local distToMe = myRoot and (myRoot.Position - root.Position).Magnitude or math.huge
					local distToCore = corePos and (corePos - root.Position).Magnitude or math.huge
					table.insert(targets, {
						model = model,
						health = humanoid.Health,
						distanceToMe = distToMe,
						distanceToCore = distToCore
					})
				end
			end
		end
	end
	if #targets == 0 then return nil end
	if Stats.TargetPriority == "LowestHP" then
		table.sort(targets, function(a, b) return a.health < b.health end)
	elseif Stats.TargetPriority == "HighestHP" then
		table.sort(targets, function(a, b) return a.health > b.health end)
	elseif Stats.TargetPriority == "Nearest" then
		table.sort(targets, function(a, b) return a.distanceToMe < b.distanceToMe end)
	elseif Stats.TargetPriority == "NearestToCore" then
		table.sort(targets, function(a, b) return a.distanceToCore < b.distanceToCore end)
	else
		table.sort(targets, function(a, b) return a.health < b.health end)
	end
	return targets[1].model
end

-- Teleport-aim above target
local function flyAboveTarget(target)
	if not target or not target.Parent then return false end
	local character = LocalPlayer.Character
	if not character then return false end
	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return false end

	setInvincible(true)
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = Stats.MoveSpeed

	local startTime = time()
	local maxTime = 30
	local backOffset = -2
	local posLerp = 0.45

	while Stats.Active and time() - startTime < maxTime do
		if not target.Parent then break end
		local targetHum = target:FindFirstChild("Humanoid")
		local targetRoot = target:FindFirstChild("HumanoidRootPart")
		if not targetHum or not targetRoot or targetHum.Health <= 0 then break end
		if hasOwnerTag(target) then
			break
		end
		if checkHealthAndHeal() then
			while Stats.Active and HealLock.Active do task.wait(0.2) end
			if not Stats.Active then break end
		end
		local height = tonumber(Stats.AttackHeight) or 10
		local desiredPos = targetRoot.Position + Vector3.new(0, height, 0) + (targetRoot.CFrame.LookVector * backOffset)
		local newPos = rootPart.Position:Lerp(desiredPos, posLerp)
		rootPart.CFrame = CFrame.new(newPos, targetRoot.Position)
		if time() - Stats.AttackCooldown >= Stats.AttackSpeed then
			performAttack()
			Stats.AttackCooldown = time()
		end
		rootPart.AssemblyLinearVelocity = rootPart.AssemblyLinearVelocity * 0.25
		rootPart.AssemblyAngularVelocity = Vector3.zero
		task.wait(0.05)
	end

	humanoid.AutoRotate = true
	setInvincible(false)
	humanoid.WalkSpeed = 16
	return true
end

-- Main hunt loop
local function hunt()
	while Stats.Active do
		if not isPlayerInLiving() then
			task.wait(1)
			continue
		end

		if checkHealthAndHeal() then
			while Stats.Active and HealLock.Active do task.wait(0.2) end
			if not Stats.Active then break end
		end

		local target = findTarget()
		if not target then
			if Stats.NoTargetTime == 0 then
				Stats.NoTargetTime = time()
			end
			task.wait(1)
			continue
		end

		Stats.NoTargetTime = 0
		Stats.CurrentTarget = target
		TargetLabel:Set("Target: " .. target.Name)

		if not flyAboveTarget(target) then
			task.wait(0.5)
			continue
		end

		task.wait(0.25)
	end

	Stats.NoTargetTime = 0
end

-- Shop
local Shop = {
	TargetPos = Vector3.new(43.973999, 16, -59.1829987),
	Matrix = {1,0,0, 0,1,0, 0,0,1},
	PosEps = 0.1,
	MatEps = 1e-3,
	LastAction = 0
}

local function isTargetPivot(cf)
	local x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22 = cf:GetComponents()
	if (Vector3.new(x,y,z) - Shop.TargetPos).Magnitude > Shop.PosEps then return false end
	local M = Shop.Matrix
	local function close(a,b) return math.abs(a - b) < Shop.MatEps end
	return close(r00,M[1]) and close(r01,M[2]) and close(r02,M[3])
		and close(r10,M[4]) and close(r11,M[5]) and close(r12,M[6])
		and close(r20,M[7]) and close(r21,M[8]) and close(r22,M[9])
end

local function autoTeleportToShop()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local shop = workspace:FindFirstChild("HelicopterShop")
	if not shop or not shop:IsA("Model") then return false end
	local pivot = shop.WorldPivot or shop:GetPivot()
	if isTargetPivot(pivot) then
		root.CFrame = pivot + Vector3.new(0, 5, 0)
		return true
	end
	return false
end

local function autoBuyHealth()
	local shop = workspace:FindFirstChild("HelicopterShop")
	if not shop or not shop:IsA("Model") then return false end
	local pivot = shop.WorldPivot or shop:GetPivot()
	if isTargetPivot(pivot) then
		local shopSystem = ReplicatedStorage:WaitForChild("ShopSystem", 5)
		if shopSystem then
			local args = { [1] = "Buy", [2] = "FillHP" }
			pcall(function() shopSystem:FireServer(unpack(args)) end)
			setHealLock(false)
			Shop.LastAction = time()
			return true
		end
	end
	return false
end

local ShopMonitorConn
if not ShopMonitorConn then
	ShopMonitorConn = RunService.Heartbeat:Connect(function()
		if not isCharacterInWorkspaceOrLiving() then return end
		local shop = workspace:FindFirstChild("HelicopterShop")
		if not shop then return end
		local pivot = shop.WorldPivot or shop:GetPivot()
		if isTargetPivot(pivot) and (time() - Shop.LastAction) > 4 then
			if Stats.AutoBuyHealth then
				autoBuyHealth()
				Shop.LastAction = time()
			end
		end
	end)
end

-- Auto vote
local AutoVote = { Active = false, Conn = nil }

local function startAutoVote()
	if AutoVote.Active then return end
	AutoVote.Active = true

	AutoHealState.WasEnabled = Stats.AutoHealEnabled
	Stats.AutoHealEnabled = false
	setHealLock(false)

	AutoVote.Conn = RunService.Heartbeat:Connect(function()
		if not Stats.AutoVoteEnabled then return end
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if not playerGui then return end
		local voteUI = playerGui:FindFirstChild("OpenVoteUI")
		if voteUI and voteUI:IsA("ScreenGui") and voteUI.Enabled then
			local voteSystem = ReplicatedStorage:WaitForChild("Vote", 5)
			if voteSystem then
				local args = { [1] = Stats.VoteMode }
				pcall(function() voteSystem:FireServer(unpack(args)) end)
				task.spawn(function()
					task.wait(0.5)
					local autoReady = Workspace:FindFirstChild("AutoReady")
					if autoReady then
						local character = LocalPlayer.Character
						if character then
							local rootPart = character:FindFirstChild("HumanoidRootPart")
							if rootPart then
								rootPart.CFrame = autoReady.CFrame + Vector3.new(0, 5, 0)
							end
						end
					end
				end)
			end
		end
	end)
end

local function stopAutoVote()
	if not AutoVote.Active then return end
	AutoVote.Active = false
	if AutoVote.Conn then
		AutoVote.Conn:Disconnect()
		AutoVote.Conn = nil
	end
	if AutoHealState.WasEnabled then
		Stats.AutoHealEnabled = true
	end
end

-- Radiant loop (anti-duplication)
local RadiantLoop = { version = 0 }

-- Control Tab
MainTab:CreateButton({
	Name = "Infinite Yield",
	Callback = function()
		loadstring(game:HttpGet('https://raw.githubusercontent.com/DarkNetworks/Infinite-Yield/main/latest.lua'))()
	end
})

MainTab:CreateButton({
	Name = "Anti-AFK",
	Callback = function()
		task.wait(0.5)
		local ba = Instance.new("ScreenGui")
		local ca = Instance.new("TextLabel")
		local da = Instance.new("Frame")
		local _b = Instance.new("TextLabel")
		local ab = Instance.new("TextLabel")

		ba.Parent = game.CoreGui
		ba.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

		ca.Parent = ba
		ca.Active = true
		ca.BackgroundColor3 = Color3.new(0.176471, 0.176471, 0.176471)
		ca.Draggable = true
		ca.Position = UDim2.new(0.698610067, 0, 0.098096624, 0)
		ca.Size = UDim2.new(0, 370, 0, 52)
		ca.Font = Enum.Font.SourceSansSemibold
		ca.Text = "Anti AFK Script"
		ca.TextColor3 = Color3.new(0, 1, 1)
		ca.TextSize = 22

		da.Parent = ca
		da.BackgroundColor3 = Color3.new(0.196078, 0.196078, 0.196078)
		da.Position = UDim2.new(0, 0, 1.0192306, 0)
		da.Size = UDim2.new(0, 370, 0, 107)

		_b.Parent = da
		_b.BackgroundColor3 = Color3.new(0.176471, 0.176471, 0.176471)
		_b.Position = UDim2.new(0, 0, 0.800455689, 0)
		_b.Size = UDim2.new(0, 370, 0, 21)
		_b.Font = Enum.Font.Arial
		_b.Text = "Made by Dynamic. (please subscribe)"
		_b.TextColor3 = Color3.new(0, 1, 1)
		_b.TextSize = 20

		ab.Parent = da
		ab.BackgroundColor3 = Color3.new(0.176471, 0.176471, 0.176471)
		ab.Position = UDim2.new(0, 0, 0.158377, 0)
		ab.Size = UDim2.new(0, 370, 0, 44)
		ab.Font = Enum.Font.ArialBold
		ab.Text = "Status: Active"
		ab.TextColor3 = Color3.new(0, 1, 1)
		ab.TextSize = 20

		local bb = game:GetService("VirtualUser")
		Players.LocalPlayer.Idled:Connect(function()
			bb:CaptureController()
			bb:ClickButton2(Vector2.new())
			ab.Text = "Roblox Tried to kick you but we didnt let them kick you :D"
			task.wait(2)
			ab.Text = "Status : Active"
		end)
	end
})

-- Farming Tab
FarmTab:CreateToggle({
	Name = "Auto Farm",
	CurrentValue = false,
	Flag = "AutoFarm",
	Callback = function(Value)
		Stats.Active = Value
		if Value then
			StatusLabel:Set("Status: Active")
			RadiantLoop.version += 1
			local my = RadiantLoop.version
			task.spawn(function()
				local radiant = ReplicatedStorage:WaitForChild(Stats.RadiantEventName, 5)
				while Stats.Active and RadiantLoop.version == my do
					if radiant and radiant.FireServer then
						pcall(function() radiant:FireServer() end)
					end
					for _ = 1, 50 do
						if not Stats.Active or RadiantLoop.version ~= my then break end
						task.wait(0.2)
					end
				end
			end)
			hunt()
		else
			StatusLabel:Set("Status: Inactive")
			setInvincible(false)
			setHealLock(false)
			RadiantLoop.version += 1
		end
	end
})

FarmTab:CreateToggle({
	Name = "Circular Flight",
	CurrentValue = false,
	Flag = "CircularFlight",
	Callback = function(Value)
		setCircularFlight(Value)
	end
})

FarmTab:CreateToggle({
	Name = "Auto Vote",
	CurrentValue = false,
	Flag = "AutoVote",
	Callback = function(Value)
		Stats.AutoVoteEnabled = Value
		if Value then
			startAutoVote()
		else
			stopAutoVote()
		end
	end
})

-- Shop Tab
ShopTab:CreateToggle({
	Name = "Auto Buy Health",
	CurrentValue = false,
	Flag = "AutoBuyHealth",
	Callback = function(Value)
		Stats.AutoBuyHealth = Value
	end
})

ShopTab:CreateToggle({
	Name = "Auto Teleport to Shop",
	CurrentValue = false,
	Flag = "AutoTeleportToShop",
	Callback = function(Value)
		Stats.AutoTeleportToShop = Value
		if Value then
			autoTeleportToShop()
		end
	end
})

-- ESP Tab
ESPTab:CreateToggle({
	Name = "ESP on Players",
	CurrentValue = false,
	Flag = "ESPPlayers",
	Callback = function(Value)
		if Value then
			enablePlayersESP()
		else
			disablePlayersESP()
		end
	end
})

ESPTab:CreateToggle({
	Name = "ESP on Targets",
	CurrentValue = false,
	Flag = "ESPTargets",
	Callback = function(Value)
		if Value then
			enableTargetsESP()
		else
			disableTargetsESP()
		end
	end
})

ESPTab:CreateToggle({
	Name = "ESP on Special",
	CurrentValue = false,
	Flag = "ESPSpecial",
	Callback = function(Value)
		if Value then
			enableSpecialESP()
		else
			disableSpecialESP()
		end
	end
})

ESPTab:CreateButton({
	Name = "Clear All ESP",
	Callback = function()
		clearTracked("players")
		clearTracked("targets")
		clearTracked("special")
	end
})

-- Visual Tab
VisualTab:CreateToggle({
	Name = "Clear Scene",
	CurrentValue = false,
	Flag = "ClearVisuals",
	Callback = function(Value)
		setClearVisuals(Value)
	end
})

-- Teleport Tab
TeleportTab:CreateButton({
	Name = "Teleport to Arena",
	Callback = function()
		local character = LocalPlayer.Character
		if not character then return end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end
		rootPart.CFrame = CFrame.new(-23.3439998626709, 30.940000534057617, 0.34200000762939453)
	end
})

TeleportTab:CreateButton({
	Name = "Teleport to Lobby",
	Callback = function()
		local character = LocalPlayer.Character
		if not character then return end
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end
		rootPart.CFrame = CFrame.new(610.3095092773438, -466.0824279785156, 454.583740234375)
	end
})

-- Settings Tab
Controls.AttackSpeedSlider = SettingsTab:CreateSlider({
	Name = "Attack Speed (sec)",
	Range = {0.1, 2},
	Increment = 0.1,
	CurrentValue = 0.5,
	Flag = "AttackSpeed",
	Callback = function(Value)
		Stats.AttackSpeed = Value
	end
})

SettingsTab:CreateInput({
	Name = "Attack Speed (input)",
	CurrentValue = tostring(Stats.AttackSpeed),
	PlaceholderText = "e.g. 0.5",
	RemoveTextAfterFocusLost = false,
	Flag = "AttackSpeedInput",
	Callback = function(Text)
		local v = tonumber(Text)
		if v then
			v = math.clamp(v, 0.1, 2)
			Stats.AttackSpeed = v
			if Controls.AttackSpeedSlider and Controls.AttackSpeedSlider.Set then
				Controls.AttackSpeedSlider:Set(v)
			end
		end
	end
})

Controls.MoveSpeedSlider = SettingsTab:CreateSlider({
	Name = "Move Speed",
	Range = {20, 1000},
	Increment = 5,
	CurrentValue = 50,
	Flag = "MoveSpeed",
	Callback = function(Value)
		Stats.MoveSpeed = Value
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = Value end
	end
})

SettingsTab:CreateInput({
	Name = "Move Speed (input)",
	CurrentValue = tostring(Stats.MoveSpeed),
	PlaceholderText = "e.g. 50",
	RemoveTextAfterFocusLost = false,
	Flag = "MoveSpeedInput",
	Callback = function(Text)
		local v = tonumber(Text)
		if v then
			v = math.clamp(v, 20, 500)
			Stats.MoveSpeed = v
			if Controls.MoveSpeedSlider and Controls.MoveSpeedSlider.Set then
				Controls.MoveSpeedSlider:Set(v)
			end
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then hum.WalkSpeed = v end
		end
	end
})

SettingsTab:CreateSlider({
	Name = "Flight Speed (studs/sec)",
	Range = {10, 20000},
	Increment = 5,
	CurrentValue = 60,
	Flag = "CircularFlightSpeed",
	Callback = function(Value)
		Stats.CircularFlightSpeed = Value
	end
})

SettingsTab:CreateInput({
	Name = "Flight Speed (input)",
	CurrentValue = tostring(Stats.CircularFlightSpeed),
	PlaceholderText = "e.g. 60",
	RemoveTextAfterFocusLost = false,
	Flag = "CircularFlightSpeedInput",
	Callback = function(Text)
		local v = tonumber(Text)
		if v then
			v = math.clamp(math.floor(v), 10, 300)
			Stats.CircularFlightSpeed = v
		end
	end
})

Controls.LowHpSlider = SettingsTab:CreateSlider({
	Name = "HP Threshold for Heal",
	Range = {50, 10000},
	Increment = 50,
	CurrentValue = 100,
	Flag = "LowHpThreshold",
	Callback = function(Value)
		Stats.LowHpThreshold = math.floor(Value)
	end
})

SettingsTab:CreateInput({
	Name = "HP Threshold (input)",
	CurrentValue = tostring(Stats.LowHpThreshold),
	PlaceholderText = "e.g. 100",
	RemoveTextAfterFocusLost = false,
	Flag = "LowHpInput",
	Callback = function(Text)
		local v = tonumber(Text)
		if v then
			v = math.clamp(math.floor(v), 50, 10000)
			Stats.LowHpThreshold = v
			if Controls.LowHpSlider and Controls.LowHpSlider.Set then
				Controls.LowHpSlider:Set(v)
			end
		end
	end
})

SettingsTab:CreateToggle({
	Name = "Auto Heal",
	CurrentValue = false,
	Flag = "AutoHeal",
	Callback = function(Value)
		Stats.AutoHealEnabled = Value
		if Value then
			HealLabel:Set("Auto-heal: Enabled")
		else
			HealLabel:Set("Auto-heal: Disabled")
			setHealLock(false)
		end
	end
})

SettingsTab:CreateInput({
	Name = "Event Name",
	CurrentValue = "",
	PlaceholderText = "Enter event name",
	RemoveTextAfterFocusLost = false,
	Flag = "RadiantEventName",
	Callback = function(Text)
		Stats.RadiantEventName = Text
	end
})

SettingsTab:CreateDropdown({
	Name = "Vote Mode",
	Options = {"Zombie", "Hell", "BossRush", "Normal", "Christmas"},
	CurrentOption = {"Zombie"},
	MultipleOptions = false,
	Flag = "VoteMode",
	Callback = function(Option)
		local selectedMode = Option[1] or Option
		Stats.VoteMode = selectedMode
	end
})

SettingsTab:CreateDropdown({
	Name = "Target Mode",
	Options = {"zombie", "normal"},
	CurrentOption = {"zombie"},
	MultipleOptions = false,
	Flag = "TargetMode",
	Callback = function(Option)
		local selectedMode = Option[1] or Option
		if TargetModes[selectedMode] then
			Stats.CurrentMode = selectedMode
			ModeLabel:Set("Mode: " .. TargetModes[selectedMode].name)
		end
	end
})

SettingsTab:CreateButton({
	Name = "Show Mode Targets",
	Callback = function()
		local currentMode = TargetModes[Stats.CurrentMode]
		if currentMode then
			Notify("Mode: " .. currentMode.name,
				"Target selection: models in `Living` with AIFolders/AI/AIScript\n" ..
				"Max HP limit (slider): " .. (Stats.MaxHpLimit or 0)
			)
		end
	end
})

Controls.MaxHpSlider = SettingsTab:CreateSlider({
	Name = "Ignore by Max HP (>)",
	Range = {200, 100000},
	Increment = 100,
	CurrentValue = Stats.MaxHpLimit,
	Flag = "MaxHpLimit",
	Callback = function(Value)
		Stats.MaxHpLimit = math.floor(Value)
	end
})

SettingsTab:CreateInput({
	Name = "Max HP Limit (input)",
	CurrentValue = tostring(Stats.MaxHpLimit),
	PlaceholderText = "e.g. 300",
	RemoveTextAfterFocusLost = false,
	Flag = "MaxHpInput",
	Callback = function(Text)
		local v = tonumber(Text)
		if v then
			v = math.clamp(math.floor(v), 200, 100000)
			Stats.MaxHpLimit = v
			if Controls.MaxHpSlider and Controls.MaxHpSlider.Set then
				Controls.MaxHpSlider:Set(v)
			end
		end
	end
})

SettingsTab:CreateDropdown({
	Name = "Target Priority",
	Options = {"LowestHP", "HighestHP", "Nearest", "NearestToCore"},
	CurrentOption = {Stats.TargetPriority},
	MultipleOptions = false,
	Flag = "TargetPriority",
	Callback = function(Option)
		local val = Option[1] or Option
		Stats.TargetPriority = val
	end
})

Controls.AttackHeightSlider = SettingsTab:CreateSlider({
	Name = "Attack Height Above Target",
	Range = {0, 60},
	Increment = 1,
	CurrentValue = Stats.AttackHeight,
	Flag = "AttackHeight",
	Callback = function(Value)
		Stats.AttackHeight = math.floor(Value)
	end
})

SettingsTab:CreateInput({
	Name = "Attack Height (input)",
	CurrentValue = tostring(Stats.AttackHeight),
	PlaceholderText = "e.g. 10",
	RemoveTextAfterFocusLost = false,
	Flag = "AttackHeightInput",
	Callback = function(Text)
		local v = tonumber(Text)
		if v then
			v = math.clamp(math.floor(v), 0, 60)
			Stats.AttackHeight = v
			if Controls.AttackHeightSlider and Controls.AttackHeightSlider.Set then
				Controls.AttackHeightSlider:Set(v)
			end
		end
	end
})

Ignore.Dropdown = SettingsTab:CreateDropdown({
	Name = "Ignore Targets (select names)",
	Options = {"Scanning..."},
	CurrentOption = {},
	MultipleOptions = true,
	Flag = "IgnoreTargets",
	Callback = function(Options)
		setIgnored(Options)
	end
})

SettingsTab:CreateButton({
	Name = "Refresh Target List",
	Callback = function()
		refreshIgnoreOptions()
	end
})

SettingsTab:CreateButton({
	Name = "Reset Ignore",
	Callback = function()
		setIgnored({})
		if Ignore.Dropdown then Ignore.Dropdown:Set({}) end
	end
})

-- Constant speed application
local Speed = { Conn = nil }

local function ensureSpeed()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.WalkSpeed ~= Stats.MoveSpeed then
		hum.WalkSpeed = Stats.MoveSpeed
	end
end

if not Speed.Conn then
	Speed.Conn = RunService.Heartbeat:Connect(function()
		ensureSpeed()
	end)
end

LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.15)
	ensureSpeed()
end)

task.defer(refreshIgnoreOptions)
