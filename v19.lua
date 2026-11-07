--[[
    ESP / WH + CHAMS + AIMBOT + TRIGGERBOT + SKELETON + HITBOX + FOV v19.1
    Полная версия. Поддержка Solara (gethui).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")

local Config = {
    Enabled = true, ColorVisible = Color3.fromRGB(0, 255, 0), ColorBehindWall = Color3.fromRGB(255, 0, 0),
    ShowBox = true, ShowName = true, ShowDistance = true, ShowHealth = true, ShowSkeleton = false,
    ShowBots = true, TeamCheck = false, WallCheckRaycast = true, MaxDistance = 1000,
    AimEnabled = false, AimFOV = 150, AimSmooth = 0.2, AimBind = Enum.KeyCode.X,
    TBEnabled = false, TBDelay = 0.05, TBTeamCheck = true, TBBind = Enum.KeyCode.Z,
    HBEnabled = false, HBSize = 15, FOVEnabled = false, FOVValue = 90
}

local function IsVisible(worldPos)
    if not Config.WallCheckRaycast then return true end
    local params = RaycastParams.new() params.FilterType = Enum.RaycastFilterType.Exclude
    local exclude = {Camera} if LocalPlayer.Character then table.insert(exclude, LocalPlayer.Character) end
    for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(exclude, p.Character) end end
    params.FilterDescendantsInstances = exclude
    local result = Workspace:Raycast(Camera.CFrame.Position, worldPos - Camera.CFrame.Position, params)
    if not result then return true end
    local model = result.Instance and result.Instance:FindFirstAncestorOfClass("Model")
    if model and model:FindFirstChildOfClass("Humanoid") then return true end
    return false
end
local function WorldToViewport(pos) local sp, onScreen = Camera:WorldToViewportPoint(pos) return Vector2.new(sp.X, sp.Y), sp.Z, onScreen end
local function NewDrawing(class, props) local ok, d = pcall(function() return Drawing.new(class) end) if not ok or not d then return nil end for k, v in pairs(props or {}) do pcall(function() d[k] = v end) end return d end
local function GetColor(info, visible) if info.teamColor and visible then return info.teamColor end return visible and Config.ColorVisible or Config.ColorBehindWall end

local Drawings = {}
local SkeletonR15 = { {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"}, {"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"}, {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"}, {"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"}, {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"} }
local SkeletonR6 = { {"Head","Torso"}, {"Torso","Left Arm"}, {"Torso","Right Arm"}, {"Torso","Left Leg"}, {"Torso","Right Leg"} }

local function CreateVisuals(model)
    local d = {
        box = Config.ShowBox and NewDrawing("Square", {Thickness=1, Filled=false, Visible=false}) or nil,
        name = Config.ShowName and NewDrawing("Text", {Center=true, Outline=true, Size=14, Font=2, Visible=false}) or nil,
        dist = Config.ShowDistance and NewDrawing("Text", {Center=true, Outline=true, Size=12, Font=2, Visible=false}) or nil,
        hpBg = Config.ShowHealth and NewDrawing("Square", {Thickness=1, Filled=true, Visible=false}) or nil,
        hpFg = Config.ShowHealth and NewDrawing("Square", {Thickness=0, Filled=true, Visible=false}) or nil,
        bones = {}
    }
    if Config.ShowSkeleton then
        local bonesList = model:FindFirstChild("UpperTorso") and SkeletonR15 or SkeletonR6
        for i = 1, #bonesList do local line = NewDrawing("Line", {Thickness=1, Visible=false}) if line then d.bones[i] = line end end
    end
    Drawings[model] = d
end
local function HideVisuals(d)
    if d.box then d.box.Visible = false end if d.name then d.name.Visible = false end if d.dist then d.dist.Visible = false end if d.hpBg then d.hpBg.Visible = false end if d.hpFg then d.hpFg.Visible = false end for _, line in pairs(d.bones) do line.Visible = false end
end
local function DestroyVisuals(model)
    local d = Drawings[model] if not d then return end
    for _, v in pairs(d) do if type(v) == "table" then for _, line in pairs(v) do pcall(function() line:Remove() end) end elseif v then pcall(function() v:Remove() end) end end
    Drawings[model] = nil
end
local function ClearAll() for model in pairs(Drawings) do DestroyVisuals(model) end end

local lastClick = 0
local function TriggerBot()
    if not Config.TBEnabled or tick() - lastClick < Config.TBDelay then return end
    local vp = Camera.ViewportSize local centerX, centerY = vp.X / 2, vp.Y / 2
    local unitRay = Camera:ViewportPointToRay(centerX, centerY)
    local params = RaycastParams.new() params.FilterType = Enum.RaycastFilterType.Exclude params.FilterDescendantsInstances = {Camera, LocalPlayer.Character}
    local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 2000, params)
    if result and result.Instance then
        local model = result.Instance:FindFirstAncestorOfClass("Model")
        if model then
            local hum = model:FindFirstChildOfClass("Humanoid") local plr = Players:GetPlayerFromCharacter(model)
            if hum and hum.Health > 0 then
                local isEnemy = true if Config.TBTeamCheck and plr and plr.Team == LocalPlayer.Team then isEnemy = false end
                if isEnemy then
                    lastClick = tick()
                    pcall(function() VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, true, game, 1) task.wait(0.01) VirtualInputManager:SendMouseButtonEvent(centerX, centerY, 0, false, game, 1) end)
                    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    if tool then tool:Activate() end
                end
            end
        end
    end
end

local function AimBot()
    if not Config.AimEnabled then 
        if Camera.CameraType == Enum.CameraType.Scriptable then Camera.CameraType = Enum.CameraType.Custom if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then Camera.CameraSubject = LocalPlayer.Character.Humanoid end end
        return 
    end
    local closest = nil local minDist = Config.AimFOV local vp = Camera.ViewportSize local cx, cy = vp.X / 2, vp.Y / 2
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Head") then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and (not Config.TeamCheck or p.Team ~= LocalPlayer.Team) then
                local sp, onScreen = Camera:WorldToViewportPoint(p.Character.Head.Position)
                if onScreen then local d2d = (Vector2.new(sp.X, sp.Y) - Vector2.new(cx, cy)).Magnitude if d2d < minDist then minDist = d2d closest = p.Character.Head end end
            end
        end
    end
    if closest and IsVisible(closest.Position) then
        if Camera.CameraType ~= Enum.CameraType.Scriptable then Camera.CameraType = Enum.CameraType.Scriptable end
        local targetCF = CFrame.new(Camera.CFrame.Position, closest.Position)
        if Config.AimSmooth > 0 then Camera.CFrame = Camera.CFrame:Lerp(targetCF, Config.AimSmooth) else Camera.CFrame = targetCF end
    else
        if Camera.CameraType == Enum.CameraType.Scriptable then Camera.CameraType = Enum.CameraType.Custom if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then Camera.CameraSubject = LocalPlayer.Character.Humanoid end end
    end
end

local function UpdateESP()
    local targets = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            if not Config.TeamCheck or p.Team ~= LocalPlayer.Team then
                local tc = nil if p.Team then tc = p.Team.TeamColor.Color end
                targets[p.Character] = { name = p.Name, teamColor = tc }
            end
        end
    end
    for model in pairs(Drawings) do if not targets[model] or not model.Parent then DestroyVisuals(model) end end
    local vp = Camera.ViewportSize
    for model, info in pairs(targets) do
        if not Drawings[model] then CreateVisuals(model) end
        local d = Drawings[model] local hrp = model:FindFirstChild("HumanoidRootPart") local head = model:FindFirstChild("Head")
        if not hrp or not head then HideVisuals(d) continue end
        local dist = (Camera.CFrame.Position - hrp.Position).Magnitude if dist > Config.MaxDistance then HideVisuals(d) continue end
        local visible = IsVisible(hrp.Position) local color = GetColor(info, visible)
        local sp, dp, on = WorldToViewport(hrp.Position) local hsp, hdp = WorldToViewport(head.Position + Vector3.new(0, 1, 0)) local fsp, fdp = WorldToViewport(hrp.Position - Vector3.new(0, 3, 0))
        if not on or dp <= 0 or hdp <= 0 or fdp <= 0 then HideVisuals(d) continue end
        local h = math.abs(fsp.Y - hsp.Y) local w = h * 0.6 if h < 5 or h > 800 then HideVisuals(d) continue end
        local x = sp.X - (w / 2) local y = hsp.Y
        if d.box then d.box.Visible = Config.ShowBox d.box.Color = color d.box.Size = Vector2.new(w, h) d.box.Position = Vector2.new(x, y) end
        if d.name then d.name.Visible = Config.ShowName d.name.Text = info.name d.name.Color = color d.name.Position = Vector2.new(sp.X, y - 18) end
        if d.dist then d.dist.Visible = Config.ShowDistance d.dist.Text = string.format("[%d]", math.floor(dist)) d.dist.Color = color d.dist.Position = Vector2.new(sp.X, y + h + 2) end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if d.hpBg and d.hpFg and hum and Config.ShowHealth then
            local pct = math.clamp(hum.Health / hum.MaxHealth, 0, 1) local barX = x - 6
            d.hpBg.Visible = true d.hpBg.Size = Vector2.new(3, h) d.hpBg.Position = Vector2.new(barX, y) d.hpBg.Color = Color3.new(0, 0, 0)
            d.hpFg.Visible = true d.hpFg.Size = Vector2.new(3, h * pct) d.hpFg.Position = Vector2.new(barX, y + h * (1 - pct))
            if pct < 0.3 then d.hpFg.Color = Color3.fromRGB(255, 0, 0) elseif pct < 0.6 then d.hpFg.Color = Color3.fromRGB(255, 255, 0) else d.hpFg.Color = Color3.fromRGB(0, 255, 0) end
        else if d.hpBg then d.hpBg.Visible = false end if d.hpFg then d.hpFg.Visible = false end end
        if Config.ShowSkeleton and d.bones then
            local bonesList = model:FindFirstChild("UpperTorso") and SkeletonR15 or SkeletonR6
            for i, pr in ipairs(bonesList) do
                local line = d.bones[i]
                if line then
                    local a = model:FindFirstChild(pr[1]) local b = model:FindFirstChild(pr[2])
                    if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                        local pa, da = WorldToViewport(a.Position) local pb, db = WorldToViewport(b.Position)
                        if da > 0 and db > 0 then line.Visible = true line.From = pa line.To = pb line.Color = color else line.Visible = false end
                    else line.Visible = false end
                end
            end
        end
    end
end

local frames = 0 local lastTime = tick() local WatermarkText
RunService.RenderStepped:Connect(function()
    frames = frames + 1
    if tick() - lastTime >= 1 then
        local fps = math.floor(frames / (tick() - lastTime)) local ping = 0 pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        if WatermarkText then WatermarkText.Text = string.format("FPS: %d | Ping: %dms", fps, ping) end
        frames = 0 lastTime = tick()
    end
    AimBot() TriggerBot()
    if Config.Enabled then UpdateESP() else for _, d in pairs(Drawings) do HideVisuals(d) end end
end)

RunService.Heartbeat:Connect(function()
    if Config.FOVEnabled then Camera.FieldOfView = Config.FOVValue end
    if Config.HBEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Head") then
                local head = p.Character.Head
                if head.Size ~= Vector3.new(Config.HBSize, Config.HBSize, Config.HBSize) then
                    head.Size = Vector3.new(Config.HBSize, Config.HBSize, Config.HBSize)
                end
            end
        end
    end
end)

local function Make(class, props, parent) local obj = Instance.new(class) for k, v in pairs(props or {}) do pcall(function() obj[k] = v end) end if parent then pcall(function() obj.Parent = parent end) end return obj end
local parentGui = (gethui and gethui()) or CoreGui
if parentGui:FindFirstChild("ESP_GUI") then parentGui.ESP_GUI:Destroy() end
local ScreenGui = Make("ScreenGui", {Name="ESP_GUI", ResetOnSpawn=false, IgnoreGuiInset=true, DisplayOrder=999})
pcall(function() ScreenGui.Parent = parentGui end)

local Watermark = Make("Frame", {Size=UDim2.new(0, 200, 0, 26), Position=UDim2.new(1, -220, 0, 20), BackgroundColor3=Color3.fromRGB(25,25,30), BackgroundTransparency=0.2, Parent=ScreenGui})
Make("UICorner", {CornerRadius=UDim.new(0,6)}, Watermark) Make("UIStroke", {Color=Color3.fromRGB(0,255,0), Thickness=1}, Watermark)
WatermarkText = Make("TextLabel", {Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text="FPS: -- | Ping: --", TextColor3=Color3.fromRGB(255,255,255), Font=Enum.Font.GothamBold, TextSize=12, Parent=Watermark})

local Main = Make("Frame", {Size=UDim2.new(0, 350, 0, 350), Position=UDim2.new(0, 20, 0, 80), BackgroundColor3=Color3.fromRGB(20, 20, 25), BorderSizePixel=0, Active=true, Parent=ScreenGui})
Make("UICorner", {CornerRadius=UDim.new(0, 10)}, Main) Make("UIStroke", {Color=Color3.fromRGB(60, 60, 70), Thickness=2}, Main)
local Header = Make("Frame", {Size=UDim2.new(1, 0, 0, 35), BackgroundColor3=Color3.fromRGB(30, 30, 40), BorderSizePixel=0, Parent=Main})
Make("UICorner", {CornerRadius=UDim.new(0, 10)}, Header)
Make("TextLabel", {Size=UDim2.new(1, -100, 1, 0), Position=UDim2.new(0, 12, 0, 0), BackgroundTransparency=1, Text="v19.1", TextColor3=Color3.fromRGB(230, 230, 230), Font=Enum.Font.GothamBlack, TextSize=16, TextXAlignment=Enum.TextXAlignment.Left, Parent=Header})
Make("TextButton", {Size=UDim2.new(0, 26, 0, 26), Position=UDim2.new(1, -30, 0.5, -13), BackgroundTransparency=1, Text="—", TextColor3=Color3.fromRGB(255, 200, 100), Font=Enum.Font.GothamBold, TextSize=18, Parent=Header}).MouseButton1Click:Connect(function() Main.Visible = false end)

local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true dragStart = input.Position startPos = Main.Position end end)
UserInputService.InputChanged:Connect(function(input) if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then local delta = input.Position - dragStart Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)

local Scroll = Make("ScrollingFrame", {Size=UDim2.new(1, -16, 1, -50), Position=UDim2.new(0, 8, 0, 42), BackgroundTransparency=1, BorderSizePixel=0, ScrollBarThickness=4, CanvasSize=UDim2.new(0,0,0,0), AutomaticCanvasSize=Enum.AutomaticSize.Y, Parent=Main})
Make("UIListLayout", {Padding=UDim.new(0, 6), SortOrder=Enum.SortOrder.LayoutOrder}, Scroll)
local Order = 0 local function NextOrder() Order += 1 return Order end

local function CreateTab(title, color)
    local TabFrame = Make("Frame", {Size=UDim2.new(1, 0, 0, 30), BackgroundColor3=Color3.fromRGB(35, 35, 45), BorderSizePixel=0, LayoutOrder=NextOrder(), Parent=Scroll})
    Make("UICorner", {CornerRadius=UDim.new(0, 6)}, TabFrame)
    local Content = Make("Frame", {Size=UDim2.new(1, 0, 0, 0), BackgroundTransparency=1, ClipsDescendants=true, LayoutOrder=NextOrder(), Parent=Scroll})
    local ContentLayout = Make("UIListLayout", {Padding=UDim.new(0, 4), SortOrder=Enum.SortOrder.LayoutOrder}, Content)
    Make("TextLabel", {Size=UDim2.new(1, -40, 1, 0), Position=UDim2.new(0, 10, 0, 0), BackgroundTransparency=1, Text=title, TextColor3=color or Color3.fromRGB(255,255,255), Font=Enum.Font.GothamBold, TextSize=13, TextXAlignment=Enum.TextXAlignment.Left, Parent=TabFrame})
    local Arrow = Make("TextLabel", {Size=UDim2.new(0, 30, 1, 0), Position=UDim2.new(1, -30, 0, 0), BackgroundTransparency=1, Text="▼", TextColor3=Color3.fromRGB(200,200,200), Font=Enum.Font.GothamBold, TextSize=14, Parent=TabFrame})
    local isOpen = false
    TabFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isOpen = not isOpen
            Arrow.Text = isOpen and "▲" or "▼"
            TweenService:Create(Content, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Size = isOpen and UDim2.new(1, 0, 0, ContentLayout.AbsoluteContentSize.Y) or UDim2.new(1, 0, 0, 0)}):Play()
        end
    end)
    return Content
