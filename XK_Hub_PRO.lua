--[[
    XK HUB · PRO — 基于 RemSpy 抓包逆向的客户端脚本 (Roblox 执行器)
    ------------------------------------------------------------------
    抓包分析结果:
      Actions:  Fire / Fire_2 (主武器), FireProjectileWeapon (RPG),
                 MeleeRequest (近战), Lava (熔岩)
      Comm:     DamageIndicator / CashIndicator / Ammo / Notification /
                Hitmarker / SoundEffect / CameraShake
      目标:     workspace.ActiveZombies (BodyHitbox 为命中盒)
      武器:     Character 下的 M1911 / MP9 / HK MG4 / M4 Benelli 等,
                各含 .Handler 与 .Exit (开火点)
    UI: 套用 Wind_UI-XK.lua 的 WindUI + 渐变边框示例
--]]

------------------------------------------------------------------
-- 0. WindUI 加载
------------------------------------------------------------------
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
WindUI.TransparencyValue = 0.2
WindUI:SetTheme("Dark")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local LocalPlayer      = Players.LocalPlayer

local function char()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end
local function root()
    return char():FindFirstChild("HumanoidRootPart")
end
local function humanoid()
    return char():FindFirstChildOfClass("Humanoid")
end

local Events = ReplicatedStorage:WaitForChild("Events")
local Actions = Events:WaitForChild("Actions")

local R = {
    Fire        = Actions:FindFirstChild("Fire"),
    Fire2       = Actions:FindFirstChild("Fire_2"),
    Projectile  = Actions:FindFirstChild("FireProjectileWeapon"),
    Melee       = Actions:FindFirstChild("MeleeRequest"),
    Lava        = Actions:FindFirstChild("Lava"),
}

------------------------------------------------------------------
-- 1. 全局状态
------------------------------------------------------------------
local S = {
    -- 自动开火
    autofire   = false,
    fireRate   = 20,    -- 发/秒
    burst      = 0,     -- 0=无限
    burstGap   = 0.3,
    lastShot   = 0,
    firedInBurst = 0,
    -- 自动瞄准
    autoAim    = false,
    aimRadius  = 300,
    aimTarget  = nil,
    -- 加速
    speed      = false,
    speedMult  = 3,
    baseSpeed  = 16,
    -- NoClip
    noclip     = false,
    -- ESP
    esp        = false,
    espColor   = Color3.fromRGB(0, 229, 255),
    espRefresh = 0.4,
    -- 透视墙 (墙体透明度)
    wallXray   = false,
    -- 日志
    logging    = true,
    -- 击杀统计
    kills      = 0,
    shots      = 0,
}

local function Log(...)
    if not S.logging then return end
    local a = {}
    for i = 1, select('#', ...) do a[i] = tostring((select(i, ...))) end
    print("[XKHUB] " .. table.concat(a, " "))
end

local function Notify(title, content, icon, dur)
    WindUI:Notify({ Title = title, Content = content, Icon = icon or "bell", Duration = dur or 2 })
end

------------------------------------------------------------------
-- 2. 目标 (丧尸) 工具
------------------------------------------------------------------
local function zombieModels()
    local out = {}
    local zb = workspace:FindFirstChild("ActiveZombies")
    if zb then
        for _, m in ipairs(zb:GetChildren()) do
            if m:FindFirstChild("BodyHitbox") then table.insert(out, m) end
        end
    end
    return out
end

local function nearestZombie(maxDist)
    local zs = zombieModels()
    local r, best, bestD = root(), nil, maxDist or math.huge
    if not r then return nil end
    for _, m in ipairs(zs) do
        local b = m:FindFirstChild("BodyHitbox")
        if b then
            local d = (r.Position - b.Position).Magnitude
            if d < bestD then best, bestD = m, d end
        end
    end
    return best, bestD
end

local function getWeaponModel()
    -- 当前手持: Character 下名字含 Exit 的最新武器
    local c = char()
    local tool = c:FindFirstChildOfClass("Tool")
    if tool then
        -- 通过 Tool 找到对应武器模型 (同名)
        local w = c:FindFirstChild(tool.Name)
        if w then return w end
        return c:FindFirstChild(tool.Name .. "2")
    end
    return nil
end

