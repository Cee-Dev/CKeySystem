--[[
    C-HUB (version 1.0) — Aimbot, ESP & TriggerBot panel
    [L] show/hide UI   [=] aim   [-] FOV circle   [ ] ] ESP charms   [ [ ] head/body
    TriggerBot: Controlled via UI toggle (AIM tab)
]]

-- ══════════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════════
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")

local plr = Players.LocalPlayer
local Mouse = plr:GetMouse()
local cam = workspace.CurrentCamera

-- ══════════════════════════════════════════════
--  THEME  (every key here is user-customizable in STYLE)
-- ══════════════════════════════════════════════
local C = {
    Bg        = Color3.fromRGB(12, 12, 16),
    Surface   = Color3.fromRGB(20, 20, 26),
    Hover     = Color3.fromRGB(34, 34, 44),
    Border    = Color3.fromRGB(38, 38, 48),
    Accent    = Color3.fromRGB(68, 162, 249),
    Text      = Color3.fromRGB(240, 240, 245),
    Muted     = Color3.fromRGB(100, 100, 115),
    Off       = Color3.fromRGB(46, 46, 56),
    Logo      = Color3.fromRGB(68, 162, 249),
    LogoGlyph = Color3.fromRGB(255, 255, 255),
    Version   = Color3.fromRGB(100, 100, 115),
    White     = Color3.fromRGB(255, 255, 255),
    Black     = Color3.fromRGB(0, 0, 0),
}

local FAST   = TweenInfo.new(0.1,  Enum.EasingStyle.Quad,  Enum.EasingDirection.Out)
local SMOOTH = TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local BOUNCE = TweenInfo.new(0.35, Enum.EasingStyle.Back,  Enum.EasingDirection.Out)
local GENTLE = TweenInfo.new(0.8,  Enum.EasingStyle.Sine,  Enum.EasingDirection.InOut)

local PALETTE = {
    Color3.fromRGB(255, 255, 255),   -- White
    Color3.fromRGB(255, 55, 55),     -- Red
    Color3.fromRGB(255, 145, 45),    -- Orange
    Color3.fromRGB(255, 230, 55),    -- Yellow
    Color3.fromRGB(75, 230, 75),     -- Green
    Color3.fromRGB(45, 220, 215),    -- Cyan
    Color3.fromRGB(68, 162, 249),    -- Blue
    Color3.fromRGB(140, 85, 255),    -- Purple
    Color3.fromRGB(255, 85, 175),    -- Pink
    Color3.fromRGB(255, 45, 125),    -- Magenta
}

-- themed-object registry: bind(obj, "BackgroundColor3", "Surface")
local themed      = {}
local toggleRefs  = {}
local themeHooks  = {}   -- extra callbacks run after a theme change

local function bind(obj, prop, key)
    obj[prop] = C[key]
    table.insert(themed, {obj, prop, key})
    return obj
end

local function applyTheme()
    for _, t in ipairs(themed) do
        pcall(function() t[1][t[2]] = C[t[3]] end)
    end
    for _, ref in pairs(toggleRefs) do ref.recolor() end
    for _, fn in ipairs(themeHooks) do pcall(fn) end
end

-- ══════════════════════════════════════════════
--  STATE
-- ══════════════════════════════════════════════
local aiming            = false
local triggerbotEnabled = false
local isClicking        = false
local fovEnabled        = false
local charmEnabled      = false
local aimBody           = false
local fovRadius         = 150
local aimSmooth         = 50

local espDistance   = false
local espHealth     = false
local espSkeleton   = false
local espNames      = false
local detectNPCs    = false     -- ESP picks up every Humanoid (NPCs, bots, dummies)
local aimNPCs       = false    -- aimbot is allowed to lock onto NPCs
local espRange      = 1500     -- ESP / charms range in studs

local maxDistance   = 500
local zoneEnabled   = false
local zoneRadius    = 400
local zoneCenter    = nil

local HEAD_SCALE    = 0.7      -- skeleton head circle size (smaller = tighter circle)

-- customizable ESP colors
local fovColor        = Color3.fromRGB(255, 55, 55)
local skelColor       = Color3.fromRGB(255, 255, 255)
local charmsFillColor = Color3.fromRGB(255, 40, 40)
local charmsOutColor  = Color3.fromRGB(255, 255, 255)
local nameColor       = Color3.fromRGB(255, 255, 255)
local distColor       = Color3.fromRGB(255, 255, 255)

local targetCount   = 0
local espCount      = 0
local manualUntil   = 0
local mouseDeltaAcc = 0
local uiVisible     = true
local minimized     = false

-- ══════════════════════════════════════════════
--  NOTIFICATION (showTempMessage)
-- ══════════════════════════════════════════════
local function showTempMessage(text, color)
    task.spawn(function()
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "TempMessageUI"
        screenGui.ResetOnSpawn = false
        pcall(function()
            if syn and syn.protect_gui then syn.protect_gui(screenGui) end
        end)
        pcall(function() screenGui.Parent = game:GetService("CoreGui") end)
        if not screenGui.Parent then screenGui.Parent = plr:WaitForChild("PlayerGui") end

        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(0, 220, 0, 42)
        textLabel.Position = UDim2.new(0, 16, 1, -60)
        textLabel.BackgroundTransparency = 0.2
        textLabel.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
        textLabel.Text = text
        textLabel.TextColor3 = color or Color3.fromRGB(255, 255, 255)
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextSize = 13
        textLabel.TextStrokeTransparency = 0.7
        textLabel.Parent = screenGui

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = textLabel

        local s = Instance.new("UIStroke")
        s.Color = color or C.Accent
        s.Thickness = 1.2
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = textLabel

        task.wait(2.5)
        local tw = TweenService:Create(textLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 1,
            TextTransparency = 1,
            TextStrokeTransparency = 1,
        })
        tw:Play()
        tw.Completed:Wait()
        screenGui:Destroy()
    end)
end

-- ══════════════════════════════════════════════
--  FOV CIRCLE
-- ══════════════════════════════════════════════
local fovCircle = Drawing.new("Circle")
fovCircle.Position     = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
fovCircle.Radius       = fovRadius
fovCircle.Color        = fovColor
fovCircle.Thickness    = 1
fovCircle.Transparency = 0.6
fovCircle.Visible      = false
fovCircle.Filled       = false

-- ══════════════════════════════════════════════
--  TEAM CHECK
-- ══════════════════════════════════════════════
local function isTeammate(p)
    if p == plr then return true end
    if plr.Team ~= nil and p.Team ~= nil then return plr.Team == p.Team end
    if plr.Team ~= nil or p.Team ~= nil then return false end
    local a, b = plr:GetAttribute("Team"), p:GetAttribute("Team")
    if a ~= nil and a == b then return true end
    return false
end

-- ══════════════════════════════════════════════
--  ENTITY TRACKER — every Humanoid in the map (players + NPCs)
-- ══════════════════════════════════════════════
local entities = {}   -- [model] = humanoid

local function registerHumanoid(h)
    if not h or not h:IsA("Humanoid") then return end
    local model = h.Parent
    if model and model:IsA("Model") then entities[model] = h end
end

task.spawn(function()
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("Humanoid") then registerHumanoid(d) end
        n = n + 1
        if n % 3000 == 0 then task.wait() end
    end
end)

workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Humanoid") then task.defer(registerHumanoid, d) end
end)

workspace.DescendantRemoving:Connect(function(d)
    if d:IsA("Humanoid") then
        local m = d.Parent
        if m and entities[m] == d then entities[m] = nil end
    end
end)

-- slow safety rescan (streaming / re-parented humanoids)
task.spawn(function()
    while task.wait(10) do
        local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Humanoid") then registerHumanoid(d) end
            n = n + 1
            if n % 3000 == 0 then task.wait() end
        end
    end
end)

-- Returns: player (or nil for NPC), rootPart, headPart, displayName, hasRealHead
-- Returns false when the entity should be ignored.
local function describe(model, hum, forAim)
    if hum.Parent ~= model or model.Parent == nil then entities[model] = nil; return false end
    if hum.Health <= 0 or model == plr.Character then return false end

    local p = Players:GetPlayerFromCharacter(model)
    if p then
        if p == plr or isTeammate(p) then return false end
    else
        if forAim then
            if not aimNPCs then return false end
        elseif not detectNPCs then
            return false
        end
    end

    local root = model:FindFirstChild("HumanoidRootPart") or hum.RootPart or model.PrimaryPart
        or model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
    if not root or not root:IsA("BasePart") then return false end

    local realHead = model:FindFirstChild("Head")
    if realHead and not realHead:IsA("BasePart") then realHead = nil end
    return p, root, realHead or root, p and p.DisplayName or model.Name, realHead ~= nil