end

local function AddToggle(parent, text, default, callback)
    local row = Make("Frame", {Size=UDim2.new(1, 0, 0, 24), BackgroundTransparency=1, LayoutOrder=NextOrder(), Parent=parent})
    local btn = Make("TextButton", {Size=UDim2.new(0, 16, 0, 16), Position=UDim2.new(0, 4, 0.5, -8), BackgroundColor3=default and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 70), Text="", BorderSizePixel=0, AutoButtonColor=false, Parent=row})
    Make("UICorner", {CornerRadius=UDim.new(0, 4)}, btn)
    Make("TextLabel", {Size=UDim2.new(1, -30, 1, 0), Position=UDim2.new(0, 28, 0, 0), BackgroundTransparency=1, Text=text, TextColor3=Color3.fromRGB(220, 220, 220), Font=Enum.Font.Gotham, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local state = default
    btn.MouseButton1Click:Connect(function() state = not state btn.BackgroundColor3 = state and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 70) callback(state) end)
end
local function AddSlider(parent, text, min, max, default, callback)
    local row = Make("Frame", {Size=UDim2.new(1, 0, 0, 46), BackgroundTransparency=1, LayoutOrder=NextOrder(), Parent=parent})
    local label = Make("TextLabel", {Size=UDim2.new(1, -8, 0, 18), Position=UDim2.new(0, 4, 0, 0), BackgroundTransparency=1, Text=text .. ": " .. default, TextColor3=Color3.fromRGB(220, 220, 220), Font=Enum.Font.Gotham, TextSize=12, TextXAlignment=Enum.TextXAlignment.Left, Parent=row})
    local barBg = Make("Frame", {Size=UDim2.new(1, -8, 0, 6), Position=UDim2.new(0, 4, 0, 26), BackgroundColor3=Color3.fromRGB(60, 60, 70), BorderSizePixel=0, Parent=row})
    Make("UICorner", {CornerRadius=UDim.new(1, 0)}, barBg)
    local fill = Make("Frame", {Size=UDim2.new((default - min) / (max - min), 0, 1, 0), BackgroundColor3=Color3.fromRGB(0, 180, 255), BorderSizePixel=0, Parent=barBg})
    Make("UICorner", {CornerRadius=UDim.new(1, 0)}, fill)
    local dragging = false
    local function Update(input) local rel = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1) local val = math.floor(min + (max - min) * rel + 0.5) fill.Size = UDim2.new(rel, 0, 1, 0) label.Text = text .. ": " .. val callback(val) end
    barBg.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true Update(input) end end)
    UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then Update(input) end end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
