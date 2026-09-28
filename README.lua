-- ==========================================================
-- PROJECT NOVA | FOOTBALL EDITION
-- Ball Trail + Trajectory + Landing Prediction + ESP
-- ==========================================================

local Weave = loadstring(game:HttpGet("https://raw.githubusercontent.com/SvenaEE/Testlibary-/refs/heads/main/Weave-Release"))()

local Window = Weave:CreateWindow({
    Name = "Project Nova | Football",
    LoadingSubtitle = "Ball Tracker v1",
    ConfigurationSaving = { Enabled = true, FolderName = nil, FileName = "ProjectNova_Ball" },
    KeySystem = false,
    ToggleKey = Enum.KeyCode.RightShift
})

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Heartbeat = RunService.Heartbeat
local RenderStepped = RunService.RenderStepped

if not Drawing or not Drawing.new then
    Weave:Notify({Title = "ERROR", Content = "Drawing API не поддерживается!", Duration = 10})
    return
end

local CONFIG = { Gravity = Workspace.Gravity or 196.2 }
local function Notify(t, d, dur) Weave:Notify({ Title = t, Content = d, Duration = dur or 3 }) end
local function GetHRP(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function GetHum(p) return p.Character and p.Character:FindFirstChildOfClass("Humanoid") end

-- ==========================================================
-- BALL FINDER
-- ==========================================================
local BallFinder = {
    ManualBall = nil,
    AutoDetect = true,
    BallPart = nil,
}

local function IsBallPart(part)
    if not part or not part:IsA("BasePart") then return false end
    local n = string.lower(part.Name)
    local keywords = {"ball", "soccer", "football", "sphere", "matchball"}
    for _, kw in ipairs(keywords) do
        if n:find(kw) then return true end
    end
    return false
end

local function FindBall()
    if BallFinder.ManualBall and BallFinder.ManualBall.Parent then
        return BallFinder.ManualBall
    end
    if not BallFinder.AutoDetect then return nil end
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if IsBallPart(desc) then
            return desc
        end
    end
    return nil
end

-- Обновление раз в секунду
task.spawn(function()
    while task.wait(1) do
        if BallFinder.AutoDetect and (not BallFinder.BallPart or not BallFinder.BallPart.Parent) then
            BallFinder.BallPart = FindBall()
        end
    end
end)

-- ==========================================================
-- BALL TRAIL
-- ==========================================================
local BallTrail = {
    Enabled = false,
    Color = Color3.fromRGB(0, 255, 100),
    Lifetime = 1,
    Width = 1.5,
    LightEmission = 1,
}
local ballTrailObject = nil

local function AttachBallTrail(ball)
    if not ball then return end
    if ballTrailObject and ballTrailObject.Parent then
        ballTrailObject:Destroy()
    end
    if not BallTrail.Enabled then return end

    local a0 = Instance.new("Attachment", ball); a0.Position = Vector3.new(0, 0, 0)
    local a1 = Instance.new("Attachment", ball); a1.Position = Vector3.new(0, 0, -1.5)

    local trail = Instance.new("Trail", ball)
    trail.Name = "NovaBallTrail"
    trail.Attachment0 = a0
    trail.Attachment1 = a1
    trail.Lifetime = BallTrail.Lifetime
    trail.MinLength = 0
    trail.WidthScale = NumberSequence.new(BallTrail.Width)
    trail.Color = ColorSequence.new(BallTrail.Color)
    trail.LightEmission = BallTrail.LightEmission
    trail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    trail.FaceCamera = true
    ballTrailObject = trail
end

-- ==========================================================
-- BALL CHAMS
-- ==========================================================
local BallChams = { Enabled = false, Color = Color3.fromRGB(0, 255, 100), Transparency = 0.3 }
local ballHighlight = nil

local function UpdateBallChams(ball)
    if not ball then
        if ballHighlight then ballHighlight:Destroy(); ballHighlight = nil end
        return
    end
    if BallChams.Enabled then
        if not ballHighlight or ballHighlight.Adornee ~= ball then
            if ballHighlight then ballHighlight:Destroy() end
            ballHighlight = Instance.new("Highlight")
            ballHighlight.Adornee = ball
            ballHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            ballHighlight.OutlineTransparency = 1
            ballHighlight.Parent = ball
        end
        ballHighlight.FillColor = BallChams.Color
        ballHighlight.FillTransparency = BallChams.Transparency
        ballHighlight.OutlineTransparency = 1
        ballHighlight.Enabled = true
    elseif ballHighlight then
        ballHighlight:Destroy()
        ballHighlight = nil
    end
end

-- ==========================================================
-- TRAJECTORY + LANDING PREDICTION
-- ==========================================================
local Trajectory = {
    Enabled = false,
    Color = Color3.fromRGB(255, 255, 0),
    Thickness = 2,
    MaxPoints = 60,
    TimeStep = 0.05,
    ShowLandingMarker = true,
    LandingColor = Color3.fromRGB(255, 50, 50),
}

local trajectoryLines = {}
local landingMarker = nil
local landingHighlight = nil

-- Создать или обновить landing marker
local function EnsureLandingMarker()
    if landingMarker and landingMarker.Parent then return end
    landingMarker = Instance.new("Part")
    landingMarker.Name = "NovaLandingMarker"
    landingMarker.Shape = Enum.PartType.Cylinder
    landingMarker.Size = Vector3.new(0.2, 5, 5)
    landingMarker.Color = Trajectory.LandingColor
    landingMarker.Material = Enum.Material.Neon
    landingMarker.Transparency = 0.4
    landingMarker.CanCollide = false
    landingMarker.CanQuery = false
    landingMarker.CanTouch = false
    landingMarker.Anchored = true
    landingMarker.Parent = Workspace

    landingHighlight = Instance.new("Highlight")
    landingHighlight.Adornee = landingMarker
    landingHighlight.FillColor = Trajectory.LandingColor
    landingHighlight.FillTransparency = 0.5
    landingHighlight.OutlineTransparency = 1
    landingHighlight.Parent = landingMarker
end

local function HideLandingMarker()
    if landingMarker then landingMarker:Destroy(); landingMarker = nil end
    if landingHighlight then landingHighlight:Destroy(); landingHighlight = nil end
end

-- Расчёт траектории
local function CalculateTrajectory(ball, maxTime)
    local points = {}
    local pos = ball.Position
    local vel = ball.AssemblyLinearVelocity
    if not vel then vel = Vector3.new(0,0,0) end
    local gravity = CONFIG.Gravity

    local t = 0
    local steps = Trajectory.MaxPoints
    local dt = Trajectory.TimeStep

    for i = 1, steps do
        t += dt
        if t > maxTime then break end
        local p = pos + vel * t - Vector3.new(0, 0.5 * gravity * t * t, 0)
        table.insert(points, p)

        -- Проверка столкновения с землёй
        if i > 1 then
            local prev = points[i-1]
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = {ball, landingMarker}
            rayParams.IgnoreWater = true
            local res = Workspace:Raycast(prev, p - prev, rayParams)
            if res then
                table.insert(points, res.Position)
                return points, res.Position
            end
        end
    end
    return points, points[#points]
end

-- Обновление линий
RenderStepped:Connect(function()
    -- Скрываем всё если выключено
    if not Trajectory.Enabled then
        for _, line in ipairs(trajectoryLines) do line.Visible = false end
        HideLandingMarker()
        return
    end

    local ball = BallFinder.BallPart
    if not ball or not ball.Parent then
        for _, line in ipairs(trajectoryLines) do line.Visible = false end
        HideLandingMarker()
        return
    end

    -- Пересчитываем траекторию
    local points, landingPos = CalculateTrajectory(ball, 5)

    -- Рисуем линии
    for i, line in ipairs(trajectoryLines) do
        line.Visible = false
    end

    for i = 1, #points - 1 do
        local line = trajectoryLines[i]
        if not line then
            line = Drawing.new("Line")
            line.Color = Trajectory.Color
            line.Thickness = Trajectory.Thickness
            line.Transparency = 1
            trajectoryLines[i] = line
        end
        local p1 = Camera:WorldToViewportPoint(points[i])
        local p2 = Camera:WorldToViewportPoint(points[i+1])
        if p1.Z > 0 and p2.Z > 0 then
            line.From = Vector2.new(p1.X, p1.Y)
            line.To = Vector2.new(p2.X, p2.Y)
            line.Color = Trajectory.Color
            line.Thickness = Trajectory.Thickness
            line.Visible = true
        else
            line.Visible = false
        end
    end

    -- Landing marker
    if Trajectory.ShowLandingMarker and landingPos then
        EnsureLandingMarker()
        if landingMarker then
            landingMarker.CFrame = CFrame.new(landingPos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
            landingMarker.Color = Trajectory.LandingColor
            landingMarker.Transparency = 0.4
            if landingHighlight then
                landingHighlight.FillColor = Trajectory.LandingColor
            end
        end
    else
        HideLandingMarker()
    end
end)

-- ==========================================================
-- GOAL LINE (линия от игрока до ворот)
-- ==========================================================
local GoalLine = {
    Enabled = false,
    Color = Color3.fromRGB(0, 255, 255),
    Thickness = 2,
    TargetPoint = nil,
}
local goalLine = nil

local function FindGoal()
    -- ищем ворота по имени
    local keywords = {"goal", "net", "target"}
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("BasePart") then
            local n = string.lower(desc.Name)
            for _, kw in ipairs(keywords) do
                if n:find(kw) then return desc end
            end
        end
    end
    return nil
end

RenderStepped:Connect(function()
    if not GoalLine.Enabled then
        if goalLine then goalLine.Visible = false end
        return
    end
    if not goalLine then
        goalLine = Drawing.new("Line")
        goalLine.Thickness = GoalLine.Thickness
        goalLine.Transparency = 1
    end
    local myHRP = GetHRP(LocalPlayer)
    if not myHRP then goalLine.Visible = false; return end

    local target = GoalLine.TargetPoint
    if not target then
        local goalPart = FindGoal()
        if goalPart then
            target = goalPart.Position
        else
            goalLine.Visible = false
            return
        end
    end

    local p1 = Camera:WorldToViewportPoint(myHRP.Position)
    local p2 = Camera:WorldToViewportPoint(target)
    if p1.Z > 0 and p2.Z > 0 then
        goalLine.From = Vector2.new(p1.X, p1.Y)
        goalLine.To = Vector2.new(p2.X, p2.Y)
        goalLine.Color = GoalLine.Color
        goalLine.Thickness = GoalLine.Thickness
        goalLine.Visible = true
    else
        goalLine.Visible = false
    end
end)

-- ==========================================================
-- BALL ESP (Box вокруг мяча)
-- ==========================================================
local BallESP = {
    Enabled = false,
    Color = Color3.fromRGB(255, 200, 50),
    Thickness = 2,
}
local ballBox = nil

RenderStepped:Connect(function()
    if not BallESP.Enabled then
        if ballBox then ballBox.Visible = false end
        return
    end
    local ball = BallFinder.BallPart
    if not ball or not ball.Parent then
        if ballBox then ballBox.Visible = false end
        return
    end
    if not ballBox then
        ballBox = Drawing.new("Square")
        ballBox.Filled = false
    end
    local sp = Camera:WorldToViewportPoint(ball.Position)
    if sp.Z > 0 then
        local size = math.clamp(2000 / sp.Z, 8, 200)
        ballBox.Size = Vector2.new(size, size)
        ballBox.Position = Vector2.new(sp.X - size/2, sp.Y - size/2)
        ballBox.Color = BallESP.Color
        ballBox.Thickness = BallESP.Thickness
        ballBox.Transparency = 1
        ballBox.Visible = true
    else
        ballBox.Visible = false
    end
end)

-- ==========================================================
-- UPDATE TRAIL & CHAMS
-- ==========================================================
RenderStepped:Connect(function()
    local ball = BallFinder.BallPart
    if ball and ball.Parent then
        if BallTrail.Enabled and (not ballTrailObject or ballTrailObject.Parent ~= ball) then
            AttachBallTrail(ball)
        elseif not BallTrail.Enabled and ballTrailObject then
            ballTrailObject:Destroy()
            ballTrailObject = nil
        end
        UpdateBallChams(ball)
    else
        if ballTrailObject then ballTrailObject:Destroy(); ballTrailObject = nil end
        UpdateBallChams(nil)
    end
end)

-- ==========================================================
-- WATERMARK
-- ==========================================================
local wmGui = Instance.new("ScreenGui", PlayerGui)
wmGui.Name = "NovaBallWatermark"; wmGui.ResetOnSpawn = false
wmGui.DisplayOrder = 999999
local wmFrame = Instance.new("Frame", wmGui)
wmFrame.Size = UDim2.fromOffset(240, 32)
wmFrame.Position = UDim2.new(1, -250, 0, 10)
wmFrame.BackgroundColor3 = Color3.fromRGB(15,15,20)
wmFrame.BorderSizePixel = 0
Instance.new("UICorner", wmFrame).CornerRadius = UDim.new(0,8)
local wmLabel = Instance.new("TextLabel", wmFrame)
wmLabel.Size = UDim2.new(1, -40, 1, 0)
wmLabel.Position = UDim2.fromOffset(10, 0)
wmLabel.BackgroundTransparency = 1
wmLabel.Text = "Project Nova | Ball"
wmLabel.TextColor3 = Color3.fromRGB(0,255,100)
wmLabel.TextSize = 13
wmLabel.Font = Enum.Font.GothamBold
wmLabel.TextXAlignment = Enum.TextXAlignment.Left
local wmBtn = Instance.new("TextButton", wmFrame)
wmBtn.Size = UDim2.fromOffset(30, 26)
wmBtn.Position = UDim2.new(1, -32, 0, 3)
wmBtn.BackgroundTransparency = 1
wmBtn.Text = "O"
wmBtn.TextColor3 = Color3.fromRGB(0,255,100)
wmBtn.TextSize = 18
wmBtn.Font = Enum.Font.GothamBold

local menuOpen = true
wmBtn.MouseButton1Click:Connect(function()
    menuOpen = not menuOpen
    if Window.SetVisible then Window:SetVisible(menuOpen) elseif Window.Toggle then Window:Toggle() end
    wmBtn.Text = menuOpen and "O" or "X"
    wmBtn.TextColor3 = menuOpen and Color3.fromRGB(0,255,100) or Color3.fromRGB(255,65,65)
end)

local dragging, dragStart, startPos = false, nil, nil
wmFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = wmFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        wmFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ==========================================================
-- UI
-- ==========================================================
local BTab = Window:CreateTab("Ball", "circle")

local BTSec = BTab:CreateSection("Ball Trail")
BTSec:CreateToggle({ Name = "Enabled", CurrentValue = false, Callback = function(v) BallTrail.Enabled = v end })
BTSec:CreateColorPicker({ Name = "Color", Color = BallTrail.Color, Callback = function(c) BallTrail.Color = c; if ballTrailObject then ballTrailObject.Color = ColorSequence.new(c) end end })
BTSec:CreateSlider({ Name = "Lifetime", Range = {1,50}, CurrentValue = 10, Callback = function(v) BallTrail.Lifetime = v/10; if ballTrailObject then ballTrailObject.Lifetime = v/10 end end })
BTSec:CreateSlider({ Name = "Width", Range = {5,50}, CurrentValue = 15, Callback = function(v) BallTrail.Width = v/10; if ballTrailObject then ballTrailObject.WidthScale = NumberSequence.new(v/10) end end })

local BCSec = BTab:CreateSection("Ball Chams")
BCSec:CreateToggle({ Name = "Enabled", CurrentValue = false, Callback = function(v) BallChams.Enabled = v end })
BCSec:CreateColorPicker({ Name = "Color", Color = BallChams.Color, Callback = function(c) BallChams.Color = c end })
BCSec:CreateSlider({ Name = "Transparency", Range = {0,95}, CurrentValue = 30, Callback = function(v) BallChams.Transparency = v/100 end })

local BESec = BTab:CreateSection("Ball ESP")
BESec:CreateToggle({ Name = "Enabled", CurrentValue = false, Callback = function(v) BallESP.Enabled = v end })
BESec:CreateColorPicker({ Name = "Color", Color = BallESP.Color, Callback = function(c) BallESP.Color = c end })
BESec:CreateSlider({ Name = "Thickness", Range = {1,5}, CurrentValue = 2, Callback = function(v) BallESP.Thickness = v end })

local TTab = Window:CreateTab("Trajectory", "trending-up")

local TSec = TTab:CreateSection("Trajectory Prediction")
TSec:CreateToggle({ Name = "Enabled", CurrentValue = false, Callback = function(v) Trajectory.Enabled = v end })
TSec:CreateColorPicker({ Name = "Line Color", Color = Trajectory.Color, Callback = function(c) Trajectory.Color = c end })
TSec:CreateColorPicker({ Name = "Landing Color", Color = Trajectory.LandingColor, Callback = function(c) Trajectory.LandingColor = c end })
TSec:CreateSlider({ Name = "Line Thickness", Range = {1,5}, CurrentValue = 2, Callback = function(v) Trajectory.Thickness = v end })
TSec:CreateSlider({ Name = "Max Points", Range = {10,150}, CurrentValue = 60, Callback = function(v) Trajectory.MaxPoints = v end })
TSec:CreateToggle({ Name = "Show Landing Marker", CurrentValue = true, Callback = function(v) Trajectory.ShowLandingMarker = v end })

local GTab = Window:CreateTab("Goal Line", "target")
local GSec = GTab:CreateSection("Goal Line")
GSec:CreateToggle({ Name = "Enabled", CurrentValue = false, Callback = function(v) GoalLine.Enabled = v end })
GSec:CreateColorPicker({ Name = "Color", Color = GoalLine.Color, Callback = function(c) GoalLine.Color = c end })

local STab = Window:CreateTab("Settings", "settings")
local SSec = STab:CreateSection("Ball Detection")
SSec:CreateToggle({ Name = "Auto Detect Ball", CurrentValue = true, Callback = function(v) BallFinder.AutoDetect = v end })
SSec:CreateButton({ Name = "Re-Scan Ball", Callback = function()
    BallFinder.BallPart = FindBall()
    if BallFinder.BallPart then
        Notify("Ball Found", BallFinder.BallPart.Name, 2)
    else
        Notify("Ball Not Found", "Try selecting manually", 2)
    end
end })
SSec:CreateSlider({ Name = "Gravity Override", Range = {50,300}, CurrentValue = 196, Callback = function(v) CONFIG.Gravity = v end })

Notify("Project Nova | Football", "Ball Tracker loaded! Stand near ball.", 5)