end

-- ══════════════════════════════════════════════
--  TARGET FILTERS / AIM CORE
-- ══════════════════════════════════════════════
local function passesFilters(part)
    local pos = part.Position
    if (pos - cam.CFrame.Position).Magnitude > maxDistance then return false end
    if zoneEnabled and zoneCenter then
        local flat = Vector3.new(pos.X - zoneCenter.X, 0, pos.Z - zoneCenter.Z)
        if flat.Magnitude > zoneRadius then return false end
    end
    return true
end

local function getValidTargets()
    local targets = {}
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    for model, hum in pairs(entities) do
        local p, root, head = describe(model, hum, true)
        if root then
            local part = aimBody and root or head
            local sp, onScreen = cam:WorldToViewportPoint(part.Position)
            if onScreen then
                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                if d <= fovRadius and passesFilters(part) then
                    table.insert(targets, {model = model, part = part, screenDist = d})
                end
            end
        end
    end
    return targets
end

-- ══════════════════════════════════════════════
--  TRIGGERBOT (UI-Controlled via triggerbotEnabled)
-- ══════════════════════════════════════════════
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
--  TRIGGERBOT
-- â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
_G.triggerbot = false

local Clicked = false

-- Keybind toggle (E) & keep UI toggle synced
UserInputService.InputBegan:Connect(function(Input, GameProcessedEvent)
    if GameProcessedEvent then
        return
    end

    if Input.KeyCode == Enum.KeyCode.E then
        _G.triggerbot = not _G.triggerbot
        triggerbotEnabled = _G.triggerbot
        if syncUI then syncUI() end
        if Log and Log.fn then Log.fn("TriggerBot " .. (_G.triggerbot and "enabled" or "disabled")) end
    end
end)

-- Main TriggerBot Execution (Instant, Reliable & Ignores Teammates)
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

RunService.RenderStepped:Connect(function()
    if not _G.triggerbot then
        if Clicked then
            if mouse1release then mouse1release() end
            Clicked = false
        end
        return
    end

    -- Determine targeted object via Raycast and Mouse.Target
    local targetPart = nil
    if plr.Character then
        raycastParams.FilterDescendantsInstances = {plr.Character}
        local unitRay = cam:ScreenPointToRay(Mouse.X, Mouse.Y)
        local rayResult = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
        if rayResult and rayResult.Instance then
            targetPart = rayResult.Instance
        end
    end
    if not targetPart then targetPart = Mouse.Target end

    if targetPart and targetPart.Parent then
        local model = (targetPart.Parent:FindFirstChildOfClass("Humanoid") and targetPart.Parent)
            or (targetPart.Parent.Parent and targetPart.Parent.Parent:FindFirstChildOfClass("Humanoid") and targetPart.Parent.Parent)
        local humanoid = model and model:FindFirstChildOfClass("Humanoid")

        if humanoid and humanoid.Health > 0 and model ~= plr.Character then
            local targetPlayer = Players:GetPlayerFromCharacter(model)
            if not targetPlayer or not isTeammate(targetPlayer) then
                if not Clicked then
                    if mouse1press then
                        mouse1press()
                    elseif mouse1click then
                        mouse1click()
                    end
                    Clicked = true
                end
                return
            end
        end
    end

    if Clicked then
        if mouse1release then mouse1release() end
        Clicked = false
    end
end)
-- ══════════════════════════════════════════════
--  ESP — CHARMS (Highlight)  — players and NPCs in range
-- ══════════════════════════════════════════════
local espObjects = {}   -- [model] = Highlight
local MAX_HIGHLIGHTS = 31

local function removeESP(m)
    local h = espObjects[m]
    if h then pcall(function() h:Destroy() end); espObjects[m] = nil end
end

local function clearAllESP()
    for m in pairs(espObjects) do removeESP(m) end
end

local function updateHighlights()
    if not charmEnabled then clearAllESP(); return end
    cam = workspace.CurrentCamera or cam
    local camPos = cam.CFrame.Position

    local list = {}
    for model, hum in pairs(entities) do
        local _, root = describe(model, hum, false)
        if root then
            local dist = (root.Position - camPos).Magnitude
            if dist <= espRange then list[#list + 1] = {model, dist} end
        end
    end
    table.sort(list, function(a, b) return a[2] < b[2] end)

    local keep = {}
    for i = 1, math.min(#list, MAX_HIGHLIGHTS) do
        local model = list[i][1]
        keep[model] = true
        local hl = espObjects[model]
        if (not hl) or hl.Parent ~= model then
            if hl then pcall(function() hl:Destroy() end) end
            hl = Instance.new("Highlight")
            hl.Adornee             = model
            hl.FillTransparency    = 0.55
            hl.OutlineTransparency = 0
            hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent              = model
            espObjects[model] = hl
        end
        hl.FillColor    = charmsFillColor
        hl.OutlineColor = charmsOutColor
    end
    for m in pairs(espObjects) do
        if not keep[m] then removeESP(m) end
    end
end

-- ══════════════════════════════════════════════
--  ESP — DRAWING API  (skeleton, head, health, distance, name)
-- ══════════════════════════════════════════════
local SKEL_R15 = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},  {"LeftUpperArm", "LeftLowerArm"},   {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},  {"LeftUpperLeg", "LeftLowerLeg"},   {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local SKEL_R6 = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}

local drawn = {}   -- [model] = drawing set

local function newLine(th, col)
    local l = Drawing.new("Line"); l.Thickness = th; l.Color = col or C.White; l.Visible = false; return l
end
local function newText()
    local t = Drawing.new("Text"); t.Size = 13; t.Center = true; t.Outline = true; t.Color = C.White; t.Visible = false
    pcall(function() t.Font = 2 end); return t
end
local function newCircle()
    local c = Drawing.new("Circle"); c.Thickness = 1.5; c.Color = C.White; c.Filled = false; c.Visible = false; c.Transparency = 1
    pcall(function() c.NumSides = 30 end); return c
end

local function getDrawing(m)
    local d = drawn[m]
    if not d then
        d = { skel = {}, headCirc = newCircle(), barBg = newLine(4, C.Black), bar = newLine(2, Color3.fromRGB(0,255,0)),
              hpText = newText(), distText = newText(), nameText = newText() }
        for i = 1, #SKEL_R15 do d.skel[i] = newLine(1, skelColor) end
        drawn[m] = d
    end
    return d
end

local function hideDrawing(d)
    for _, l in ipairs(d.skel) do l.Visible = false end
    d.headCirc.Visible = false; d.barBg.Visible = false; d.bar.Visible = false
    d.hpText.Visible = false; d.distText.Visible = false; d.nameText.Visible = false
end

local function destroyDrawing(m)
    local d = drawn[m]; if not d then return end
    for _, l in ipairs(d.skel) do pcall(function() l:Remove() end) end
    pcall(function() d.headCirc:Remove() end); pcall(function() d.barBg:Remove() end)
    pcall(function() d.bar:Remove() end); pcall(function() d.hpText:Remove() end)
    pcall(function() d.distText:Remove() end); pcall(function() d.nameText:Remove() end)
    drawn[m] = nil
end

local function renderESP()
    cam = workspace.CurrentCamera or cam
    local camPos = cam.CFrame.Position
    local anyOn  = espDistance or espHealth or espSkeleton or espNames
    local count  = 0

    for model, hum in pairs(entities) do
        local d    = drawn[model]
        local drew = false

        if anyOn then
            local p, hrp, head, dispName, hasHead = describe(model, hum, false)
            if hrp and (hrp.Position - camPos).Magnitude <= espRange then
                local rp = cam:WorldToViewportPoint(hrp.Position)
                if rp.Z > 0 then
                    d = getDrawing(model); drew = true; count = count + 1
                    local top = cam:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y/2 + 0.2, 0))
                    local bot = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                    local h   = math.abs(bot.Y - top.Y)
                    local w   = h / 2
                    local cx  = rp.X

                    -- skeleton
                    local list = model:FindFirstChild("UpperTorso") and SKEL_R15 or SKEL_R6
                    for i, line in ipairs(d.skel) do
                        local pair = list[i]; local shown = false
                        if espSkeleton and pair then
                            local a = model:FindFirstChild(pair[1]); local b = model:FindFirstChild(pair[2])
                            if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                                local pa = cam:WorldToViewportPoint(a.Position)
                                local pb = cam:WorldToViewportPoint(b.Position)
                                if pa.Z > 0 and pb.Z > 0 then
                                    line.From = Vector2.new(pa.X, pa.Y); line.To = Vector2.new(pb.X, pb.Y)
                                    line.Color = skelColor; shown = true
                                end
                            end
                        end
                        line.Visible = shown
                    end

                    -- head circle (HEAD_SCALE)
                    if espSkeleton and hasHead then
                        local hp = cam:WorldToViewportPoint(head.Position)
                        if hp.Z > 0 then
                            local ht = cam:WorldToViewportPoint(head.Position + Vector3.new(0, head.Size.Y/2, 0))
                            local hb = cam:WorldToViewportPoint(head.Position - Vector3.new(0, head.Size.Y/2, 0))
                            local r = math.clamp((math.abs(ht.Y - hb.Y) / 2) * HEAD_SCALE, 2, 40)
                            d.headCirc.Position = Vector2.new(hp.X, hp.Y)
                            d.headCirc.Radius = r; d.headCirc.Color = skelColor; d.headCirc.Visible = true
                        else d.headCirc.Visible = false end
                    else d.headCirc.Visible = false end

                    -- health bar
                    if espHealth then
                        local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                        local x = cx - w/2 - 5
                        d.barBg.From = Vector2.new(x, bot.Y+1); d.barBg.To = Vector2.new(x, top.Y-1)
                        d.bar.From = Vector2.new(x, bot.Y); d.bar.To = Vector2.new(x, bot.Y - h*pct)
                        d.bar.Color = Color3.fromHSV(pct/3, 1, 1)
                        d.hpText.Text = tostring(math.ceil(hum.Health))
                        d.hpText.Position = Vector2.new(x - 14, top.Y); d.hpText.Color = d.bar.Color
                        d.barBg.Visible = true; d.bar.Visible = pct > 0; d.hpText.Visible = true
                    else d.barBg.Visible = false; d.bar.Visible = false; d.hpText.Visible = false end

                    -- distance
                    if espDistance then
                        local dist = (hrp.Position - camPos).Magnitude
                        d.distText.Text = string.format("%d studs", math.floor(dist + 0.5))
                        d.distText.Color = distColor
                        d.distText.Position = Vector2.new(cx, bot.Y + 3); d.distText.Visible = true
                    else d.distText.Visible = false end

                    -- name (players: display name, NPCs: model name)
                    if espNames then
                        d.nameText.Text = dispName; d.nameText.Color = nameColor
                        d.nameText.Position = Vector2.new(cx, top.Y - 18); d.nameText.Visible = true
                    else d.nameText.Visible = false end
                end
            end
        end
        if not drew and d then hideDrawing(d) end
    end
    espCount = count