end

local EspTab = CreateTab("ESP / Визуал", Color3.fromRGB(0, 255, 0))
AddToggle(EspTab, "ESP вкл", Config.Enabled, function(v) Config.Enabled = v if not v then ClearAll() end end)
AddToggle(EspTab, "Бокс", Config.ShowBox, function(v) Config.ShowBox = v ClearAll() end)
AddToggle(EspTab, "Имя", Config.ShowName, function(v) Config.ShowName = v ClearAll() end)
AddToggle(EspTab, "Дистанция", Config.ShowDistance, function(v) Config.ShowDistance = v ClearAll() end)
AddToggle(EspTab, "HP", Config.ShowHealth, function(v) Config.ShowHealth = v ClearAll() end)
AddToggle(EspTab, "Скелет", Config.ShowSkeleton, function(v) Config.ShowSkeleton = v ClearAll() end)
AddSlider(EspTab, "Макс. дистанция", 50, 3000, Config.MaxDistance, function(v) Config.MaxDistance = v end)

local AimTab = CreateTab("Aimbot / Наведение", Color3.fromRGB(255, 100, 100))
local abTg = Make("TextButton", {Size=UDim2.new(1, -8, 0, 26), BackgroundColor3=Config.AimEnabled and Color3.fromRGB(0,180,60) or Color3.fromRGB(60,60,80), Text=Config.AimEnabled and "AIMBOT: ON" or "AIMBOT: OFF", TextColor3=Color3.fromRGB(255,255,255), Font=Enum.Font.GothamBold, TextSize=12, BorderSizePixel=0, Parent=AimTab, LayoutOrder=NextOrder()})
Make("UICorner", {CornerRadius=UDim.new(0,4)}, abTg)
abTg.MouseButton1Click:Connect(function() Config.AimEnabled = not Config.AimEnabled abTg.BackgroundColor3 = Config.AimEnabled and Color3.fromRGB(0,180,60) or Color3.fromRGB(60,60,80) abTg.Text = Config.AimEnabled and "AIMBOT: ON" or "AIMBOT: OFF" end)
AddSlider(AimTab, "Плавность", 1, 100, Config.AimSmooth * 100, function(v) Config.AimSmooth = v / 100 end)
AddSlider(AimTab, "Радиус FOV", 50, 500, Config.AimFOV, function(v) Config.AimFOV = v end)