------------------------------------------------------------------
-- 3. 真实开火 (按抓包格式构造 FireServer)
------------------------------------------------------------------
local function simulateFire(targetModel)
    -- 完全按日志格式:
    -- Fire:FireServer(weaponName, {{hitbox, pos, dir}}, {{name, muzz, endA, endB, true, hitbox, false, false, "Default", Exit}})
    local w = getWeaponModel()
    local wname = w and w.Name or "M1911"
    local exit = w and w:FindFirstChild("Exit")
    local muzz = exit and exit.Position or (root() and root().Position or Vector3.zero)

    local hitbox, tpos
    if targetModel and targetModel:FindFirstChild("BodyHitbox") then
        hitbox = targetModel:FindFirstChild("BodyHitbox")
        tpos = hitbox.Position
    elseif targetModel then
        tpos = targetModel:GetChildren()[1] and targetModel:GetChildren()[1].Position or muzz + Vector3.new(0, 0, 10)
    else
        -- 无目标: 朝准星方向远处
        local cam = workspace.CurrentCamera
        tpos = muzz + cam.CFrame.LookVector * 200
    end

    local dir = (tpos - muzz).Unit * 2
    local endA, endB = tpos, tpos
    local payload1 = { { hitbox or nil, tpos, dir } }
    local payload2 = {
        {
            wname, muzz, endA, endB,
            true,
            hitbox or nil,
            false, false,
            "Default",
            exit or nil,
        }
    }
    local ev = R.Fire or R.Fire2
    if ev then
        pcall(function() ev:FireServer(wname, payload1, payload2) end)
    end
    S.shots = S.shots + 1
end

local function fastFireStep()
    if not S.autofire then return end
    local now = os.clock()
    if now - S.lastShot < (1 / S.fireRate) then return end
    S.lastShot = now
    local target = (S.autoAim and S.aimTarget) or nil
    simulateFire(target)
    S.firedInBurst = S.firedInBurst + 1
    if S.burst > 0 and S.firedInBurst >= S.burst then
        S.firedInBurst = 0
        task.wait(S.burstGap)
    end
end

------------------------------------------------------------------
-- 4. 窗口 / UI (套用示例样式)
------------------------------------------------------------------
local Window = WindUI:CreateWindow({
    Title = "XK Hub · PRO",
    Icon = "rbxassetid://136469174415866",
    Author = "XK",
    Folder = "XK Hub",
    Size = UDim2.fromOffset(640, 520),
    Theme = "Dark",
    SideBarWidth = 220,
    ScrollBarEnabled = true
})

Window:EditOpenButton({
    Title = "XK HUB",
    CornerRadius = UDim.new(4, 16),
    StrokeThickness = 0.75,
    Draggable = true,
})

-- 开按钮呼吸边框 (示例同款)
task.spawn(function()
    local cA, cB = Color3.fromRGB(0,0,0), Color3.fromRGB(255,255,255)
    RunService.Heartbeat:Connect(function()
        local t = tick() * 0.8
        local kp = {}
        for i = 0, 10 do
            local x = i / 10
            local w = (math.sin((x - t) * math.pi * 2) + 1) / 2
            table.insert(kp, ColorSequenceKeypoint.new(x, cA:Lerp(cB, w)))
        end
        Window:EditOpenButton({
            CornerRadius = UDim.new(4, 16),
            StrokeThickness = 2,
            Color = ColorSequence.new(kp),
        })
    end)
end)

Window:CreateTopbarButton("theme-switcher", "moon", function()
    WindUI:SetTheme(WindUI:GetCurrentTheme() == "Dark" and "Light" or "Dark")
    Notify("主题", "当前: " .. WindUI:GetCurrentTheme(), "palette", 2)
end, 990)

-- 主窗口渐变边框 (示例同款)
local borderAnim, borderOn, borderSpeed = nil, true, 3

local function makeBorder(win)
    local m = win.UIElements and win.UIElements.Main
    if not m then return nil end
    local old = m:FindFirstChild("GradientStroke")
    if old then old:Destroy() end
    if not m:FindFirstChildOfClass("UICorner") then
        local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(0,16); cr.Parent = m
    end
    local s = Instance.new("UIStroke")
    s.Name = "GradientStroke"; s.Thickness = 2; s.Color = Color3.new(1,1,1)
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.LineJoinMode = Enum.LineJoinMode.Round
    s.Parent = m
    local g = Instance.new("UIGradient")
    g.Name = "GlowEffect"
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(0,0,0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(0,0,0)),
    })
    g.Parent = s
    return s
end

local function animBorder(win, spd)
    local m = win.UIElements and win.UIElements.Main
    if not m then return nil end
    local g = m:FindFirstChild("GradientStroke") and m:FindFirstChild("GradientStroke"):FindFirstChild("GlowEffect")
    if not g then return nil end
    return RunService.Heartbeat:Connect(function()
        if not m:FindFirstChild("GradientStroke") then
            g.Parent = nil
            return
        end
        g.Rotation = ((tick() * spd * 60)) % 360
    end)