end

-- free drawings of entities that no longer exist
task.spawn(function()
    while task.wait(1) do
        for m in pairs(drawn) do
            if not entities[m] then destroyDrawing(m) end
        end
    end
end)

-- ══════════════════════════════════════════════
--  UI  —  HELPERS
-- ══════════════════════════════════════════════
local function corner(obj, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = obj; return c
end
local function stroke(obj, key, t)
    local s = Instance.new("UIStroke"); s.Thickness = t or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = obj
    bind(s, "Color", key or "Border"); return s
end
local function label(parent, text, size, key, font, xAlign)
    local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.Text = text
    l.TextSize = size; l.Font = font
    l.TextXAlignment = xAlign or Enum.TextXAlignment.Left; l.Parent = parent
    bind(l, "TextColor3", key); return l
end

local Log = {fn = function() end}
local MONO = Enum.Font.RobotoMono
local sectionCount = {}

local function makeSection(parent, text, order)
    sectionCount[parent] = (sectionCount[parent] or 0) + 1
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 26); wrap.BackgroundTransparency = 1
    wrap.LayoutOrder = order; wrap.Parent = parent

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1); line.Position = UDim2.new(0, 0, 0.5, 0)
    line.BackgroundTransparency = 0.45; line.BorderSizePixel = 0; line.Parent = wrap
    bind(line, "BackgroundColor3", "Border")

    local lbl = label(wrap, string.format("%02d / %s", sectionCount[parent], text), 10, "Muted", MONO)
    lbl.AutomaticSize = Enum.AutomaticSize.X; lbl.Size = UDim2.new(0, 0, 1, 0)
    lbl.BackgroundTransparency = 0
    bind(lbl, "BackgroundColor3", "Bg")
    local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 14); pad.PaddingRight = UDim.new(0, 8); pad.Parent = lbl

    local mark = Instance.new("Frame")
    mark.Size = UDim2.fromOffset(5, 5); mark.Position = UDim2.new(0, 2, 0.5, -2)
    mark.BorderSizePixel = 0; mark.Rotation = 45; mark.ZIndex = 2; mark.Parent = wrap
    bind(mark, "BackgroundColor3", "Accent")
    return wrap
end

local function makeHeader(parent, eyebrow, titleText, sub, order)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 52); f.BackgroundTransparency = 1; f.LayoutOrder = order; f.Parent = parent
    local e = label(f, eyebrow, 9, "Accent", MONO)
    e.Size = UDim2.new(1, 0, 0, 12); e.Position = UDim2.new(0, 2, 0, 0)
    local t = label(f, titleText, 17, "Text", Enum.Font.GothamBold)
    t.Size = UDim2.new(1, 0, 0, 22); t.Position = UDim2.new(0, 2, 0, 12)
    local sdesc = label(f, sub, 10, "Muted", Enum.Font.Gotham)
    sdesc.Size = UDim2.new(1, 0, 0, 14); sdesc.Position = UDim2.new(0, 2, 0, 35)
    return f
end

local function makeKeyRow(parent, key, desc, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 30); row.BorderSizePixel = 0; row.LayoutOrder = order; row.Parent = parent
    bind(row, "BackgroundColor3", "Surface"); corner(row, 8)
    local chip = Instance.new("TextLabel")
    chip.Size = UDim2.fromOffset(34, 20); chip.Position = UDim2.new(0, 6, 0.5, -10)
    chip.BorderSizePixel = 0; chip.Text = key; chip.TextSize = 11; chip.Font = MONO; chip.Parent = row
    bind(chip, "BackgroundColor3", "Bg"); bind(chip, "TextColor3", "Accent")
    corner(chip, 5); stroke(chip, "Border", 1)
    local d = label(row, desc, 11, "Text", Enum.Font.GothamMedium)
    d.Size = UDim2.new(1, -52, 1, 0); d.Position = UDim2.new(0, 48, 0, 0)
    return row
end