local TBTab = CreateTab("Triggerbot / Авто-стрельба", Color3.fromRGB(255, 200, 100))
local tbTg = Make("TextButton", {Size=UDim2.new(1, -8, 0, 26), BackgroundColor3=Config.TBEnabled and Color3.fromRGB(0,180,60) or Color3.fromRGB(60,60,80), Text=Config.TBEnabled and "TRIGGERBOT: ON" or "TRIGGERBOT: OFF", TextColor3=Color3.fromRGB(255,255,255), Font=Enum.Font.GothamBold, TextSize=12, BorderSizePixel=0, Parent=TBTab, LayoutOrder=NextOrder()})
Make("UICorner", {CornerRadius=UDim.new(0,4)}, tbTg)
tbTg.MouseButton1Click:Connect(function() Config.TBEnabled = not Config.TBEnabled tbTg.BackgroundColor3 = Config.TBEnabled and Color3.fromRGB(0,180,60) or Color3.fromRGB(60,60,80) tbTg.Text = Config.TBEnabled and "TRIGGERBOT: ON" or "TRIGGERBOT: OFF" end)
AddSlider(TBTab, "Задержка (мс)", 10, 500, Config.TBDelay * 1000, function(v) Config.TBDelay = v / 1000 end)

local HBTab = CreateTab("Hitbox / Хитбокс", Color3.fromRGB(100, 200, 255))
AddToggle(HBTab, "Увеличить хитбокс (Голова)", Config.HBEnabled, function(v) Config.HBEnabled = v end)
AddSlider(HBTab, "Размер хитбокса", 5, 100, Config.HBSize, function(v) Config.HBSize = v end)

