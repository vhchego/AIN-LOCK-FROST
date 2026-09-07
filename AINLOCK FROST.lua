--[[
    ❄️ FROSTHUB LOCKON STANDALONE v3 ❄️
    - F1: Abre/fecha a interface (estilo HUB)
    - T: Ativa/desativa o LockOn
    - Janela movível e redimensionável
    - Minimizar / Fechar não quebra a reabertura
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local TweenService = game:GetService("TweenService")

-- ========== CONFIGURAÇÕES ==========
local Config = {
    Enabled = false,
    ToggleKey = Enum.KeyCode.T,       -- Tecla para ligar/desligar o LockOn
    UIToggleKey = Enum.KeyCode.F1,    -- Tecla para abrir/fechar a interface
    FOV = 180,
    Smoothness = 0,
    AimPart = "Head",
    ShowFOV = true,
    FOVColor = Color3.fromRGB(255, 50, 50),
    VisibleCheck = false,
    TeamCheck = true,
    UI = {
        AccentColor = Color3.fromRGB(0, 180, 255),
        BackgroundColor = Color3.fromRGB(8, 12, 20),
        SectionColor = Color3.fromRGB(14, 20, 32),
        BorderColor = Color3.fromRGB(0, 140, 210),
        TextColor = Color3.fromRGB(220, 240, 255),
        WindowWidth = 240,
        WindowHeight = 180,
        MinWidth = 220,
        MinHeight = 140
    }
}

-- ========== VARIÁVEIS ==========
local lockonConnection = nil
local lockonTarget = nil
local fovCircle = nil
local menuGui = nil
local mainFrame = nil
local ToggleUpdates = {}

-- Arraste e redimensionamento
local dragStart, dragStartPos, dragging = nil, nil, false
local resizing = false
local resizeStartPos, resizeStartSize = nil, nil

-- ========== FUNÇÕES AUXILIARES ==========
local function IsEnemy(player)
    if player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if Config.TeamCheck and LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
        return false
    end
    return true
end

local function IsTargetVisible(targetPart)
    if not targetPart then return false end
    local cam = Camera
    if not cam then return false end
    local startPos = cam.CFrame.Position
    local targetPos = targetPart.Position
    local direction = (targetPos - startPos).Unit
    local distance = (targetPos - startPos).Magnitude

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.IgnoreWater = true

    local result = workspace:Raycast(startPos, direction * distance, params)
    if not result then return true end
    local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
    if hitChar == targetPart.Parent then return true end
    return false
end

local function GetBestTarget()
    local cam = Camera
    if not cam then return nil end
    local camPos = cam.CFrame.Position
    local lookVec = cam.CFrame.LookVector
    local best, bestAngle = nil, Config.FOV + 1

    for _, p in pairs(Players:GetPlayers()) do
        if IsEnemy(p) and p.Character then
            local part = p.Character:FindFirstChild(Config.AimPart)
            if part then
                local direction = (part.Position - camPos).Unit
                local angle = math.deg(math.acos(math.clamp(lookVec:Dot(direction), -1, 1)))
                if angle < bestAngle then
                    if Config.VisibleCheck and not IsTargetVisible(part) then continue end
                    bestAngle = angle
                    best = { part = part, player = p }
                end
            end
        end
    end
    return best
end

local function IsLockOnTargetValid()
    if not lockonTarget or not lockonTarget.Parent then return false end
    local char = lockonTarget.Parent
    local hum = char:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local cam = Camera
    if not cam then return false end
    local camPos = cam.CFrame.Position
    local lookVec = cam.CFrame.LookVector
    local direction = (lockonTarget.Position - camPos).Unit
    local angle = math.deg(math.acos(math.clamp(lookVec:Dot(direction), -1, 1)))
    return angle <= Config.FOV
end

local function LockOnLoop(deltaTime)
    if not Config.Enabled then return end

    if lockonTarget and not IsLockOnTargetValid() then
        lockonTarget = nil
    end

    if not lockonTarget then
        local best = GetBestTarget()
        if best then lockonTarget = best.part end
    end

    if not lockonTarget then return end

    local targetPos = lockonTarget.Position
    local cam = Camera
    local camPos = cam.CFrame.Position
    local desiredDir = (targetPos - camPos).Unit
    cam.CFrame = CFrame.new(camPos, camPos + desiredDir)

    -- Rotaciona o personagem para o alvo
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if hum and root then
            local originalAutoRotate = hum.AutoRotate
            hum.AutoRotate = false
            local rootPos = root.Position
            local lookDir = (Vector3.new(targetPos.X, rootPos.Y, targetPos.Z) - rootPos).Unit
            if lookDir.Magnitude > 0 then
                root.CFrame = CFrame.new(rootPos, rootPos + lookDir)
            end
            hum.AutoRotate = originalAutoRotate
        end
    end
end

local function UpdateFOVCircle()
    if Config.Enabled and Config.ShowFOV then
        if not fovCircle then
            fovCircle = Drawing.new("Circle")
        end
        fovCircle.Color = Config.FOVColor
        fovCircle.Thickness = 2
        fovCircle.Radius = Config.FOV
        fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        fovCircle.Visible = true
    else
        if fovCircle then fovCircle.Visible = false end
    end
end

local function StartLockOn()
    if lockonConnection then lockonConnection:Disconnect() end
    local lastTime = tick()
    lockonConnection = RunService.RenderStepped:Connect(function()
        local now = tick()
        local dt = now - lastTime
        lastTime = now
        LockOnLoop(dt)
    end)
    UpdateFOVCircle()
end

local function StopLockOn()
    if lockonConnection then lockonConnection:Disconnect(); lockonConnection = nil end
    lockonTarget = nil
    UpdateFOVCircle()
end

-- ========== INTERFACE (com arraste, redimensionamento e reabertura) ==========
local function CreateMenu()
    if menuGui then menuGui:Destroy() end
    menuGui = Instance.new("ScreenGui")
    menuGui.Name = "FrostHub_LockOn"
    menuGui.ResetOnSpawn = false
    menuGui.Parent = CoreGui
    menuGui.Enabled = true  -- começa visível

    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, Config.UI.WindowWidth, 0, Config.UI.WindowHeight)
    mainFrame.Position = UDim2.new(0.5, -Config.UI.WindowWidth/2, 0.5, -Config.UI.WindowHeight/2)
    mainFrame.BackgroundColor3 = Config.UI.BackgroundColor
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = menuGui
    Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
    Instance.new("UIStroke", mainFrame).Color = Config.UI.BorderColor
    mainFrame.UIStroke.Thickness = 1.5

    -- Barra de título (arraste)
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 30)
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    titleBar.Parent = mainFrame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -70, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "❄️ LockOn"
    titleText.TextColor3 = Config.UI.TextColor
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 14
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar

    -- Minimizar
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 26, 0, 26)
    minimizeBtn.Position = UDim2.new(1, -56, 0, 2)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
    minimizeBtn.Text = "_"
    minimizeBtn.TextColor3 = Config.UI.TextColor
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = 12
    minimizeBtn.AutoButtonColor = false
    minimizeBtn.Parent = titleBar
    Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 4)
    minimizeBtn.MouseEnter:Connect(function() TweenService:Create(minimizeBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 60, 80)}):Play() end)
    minimizeBtn.MouseLeave:Connect(function() TweenService:Create(minimizeBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 40, 60)}):Play() end)
    minimizeBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
    end)

    -- Fechar (esconde, mas F1 traz de volta)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -28, 0, 2)
    closeBtn.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Config.UI.TextColor
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = titleBar
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
    closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(220, 50, 50)}):Play() end)
    closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 40, 60)}):Play() end)
    closeBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
    end)

    -- Arraste da janela (titleBar)
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            dragStartPos = mainFrame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                dragStartPos.X.Scale,
                dragStartPos.X.Offset + delta.X,
                dragStartPos.Y.Scale,
                dragStartPos.Y.Offset + delta.Y
            )
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    -- Redimensionamento (cantinho inferior direito)
    local resizeHandle = Instance.new("TextButton")
    resizeHandle.Size = UDim2.new(0, 18, 0, 18)
    resizeHandle.Position = UDim2.new(1, -2, 1, -2)
    resizeHandle.AnchorPoint = Vector2.new(1, 1)
    resizeHandle.BackgroundTransparency = 1
    resizeHandle.Text = ""
    resizeHandle.AutoButtonColor = false
    resizeHandle.Parent = mainFrame
    local resizeIcon = Instance.new("ImageLabel")
    resizeIcon.Size = UDim2.new(0, 12, 0, 12)
    resizeIcon.Position = UDim2.new(0, 2, 0, 2)
    resizeIcon.BackgroundTransparency = 1
    resizeIcon.Image = "rbxassetid://6924631287"
    resizeIcon.ImageColor3 = Config.UI.TextColor
    resizeIcon.ScaleType = Enum.ScaleType.Fit
    resizeIcon.Parent = resizeHandle
    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = true
            resizeStartPos = input.Position
            resizeStartSize = mainFrame.AbsoluteSize
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - resizeStartPos
            local newWidth = math.max(Config.UI.MinWidth, resizeStartSize.X + delta.X)
            local newHeight = math.max(Config.UI.MinHeight, resizeStartSize.Y + delta.Y)
            mainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
            Config.UI.WindowWidth = newWidth
            Config.UI.WindowHeight = newHeight
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            resizing = false
        end
    end)

    -- Conteúdo
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 1, -40)
    content.Position = UDim2.new(0, 10, 0, 35)
    content.BackgroundTransparency = 1
    content.Parent = mainFrame

    local y = 5
    local function CreateToggle(text, configKey, callback, toggleId)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 28)
        frame.Position = UDim2.new(0, 0, 0, y)
        frame.BackgroundColor3 = Config.UI.SectionColor
        frame.BackgroundTransparency = 0.5
        frame.BorderSizePixel = 0
        frame.Parent = content
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
        Instance.new("UIStroke", frame).Color = Config.UI.BorderColor
        frame.UIStroke.Thickness = 0.5

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 120, 1, 0)
        label.Position = UDim2.new(0, 8, 0, 0)
        label.BackgroundTransparency = 1
        label.Text = text .. ": " .. (Config[configKey] and "ON" or "OFF")
        label.TextColor3 = Config.UI.TextColor
        label.Font = Enum.Font.Gotham
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local switch = Instance.new("Frame")
        switch.Size = UDim2.new(0, 38, 0, 18)
        switch.Position = UDim2.new(1, -46, 0.5, -9)
        switch.BackgroundColor3 = Config[configKey] and Config.UI.AccentColor or Color3.fromRGB(20, 30, 50)
        switch.BorderSizePixel = 0
        switch.Parent = frame
        Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 14, 0, 14)
        knob.Position = Config[configKey] and UDim2.new(0, 22, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        knob.BackgroundColor3 = Color3.fromRGB(220, 240, 255)
        knob.BorderSizePixel = 0
        knob.Parent = switch
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local function UpdateVisual()
            local enabled = Config[configKey]
            switch.BackgroundColor3 = enabled and Config.UI.AccentColor or Color3.fromRGB(20, 30, 50)
            knob.Position = enabled and UDim2.new(0, 22, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
            label.Text = text .. ": " .. (enabled and "ON" or "OFF")
        end

        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                Config[configKey] = not Config[configKey]
                UpdateVisual()
                if callback then callback(Config[configKey]) end
            end
        end)
        if toggleId then ToggleUpdates[toggleId] = UpdateVisual end
        return frame
    end

    local function CreateSlider(text, configKey, min, max, step, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 50)
        frame.Position = UDim2.new(0, 0, 0, y)
        frame.BackgroundColor3 = Config.UI.SectionColor
        frame.BackgroundTransparency = 0.5
        frame.BorderSizePixel = 0
        frame.Parent = content
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
        Instance.new("UIStroke", frame).Color = Config.UI.BorderColor
        frame.UIStroke.Thickness = 0.5

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -16, 0, 16)
        label.Position = UDim2.new(0, 8, 0, 4)
        label.BackgroundTransparency = 1
        label.Text = text .. ": " .. tostring(Config[configKey])
        label.TextColor3 = Config.UI.TextColor
        label.Font = Enum.Font.Gotham
        label.TextSize = 11
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local sliderBg = Instance.new("Frame")
        sliderBg.Size = UDim2.new(1, -16, 0, 5)
        sliderBg.Position = UDim2.new(0, 8, 0, 24)
        sliderBg.BackgroundColor3 = Color3.fromRGB(15, 25, 45)
        sliderBg.BorderSizePixel = 0
        sliderBg.Parent = frame
        Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(0, 2)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((Config[configKey] - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Config.UI.AccentColor
        fill.BorderSizePixel = 0
        fill.Parent = sliderBg
        Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 2)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 12, 0, 12)
        knob.Position = UDim2.new((Config[configKey] - min) / (max - min), -6, 0.5, -6)
        knob.BackgroundColor3 = Color3.fromRGB(220, 240, 255)
        knob.BorderSizePixel = 0
        knob.Parent = sliderBg
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local draggingSlider = false
        local function updateValue(inputX)
            local relX = math.clamp((inputX - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            local raw = min + (max - min) * relX
            local stepped = math.floor(raw / step + 0.5) * step
            local value = math.clamp(stepped, min, max)
            Config[configKey] = value
            label.Text = text .. ": " .. tostring(value)
            fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
            knob.Position = UDim2.new((value - min) / (max - min), -6, 0.5, -6)
            if callback then callback(value) end
        end
        sliderBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingSlider = true
                updateValue(input.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateValue(input.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = false end
        end)
        return frame
    end

    -- Toggle Ativar (sincronizado com T)
    CreateToggle("🔒 Ativar", "Enabled", function(val)
        if val then StartLockOn() else StopLockOn() end
    end, "LockOn")
    y = y + 32

    -- Mostrar FOV
    CreateToggle("⭕ Mostrar FOV", "ShowFOV", function() UpdateFOVCircle() end, "ShowFOV")
    y = y + 32

    -- Visível Apenas
    CreateToggle("👁️ Visível Apenas", "VisibleCheck")
    y = y + 32

    -- FOV Slider
    CreateSlider("FOV", "FOV", 50, 360, 5, function(val)
        if Config.Enabled then UpdateFOVCircle() end
    end)
    y = y + 55

    -- Team Check
    CreateToggle("🛡️ Team Check", "TeamCheck")
end

-- ========== TECLAS ==========
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if UserInputService:GetFocusedTextBox() then return end
    
    -- F1: alterna a visibilidade da interface
    if input.KeyCode == Config.UIToggleKey then
        if menuGui then
            local newState = not menuGui.Enabled
            menuGui.Enabled = newState
            if mainFrame and newState then
                mainFrame.Visible = true  -- garante que o frame principal esteja visível
            end
        end
        return
    end

    -- T: alterna o LockOn
    if input.KeyCode == Config.ToggleKey then
        -- Se a janela estiver invisível, mostra ela também (para feedback)
        if menuGui and not menuGui.Enabled then
            menuGui.Enabled = true
            if mainFrame then mainFrame.Visible = true end
        end
        Config.Enabled = not Config.Enabled
        Config.ShowFOV = Config.Enabled
        if Config.Enabled then StartLockOn() else StopLockOn() end
        if ToggleUpdates["LockOn"] then ToggleUpdates["LockOn"]() end
        if ToggleUpdates["ShowFOV"] then ToggleUpdates["ShowFOV"]() end
    end
end)

-- ========== INICIALIZAÇÃO ==========
print("[FrostHub LockOn v3] Carregado!")
print("F1 = Abrir/Fechar interface | T = Ativar/Desativar LockOn")
CreateMenu()
RunService.RenderStepped:Connect(UpdateFOVCircle)

-- Limpeza ao remover o script
LocalPlayer.PlayerRemoving:Connect(function()
    StopLockOn()
    if menuGui then menuGui:Destroy() end
end)