local function makeToggle(parent, text, default, order, callback)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 36); row.BorderSizePixel = 0
    row.AutoButtonColor = false; row.Text = ""; row.LayoutOrder = order; row.Parent = parent
    bind(row, "BackgroundColor3", "Surface")
    corner(row, 8)

    local hoverStroke = stroke(row, "Border", 1)
    hoverStroke.Transparency = 1

    row.MouseEnter:Connect(function()
        TweenService:Create(row, FAST, {BackgroundColor3 = C.Hover}):Play()
        TweenService:Create(hoverStroke, FAST, {Transparency = 0, Color = C.Accent}):Play()
    end)
    row.MouseLeave:Connect(function()
        TweenService:Create(row, FAST, {BackgroundColor3 = C.Surface}):Play()
        TweenService:Create(hoverStroke, FAST, {Transparency = 1, Color = C.Border}):Play()
    end)

    local lbl = label(row, text, 12, "Text", Enum.Font.GothamMedium)
    lbl.Size = UDim2.new(1, -64, 1, 0); lbl.Position = UDim2.new(0, 14, 0, 0)

    local state = default

    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.fromOffset(4, 4); statusDot.Position = UDim2.new(0, 6, 0.5, -2)
    statusDot.BackgroundColor3 = state and C.Accent or C.Off
    statusDot.BorderSizePixel = 0; statusDot.Parent = row
    corner(statusDot, 2)

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 36, 0, 20); track.Position = UDim2.new(1, -48, 0.5, -10)
    track.BackgroundColor3 = state and C.Accent or C.Off
    track.BorderSizePixel = 0; track.Parent = row
    corner(track, 10)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = C.White; knob.BorderSizePixel = 0; knob.Parent = track
    corner(knob, 8)

    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 4, 1, 4); shadow.Position = UDim2.new(0, -2, 0, -1)
    shadow.BackgroundColor3 = C.Black; shadow.BackgroundTransparency = 0.8
    shadow.BorderSizePixel = 0; shadow.ZIndex = 0; shadow.Parent = knob
    corner(shadow, 8)

    local function setState(v, skipCb)
        state = v
        TweenService:Create(track, SMOOTH, {BackgroundColor3 = v and C.Accent or C.Off}):Play()
        TweenService:Create(statusDot, SMOOTH, {BackgroundColor3 = v and C.Accent or C.Off}):Play()
        TweenService:Create(knob, BOUNCE, {
            Position = v and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.1), {Size = UDim2.new(0, 18, 0, 18)}):Play()
        task.delay(0.1, function()
            TweenService:Create(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(0, 16, 0, 16)}):Play()
        end)
        if not skipCb and callback then callback(v) end
    end

    row.MouseButton1Click:Connect(function() setState(not state); Log.fn(text .. (state and " enabled" or " disabled")) end)

    local ref = {
        setState = setState,
        getState = function() return state end,
        recolor  = function()
            track.BackgroundColor3     = state and C.Accent or C.Off
            statusDot.BackgroundColor3 = state and C.Accent or C.Off
        end,
    }
    toggleRefs[text] = ref
    return ref
end

local function makeSlider(parent, text, min, max, default, order, callback, suffix)
    suffix = suffix or ""
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 48); row.BorderSizePixel = 0; row.LayoutOrder = order; row.Parent = parent
    bind(row, "BackgroundColor3", "Surface")
    corner(row, 8)

    local hoverStroke = stroke(row, "Border", 1)
    hoverStroke.Transparency = 1

    local lbl = label(row, text, 12, "Text", Enum.Font.GothamMedium)
    lbl.Size = UDim2.new(0.6, 0, 0, 22); lbl.Position = UDim2.new(0, 14, 0, 4)

    local val = label(row, tostring(default) .. suffix, 12, "Accent", Enum.Font.GothamBold, Enum.TextXAlignment.Right)
    val.Size = UDim2.new(0.4, -14, 0, 22); val.Position = UDim2.new(0.6, 0, 0, 4)

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -28, 0, 4); track.Position = UDim2.new(0, 14, 0, 34)
    track.BorderSizePixel = 0; track.Parent = row
    bind(track, "BackgroundColor3", "Off")
    corner(track, 2)

    local rel0 = (default - min) / (max - min)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(rel0, 0, 1, 0); fill.BorderSizePixel = 0; fill.Parent = track
    bind(fill, "BackgroundColor3", "Accent")
    corner(fill, 2)

    local fillGlow = Instance.new("Frame")
    fillGlow.Size = UDim2.new(1, 0, 1, 6); fillGlow.Position = UDim2.new(0, 0, 0, -3)
    fillGlow.BackgroundTransparency = 0.8; fillGlow.BorderSizePixel = 0; fillGlow.ZIndex = 0; fillGlow.Parent = fill
    bind(fillGlow, "BackgroundColor3", "Accent")
    corner(fillGlow, 3)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Size = UDim2.new(0, 14, 0, 14); knob.Position = UDim2.new(rel0, 0, 0.5, 0)
    knob.BackgroundColor3 = C.White; knob.BorderSizePixel = 0; knob.ZIndex = 3; knob.Parent = track
    corner(knob, 7)

    local knobRing = stroke(knob, "Accent", 2)
    knobRing.Transparency = 1

    local function update(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = math.floor(min + rel * (max - min) + 0.5)
        TweenService:Create(fill, FAST, {Size = UDim2.new(rel, 0, 1, 0)}):Play()
        TweenService:Create(knob, FAST, {Position = UDim2.new(rel, 0, 0.5, 0)}):Play()
        val.Text = tostring(v) .. suffix
        if callback then callback(v) end
    end

    local hit = Instance.new("TextButton")
    hit.Size = UDim2.new(1, -12, 0, 24); hit.Position = UDim2.new(0, 6, 0, 24)
    hit.BackgroundTransparency = 1; hit.Text = ""; hit.ZIndex = 4; hit.Parent = row

    local dragging = false
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(input.Position.X)
            TweenService:Create(knob, FAST, {Size = UDim2.new(0, 18, 0, 18)}):Play()
            TweenService:Create(knobRing, FAST, {Transparency = 0}):Play()
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                TweenService:Create(knob, BOUNCE, {Size = UDim2.new(0, 14, 0, 14)}):Play()
                TweenService:Create(knobRing, FAST, {Transparency = 1}):Play()
            end
        end
    end)

    row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            TweenService:Create(row, FAST, {BackgroundColor3 = C.Hover}):Play()
            TweenService:Create(hoverStroke, FAST, {Transparency = 0, Color = C.Accent}):Play()
        end
    end)
    row.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            TweenService:Create(row, FAST, {BackgroundColor3 = C.Surface}):Play()
            TweenService:Create(hoverStroke, FAST, {Transparency = 1, Color = C.Border}):Play()
        end
    end)
end

local function makeButton(parent, text, order, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34); btn.BorderSizePixel = 0; btn.AutoButtonColor = false
    btn.Text = text; btn.TextSize = 12; btn.Font = Enum.Font.GothamBold
    btn.LayoutOrder = order; btn.Parent = parent
    bind(btn, "BackgroundColor3", "Surface"); bind(btn, "TextColor3", "Accent")
    corner(btn, 8)
    local s = stroke(btn, "Border", 1)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, FAST, {BackgroundColor3 = C.Hover}):Play()
        TweenService:Create(s, FAST, {Color = C.Accent}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, FAST, {BackgroundColor3 = C.Surface}):Play()
        TweenService:Create(s, FAST, {Color = C.Border}):Play()
    end)
    btn.MouseButton1Click:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.06), {BackgroundColor3 = C.Accent, TextColor3 = C.White}):Play()
        task.delay(0.12, function()
            TweenService:Create(btn, SMOOTH, {BackgroundColor3 = C.Surface, TextColor3 = C.Accent}):Play()
        end)
        callback(btn)
    end)
    return btn
end

local function makeNote(parent, text, height, order)
    local l = label(parent, text, 10, "Muted", Enum.Font.Gotham)
    l.Size = UDim2.new(1, 0, 0, height); l.TextWrapped = true
    l.TextYAlignment = Enum.TextYAlignment.Top; l.LayoutOrder = order; return l
end

local function toHex(c)
    return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function parseHex(s)
    s = (s or ""):gsub("[#%s]", "")
    if #s == 6 and s:match("^%x+$") then
        return Color3.fromRGB(tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16))
    end
end
local function sameColor(a, b)
    return math.abs(a.R - b.R) < 0.004 and math.abs(a.G - b.G) < 0.004 and math.abs(a.B - b.B) < 0.004
end