local FOVTab = CreateTab("FOV / Обзор", Color3.fromRGB(200, 100, 255))
AddToggle(FOVTab, "Изменить FOV", Config.FOVEnabled, function(v) Config.FOVEnabled = v if not v then Camera.FieldOfView = 70 end end)
AddSlider(FOVTab, "Значение FOV", 50, 120, Config.FOVValue, function(v) Config.FOVValue = v end)

local BindTab = CreateTab("Настройки биндов", Color3.fromRGB(255, 255, 255))
local aimBindBtn = Make("TextButton", {Size=UDim2.new(1, -8, 0, 26), BackgroundColor3=Color3.fromRGB(60,60,80), Text="Бинд Аимбота: " .. Config.AimBind.Name, TextColor3=Color3.fromRGB(255,255,255), Font=Enum.Font.GothamBold, TextSize=12, BorderSizePixel=0, Parent=BindTab, LayoutOrder=NextOrder()})
Make("UICorner", {CornerRadius=UDim.new(0,4)}, aimBindBtn)
local isBindingAim = false
aimBindBtn.MouseButton1Click:Connect(function() isBindingAim = true aimBindBtn.Text = "Нажмите клавишу..." aimBindBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40) end)
local tbBindBtn = Make("TextButton", {Size=UDim2.new(1, -8, 0, 26), BackgroundColor3=Color3.fromRGB(60,60,80), Text="Бинд Триггербота: " .. Config.TBBind.Name, TextColor3=Color3.fromRGB(255,255,255), Font=Enum.Font.GothamBold, TextSize=12, BorderSizePixel=0, Parent=BindTab, LayoutOrder=NextOrder()})
Make("UICorner", {CornerRadius=UDim.new(0,4)}, tbBindBtn)
local isBindingTB = false
tbBindBtn.MouseButton1Click:Connect(function() isBindingTB = true tbBindBtn.Text = "Нажмите клавишу..." tbBindBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40) end)