end

local function rebuildBorder()
    if borderAnim then borderAnim:Disconnect(); borderAnim = nil end
    local s = makeBorder(Window)
    if s and borderOn then borderAnim = animBorder(Window, borderSpeed) end
end

local gs = makeBorder(Window)
if gs then borderAnim = animBorder(Window, borderSpeed) end

-- 窗口重开监听 (示例同款)
RunService.Heartbeat:Connect(function()
    local m = Window.UIElements and Window.UIElements.Main
    if m and not m:FindFirstChild("GradientStroke") and borderOn then
        rebuildBorder()
    end
end)

------------------------------------------------------------------
-- 5. 选项卡
------------------------------------------------------------------
local Tabs = {
    Combat   = Window:Section({ Title = "战斗",   Opened = true }),
    Move     = Window:Section({ Title = "移动",   Opened = true }),
    Visual   = Window:Section({ Title = "视觉",   Opened = true }),
    Settings = Window:Section({ Title = "设置",   Opened = true }),
}

local T = {
    Auto   = Tabs.Combat:Tab({ Title = "自动开火", Icon = "crosshair" }),
    Aim    = Tabs.Combat:Tab({ Title = "自动瞄准", Icon = "target" }),
    Other  = Tabs.Combat:Tab({ Title = "近战/投掷", Icon = "sword" }),
    Speed  = Tabs.Move:Tab({ Title = "速度", Icon = "zap" }),
    Clip   = Tabs.Move:Tab({ Title = "NoClip", Icon = "ghost" }),
    Esp    = Tabs.Visual:Tab({ Title = "ESP", Icon = "eye" }),
    Xray   = Tabs.Visual:Tab({ Title = "透视", Icon = "globe" }),
    Stat   = Tabs.Settings:Tab({ Title = "状态", Icon = "activity" }),
    Conf   = Tabs.Settings:Tab({ Title = "配置", Icon = "save" }),
}

------------------------------------------------------------------
-- 6. 自动开火
------------------------------------------------------------------
T.Auto:Paragraph({ Title = "自动开火引擎", Desc = "按抓包格式构造真实开火请求", Image = "zap", ImageSize = 20 })

T.Auto:Toggle({
    Title = "启动/停止自动开火",
    Value = false,
    Callback = function(v)
        S.autofire = v
        S.firedInBurst = 0
        Notify("自动开火", v and "已启动" or "已停止", v and "check" or "x", 2)
        Log("autofire ->", v)
    end
})

T.Auto:Slider({
    Title = "射速 (发/秒)",
    Value = { Min = 4, Max = 60, Default = 20 },
    Callback = function(v) S.fireRate = v end
})

T.Auto:Slider({
    Title = "连发数 (0=无限)",
    Value = { Min = 0, Max = 40, Default = 0 },
    Callback = function(v) S.burst = v end
})

T.Auto:Slider({
    Title = "连发间歇 (秒)",
    Value = { Min = 0, Max = 2, Default = 0.3, Step = 0.05 },
    Callback = function(v) S.burstGap = v end
})

T.Auto:Button({
    Title = "一键爆弹 (当前连发数)",
    Icon = "rocket",
    Callback = function()
        local n = math.max(S.burst, 10)
        for i = 1, n do
            simulateFire(S.autoAim and S.aimTarget or nil)
            task.wait(0.02)
        end
        Notify("爆弹", "发射 " .. n .. " 发", "rocket", 2)
    end
})

------------------------------------------------------------------
-- 7. 自动瞄准
------------------------------------------------------------------
T.Aim:Paragraph({ Title = "锁定最近丧尸", Desc = "跟随 BodyHitbox", Image = "target", ImageSize = 20 })

T.Aim:Toggle({
    Title = "自动瞄准",
    Value = false,
    Callback = function(v)
        S.autoAim = v
        Notify("自动瞄准", v and "开启" or "关闭", "crosshair", 2)
    end
})

T.Aim:Slider({
    Title = "锁定半径 (米)",
    Value = { Min = 20, Max = 600, Default = 300 },
    Callback = function(v) S.aimRadius = v end
})

T.Aim:Button({
    Title = "击杀最近目标",
    Icon = "skull",
    Callback = function()
        local m = nearestZombie(S.aimRadius)
        if m then
            for _ = 1, 60 do simulateFire(m); task.wait(0.01) end
            Notify("击杀", "已向 " .. m.Name .. " 倾泻火力", "skull", 2)
        else
            Notify("击杀", "范围内无目标", "x", 2)
        end
    end
})