local function makeColorRow(parent, text, order, getCurrent, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 60); row.BorderSizePixel = 0; row.LayoutOrder = order; row.Parent = parent
    bind(row, "BackgroundColor3", "Surface")
    corner(row, 8)

    local preview = Instance.new("Frame")
    preview.Size = UDim2.fromOffset(16, 16); preview.Position = UDim2.new(0, 12, 0, 6)
    preview.BackgroundColor3 = getCurrent(); preview.BorderSizePixel = 0; preview.Parent = row
    corner(preview, 5); stroke(preview, "Border", 1)

    local lbl = label(row, text, 11, "Text", Enum.Font.GothamMedium)
    lbl.Size = UDim2.new(1, -130, 0, 28); lbl.Position = UDim2.new(0, 34, 0, 0)

    local hexBox = Instance.new("TextBox")
    hexBox.Size = UDim2.fromOffset(72, 20); hexBox.Position = UDim2.new(1, -84, 0, 4)
    hexBox.BorderSizePixel = 0; hexBox.ClearTextOnFocus = false
    hexBox.Font = Enum.Font.GothamMedium; hexBox.TextSize = 10; hexBox.Text = toHex(getCurrent())
    hexBox.PlaceholderText = "#RRGGBB"; hexBox.Parent = row
    bind(hexBox, "BackgroundColor3", "Bg"); bind(hexBox, "TextColor3", "Text")
    corner(hexBox, 5); stroke(hexBox, "Border", 1)

    local dots, selected = {}, nil
    local function mark(idx)
        if selected and dots[selected] then
            dots[selected].ring.Thickness = 0; dots[selected].check.Text = ""
        end
        selected = idx
        if idx and dots[idx] then dots[idx].ring.Thickness = 2; dots[idx].check.Text = "✓" end
    end

    local api = {}
    function api.set(col, silent)
        preview.BackgroundColor3 = col
        hexBox.Text = toHex(col)
        local found
        for i, pc in ipairs(PALETTE) do if sameColor(pc, col) then found = i break end end
        mark(found)
        if not silent then callback(col) end
    end

    for i, color in ipairs(PALETTE) do
        local dot = Instance.new("TextButton")
        dot.Size = UDim2.fromOffset(22, 22)
        dot.Position = UDim2.new(0, 12 + (i - 1) * 28, 0, 32)
        dot.BackgroundColor3 = color; dot.BorderSizePixel = 0
        dot.Text = ""; dot.AutoButtonColor = false; dot.Parent = row
        corner(dot, 11)

        local ring = Instance.new("UIStroke")
        ring.Color = C.White; ring.Thickness = 0
        ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; ring.Parent = dot

        local check = Instance.new("TextLabel")
        check.Size = UDim2.new(1, 0, 1, 0); check.BackgroundTransparency = 1
        check.Text = ""; check.TextSize = 11; check.Font = Enum.Font.GothamBold
        check.TextColor3 = C.Black; check.Parent = dot
        dots[i] = {ring = ring, check = check}

        dot.MouseEnter:Connect(function()
            TweenService:Create(dot, FAST, {Size = UDim2.fromOffset(26, 26),
                Position = UDim2.new(0, 10 + (i-1)*28, 0, 30)}):Play()
        end)
        dot.MouseLeave:Connect(function()
            TweenService:Create(dot, FAST, {Size = UDim2.fromOffset(22, 22),
                Position = UDim2.new(0, 12 + (i-1)*28, 0, 32)}):Play()
        end)
        dot.MouseButton1Click:Connect(function() api.set(color) end)
    end

    hexBox.FocusLost:Connect(function()
        local col = parseHex(hexBox.Text)
        if col then api.set(col) else hexBox.Text = toHex(getCurrent()) end
    end)

    api.set(getCurrent(), true)
    return api
end

-- ══════════════════════════════════════════════
--  UI  —  WINDOW
-- ══════════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = "CHUB"; gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.IgnoreGuiInset = true

pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not gui.Parent then gui.Parent = plr:WaitForChild("PlayerGui") end

local WIN_W, WIN_H, TITLE_H = 372, 530, 46
local TAB_H, FOOT_H = 32, 50

local win = Instance.new("Frame")
win.Name = "Window"; win.Size = UDim2.fromOffset(WIN_W, WIN_H)
win.Position = UDim2.new(0.5, -WIN_W/2, 0.2, 0)
win.BorderSizePixel = 0; win.ClipsDescendants = true; win.Active = true; win.Parent = gui
bind(win, "BackgroundColor3", "Bg")
corner(win, 12)
local winStroke = stroke(win, "Border", 1)

win.BackgroundTransparency = 1
win.Size = UDim2.fromOffset(WIN_W * 0.85, WIN_H * 0.85)
win.Position = UDim2.new(0.5, -WIN_W * 0.425, 0.2, 10)
task.delay(0.05, function()
    TweenService:Create(win, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0,
        Size = UDim2.fromOffset(WIN_W, WIN_H),
        Position = UDim2.new(0.5, -WIN_W/2, 0.2, 0),
    }):Play()
end)

task.spawn(function()
    while task.wait(3) do
        TweenService:Create(winStroke, GENTLE, {Color = C.Accent}):Play()
        task.wait(1.5)
        TweenService:Create(winStroke, GENTLE, {Color = C.Border}):Play()
    end
end)

local glow = Instance.new("Frame")
glow.Size = UDim2.new(1, 0, 0, 120); glow.BackgroundTransparency = 0.9
glow.BorderSizePixel = 0; glow.ZIndex = 0; glow.Parent = win
bind(glow, "BackgroundColor3", "Accent")
do
    local g = Instance.new("UIGradient")
    g.Rotation = 90
    g.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1)})
    g.Parent = glow
end

-- ═══ TITLE BAR ═══
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, TITLE_H); titleBar.BackgroundTransparency = 1; titleBar.Parent = win

local accentLine = Instance.new("Frame")
accentLine.Size = UDim2.new(1, 0, 0, 1); accentLine.Position = UDim2.new(0, 0, 0, TITLE_H)
accentLine.BorderSizePixel = 0; accentLine.Parent = win
bind(accentLine, "BackgroundColor3", "Accent")

local grad = Instance.new("UIGradient")
grad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0), NumberSequenceKeypoint.new(1, 1),
}); grad.Parent = accentLine

task.spawn(function()
    while task.wait(4) do
        grad.Offset = Vector2.new(-1, 0)
        TweenService:Create(grad, TweenInfo.new(2, Enum.EasingStyle.Sine), {Offset = Vector2.new(1, 0)}):Play()
    end
end)

-- Wave Logo PNG with transparency
local LOGO_B64 = "iVBORw0KGgoAAAANSUhEUgAAAGQAAABkCAYAAABw4pVUAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAACK0SURBVHhe7Z15lFTVncf5M+ckLlFBhCiKAtIIuLA0NDY0WwMCAi0oqwZkkUVxwRUXQIQAiqLIjkZJouOYReMckxPNJJPE6JzJZqLGuOsYDRJEQbRrm+/nzu++3HpV1VXV0Arq75zfebW89+re3+f+lvu2anYwSG1t7UmVlZVnz549e+HkyZO3LV269JfLli37i/St5cuX75Du/ta3voXukL6p989pnV9MmTJl27x5867TtiOHDh16gu3uSylHevbsedjUqVPHXn755Q/fcccd723dujV95513Zu66666MAGRk8Mwtt9wSKZ95FYhIWW/lypVuuX79+szdd9+duf/++1m+fc011zw8duzYMZ06dTrSfvZLCUWjt4VG8k0y+v9u2LAhs2LFioxGeGbx4sWZJUuWpKWZm2++OVK+Q0MwxeCYpnnP/teuXZvZsmVLZvPmza9eccUVNw0aNOgb1pwvrsgTpt56661vAAEjLlq0KCOvyKxZsyaDV+i7zE033QQQB8VrHI4HEr4uAU4EaNWqVRl5IpBenjNnzmRr3hdD+vTpc7SM+pOHH36YMLRn9erVf5o+ffoPZs2atVxhap6+n9yvX79zunfvPnTcuHE1CjufAApv8doQnEZ6joeTZkBs27aNfa9TSDvMmv35k+rq6vY33HDDDxUu/iRDjy/W2QsvvHCIPGX3jTfemAZIqMXgFAJTKhy9T7Ek52h//3biiSd+1Zr1+ZC5c+f2GD58+BB7W1QUQv7rtttuy1x//fUJQpagELoKQonD8WD2FY5eJzWA0niMlquseV8cmThxYoUSbWLhwoVpwUjKozLAiGs+OH4pQ6fJCRs3bsysW7cuoZD4gTztbenrqMLk37XcpWorcc8997icxfps5yHF4QCGiu073/lOcv78+TXW3M+3qNJZQGmrktQDwUMizQcH75Gm8ABKWxUBr1188cW3jx8/vl+HDh1a2K4LSpcuXVpo3Z7KX0u07fMAwvDaXyruOYARsCSg1c7f2C4+n3L77bf/DKNed9119VKWTgUm0hgcgKW1HcbZrmLtkl69eu1zAiavXSZRxfW+PAswSQ8m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"