local function UnloadScript()
    ClearAll()
    for model, data in pairs(Drawings) do
        for _, obj in pairs(data) do
            if type(obj) == "table" then
                for _, line in pairs(obj) do pcall(function() line:Remove() end) end
            elseif obj then
                pcall(function() obj:Remove() end)
            end
        end
    end
    pcall(function() Camera.CameraType = Enum.CameraType.Custom if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then Camera.CameraSubject = LocalPlayer.Character.Humanoid end end)
    pcall(function() ScreenGui:Destroy() end)
    print("[ESP] Выгружено.")
end

Make("TextButton", {Size=UDim2.new(1, -16, 0, 26), Position=UDim2.new(0, 8, 1, -34), BackgroundColor3=Color3.fromRGB(180, 40, 40), Text="Выгрузить всё", TextColor3=Color3.fromRGB(255, 255, 255), Font=Enum.Font.GothamBold, TextSize=12, BorderSizePixel=0, Parent=Main}).MouseButton1Click:Connect(UnloadScript)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if isBindingAim then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            Config.AimBind = input.KeyCode
            isBindingAim = false
            aimBindBtn.Text = "Бинд Аимбота: " .. Config.AimBind.Name
            aimBindBtn.BackgroundColor3 = Color3.fromRGB(60,60,80)
        end
        return
    end
    if isBindingTB then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            Config.TBBind = input.KeyCode
            isBindingTB = false
            tbBindBtn.Text = "Бинд Триггербота: " .. Config.TBBind.Name
            tbBindBtn.BackgroundColor3 = Color3.fromRGB(60,60,80)
        end
        return
    end
    if input.KeyCode == Config.AimBind then
        Config.AimEnabled = not Config.AimEnabled
        if abTg then 
            abTg.BackgroundColor3 = Config.AimEnabled and Color3.fromRGB(0,180,60) or Color3.fromRGB(60,60,80)
            abTg.Text = Config.AimEnabled and "AIMBOT: ON" or "AIMBOT: OFF"
        end
    end
    if input.KeyCode == Config.TBBind then
        Config.TBEnabled = not Config.TBEnabled
        if tbTg then 
            tbTg.BackgroundColor3 = Config.TBEnabled and Color3.fromRGB(0,180,60) or Color3.fromRGB(60,60,80)
            tbTg.Text = Config.TBEnabled and "TRIGGERBOT: ON" or "TRIGGERBOT: OFF"
        end
    end
    if input.KeyCode == Enum.KeyCode.RightShift then
        Main.Visible = not Main.Visible
    end
end)

print("[ESP] v19.1 loaded.")