------------------------------------------------------------------
-- 8. 近战 / 投掷 / 熔岩
------------------------------------------------------------------
T.Other:Paragraph({ Title = "一键触发", Desc = "按抓包 Remote 直接调用", Image = "sword", ImageSize = 20 })

T.Other:Button({
    Title = "近战 (棒球棍)",
    Icon = "sword",
    Callback = function()
        if R.Melee then R.Melee:FireServer(); Notify("近战", "已挥击", "sword", 1)
        else Notify("近战", "MeleeRequest 不存在", "x", 2) end
    end
})

T.Other:Button({
    Title = "RPG 投掷",
    Icon = "rocket",
    Callback = function()
        if R.Projectile then
            local m = nearestZombie(400)
            local pos = (m and m:FindFirstChild("BodyHitbox") and m:FindFirstChild("BodyHitbox").Position)
                or ((root() and root().Position) or Vector3.zero) + Vector3.new(0,1,0)
            R.Projectile:FireServer("RPG", pos)
            Notify("RPG", "已投向 " .. (m and m.Name or "地面"), "rocket", 1)
        else Notify("RPG", "Remote 不存在", "x", 2) end
    end
})

T.Other:Button({
    Title = "熔岩攻击",
    Icon = "flame",
    Callback = function()
        if R.Lava then R.Lava:FireServer(); Notify("熔岩", "已触发", "flame", 1)
        else Notify("熔岩", "Remote 不存在", "x", 2) end
    end
})

------------------------------------------------------------------
-- 9. 加速 / NoClip
------------------------------------------------------------------
T.Speed:Paragraph({ Title = "移动速度", Desc = "修改 WalkSpeed", Image = "zap", ImageSize = 20 })

local function setSpeed()
    local h = humanoid()
    if h then h.WalkSpeed = S.baseSpeed * S.speedMult end
end

local _ = T.Speed:Slider({
    Title = "速度倍率",
    Value = { Min = 1, Max = 10, Default = 3, Step = 0.5 },
    Callback = function(v) S.speedMult = v; if S.speed then setSpeed() end end
})

T.Speed:Toggle({
    Title = "启用加速",
    Value = false,
    Callback = function(v)
        S.speed = v
        if v then setSpeed()
        else local h = humanoid(); if h then h.WalkSpeed = S.baseSpeed end end
        Notify("加速", v and ("×" .. S.speedMult) or "关闭", "zap", 1)
    end
})

T.Clip:Paragraph({ Title = "NoClip 穿墙", Desc = "脱离碰撞继续移动", Image = "ghost", ImageSize = 20 })

T.Clip:Toggle({
    Title = "NoClip",
    Value = false,
    Callback = function(v)
        S.noclip = v
        if v then
            task.spawn(function()
                while S.noclip do
                    local r = root(); local h = humanoid()
                    if r and h then
                        pcall(function() r:BreakJoints() end)
                        h:SetState(Enum.HumanoidStateType.Freefall)
                    end
                    task.wait(0.1)
                end
            end)
        else
            local h = humanoid(); if h then h:SetState(Enum.HumanoidStateType.GettingUp) end
        end
        Notify("NoClip", v and "开启" or "关闭", "ghost", 1)
    end
})

------------------------------------------------------------------
-- 10. ESP
------------------------------------------------------------------
local espParts = {}
local function clearESP()
    for _, p in ipairs(espParts) do pcall(function() p:Destroy() end) end
    espParts = {}
end

local function drawESP()
    clearESP()
    local zs = zombieModels()
    for _, m in ipairs(zs) do
        local b = m:FindFirstChild("BodyHitbox")
        if b then
            local part = Instance.new("Part")
            part.Name = "XK_ESP"
            part.Anchored = true
            part.CanCollide = false
            part.Transparency = 0.55
            part.Color = S.espColor
            part.Size = b.Size + Vector3.new(0.2, 0.2, 0.2)
            part.CFrame = b.CFrame
            part.Parent = workspace
            table.insert(espParts, part)
        end
    end
end

T.Esp:Paragraph({ Title = "丧尸透视框", Desc = "周期性刷新", Image = "eye", ImageSize = 20 })

T.Esp:Toggle({
    Title = "启用 ESP",
    Value = false,
    Callback = function(v)
        S.esp = v
        if not v then clearESP() end
        Notify("ESP", v and "开启" or "关闭", "eye", 1)
    end
})

T.Esp:Colorpicker({
    Title = "ESP 颜色",
    Default = Color3.fromRGB(0, 229, 255),
    Callback = function(c) S.espColor = c end
})

T.Esp:Slider({
    Title = "刷新间隔 (秒)",
    Value = { Min = 0.1, Max = 3, Default = 0.4, Step = 0.1 },
    Callback = function(v) S.espRefresh = v end
})