local function b64decode(data)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local lookup = {}
    for i = 1, #chars do lookup[chars:byte(i)] = i - 1 end
    local out, buf, bits = {}, 0, 0
    for i = 1, #data do
        local v = lookup[data:byte(i)]
        if v then
            buf = buf * 64 + v; bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local byte = math.floor(buf / 2 ^ bits)
                buf = buf - byte * 2 ^ bits
                out[#out + 1] = string.char(byte)
            end
        end
    end
    return table.concat(out)
end

local logo = Instance.new("ImageLabel")
logo.Size = UDim2.fromOffset(32, 32); logo.Position = UDim2.new(0, 12, 0.5, -16)
logo.BackgroundTransparency = 1; logo.BorderSizePixel = 0
logo.ScaleType = Enum.ScaleType.Fit; logo.Parent = titleBar
bind(logo, "ImageColor3", "Logo")

pcall(function()
    local getAsset = getcustomasset or getsynasset
    if writefile and getAsset then
        local p = "CHUB_wave_logo.png"
        writefile(p, b64decode(LOGO_B64))
        logo.Image = getAsset(p)
    end
end)

local title = label(titleBar, "C-HUB", 14, "Text", Enum.Font.GothamBold)
title.Size = UDim2.new(0, 100, 0, 18); title.Position = UDim2.new(0, 52, 0, 6)
title.TextSize = 14

local verSub = label(titleBar, "version 1.0", 10, "Muted", MONO)
verSub.Size = UDim2.new(0, 100, 0, 14); verSub.Position = UDim2.new(0, 52, 0, 24)

local function winBtn(symbol, fromRight, hoverCol)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromOffset(28, 24); bg.Position = UDim2.new(1, -fromRight, 0.5, -12)
    bg.BackgroundTransparency = 1; bg.BorderSizePixel = 0; bg.Parent = titleBar
    bind(bg, "BackgroundColor3", "Surface"); corner(bg, 6)

    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 1, 0); b.BackgroundTransparency = 1
    b.Text = symbol; b.TextSize = 14; b.Font = Enum.Font.GothamBold; b.Parent = bg
    bind(b, "TextColor3", "Muted")

    b.MouseEnter:Connect(function()
        TweenService:Create(b, FAST, {TextColor3 = hoverCol}):Play()
        TweenService:Create(bg, FAST, {BackgroundTransparency = 0}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, FAST, {TextColor3 = C.Muted}):Play()
        TweenService:Create(bg, FAST, {BackgroundTransparency = 1}):Play()
    end)
    return b
end

local closeBtn = winBtn("×", 38, Color3.fromRGB(235, 70, 70))
local minBtn   = winBtn("–", 70, C.Accent)

-- ═══ TABS (segmented control) ═══
local TAB_NAMES = {"AIM", "ESP", "STYLE", "INFO"}
local currentTab = 1
local tabBtns, tabPages = {}, {}

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -24, 0, TAB_H); tabBar.Position = UDim2.new(0, 12, 0, TITLE_H + 10)
tabBar.BorderSizePixel = 0; tabBar.Parent = win
bind(tabBar, "BackgroundColor3", "Surface"); corner(tabBar, 9); stroke(tabBar, "Border", 1)

local tabIndicator = Instance.new("Frame")
tabIndicator.Size = UDim2.new(1 / #TAB_NAMES, -6, 1, -6)
tabIndicator.Position = UDim2.new(0, 3, 0, 3); tabIndicator.BorderSizePixel = 0; tabIndicator.Parent = tabBar
bind(tabIndicator, "BackgroundColor3", "Hover"); corner(tabIndicator, 7); stroke(tabIndicator, "Accent", 1)

local CONTENT_Y = TITLE_H + 10 + TAB_H + 10
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -24, 1, -(CONTENT_Y + FOOT_H + 4))
content.Position = UDim2.new(0, 12, 0, CONTENT_Y)
content.BackgroundTransparency = 1; content.ClipsDescendants = true; content.Parent = win

-- footer: live status chips + a one-line event log
local footer = Instance.new("Frame")
footer.Size = UDim2.new(1, 0, 0, FOOT_H); footer.Position = UDim2.new(0, 0, 1, -FOOT_H)
footer.BorderSizePixel = 0; footer.Parent = win
bind(footer, "BackgroundColor3", "Surface")
do
    local topLine = Instance.new("Frame")
    topLine.Size = UDim2.new(1, 0, 0, 1); topLine.BorderSizePixel = 0; topLine.Parent = footer
    bind(topLine, "BackgroundColor3", "Border")
end

local chipRow = Instance.new("Frame")
chipRow.Size = UDim2.new(1, -24, 0, 18); chipRow.Position = UDim2.new(0, 12, 0, 7)
chipRow.BackgroundTransparency = 1; chipRow.Parent = footer
do
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Horizontal; l.Padding = UDim.new(0, 5)
    l.SortOrder = Enum.SortOrder.LayoutOrder; l.Parent = chipRow
end
local function makeFooterChip(order)
    local c = Instance.new("TextLabel")
    c.AutomaticSize = Enum.AutomaticSize.X; c.Size = UDim2.new(0, 0, 1, 0)
    c.BorderSizePixel = 0; c.Font = MONO; c.TextSize = 9; c.Text = ""
    c.LayoutOrder = order; c.Parent = chipRow
    bind(c, "BackgroundColor3", "Bg"); bind(c, "TextColor3", "Muted")
    local p = Instance.new("UIPadding"); p.PaddingLeft = UDim.new(0, 7); p.PaddingRight = UDim.new(0, 7); p.Parent = c
    corner(c, 5); stroke(c, "Border", 1)
    return c
end
local chipAim, chipTrigger, chipTargets, chipEsp, chipZone = makeFooterChip(1), makeFooterChip(2), makeFooterChip(3), makeFooterChip(4), makeFooterChip(5)

local logLabel = label(footer, "", 9, "Muted", MONO)
logLabel.Size = UDim2.new(1, -24, 0, 14); logLabel.Position = UDim2.new(0, 12, 0, 30)
logLabel.TextTruncate = Enum.TextTruncate.AtEnd
Log.fn = function(msg)
    logLabel.Text = string.format("› [%s]  %s", os.date("%H:%M:%S"), msg)
end
Log.fn("C-HUB loaded")

local function paintTabs()
    for n = 1, #TAB_NAMES do
        tabBtns[n].TextColor3 = (n == currentTab) and C.Accent or C.Muted
    end
end
table.insert(themeHooks, paintTabs)

for i, name in ipairs(TAB_NAMES) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1 / #TAB_NAMES, 0, 1, 0)
    btn.Position = UDim2.new((i - 1) / #TAB_NAMES, 0, 0, 0)
    btn.BackgroundTransparency = 1; btn.Text = name; btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold; btn.ZIndex = 2
    btn.TextColor3 = (i == 1) and C.Accent or C.Muted
    btn.Parent = tabBar
    tabBtns[i] = btn

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0); page.BackgroundTransparency = 1
    page.BorderSizePixel = 0; page.ScrollBarThickness = 2
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y; page.Visible = (i == 1)
    page.Parent = content
    bind(page, "ScrollBarImageColor3", "Accent")
    tabPages[i] = page

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Padding = UDim.new(0, 5); layout.Parent = page
    local pad = Instance.new("UIPadding"); pad.PaddingRight = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 8); pad.Parent = page

    btn.MouseButton1Click:Connect(function()
        if i == currentTab then return end
        currentTab = i
        TweenService:Create(tabIndicator, SMOOTH, {Position = UDim2.new((i - 1) / #TAB_NAMES, 3, 0, 3)}):Play()
        for n = 1, #TAB_NAMES do
            local active = (n == i)
            TweenService:Create(tabBtns[n], SMOOTH, {TextColor3 = active and C.Accent or C.Muted}):Play()
            if active then
                tabPages[n].CanvasPosition = Vector2.new(0, 0)
                tabPages[n].Position = UDim2.new(0.04, 0, 0, 0)
                tabPages[n].Visible = true
                TweenService:Create(tabPages[n], SMOOTH, {Position = UDim2.new(0, 0, 0, 0)}):Play()
            else
                tabPages[n].Visible = false
            end
        end
    end)
end

-- ══════════════════════════════════════════════
--  PAGE: AIM
-- ══════════════════════════════════════════════
local ap = tabPages[1]
makeHeader(ap, "C-HUB / AIM", "Aim assist", "Lock-on, smoothing and target filters.", 0)
makeSection(ap, "AIMBOT", 1)
makeToggle(ap, "Aim Lock", aiming, 2, function(s) aiming = s end)
makeToggle(ap, "TriggerBot", triggerbotEnabled, 3, function(s)
    triggerbotEnabled = s
    _G.triggerbot = s
    Log.fn("TriggerBot " .. (s and "enabled" or "disabled"))
end)
makeToggle(ap, "Aim at Body", aimBody, 4, function(s) aimBody = s end)
makeToggle(ap, "Target NPCs", aimNPCs, 5, function(s) aimNPCs = s end)
makeToggle(ap, "FOV Circle", fovEnabled, 6, function(s) fovEnabled = s; fovCircle.Visible = s end)
makeSlider(ap, "FOV Radius", 30, 1000, fovRadius, 7, function(v) fovRadius = v; fovCircle.Radius = v end)
makeSlider(ap, "Smoothness", 5, 100, aimSmooth, 8, function(v) aimSmooth = v end)

makeSection(ap, "TARGET FILTER", 8)
makeSlider(ap, "Max Distance", 50, 2000, maxDistance, 9, function(v) maxDistance = v end, " st")
makeSlider(ap, "Zone Radius", 50, 2000, zoneRadius, 10, function(v) zoneRadius = v end, " st")
makeToggle(ap, "Combat Zone Only", zoneEnabled, 11, function(s)
    zoneEnabled = s
    if s and not zoneCenter then
        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp then zoneCenter = hrp.Position end
    end
end)
makeButton(ap, "SET ZONE CENTER", 12, function(btn)
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        zoneCenter = hrp.Position
        btn.Text = "ZONE CENTER SAVED ✓"; Log.fn("Zone center saved")
    else
        btn.Text = "NO CHARACTER FOUND"
    end
    task.delay(1.5, function() btn.Text = "SET ZONE CENTER" end)
end)

-- ══════════════════════════════════════════════
--  PAGE: ESP
-- ══════════════════════════════════════════════
local ep = tabPages[2]
makeHeader(ep, "C-HUB / ESP", "Visuals", "Players and NPCs within your range.", 0)
makeSection(ep, "DETECTION", 1)
makeToggle(ep, "Detect NPCs / Humanoids", detectNPCs, 2, function(s) detectNPCs = s end)
makeSlider(ep, "ESP Range", 50, 5000, espRange, 3, function(v) espRange = v end, " st")
makeSection(ep, "ENEMY ESP", 4)
makeToggle(ep, "Charms", charmEnabled, 5, function(s)
    charmEnabled = s; if not s then clearAllESP() end
end)
makeToggle(ep, "Display Name", espNames, 6, function(s) espNames = s end)
makeToggle(ep, "Distance", espDistance, 7, function(s) espDistance = s end)
makeToggle(ep, "Health", espHealth, 8, function(s) espHealth = s end)
makeToggle(ep, "Skeleton", espSkeleton, 9, function(s) espSkeleton = s end)
makeNote(ep, "Every Humanoid within ESP Range is tracked — real players and NPCs/bots (turn NPCs off above). Health fades green → red. Teammates are hidden. Charms are capped at the 31 nearest targets (Roblox limit).", 62, 10)

-- ══════════════════════════════════════════════
--  PAGE: STYLE  (everything here is colour-only)
-- ══════════════════════════════════════════════
local sp = tabPages[3]
local rows = {}
local logoCustom = false

local function themeRow(text, order, key, after)
    rows[key] = makeColorRow(sp, text, order, function() return C[key] end, function(col)
        C[key] = col; applyTheme()
        if after then after(col) end
    end)
end
local function espRow(text, order, get, set)
    return makeColorRow(sp, text, order, get, set)
end

-- presets
local PRESETS = {
    {"Ocean",   {Accent=Color3.fromRGB(68,162,249),  Bg=Color3.fromRGB(12,12,16),   Surface=Color3.fromRGB(20,20,26),    Hover=Color3.fromRGB(34,34,44),    Border=Color3.fromRGB(38,38,48),    Text=Color3.fromRGB(240,240,245), Muted=Color3.fromRGB(100,100,115), Off=Color3.fromRGB(46,46,56)}},
    {"Crimson", {Accent=Color3.fromRGB(235,64,82),   Bg=Color3.fromRGB(14,10,12),   Surface=Color3.fromRGB(24,17,20),    Hover=Color3.fromRGB(38,26,31),    Border=Color3.fromRGB(50,34,40),    Text=Color3.fromRGB(245,238,240), Muted=Color3.fromRGB(120,100,106), Off=Color3.fromRGB(56,44,48)}},
    {"Violet",  {Accent=Color3.fromRGB(150,100,255), Bg=Color3.fromRGB(13,11,20),   Surface=Color3.fromRGB(21,18,32),    Hover=Color3.fromRGB(33,28,50),    Border=Color3.fromRGB(44,38,66),    Text=Color3.fromRGB(242,239,250), Muted=Color3.fromRGB(110,104,135), Off=Color3.fromRGB(50,45,70)}},
    {"Amoled",  {Accent=Color3.fromRGB(68,162,249),  Bg=Color3.fromRGB(0,0,0),      Surface=Color3.fromRGB(10,10,12),    Hover=Color3.fromRGB(22,22,26),    Border=Color3.fromRGB(30,30,36),    Text=Color3.fromRGB(245,245,248), Muted=Color3.fromRGB(110,110,122), Off=Color3.fromRGB(38,38,46)}},
}
local THEME_KEYS = {"Accent","Bg","Surface","Hover","Border","Text","Muted","Off","Logo","LogoGlyph","Version"}

makeHeader(sp, "C-HUB / STYLE", "Appearance", "Colors only — everything updates live.", 0)
makeSection(sp, "THEME PRESETS", 1)
local presetGrid = Instance.new("Frame")
presetGrid.Size = UDim2.new(1, 0, 0, 62); presetGrid.BackgroundTransparency = 1
presetGrid.LayoutOrder = 2; presetGrid.Parent = sp
do
    local gl = Instance.new("UIGridLayout")
    gl.CellSize = UDim2.new(1/2, -4, 0, 28); gl.CellPadding = UDim2.fromOffset(6, 6)
    gl.SortOrder = Enum.SortOrder.LayoutOrder; gl.Parent = presetGrid
end
for i, pr in ipairs(PRESETS) do
    local pb = Instance.new("TextButton")
    pb.BorderSizePixel = 0; pb.AutoButtonColor = false; pb.Text = pr[1]
    pb.TextSize = 11; pb.Font = Enum.Font.GothamBold; pb.LayoutOrder = i; pb.Parent = presetGrid
    bind(pb, "BackgroundColor3", "Surface"); bind(pb, "TextColor3", "Text")
    corner(pb, 7); stroke(pb, "Border", 1)
    local swatch = Instance.new("Frame")
    swatch.Size = UDim2.fromOffset(6, 6); swatch.Position = UDim2.new(0, 8, 0.5, -3)
    swatch.BackgroundColor3 = pr[2].Accent; swatch.BorderSizePixel = 0; swatch.Parent = pb
    corner(swatch, 3)
    pb.MouseButton1Click:Connect(function()
        for k, v in pairs(pr[2]) do C[k] = v end
        C.Logo = pr[2].Accent; C.LogoGlyph = Color3.fromRGB(255, 255, 255); C.Version = pr[2].Muted
        logoCustom = false
        applyTheme()
        for _, k in ipairs(THEME_KEYS) do if rows[k] then rows[k].set(C[k], true) end end
    end)
end

makeSection(sp, "INTERFACE", 3)
themeRow("Accent Color",   4,  "Accent", function(col)
    if not logoCustom then
        C.Logo = col; applyTheme(); rows.Logo.set(col, true)
    end
end)
themeRow("Background",     5,  "Bg")
themeRow("Panels",         6,  "Surface")
themeRow("Hover",          7,  "Hover")
themeRow("Borders",        8,  "Border")
themeRow("Text",           9,  "Text")
themeRow("Muted Text",     10, "Muted")
themeRow("Toggle Off",     11, "Off")

makeSection(sp, "LOGO", 12)
themeRow("Logo Color",       13, "Logo",      function() logoCustom = true end)

makeSection(sp, "AIMBOT", 15)
espRow("FOV Circle", 16, function() return fovColor end, function(col) fovColor = col; fovCircle.Color = col end)

makeSection(sp, "ESP COLORS", 17)
espRow("Skeleton",       18, function() return skelColor end,       function(col) skelColor = col end)
espRow("Charms Fill",    19, function() return charmsFillColor end, function(col) charmsFillColor = col end)
espRow("Charms Outline", 20, function() return charmsOutColor end,  function(col) charmsOutColor = col end)
espRow("Name Tags",      21, function() return nameColor end,       function(col) nameColor = col end)
espRow("Distance Text",  22, function() return distColor end,       function(col) distColor = col end)

makeNote(sp, "Colours apply live. Pick a swatch or type any hex like #44A2F9. Presets reset the interface colours (ESP colours are kept).", 40, 23)

-- ══════════════════════════════════════════════
--  PAGE: INFO
-- ══════════════════════════════════════════════
local ip = tabPages[4]
makeHeader(ip, "C-HUB / INFO", "Controls", "Keybinds and credits.", 0)
makeSection(ip, "KEYBINDS", 1)
makeKeyRow(ip, "=",   "Aim Lock on / off", 2)
makeKeyRow(ip, "-",   "FOV circle", 3)
makeKeyRow(ip, "]",   "ESP charms", 4)
makeKeyRow(ip, "[",   "Aim part (Head / Body)", 5)
makeKeyRow(ip, "L",   "Show / hide this window", 6)
makeSection(ip, "CREDITS", 7)

local creditCard = Instance.new("Frame")
creditCard.Size = UDim2.new(1, 0, 0, 50); creditCard.BorderSizePixel = 0
creditCard.LayoutOrder = 8; creditCard.Parent = ip
bind(creditCard, "BackgroundColor3", "Surface"); corner(creditCard, 8)

local creditAccent = Instance.new("Frame")
creditAccent.Size = UDim2.new(0, 3, 0.6, 0); creditAccent.Position = UDim2.new(0, 0, 0.2, 0)
creditAccent.BorderSizePixel = 0; creditAccent.Parent = creditCard
bind(creditAccent, "BackgroundColor3", "Accent"); corner(creditAccent, 2)

local creditTitle = label(creditCard, "Made by CDev", 13, "Text", Enum.Font.GothamBold)
creditTitle.Size = UDim2.new(1, -20, 0, 22); creditTitle.Position = UDim2.new(0, 14, 0, 6)

local creditSub = label(creditCard, "C-HUB — version 1.0", 10, "Muted", Enum.Font.Gotham)
creditSub.Size = UDim2.new(1, -20, 0, 16); creditSub.Position = UDim2.new(0, 14, 0, 28)

-- ══════════════════════════════════════════════
--  SHOW / HIDE / MINIMIZE
-- ══════════════════════════════════════════════
local function setVisible(v)
    uiVisible = v
    if v then
        win.Visible = true; win.BackgroundTransparency = 1
        win.Size = UDim2.fromOffset(WIN_W * 0.9, WIN_H * 0.9)
        TweenService:Create(win, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(WIN_W, minimized and TITLE_H or WIN_H),
            BackgroundTransparency = 0,
        }):Play()
    else
        TweenService:Create(win, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.fromOffset(WIN_W * 0.9, (minimized and TITLE_H or WIN_H) * 0.9),
            BackgroundTransparency = 1,
        }):Play()
        task.delay(0.2, function() if not uiVisible then win.Visible = false end end)
    end
end

local function setMinimized(m)
    minimized = m
    minBtn.Text = m and "+" or "–"
    tabBar.Visible = not m; content.Visible = not m; footer.Visible = not m; accentLine.Visible = not m
    TweenService:Create(win, SMOOTH, {Size = UDim2.fromOffset(WIN_W, m and TITLE_H or WIN_H)}):Play()
end

closeBtn.MouseButton1Click:Connect(function() setVisible(false) end)
minBtn.MouseButton1Click:Connect(function() setMinimized(not minimized) end)

-- dragging
do
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, win.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                                     startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ══════════════════════════════════════════════
--  KEYBINDS
-- ══════════════════════════════════════════════
local function syncUI()
    local map = {
        ["Aim Lock"]    = aiming,
        ["TriggerBot"]  = triggerbotEnabled,
        ["Aim at Body"] = aimBody,
        ["FOV Circle"]  = fovEnabled,
        ["Charms"]      = charmEnabled,
    }
    for name, v in pairs(map) do
        if toggleRefs[name] then toggleRefs[name].setState(v, true) end
    end
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Minus then
        fovEnabled = not fovEnabled; fovCircle.Visible = fovEnabled; syncUI(); Log.fn("FOV Circle " .. (fovEnabled and "enabled" or "disabled"))
    elseif input.KeyCode == Enum.KeyCode.RightBracket then
        charmEnabled = not charmEnabled; if not charmEnabled then clearAllESP() end; syncUI(); Log.fn("Charms " .. (charmEnabled and "enabled" or "disabled"))
    elseif input.KeyCode == Enum.KeyCode.LeftBracket then
        aimBody = not aimBody; syncUI(); Log.fn("Aim part: " .. (aimBody and "Body" or "Head"))
    end
end)