T.Esp:Button({
    Title = "立即刷新",
    Icon = "refresh-cw",
    Callback = function() drawESP() end
})

------------------------------------------------------------------
-- 11. 透视墙
------------------------------------------------------------------
T.Xray:Paragraph({ Title = "墙体透明", Desc = "看见墙后丧尸", Image = "globe", ImageSize = 20 })

local savedTrans = {}
local function setXray(on)
    if on then
        for _, n in ipairs({ "Wall1", "Wall2", "Wall3", "Wall4", "Floor", "Ceiling" }) do
            for i = 1, 12 do
                local room = workspace:FindFirstChild(tostring(i))
                if room then
                    for j = 1, 3 do
                        local w = room:FindFirstChild(n .. tostring(j))
                        if w and w:IsA("BasePart") then
                            savedTrans[w] = w.Transparency
                            w.Transparency = 0.15
                        end
                    end
                end
            end
        end
    else
        for w, t in pairs(savedTrans) do pcall(function() w.Transparency = t end) end
        savedTrans = {}
    end
end

T.Xray:Toggle({
    Title = "墙体透视",
    Value = false,
    Callback = function(v)
        S.wallXray = v
        setXray(v)
        Notify("透视", v and "墙体已透明" or "已恢复", "globe", 1)
    end
})

------------------------------------------------------------------
-- 12. 状态 & 配置
------------------------------------------------------------------
------------------------------------------------------------------
-- 12. 状态 & 配置
------------------------------------------------------------------
T.Stat:Paragraph({ Title = "运行状态", Desc = "点按钮查看当前状态", Image = "activity", ImageSize = 20 })

local function statusText()
    local m, d = nearestZombie(S.aimRadius)
    return string.format(
        "自动开火: %s\n瞄准: %s\n目标: %s (%.1fm)\n加速: ×%s\nESP: %s\n开火: %d 发",
        S.autofire and "开" or "关",
        S.autoAim and "开" or "关",
        m and m.Name or "无", d or 0,
        S.speedMult,
        S.esp and "开" or "关",
        S.shots
    )
end

T.Stat:Button({
    Title = "查看状态",
    Icon = "activity",
    Callback = function()
        Notify("状态", statusText(), "activity", 4)
    end
})

-- 每 5 秒自动刷新一次状态到控制台
task.spawn(function()
    while task.wait(5) do
        Log(statusText():gsub("\n", " | "))
    end
end)

local confName = "xk_default"
T.Conf:Paragraph({ Title = "配置管理", Desc = "保存当前设置", Image = "save", ImageSize = 20 })
T.Conf:Input({ Title = "配置名", Value = confName, Callback = function(v) confName = v end })

local CM = Window.ConfigManager
if CM then
    CM:Init(Window)
    T.Conf:Button({
        Title = "保存配置",
        Icon = "save",
        Variant = "Primary",
        Callback = function()
            local f = CM:CreateConfig(confName)
            f:Set("speedMult", S.speedMult)
            f:Set("aimRadius", S.aimRadius)
            f:Set("fireRate", S.fireRate)
            f:Set("last", os.date("%Y-%m-%d %H:%M:%S"))
            if f:Save() then Notify("保存", "已存 " .. confName, "check", 2)
            else Notify("保存", "失败", "x", 2) end
        end
    })
end

------------------------------------------------------------------
-- 13. 主循环
------------------------------------------------------------------
-- 自动开火
task.spawn(function()
    while task.wait(0.005) do fastFireStep() end
end)

-- 自动瞄准锁跟
task.spawn(function()
    RunService.Heartbeat:Connect(function()
        if not S.autoAim then S.aimTarget = nil; return end
        local m = nearestZombie(S.aimRadius)
        S.aimTarget = m
        if m then
            local b = m:FindFirstChild("BodyHitbox")
            local r = root()
            if b and r then
                -- 平滑转向
                local look = CFrame.new(r.Position, b.Position)
                r.CFrame = r.CFrame:Lerp(look, 0.35)
            end
        end
    end)
end)

-- ESP 周期刷新
task.spawn(function()
    while task.wait(S.espRefresh) do
        if S.esp then drawESP() end
    end
end)

------------------------------------------------------------------
-- 14. 窗口生命周期
------------------------------------------------------------------
Window:OnClose(function()
    Notify("XK HUB", "窗口已关闭", "x", 1)
end)

Window:OnDestroy(function()
    if borderAnim then borderAnim:Disconnect() end
    clearESP()
end)

Notify("XK HUB · PRO", "已加载 — 开始压制", "check", 3)