do
    local lastL, lastEq = false, false
    RunService.Heartbeat:Connect(function()
        local typing = UserInputService:GetFocusedTextBox() ~= nil
        local l  = UserInputService:IsKeyDown(Enum.KeyCode.L)
        local eq = UserInputService:IsKeyDown(Enum.KeyCode.Equals)
        if not typing then
            if l and not lastL then setVisible(not uiVisible) end
            if eq and not lastEq then aiming = not aiming; syncUI(); Log.fn("Aim Lock " .. (aiming and "enabled" or "disabled")) end
        end
        lastL, lastEq = l, eq
    end)
end

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        mouseDeltaAcc = mouseDeltaAcc + input.Delta.Magnitude
    end
end)

-- ══════════════════════════════════════════════
--  AIM LOOP
-- ══════════════════════════════════════════════
pcall(function() RunService:UnbindFromRenderStep("CHubAim") end)
pcall(function() RunService:UnbindFromRenderStep("CHubESP") end)

RunService:BindToRenderStep("CHubAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
    cam = workspace.CurrentCamera or cam
    fovCircle.Position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

    local targets = getValidTargets()
    targetCount = #targets
    local now = os.clock()

    if mouseDeltaAcc > 8 then manualUntil = now + 0.1 end
    mouseDeltaAcc = 0

    local best, bestD = nil, math.huge
    for _, t in ipairs(targets) do
        if t.screenDist < bestD then bestD = t.screenDist; best = t end
    end

    if aiming and best and now >= manualUntil then
        local goal  = CFrame.new(cam.CFrame.Position, best.part.Position)
        local alpha = 1 - (1 - math.clamp(aimSmooth / 100, 0.01, 1)) ^ (math.clamp(dt, 0, 0.1) * 60)
        cam.CFrame  = cam.CFrame:Lerp(goal, alpha)
    end
end)

RunService:BindToRenderStep("CHubESP", Enum.RenderPriority.Camera.Value + 2, function()
    pcall(renderESP)
end)

-- ══════════════════════════════════════════════
--  BACKGROUND LOOP  (highlights + footer)
-- ══════════════════════════════════════════════
task.spawn(function()
    local function chip(c, text, active)
        c.Text = text
        c.TextColor3 = active and C.Accent or C.Muted
    end
    while task.wait(0.1) do
        pcall(updateHighlights)
        chip(chipAim,     "AIM " .. (aiming and "ON" or "OFF"), aiming)
        chip(chipTrigger, "TRIG " .. (triggerbotEnabled and "ON" or "OFF"), triggerbotEnabled)
        chip(chipTargets, "TGT " .. targetCount, targetCount > 0)
        chip(chipEsp,     "ESP " .. espCount, espCount > 0)
        chip(chipZone,    "ZONE " .. ((zoneEnabled and zoneCenter) and "ON" or "OFF"), zoneEnabled and zoneCenter ~= nil)
    end
end)
