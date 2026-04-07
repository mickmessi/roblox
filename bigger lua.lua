-- ============================================================
--  SAVE MANAGER
-- ============================================================

local SaveManager = {}
SaveManager.__index = SaveManager

local HttpService = game:GetService("HttpService")

local folderRoot   = "IGNITE"
local folderSub    = "default-game"
local configName   = "config"

function SaveManager:SetFolder(sub)
    folderSub = sub
    local paths = {folderRoot, folderRoot .. "/" .. folderSub}
    for _, p in ipairs(paths) do
        if not isfolder(p) then makefolder(p) end
    end
end

function SaveManager:SetConfig(name) configName = name end

function SaveManager:GetPath()
    return folderRoot .. "/" .. folderSub .. "/" .. configName .. ".json"
end

function SaveManager:GetFolder()
    return folderRoot .. "/" .. folderSub
end

-- ── Serialization helpers ─────────────────────────────────────
-- JSON can only hold plain types. Color3 and KeyCode must be
-- converted to/from plain tables before encode/decode.

local function serializeValue(v)
    local t = typeof(v)
    if t == "Color3" then
        return { __type = "Color3", r = v.R, g = v.G, b = v.B }
    elseif t == "EnumItem" then
        -- e.g. Enum.KeyCode.Q  →  "Enum.KeyCode.Q"
        return { __type = "EnumItem", value = tostring(v) }
    else
        return v  -- number, string, boolean pass through
    end
end

local function deserializeValue(v)
    if type(v) == "table" then
        if v.__type == "Color3" then
            return Color3.new(v.r, v.g, v.b)
        elseif v.__type == "EnumItem" then
            -- "Enum.KeyCode.Q" → Enum.KeyCode.Q
            local ok, result = pcall(function()
                local parts = string.split(v.value, ".")
                -- parts = {"Enum", "KeyCode", "Q"}
                local enum = Enum
                for i = 2, #parts do
                    enum = enum[parts[i]]
                end
                return enum
            end)
            return ok and result or nil
        end
    end
    return v
end

local function serializeState(data)
    local out = {}
    for k, v in pairs(data) do
        local sv = serializeValue(v)
        -- Only store JSON-compatible types (skip functions, userdata etc.)
        local t = type(sv)
        if t == "number" or t == "string" or t == "boolean" or t == "table" then
            out[k] = sv
        end
    end
    return out
end

local function deserializeState(raw)
    local out = {}
    for k, v in pairs(raw) do
        out[k] = deserializeValue(v)
    end
    return out
end

function SaveManager:Save(data)
    local ok, err = pcall(function()
        writefile(self:GetPath(), HttpService:JSONEncode(serializeState(data)))
    end)
    if not ok then warn("[SaveManager] Save failed: " .. tostring(err)) end
    return ok
end

function SaveManager:Load()
    local path = self:GetPath()
    if not isfile(path) then return nil end
    local ok, result = pcall(function()
        return deserializeState(HttpService:JSONDecode(readfile(path)))
    end)
    if not ok then warn("[SaveManager] Load failed: " .. tostring(result)) return nil end
    return result
end

function SaveManager:Delete()
    local path = self:GetPath()
    if isfile(path) then delfile(path) end
end

function SaveManager:ListConfigs()
    local folder = self:GetFolder()
    if not isfolder(folder) then return {} end
    local out = {}
    for _, f in ipairs(listfiles(folder)) do
        local name = f:match("([^/\\]+)%.json$")
        if name then table.insert(out, name) end
    end
    return out
end

-- ============================================================
--  SETUP
-- ============================================================

SaveManager:SetFolder("arsenal")   -- creates IGNITE/arsenal/

-- ============================================================
--  SERVICES
-- ============================================================

local CoreGui          = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer      = Players.LocalPlayer
local Camera           = Workspace.CurrentCamera

-- ============================================================
--  ORIGINAL VALUES (for cleanup/eject restore)
-- ============================================================

local Original = {
    TimeOfDay  = Lighting.TimeOfDay,
    Brightness = Lighting.Brightness,
    Ambient    = Lighting.Ambient,
    WalkSpeed  = 16,
    JumpPower  = 50,
}

-- Try to read actual game defaults from the humanoid if already spawned
do
    local chr = Players.LocalPlayer.Character
    local hum = chr and chr:FindFirstChildOfClass("Humanoid")
    if hum then
        Original.WalkSpeed = hum.WalkSpeed
        Original.JumpPower = hum.JumpPower
    end
end

-- Re-capture on every respawn (before our code touches the values)
Players.LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        -- Wait one frame so the game sets its defaults first
        task.wait()
        Original.WalkSpeed = hum.WalkSpeed
        Original.JumpPower = hum.JumpPower
    end
end)

-- ============================================================
--  STATE
-- ============================================================

local State = {
    -- Combat (existing)
    AimbotEnabled = false, SilentAim = false, Prediction = false,
    FOV = 90, Smooth = 30, AimTarget = "Head",
    TrigbotEnabled = false, AutoFire = false, TrigDelay = 80, TrigMode = "Always",
    TrigbotKey     = Enum.KeyCode.Q,
    TrigbotToggled = false,
    TrigbotDist    = 500,  -- max distance (studs) for triggerbot
    AutoWeapon     = false,  -- holds LMB to make semi-autos fire fully automatic

    -- Aimbot extras (from Arsenal)
    AimbotKey      = Enum.KeyCode.LeftAlt,
    TeamCheck      = false,
    TargetMode     = "Closest to Crosshair", -- Closest to Crosshair | Distance | Visible
    TargetColor    = false,
    TargetColorVal = Color3.fromRGB(255, 165, 0),

    -- Visuals: ESP (existing)
    BoxESP    = false, NameESP = false, Distance = false,
    MaxDist   = 500,   ESPColor = "Team Color",

    -- Visuals: ESP extras (from Arsenal)
    BoxVisibleColor   = Color3.fromRGB(0, 255, 0),
    BoxInvisibleColor = Color3.fromRGB(255, 0, 0),
    BoxType           = "2D Box",   -- "2D Box" | "Corner Box"
    BoxThickness      = 2,
    NameThickness     = 1,
    SkeletonThickness = 1,
    NameColor         = Color3.fromRGB(255, 255, 255),
    SkeletonESP       = false,
    SkeletonColor     = Color3.fromRGB(255, 255, 255),
    ShowFOV           = true,
    FOVColor          = Color3.fromRGB(255, 255, 255),

    -- Visuals: World (from Arsenal)
    Fullbright     = false,
    TimeOfDay      = 12,
    CustomAmbient  = false,
    AmbientColor   = Color3.fromRGB(100, 100, 100),

    -- Chams
    ChamsEnabled  = false,
    VisibleOnly   = false,
    ChamsOpacity  = 0,
    ChamsColor    = Color3.fromRGB(255, 50, 50),
    ChamsOutline  = Color3.fromRGB(255, 255, 255),
    ChamsOccluded = Color3.fromRGB(80, 20, 20),

    -- Misc (existing)
    InfiniteJump = false, SpeedBoost = false, JumpBoost = false, WalkSpeed = 16, JumpPower = 50,

    -- Utility extras
    Spinbot      = false,
    SpinbotSpeed = 20,   -- degrees per frame
    FlyEnabled   = false,
    FlySpeed     = 60,

    -- Keys
    MenuKey  = Enum.KeyCode.K,
    EjectKey = Enum.KeyCode.End,
}

-- ============================================================
--  ESP DRAWING SYSTEM (from Arsenal)
-- ============================================================

local Drawings = { FOVCircle = nil, ESP = {} }

-- FOV Circle drawing object
Drawings.FOVCircle = Drawing.new("Circle")
Drawings.FOVCircle.Thickness    = 2
Drawings.FOVCircle.NumSides     = 60
Drawings.FOVCircle.Radius       = State.FOV
Drawings.FOVCircle.Filled       = false
Drawings.FOVCircle.Transparency = 1
Drawings.FOVCircle.Color        = State.FOVColor
Drawings.FOVCircle.Visible      = false

-- ============================================================
--  UI ROOT
-- ============================================================

local UI = Instance.new("ScreenGui")
UI.Name            = "IGNITE_UI"
UI.ResetOnSpawn    = false
UI.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
UI.Parent          = CoreGui

-- ============================================================
--  WINDOW
-- ============================================================

local WIN_MIN_W, WIN_MIN_H = 500, 360
local WIN_DEF_W, WIN_DEF_H = 640, 460

local Window = Instance.new("Frame", UI)
Window.Size             = UDim2.new(0, WIN_DEF_W, 0, WIN_DEF_H)
Window.Position         = UDim2.new(0.5, -WIN_DEF_W/2, 0.5, -WIN_DEF_H/2)
Window.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
Window.BorderSizePixel  = 2
Window.BorderColor3     = Color3.fromRGB(80, 80, 80)
Window.Active           = true
Window.ClipsDescendants = true

local Rainbow = Instance.new("Frame", Window)
Rainbow.Size           = UDim2.new(1, 0, 0, 3)
Rainbow.BorderSizePixel = 0
Instance.new("UIGradient", Rainbow).Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(255,0,0)),
    ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255,165,0)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255,255,0)),
    ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0,255,0)),
    ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0,0,255)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(128,0,128)),
})

local TitleBar = Instance.new("Frame", Window)
TitleBar.Size             = UDim2.new(1, 0, 0, 26)
TitleBar.Position         = UDim2.new(0, 0, 0, 3)
TitleBar.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
TitleBar.BorderSizePixel  = 0

local TitleLabel = Instance.new("TextLabel", TitleBar)
TitleLabel.Size                = UDim2.new(1, -10, 1, 0)
TitleLabel.Position            = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text                = "◆ IGNITE  |  Arsenal  |  Made By NegerMand"
TitleLabel.TextXAlignment      = Enum.TextXAlignment.Left
TitleLabel.TextColor3          = Color3.fromRGB(200, 200, 200)
TitleLabel.Font                = Enum.Font.GothamBold
TitleLabel.TextSize            = 12

-- Resize handle
local ResizeHandle = Instance.new("TextButton", Window)
ResizeHandle.Size             = UDim2.new(0, 18, 0, 18)
ResizeHandle.Position         = UDim2.new(1, -18, 1, -18)
ResizeHandle.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
ResizeHandle.BorderSizePixel  = 0
ResizeHandle.Text             = "↘"
ResizeHandle.TextColor3       = Color3.fromRGB(180, 180, 180)
ResizeHandle.Font             = Enum.Font.GothamBold
ResizeHandle.TextSize         = 12
ResizeHandle.ZIndex           = 20

local resizing, rsMouseStart, rsSizeStart = false, Vector2.new(), Vector2.new()
ResizeHandle.InputBegan:Connect(function(i)
    if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    resizing     = true
    rsMouseStart = Vector2.new(i.Position.X, i.Position.Y)
    rsSizeStart  = Vector2.new(Window.AbsoluteSize.X, Window.AbsoluteSize.Y)
    i.Changed:Connect(function()
        if i.UserInputState == Enum.UserInputState.End then resizing = false end
    end)
end)

-- Drag
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
TitleBar.InputBegan:Connect(function(i)
    if i.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    dragging  = true
    dragStart = i.Position
    startPos  = Window.Position
    i.Changed:Connect(function()
        if i.UserInputState == Enum.UserInputState.End then dragging = false end
    end)
end)
TitleBar.InputChanged:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseMovement then dragInput = i end
end)
UserInputService.InputChanged:Connect(function(i)
    if resizing and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = Vector2.new(i.Position.X, i.Position.Y) - rsMouseStart
        Window.Size = UDim2.new(0, math.max(WIN_MIN_W, rsSizeStart.X + d.X),
                                 0, math.max(WIN_MIN_H, rsSizeStart.Y + d.Y))
    elseif dragging and not resizing and i == dragInput then
        local d = i.Position - dragStart
        Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                     startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

-- ============================================================
--  DYNAMIC KEYBIND SYSTEM
-- ============================================================

local KeybindListeners = {}

local function registerKeybind(id, keyCode, callback)
    KeybindListeners[id] = { key = keyCode, callback = callback }
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    for _, bind in pairs(KeybindListeners) do
        if input.KeyCode == bind.key then
            bind.callback()
        end
    end
end)

-- Menu toggle (default K)
registerKeybind("MenuToggle", State.MenuKey, function()
    Window.Visible = not Window.Visible
end)

-- ============================================================
--  HELPERS
-- ============================================================

local function makeCorner(p, r)
    local c = Instance.new("UICorner", p); c.CornerRadius = UDim.new(0, r or 4)
end

local function GroupBox(parent, title, pos, size)
    local box = Instance.new("Frame", parent)
    box.Size             = size
    box.Position         = pos
    box.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    box.BorderSizePixel  = 1
    box.BorderColor3     = Color3.fromRGB(55, 55, 55)

    local lbl = Instance.new("TextLabel", box)
    lbl.Size                  = UDim2.new(1, 0, 0, 18)
    lbl.Position              = UDim2.new(0, 0, 0, -18)
    lbl.BackgroundColor3      = Color3.fromRGB(18, 18, 18)
    lbl.BorderSizePixel       = 0
    lbl.Text                  = "  " .. title
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.TextColor3            = Color3.fromRGB(180, 180, 180)
    lbl.Font                  = Enum.Font.GothamBold
    lbl.TextSize              = 12
    return box
end

local function Label(parent, text, yPos, color)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size                  = UDim2.new(1, -16, 0, 18)
    lbl.Position              = UDim2.new(0, 8, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text                  = text
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.TextColor3            = color or Color3.fromRGB(130, 130, 130)
    lbl.Font                  = Enum.Font.Gotham
    lbl.TextSize              = 11
    return lbl
end

local function Button(parent, text, yPos, w, callback)
    local btn = Instance.new("TextButton", parent)
    btn.Size             = w or UDim2.new(1, -16, 0, 26)
    btn.Position         = UDim2.new(0, 8, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    btn.BorderSizePixel  = 1
    btn.BorderColor3     = Color3.fromRGB(60, 60, 60)
    btn.Text             = text
    btn.TextColor3       = Color3.fromRGB(200, 200, 200)
    btn.Font             = Enum.Font.Gotham
    btn.TextSize         = 12
    makeCorner(btn, 3)
    btn.MouseButton1Click:Connect(function() if callback then callback() end end)
    return btn
end

local Setters = {}
local ApplyState  -- forward declaration; body assigned after all functions are defined

local function Toggle(parent, labelText, yPos, default, stateKey, callback)
    local row = Instance.new("Frame", parent)
    row.Size                  = UDim2.new(1, -16, 0, 22)
    row.Position              = UDim2.new(0, 8, 0, yPos)
    row.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", row)
    lbl.Size                  = UDim2.new(0.75, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                  = labelText
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.TextColor3            = Color3.fromRGB(190, 190, 190)
    lbl.Font                  = Enum.Font.Gotham
    lbl.TextSize              = 12

    local track = Instance.new("Frame", row)
    track.Size             = UDim2.new(0, 36, 0, 18)
    track.Position         = UDim2.new(1, -36, 0.5, -9)
    track.BackgroundColor3 = default and Color3.fromRGB(50,130,220) or Color3.fromRGB(55,55,55)
    makeCorner(track, 9)

    local knob = Instance.new("Frame", track)
    knob.Size             = UDim2.new(0, 14, 0, 14)
    knob.Position         = default and UDim2.new(0,20,0.5,-7) or UDim2.new(0,2,0.5,-7)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    makeCorner(knob, 7)

    local state = default or false
    local function applyState(s, anim)
        state = s
        if stateKey then State[stateKey] = s end
        local info = TweenInfo.new(anim and 0.15 or 0)
        TweenService:Create(track, info, {BackgroundColor3 = s
            and Color3.fromRGB(50,130,220) or Color3.fromRGB(55,55,55)}):Play()
        TweenService:Create(knob, info, {Position = s
            and UDim2.new(0,20,0.5,-7) or UDim2.new(0,2,0.5,-7)}):Play()
        if callback then callback(s) end
    end

    local btn = Instance.new("TextButton", track)
    btn.Size                  = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text                  = ""
    btn.MouseButton1Click:Connect(function() applyState(not state, true) end)
    return function(v) applyState(v, false) end
end

local function Slider(parent, labelText, min, max, default, yPos, stateKey, callback)
    local row = Instance.new("Frame", parent)
    row.Size                  = UDim2.new(1, -16, 0, 34)
    row.Position              = UDim2.new(0, 8, 0, yPos)
    row.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", row)
    lbl.Size                  = UDim2.new(0.65, 0, 0, 14)
    lbl.BackgroundTransparency = 1
    lbl.Text                  = labelText
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.TextColor3            = Color3.fromRGB(190,190,190)
    lbl.Font                  = Enum.Font.Gotham
    lbl.TextSize              = 12

    local valLbl = Instance.new("TextLabel", row)
    valLbl.Size                  = UDim2.new(0.35, 0, 0, 14)
    valLbl.Position              = UDim2.new(0.65, 0, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text                  = tostring(default)
    valLbl.TextXAlignment        = Enum.TextXAlignment.Right
    valLbl.TextColor3            = Color3.fromRGB(100,180,255)
    valLbl.Font                  = Enum.Font.GothamBold
    valLbl.TextSize              = 12

    local track = Instance.new("Frame", row)
    track.Size             = UDim2.new(1, 0, 0, 4)
    track.Position         = UDim2.new(0, 0, 0, 22)
    track.BackgroundColor3 = Color3.fromRGB(50,50,50)
    makeCorner(track, 2)

    local fill = Instance.new("Frame", track)
    fill.Size             = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(50,130,220)
    makeCorner(fill, 2)

    local knob = Instance.new("Frame", fill)
    knob.Size             = UDim2.new(0, 12, 0, 12)
    knob.Position         = UDim2.new(1, -6, 0.5, -6)
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    makeCorner(knob, 6)

    local sliding = false
    local function applyValue(v)
        if stateKey then State[stateKey] = v end
        valLbl.Text = tostring(v)
        fill.Size   = UDim2.new((v-min)/(max-min), 0, 1, 0)
        if callback then callback(v) end
    end

    knob.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = true end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            applyValue(math.floor(min + (max-min)*rel))
        end
    end)
    return function(v) applyValue(math.clamp(math.floor(v), min, max)) end
end

local function Dropdown(parent, options, default, yPos, stateKey, callback)
    local frame = Instance.new("Frame", parent)
    frame.Size             = UDim2.new(1, -16, 0, 24)
    frame.Position         = UDim2.new(0, 8, 0, yPos)
    frame.BackgroundColor3 = Color3.fromRGB(18,18,18)
    frame.BorderSizePixel  = 1
    frame.BorderColor3     = Color3.fromRGB(55,55,55)
    makeCorner(frame, 3)

    local current = Instance.new("TextLabel", frame)
    current.Size                  = UDim2.new(1, -26, 1, 0)
    current.Position              = UDim2.new(0, 8, 0, 0)
    current.BackgroundTransparency = 1
    current.Text                  = default or options[1]
    current.TextXAlignment        = Enum.TextXAlignment.Left
    current.TextColor3            = Color3.fromRGB(200,200,200)
    current.Font                  = Enum.Font.Gotham
    current.TextSize              = 12

    local arrowLbl = Instance.new("TextLabel", frame)
    arrowLbl.Size                  = UDim2.new(0, 20, 1, 0)
    arrowLbl.Position              = UDim2.new(1, -22, 0, 0)
    arrowLbl.BackgroundTransparency = 1
    arrowLbl.Text                  = "▾"
    arrowLbl.TextColor3            = Color3.fromRGB(130,130,130)
    arrowLbl.Font                  = Enum.Font.Gotham
    arrowLbl.TextSize              = 13

    local open     = false
    local dropdown = Instance.new("Frame", parent)
    dropdown.ZIndex           = 15
    dropdown.Visible          = false
    dropdown.BackgroundColor3 = Color3.fromRGB(20,20,20)
    dropdown.BorderSizePixel  = 1
    dropdown.BorderColor3     = Color3.fromRGB(60,60,60)
    dropdown.Size             = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset,
                                          0, #options * 26)
    dropdown.Position         = UDim2.new(frame.Position.X.Scale, frame.Position.X.Offset,
                                          frame.Position.Y.Scale, frame.Position.Y.Offset + 26)
    makeCorner(dropdown, 3)

    local function applyOption(opt)
        current.Text = opt
        if stateKey then State[stateKey] = opt end
        dropdown.Visible = false
        open = false
        if callback then callback(opt) end
    end

    for i, opt in ipairs(options) do
        local item = Instance.new("TextButton", dropdown)
        item.Size                  = UDim2.new(1, 0, 0, 26)
        item.Position              = UDim2.new(0, 0, 0, (i-1)*26)
        item.BackgroundTransparency = 1
        item.Text                  = "  " .. opt
        item.TextXAlignment        = Enum.TextXAlignment.Left
        item.TextColor3            = Color3.fromRGB(190,190,190)
        item.Font                  = Enum.Font.Gotham
        item.TextSize              = 12
        item.ZIndex                = 16
        item.MouseEnter:Connect(function()
            item.BackgroundTransparency = 0
            item.BackgroundColor3 = Color3.fromRGB(35,35,35)
        end)
        item.MouseLeave:Connect(function() item.BackgroundTransparency = 1 end)
        item.MouseButton1Click:Connect(function() applyOption(opt) end)
    end

    local btn = Instance.new("TextButton", frame)
    btn.Size                  = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text                  = ""
    btn.ZIndex                = 2
    btn.MouseButton1Click:Connect(function() open = not open; dropdown.Visible = open end)
    return function(v) applyOption(v) end
end

-- Color picker helper (simple RGB sliders)
-- ============================================================
--  PROPER HSV COLOR PICKER  (LinoriaLib-style popup)
--  Each picker is a small colored swatch inside the groupbox.
--  Clicking it opens a floating 230×260 HSV popup on the ScreenGui.
--  Only one popup is open at a time.
-- ============================================================

local Mouse = Players.LocalPlayer:GetMouse()
local ActiveColorPicker = nil  -- currently open picker popup

-- Helper: darker shade of a color (for borders)
local function DarkerColor(c)
    local h,s,v = Color3.toHSV(c)
    return Color3.fromHSV(h, s, math.max(0, v - 0.3))
end

local function ColorPicker(parent, labelText, yPos, defaultColor, stateKey, callback)
    -- Initialise state
    if stateKey then State[stateKey] = defaultColor end

    local cp = {
        hue = 0, sat = 1, val = 1,
        color = defaultColor,
    }
    do
        local h,s,v = Color3.toHSV(defaultColor)
        cp.hue, cp.sat, cp.val = h, s, v
    end

    -- ── Swatch button (sits inline in the groupbox) ───────────
    local swatchOuter = Instance.new("Frame", parent)
    swatchOuter.Size             = UDim2.new(0, 28, 0, 14)
    swatchOuter.Position         = UDim2.new(1, -36, 0, yPos)
    swatchOuter.BackgroundColor3 = Color3.new(0,0,0)
    swatchOuter.BorderSizePixel  = 0
    swatchOuter.ZIndex           = 6

    local swatch = Instance.new("Frame", swatchOuter)
    swatch.Size             = UDim2.new(1,-2,1,-2)
    swatch.Position         = UDim2.new(0,1,0,1)
    swatch.BackgroundColor3 = defaultColor
    swatch.BorderSizePixel  = 0
    swatch.ZIndex           = 7
    makeCorner(swatch, 2)

    -- ── Floating popup (parented to ScreenGui, hidden by default) ─
    local PICKER_W, PICKER_H = 230, 260

    local popupOuter = Instance.new("Frame", UI)
    popupOuter.Name             = "ColorPickerPopup"
    popupOuter.Size             = UDim2.fromOffset(PICKER_W, PICKER_H)
    popupOuter.BackgroundColor3 = Color3.new(0,0,0)
    popupOuter.BorderSizePixel  = 0
    popupOuter.ZIndex           = 50
    popupOuter.Visible          = false
    makeCorner(popupOuter, 4)

    local popupInner = Instance.new("Frame", popupOuter)
    popupInner.Size             = UDim2.new(1,-2,1,-2)
    popupInner.Position         = UDim2.new(0,1,0,1)
    popupInner.BackgroundColor3 = Color3.fromRGB(22,22,22)
    popupInner.BorderSizePixel  = 0
    popupInner.ZIndex           = 51
    makeCorner(popupInner, 3)

    -- Accent bar at top
    local accentBar = Instance.new("Frame", popupInner)
    accentBar.Size             = UDim2.new(1,0,0,2)
    accentBar.BackgroundColor3 = Color3.fromRGB(50,130,220)
    accentBar.BorderSizePixel  = 0
    accentBar.ZIndex           = 52

    -- Title
    local titleLbl = Instance.new("TextLabel", popupInner)
    titleLbl.Size                  = UDim2.new(1,-8,0,18)
    titleLbl.Position              = UDim2.new(0,6,0,4)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text                  = labelText
    titleLbl.TextXAlignment        = Enum.TextXAlignment.Left
    titleLbl.TextColor3            = Color3.fromRGB(180,180,180)
    titleLbl.Font                  = Enum.Font.GothamBold
    titleLbl.TextSize              = 12
    titleLbl.ZIndex                = 52

    -- ── 2-D Sat/Val map ──────────────────────────────────────
    local svMapOuter = Instance.new("Frame", popupInner)
    svMapOuter.Size             = UDim2.fromOffset(PICKER_W - 30, PICKER_W - 30)
    svMapOuter.Position         = UDim2.fromOffset(4, 24)
    svMapOuter.BackgroundColor3 = Color3.new(1,1,1)
    svMapOuter.BorderSizePixel  = 0
    svMapOuter.ZIndex           = 52
    makeCorner(svMapOuter, 2)

    local svMap = Instance.new("ImageLabel", svMapOuter)
    svMap.Size             = UDim2.new(1,0,1,0)
    svMap.BackgroundColor3 = Color3.fromHSV(cp.hue, 1, 1)
    svMap.BorderSizePixel  = 0
    -- rbxassetid://4155801252 = the white→transparent + black gradient sat/val map
    svMap.Image            = "rbxassetid://4155801252"
    svMap.ZIndex           = 53

    -- Cursor dot on sv map
    local svCursor = Instance.new("Frame", svMap)
    svCursor.Size             = UDim2.fromOffset(10,10)
    svCursor.AnchorPoint      = Vector2.new(0.5,0.5)
    svCursor.BackgroundColor3 = Color3.new(1,1,1)
    svCursor.BorderSizePixel  = 1
    svCursor.BorderColor3     = Color3.new(0,0,0)
    svCursor.ZIndex           = 54
    makeCorner(svCursor, 5)

    -- ── Hue strip ────────────────────────────────────────────
    local hueOuter = Instance.new("Frame", popupInner)
    hueOuter.Size             = UDim2.fromOffset(14, PICKER_W - 30)
    hueOuter.Position         = UDim2.fromOffset(PICKER_W - 22, 24)
    hueOuter.BackgroundColor3 = Color3.new(1,1,1)
    hueOuter.BorderSizePixel  = 0
    hueOuter.ZIndex           = 52
    makeCorner(hueOuter, 2)

    local hueGrad = Instance.new("UIGradient", hueOuter)
    hueGrad.Rotation = 90
    local kps = {}
    for i = 0, 6 do
        kps[i+1] = ColorSequenceKeypoint.new(i/6, Color3.fromHSV(i/6, 1, 1))
    end
    hueGrad.Color = ColorSequence.new(kps)

    local hueCursor = Instance.new("Frame", hueOuter)
    hueCursor.Size             = UDim2.new(1,0,0,2)
    hueCursor.AnchorPoint      = Vector2.new(0,0.5)
    hueCursor.BackgroundColor3 = Color3.new(1,1,1)
    hueCursor.BorderSizePixel  = 1
    hueCursor.BorderColor3     = Color3.new(0,0,0)
    hueCursor.ZIndex           = 54

    -- ── Hex input ────────────────────────────────────────────
    local MAP_BOTTOM = 24 + (PICKER_W - 30) + 6  -- y just below the sv map

    local hexBg = Instance.new("Frame", popupInner)
    hexBg.Size             = UDim2.new(0.5,-8,0,22)
    hexBg.Position         = UDim2.fromOffset(4, MAP_BOTTOM)
    hexBg.BackgroundColor3 = Color3.fromRGB(18,18,18)
    hexBg.BorderSizePixel  = 1
    hexBg.BorderColor3     = Color3.fromRGB(55,55,55)
    hexBg.ZIndex           = 52
    makeCorner(hexBg, 3)

    local hexBox = Instance.new("TextBox", hexBg)
    hexBox.Size                  = UDim2.new(1,-8,1,0)
    hexBox.Position              = UDim2.new(0,4,0,0)
    hexBox.BackgroundTransparency = 1
    hexBox.Text                  = "#" .. defaultColor:ToHex()
    hexBox.PlaceholderText       = "#RRGGBB"
    hexBox.Font                  = Enum.Font.GothamBold
    hexBox.TextSize              = 11
    hexBox.TextColor3            = Color3.fromRGB(200,200,200)
    hexBox.TextXAlignment        = Enum.TextXAlignment.Left
    hexBox.ZIndex                = 53
    hexBox.ClearTextOnFocus      = false

    -- ── RGB input ────────────────────────────────────────────
    local rgbBg = Instance.new("Frame", popupInner)
    rgbBg.Size             = UDim2.new(0.5,-8,0,22)
    rgbBg.Position         = UDim2.new(0.5,4,0,MAP_BOTTOM)
    rgbBg.BackgroundColor3 = Color3.fromRGB(18,18,18)
    rgbBg.BorderSizePixel  = 1
    rgbBg.BorderColor3     = Color3.fromRGB(55,55,55)
    rgbBg.ZIndex           = 52
    makeCorner(rgbBg, 3)

    local rgbBox = Instance.new("TextBox", rgbBg)
    rgbBox.Size                  = UDim2.new(1,-8,1,0)
    rgbBox.Position              = UDim2.new(0,4,0,0)
    rgbBox.BackgroundTransparency = 1
    local function fmtRGB(c)
        return math.floor(c.R*255)..","..math.floor(c.G*255)..","..math.floor(c.B*255)
    end
    rgbBox.Text                  = fmtRGB(defaultColor)
    rgbBox.PlaceholderText       = "R,G,B"
    rgbBox.Font                  = Enum.Font.GothamBold
    rgbBox.TextSize              = 11
    rgbBox.TextColor3            = Color3.fromRGB(200,200,200)
    rgbBox.TextXAlignment        = Enum.TextXAlignment.Left
    rgbBox.ZIndex                = 53
    rgbBox.ClearTextOnFocus      = false

    -- ── Internal update ──────────────────────────────────────
    local function applyColor()
        cp.color = Color3.fromHSV(cp.hue, cp.sat, cp.val)

        -- Update swatch
        swatch.BackgroundColor3  = cp.color
        swatchOuter.BackgroundColor3 = DarkerColor(cp.color)

        -- Update sv map background tint
        svMap.BackgroundColor3 = Color3.fromHSV(cp.hue, 1, 1)

        -- Move cursors
        svCursor.Position  = UDim2.new(cp.sat, 0, 1 - cp.val, 0)
        hueCursor.Position = UDim2.new(0, 0, cp.hue, 0)

        -- Update text inputs
        hexBox.Text = "#" .. cp.color:ToHex()
        rgbBox.Text = fmtRGB(cp.color)

        -- Propagate
        if stateKey then State[stateKey] = cp.color end
        if callback then callback(cp.color) end
    end

    -- ── Sat/Val map drag ─────────────────────────────────────
    local svDragging = false
    svMap.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        svDragging = true
        while svDragging and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
            local ax = svMap.AbsolutePosition.X
            local ay = svMap.AbsolutePosition.Y
            local aw = svMap.AbsoluteSize.X
            local ah = svMap.AbsoluteSize.Y
            cp.sat = math.clamp((Mouse.X - ax) / aw, 0, 1)
            cp.val = 1 - math.clamp((Mouse.Y - ay) / ah, 0, 1)
            applyColor()
            RunService.RenderStepped:Wait()
        end
        svDragging = false
    end)

    -- ── Hue strip drag ───────────────────────────────────────
    local hueDragging = false
    hueOuter.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        hueDragging = true
        while hueDragging and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
            local ay = hueOuter.AbsolutePosition.Y
            local ah = hueOuter.AbsoluteSize.Y
            cp.hue = math.clamp((Mouse.Y - ay) / ah, 0, 1)
            applyColor()
            RunService.RenderStepped:Wait()
        end
        hueDragging = false
    end)

    -- ── Hex box input ────────────────────────────────────────
    hexBox.FocusLost:Connect(function(enter)
        if not enter then return end
        local txt = hexBox.Text:gsub("#",""):gsub("%s","")
        local ok, col = pcall(Color3.fromHex, txt)
        if ok and typeof(col) == "Color3" then
            local h,s,v = Color3.toHSV(col)
            cp.hue, cp.sat, cp.val = h, s, v
            applyColor()
        else
            hexBox.Text = "#" .. cp.color:ToHex()
        end
    end)

    -- ── RGB box input ────────────────────────────────────────
    rgbBox.FocusLost:Connect(function(enter)
        if not enter then return end
        local r,g,b = rgbBox.Text:match("(%d+)[,%s]+(%d+)[,%s]+(%d+)")
        if r and g and b then
            local col = Color3.fromRGB(tonumber(r), tonumber(g), tonumber(b))
            local h,s,v = Color3.toHSV(col)
            cp.hue, cp.sat, cp.val = h, s, v
            applyColor()
        else
            rgbBox.Text = fmtRGB(cp.color)
        end
    end)

    -- ── Show / Hide popup ────────────────────────────────────
    local function showPicker()
        -- Close any other open picker
        if ActiveColorPicker and ActiveColorPicker ~= popupOuter then
            ActiveColorPicker.Visible = false
        end
        ActiveColorPicker = popupOuter

        -- Position popup next to the swatch
        local absPos = swatchOuter.AbsolutePosition
        local absSize = swatchOuter.AbsoluteSize
        local screenSize = UI.AbsoluteSize

        local px = absPos.X + absSize.X + 4
        local py = absPos.Y

        -- Clamp to screen
        if px + PICKER_W > screenSize.X then px = absPos.X - PICKER_W - 4 end
        if py + PICKER_H > screenSize.Y then py = screenSize.Y - PICKER_H - 4 end

        popupOuter.Position = UDim2.fromOffset(px, py)
        popupOuter.Visible  = true
    end

    local function hidePicker()
        popupOuter.Visible = false
        if ActiveColorPicker == popupOuter then
            ActiveColorPicker = nil
        end
    end

    -- Toggle on swatch click
    local swatchBtn = Instance.new("TextButton", swatchOuter)
    swatchBtn.Size                  = UDim2.new(1,0,1,0)
    swatchBtn.BackgroundTransparency = 1
    swatchBtn.Text                  = ""
    swatchBtn.ZIndex                = 8
    swatchBtn.MouseButton1Click:Connect(function()
        if popupOuter.Visible then hidePicker() else showPicker() end
    end)

    -- Close when clicking outside
    UserInputService.InputBegan:Connect(function(inp)
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not popupOuter.Visible then return end

        local ap = popupOuter.AbsolutePosition
        local as = popupOuter.AbsoluteSize
        local mx, my = Mouse.X, Mouse.Y

        -- also keep open if clicking inside the swatch
        local sp = swatchOuter.AbsolutePosition
        local ss = swatchOuter.AbsoluteSize

        local overPopup = mx >= ap.X and mx <= ap.X+as.X and my >= ap.Y and my <= ap.Y+as.Y
        local overSwatch = mx >= sp.X and mx <= sp.X+ss.X and my >= sp.Y and my <= sp.Y+ss.Y

        if not overPopup and not overSwatch then
            hidePicker()
        end
    end)

    -- Initial display
    applyColor()
end
-- ColorPicker: inline cost = 0px (swatch only, popup is floating)

-- Key name helper and KeybindRow — defined here so they can be used in any tab
local function keyName(kc)
    local s = tostring(kc):gsub("Enum.KeyCode.","")
    return s
end

local function KeybindRow(parent, label, yPos, bindId, defaultKey, onChanged)
    local row = Instance.new("Frame", parent)
    row.Size                  = UDim2.new(1,-16,0,26)
    row.Position              = UDim2.new(0,8,0,yPos)
    row.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", row)
    lbl.Size                  = UDim2.new(0.6,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text                  = label
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
    lbl.TextColor3            = Color3.fromRGB(190,190,190)
    lbl.Font                  = Enum.Font.Gotham
    lbl.TextSize              = 12

    local keyBtn = Instance.new("TextButton", row)
    keyBtn.Size             = UDim2.new(0.4,0,0,22)
    keyBtn.Position         = UDim2.new(0.6,0,0.5,-11)
    keyBtn.BackgroundColor3 = Color3.fromRGB(35,35,35)
    keyBtn.BorderSizePixel  = 1
    keyBtn.BorderColor3     = Color3.fromRGB(70,70,70)
    keyBtn.Text             = keyName(defaultKey)
    keyBtn.TextColor3       = Color3.fromRGB(100,180,255)
    keyBtn.Font             = Enum.Font.GothamBold
    keyBtn.TextSize         = 12
    makeCorner(keyBtn, 3)

    local listening = false
    keyBtn.MouseButton1Click:Connect(function()
        if listening then return end
        listening         = true
        keyBtn.Text       = "[ Press key ]"
        keyBtn.TextColor3 = Color3.fromRGB(255,200,60)
        local conn
        conn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
            conn:Disconnect()
            listening = false
            local newKey = input.KeyCode
            keyBtn.Text       = keyName(newKey)
            keyBtn.TextColor3 = Color3.fromRGB(100,180,255)
            if KeybindListeners[bindId] then
                registerKeybind(bindId, newKey, KeybindListeners[bindId].callback)
            end
            if onChanged then onChanged(newKey) end
        end)
    end)
end

-- ============================================================
--  TAB SYSTEM  (vertical left sidebar)
-- ============================================================

local TAB_W    = 110   -- sidebar width
local HEADER_H = 29    -- height of title bar + rainbow bar

local tabSidebar = Instance.new("Frame", Window)
tabSidebar.Size             = UDim2.new(0, TAB_W, 1, -HEADER_H)
tabSidebar.Position         = UDim2.new(0, 0, 0, HEADER_H)
tabSidebar.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
tabSidebar.BorderSizePixel  = 0

-- Thin separator line between sidebar and content
local sideDiv = Instance.new("Frame", Window)
sideDiv.Size             = UDim2.new(0, 1, 1, -HEADER_H)
sideDiv.Position         = UDim2.new(0, TAB_W, 0, HEADER_H)
sideDiv.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
sideDiv.BorderSizePixel  = 0

local tabNames  = {"Combat", "Visuals", "Misc", "Config"}
local tabFrames = {}
local tabBtns   = {}
local CONTENT_Y = HEADER_H   -- content starts right below header (sidebar handles vertical space)

local function switchTab(name)
    for n,f in pairs(tabFrames) do f.Visible = (n==name) end
    for n,b in pairs(tabBtns) do
        b.BackgroundColor3 = (n==name) and Color3.fromRGB(35,35,35) or Color3.fromRGB(16,16,16)
        b.TextColor3       = (n==name) and Color3.fromRGB(255,255,255) or Color3.fromRGB(130,130,130)
        -- Active tab accent bar
        local accent = b:FindFirstChild("_accent")
        if accent then accent.Visible = (n==name) end
    end
end

local TAB_BTN_H = 34
for i, name in ipairs(tabNames) do
    local btn = Instance.new("TextButton", tabSidebar)
    btn.Size             = UDim2.new(1, 0, 0, TAB_BTN_H)
    btn.Position         = UDim2.new(0, 0, 0, (i-1)*TAB_BTN_H)
    btn.BackgroundColor3 = i==1 and Color3.fromRGB(35,35,35) or Color3.fromRGB(16,16,16)
    btn.BorderSizePixel  = 0
    btn.Text             = name
    btn.TextColor3       = i==1 and Color3.fromRGB(255,255,255) or Color3.fromRGB(130,130,130)
    btn.Font             = Enum.Font.GothamBold
    btn.TextSize         = 12
    tabBtns[name]        = btn

    -- Left accent bar shown when tab is active
    local accent = Instance.new("Frame", btn)
    accent.Name             = "_accent"
    accent.Size             = UDim2.new(0, 3, 1, 0)
    accent.BackgroundColor3 = Color3.fromRGB(50, 130, 220)
    accent.BorderSizePixel  = 0
    accent.Visible          = (i == 1)

    local scroll = Instance.new("ScrollingFrame", Window)
    scroll.Size                = UDim2.new(1, -(TAB_W+1), 1, -HEADER_H)
    scroll.Position            = UDim2.new(0, TAB_W+1, 0, HEADER_H)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel     = 0
    scroll.ScrollBarThickness  = 4
    scroll.CanvasSize          = UDim2.new(0,0,0,0)
    scroll.Visible             = (i==1)
    tabFrames[name]            = scroll
    btn.MouseButton1Click:Connect(function() switchTab(name) end)
end

-- ============================================================
--  COMBAT TAB
-- ============================================================

local combat = tabFrames["Combat"]
combat.CanvasSize = UDim2.new(0,0,0,580)

local aimBox = GroupBox(combat, "Aimbot",
    UDim2.new(0,10,0,25), UDim2.new(0.5,-15,0,430))
Setters.AimbotEnabled = Toggle(aimBox, "Enabled",      5,   State.AimbotEnabled, "AimbotEnabled", nil)
KeybindRow(aimBox, "Aimbot (Hold)", 32, "AimbotHold", State.AimbotKey, function(k) State.AimbotKey = k end)
--Setters.SilentAim     = Toggle(aimBox, "Silent Aim",   32,  State.SilentAim,     "SilentAim",     nil)
Setters.Prediction    = Toggle(aimBox, "Prediction",   59,  State.Prediction,    "Prediction",    nil)
Setters.TeamCheck     = Toggle(aimBox, "Team Check",   86,  State.TeamCheck,     "TeamCheck",     nil)
Setters.FOV           = Slider(aimBox, "FOV",   10, 360, State.FOV,   118, "FOV", function(v)
    Drawings.FOVCircle.Radius = v
end)
Setters.Smooth        = Slider(aimBox, "Smooth",  0, 100, State.Smooth, 157, "Smooth", nil)
Label(aimBox, "Target Mode", 200, Color3.fromRGB(150,150,150))
Setters.TargetMode = Dropdown(aimBox, {"Closest to Crosshair", "Distance", "Visible"},
    State.TargetMode, 215, "TargetMode", nil)
Label(aimBox, "Target Hitbox", 248, Color3.fromRGB(150,150,150))
Setters.AimTarget = Dropdown(aimBox, {"Head", "Torso", "HumanoidRootPart", "LeftLeg"},
    State.AimTarget, 263, "AimTarget", nil)
Label(aimBox, "Hold LAlt to Aim  (see Config tab)", 296, Color3.fromRGB(100,100,100))
Setters.TargetColor = Toggle(aimBox, "Target Color", 318, State.TargetColor, "TargetColor", nil)
Label(aimBox, "Target Color", 346, Color3.fromRGB(150,150,150))
ColorPicker(aimBox, "Target Color", 346, State.TargetColorVal, "TargetColorVal", nil)
-- FOV Circle controls
Setters.ShowFOV = Toggle(aimBox, "Show FOV Circle", 372, State.ShowFOV, "ShowFOV", nil)
Label(aimBox, "FOV Color", 400, Color3.fromRGB(150,150,150))
ColorPicker(aimBox, "FOV Color", 400, State.FOVColor, "FOVColor", function(c)
    Drawings.FOVCircle.Color = c
end)

local trigBox = GroupBox(combat, "Trigger Bot",
    UDim2.new(0.5,5,0,25), UDim2.new(0.5,-15,0,275))
Setters.TrigbotEnabled = Toggle(trigBox, "Enabled",    5,  State.TrigbotEnabled, "TrigbotEnabled", nil)
Setters.TrigDelay      = Slider(trigBox, "Delay (ms)", 0, 500, State.TrigDelay, 35, "TrigDelay", nil)
Setters.TrigbotDist    = Slider(trigBox, "Distance (studs)", 50, 1000, State.TrigbotDist, 75, "TrigbotDist", nil)
Label(trigBox, "Mode", 118, Color3.fromRGB(150,150,150))
Setters.TrigMode = Dropdown(trigBox, {"Always","While Holding","Toggle"},
    State.TrigMode, 136, "TrigMode", nil)
KeybindRow(trigBox, "Triggerbot Key", 170, "TrigbotKey", State.TrigbotKey, function(k)
    State.TrigbotKey = k
end)

-- ============================================================
--  VISUALS TAB  (ESP + Skeleton + World)
-- ============================================================

-- ============================================================
-- VISUALS TAB LAYOUT
-- ColorPicker is now a floating popup — zero inline height.
-- Label + swatch = one row of 18px.
-- Toggle = 22px, Slider = 34px, gap = 8px
-- ============================================================

local vis = tabFrames["Visuals"]

-- ── LEFT: Player ESP ─────────────────────────────────────────
-- Box ESP toggle:            y=5,   h=22 → 27
-- Box Type label+dd:         y=33,  h=14+24=38 → 71
-- Box Thickness slider:      y=79,  h=34 → 113
-- Visible Color label+sw:    y=121, h=18 → 139
-- Invisible Color label+sw:  y=147, h=18 → 165
-- gap 8
-- Name ESP toggle:           y=173, h=22 → 195
-- Name Thickness slider:     y=203, h=34 → 237
-- Name Color label+sw:       y=245, h=18 → 263
-- gap 8
-- Skeleton ESP toggle:       y=369, h=22 → 391
-- Skeleton Thickness slider: y=399, h=34 → 433
-- Skeleton Color label+sw:   y=441, h=18 → 459
-- total ≈ 459+10 = 469

local espBox = GroupBox(vis, "Player ESP",
    UDim2.new(0,10,0,25), UDim2.new(0.5,-15,0,360))

Setters.BoxESP = Toggle(espBox, "Box ESP", 5, State.BoxESP, "BoxESP", nil)
Label(espBox, "Box Type", 33, Color3.fromRGB(150,150,150))
Setters.BoxType = Dropdown(espBox, {"2D Box", "Corner Box"}, State.BoxType, 49, "BoxType", nil)
Setters.BoxThickness = Slider(espBox, "Box Thickness", 1, 6, State.BoxThickness, 79, "BoxThickness", nil)
Label(espBox, "Visible Color",   121, Color3.fromRGB(150,150,150))
ColorPicker(espBox, "Visible Color",   121, State.BoxVisibleColor,   "BoxVisibleColor",   nil)
Label(espBox, "Invisible Color", 147, Color3.fromRGB(150,150,150))
ColorPicker(espBox, "Invisible Color", 147, State.BoxInvisibleColor, "BoxInvisibleColor", nil)

Setters.NameESP = Toggle(espBox, "Name ESP", 173, State.NameESP, "NameESP", nil)
Setters.NameThickness = Slider(espBox, "Name Thickness", 1, 4, State.NameThickness, 203, "NameThickness", nil)
Label(espBox, "Name Color", 245, Color3.fromRGB(150,150,150))
ColorPicker(espBox, "Name Color", 245, State.NameColor, "NameColor", nil)

Setters.SkeletonESP = Toggle(espBox, "Skeleton ESP", 271, State.SkeletonESP, "SkeletonESP", nil)
Setters.SkeletonThickness = Slider(espBox, "Skeleton Thickness", 1, 6, State.SkeletonThickness, 301, "SkeletonThickness", nil)
Label(espBox, "Skeleton Color", 330, Color3.fromRGB(150,150,150))
ColorPicker(espBox, "Skeleton Color", 330, State.SkeletonColor, "SkeletonColor", nil)

-- ── RIGHT: World ─────────────────────────────────────────────
-- Fullbright toggle:      y=5,  h=22 → next=27
-- Time of Day slider:     y=35, h=34 → next=69
-- Custom Ambient toggle:  y=77, h=22 → next=99
-- Ambient Color label+sw: y=105,h=18 → next=123
-- box height = 123+10 = 133

local worldBox = GroupBox(vis, "World",
    UDim2.new(0.5,5,0,25), UDim2.new(0.5,-15,0,140))
Setters.Fullbright    = Toggle(worldBox, "Fullbright",      5,  State.Fullbright,    "Fullbright",    nil)
Setters.TimeOfDay     = Slider(worldBox, "Time of Day", 0, 24, State.TimeOfDay, 35, "TimeOfDay",     nil)
Setters.CustomAmbient = Toggle(worldBox, "Custom Ambient",  77, State.CustomAmbient, "CustomAmbient", nil)
Label(worldBox, "Ambient Color", 105, Color3.fromRGB(150,150,150))
ColorPicker(worldBox, "Ambient Color", 105, State.AmbientColor, "AmbientColor", nil)

-- ============================================================
--  CHAMS SYSTEM  (Highlight-based, full implementation)
-- ============================================================

--  CHAMS SYSTEM
-- ============================================================

local Chams = {}

-- Single highlight per player, AlwaysOnTop.
-- Each frame we raycast to check visibility and swap colors accordingly:
--   visible   → ChamsColor (fill) + ChamsOutline
--   behind wall → ChamsOccluded (fill, dimmer) + ChamsOutline
--   VisibleOnly ON + behind wall → fully hidden

local function CreateChams(player)
    if Chams[player] then return end
    local char = player.Character
    if not char then return end

    local h = Instance.new("Highlight")
    h.Adornee            = char
    h.Parent             = char
    h.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
    h.FillColor          = State.ChamsColor   or Color3.fromRGB(255,50,50)
    h.OutlineColor       = State.ChamsOutline or Color3.fromRGB(255,255,255)
    h.FillTransparency   = (State.ChamsOpacity or 0) / 100
    h.OutlineTransparency = 0

    Chams[player] = h
end

local function RemoveChams(player)
    if not Chams[player] then return end
    pcall(function() Chams[player]:Destroy() end)
    Chams[player] = nil
end

local function RefreshAllChams()
    if not State.ChamsEnabled then
        for player in pairs(Chams) do RemoveChams(player) end
        return
    end
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not (player.Character and player.Character:FindFirstChild("HumanoidRootPart")) then continue end
        if State.TeamCheck and SameTeam(player) then
            RemoveChams(player)
            continue
        end
        RemoveChams(player)
        CreateChams(player)
    end
end

-- ── Chams UI ─────────────────────────────────────────────────
-- Enabled toggle:             y=5,  h=22 → next=27
-- Visible Only toggle:        y=35, h=22 → next=57
-- Fill Opacity slider:        y=67, h=34 → next=101
-- Fill Color label+sw:        y=109,h=18 → next=127
-- Outline Color label+sw:     y=135,h=18 → next=153
-- Through-Wall Color label+sw:y=161,h=18 → next=179
-- box height = 179+12 = 191
-- placed directly below World box: 25+18+140+10 = 193

local chamBox = GroupBox(vis, "Chams",
    UDim2.new(0.5,5,0,193), UDim2.new(0.5,-15,0,196))

Setters.ChamsEnabled = Toggle(chamBox, "Enabled", 5, State.ChamsEnabled, "ChamsEnabled", function(v)
    if v then RefreshAllChams() else
        for player in pairs(Chams) do RemoveChams(player) end
    end
end)

Setters.VisibleOnly = Toggle(chamBox, "Visible Only (no wallhack)", 35, State.VisibleOnly, "VisibleOnly", nil)

Setters.ChamsOpacity = Slider(chamBox, "Fill Opacity", 0, 100, State.ChamsOpacity, 67, "ChamsOpacity", function()
    for _, h in pairs(Chams) do
        if h then h.FillTransparency = (State.ChamsOpacity or 0) / 100 end
    end
end)

Label(chamBox, "Fill Color", 109, Color3.fromRGB(150,150,150))
ColorPicker(chamBox, "Fill Color", 109, State.ChamsColor, "ChamsColor", nil)

Label(chamBox, "Outline Color", 135, Color3.fromRGB(150,150,150))
ColorPicker(chamBox, "Outline Color", 135, State.ChamsOutline, "ChamsOutline", nil)

Label(chamBox, "Through-Wall Color", 161, Color3.fromRGB(150,150,150))
ColorPicker(chamBox, "Through-Wall Color", 161, State.ChamsOccluded, "ChamsOccluded", nil)

-- canvas: left col bottom = 25+18+360 = 403, right col bottom = 193+18+196 = 407
vis.CanvasSize = UDim2.new(0,0,0,430)

-- ============================================================
--  MISC TAB
-- ============================================================

local misc = tabFrames["Misc"]
misc.CanvasSize = UDim2.new(0,0,0,385)

local movBox = GroupBox(misc, "Movement",
    UDim2.new(0,10,0,25), UDim2.new(0.5,-15,0,175))
Setters.InfiniteJump = Toggle(movBox, "Infinite Jump", 5, State.InfiniteJump, "InfiniteJump", function(v)
    if v then
        _G.IJ = UserInputService.JumpRequest:Connect(function()
            local chr = LocalPlayer.Character
            local hum = chr and chr:FindFirstChild("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    else
        if _G.IJ then _G.IJ:Disconnect() end
    end
end)

Setters.SpeedBoost = Toggle(movBox, "Speed Boost", 32, State.SpeedBoost, "SpeedBoost", function(v)
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = v and (State.WalkSpeed or 16) or Original.WalkSpeed
    end
end)

Setters.WalkSpeed = Slider(movBox, "Walk Speed", 16, 300, State.WalkSpeed, 62, "WalkSpeed", function(v)
    if State.SpeedBoost then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end
end)

Setters.JumpBoost = Toggle(movBox, "Jump Boost", 101, State.JumpBoost, "JumpBoost", function(v)
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.JumpPower = v and (State.JumpPower or 50) or Original.JumpPower
    end
end)

Setters.JumpPower = Slider(movBox, "Jump Power", 50, 500, State.JumpPower, 128, "JumpPower", function(v)
    if State.JumpBoost then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.JumpPower = v end
    end
end)

local utilBox = GroupBox(misc, "Utility",
    UDim2.new(0.5,5,0,25), UDim2.new(0.5,-15,0,210))
Setters.AutoWeapon  = Toggle(utilBox, "Automatic Weapon",   5,  State.AutoWeapon,  "AutoWeapon",  nil)
Setters.Spinbot     = Toggle(utilBox, "Spinbot",            32, State.Spinbot,     "Spinbot",     nil)
Setters.SpinbotSpeed = Slider(utilBox, "Spin Speed", 1, 60, State.SpinbotSpeed, 59, "SpinbotSpeed", nil)
Setters.FlyEnabled  = Toggle(utilBox, "Fly",               100, State.FlyEnabled,  "FlyEnabled",  function(v)
    if not v then
        -- restore humanoid state when fly is turned off
        local chr = LocalPlayer.Character
        local hum = chr and chr:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
        local hrp = chr and chr:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("__FlyVel")
            local bg = hrp:FindFirstChild("__FlyGyro")
            if bv then bv:Destroy() end
            if bg then bg:Destroy() end
        end
    end
end)
Setters.FlySpeed    = Slider(utilBox, "Fly Speed", 10, 300, State.FlySpeed, 127, "FlySpeed", nil)
Button(utilBox, "⚡  Insta Kill (Self)", 170, nil, function()
    local chr = LocalPlayer.Character
    local hum = chr and chr:FindFirstChildOfClass("Humanoid")
    if hum then hum.Health = 0 end
end)

local playerName = game.Players.LocalPlayer.Name

local infoBox = GroupBox(misc, "Info",
    UDim2.new(0,10,0,263), UDim2.new(1,-20,0,200))

Label(infoBox, "Connected  ●",              8,  Color3.fromRGB(80,200,80))
Label(infoBox, "Welcome back, " .. playerName, 26, Color3.fromRGB(200,200,200))
Label(infoBox, "K = menu toggle",          44, Color3.fromRGB(200,200,200))
Label(infoBox, "End = eject/unload",       62, Color3.fromRGB(200,200,200))
Label(infoBox, "any bug or questions? @ me on Discord: @negerti",        80, Color3.fromRGB(200,200,200))
Label(infoBox, "this is a free script so dont expect the most", 98, Color3.fromRGB(200,200,200))
Label(infoBox, "i will be supporting other games later on", 116, Color3.fromRGB(200,200,200))
Label(infoBox, "dm @negerti if you have game suggestions or feature suggestions.", 134, Color3.fromRGB(200,200,200))
Label(infoBox, "i am not a pro scripter it is something i do for fun", 152, Color3.fromRGB(200,200,200))
Label(infoBox, "the script is 95% self made", 170, Color3.fromRGB(200,200,200))
-- ============================================================
--  CONFIG TAB
-- ============================================================

local cfg = tabFrames["Config"]
cfg.CanvasSize = UDim2.new(0,0,0,520)

-- LEFT: Keybinds
local keybindBox = GroupBox(cfg, "Essential",
    UDim2.new(0,10,0,25), UDim2.new(0.5,-15,0,310))

Label(keybindBox, "left click the key picker then the key you want to bind", 6, Color3.fromRGB(100,100,100))
KeybindRow(keybindBox, "Menu Toggle",   28, "MenuToggle", State.MenuKey, function(k) State.MenuKey = k end)
KeybindRow(keybindBox, "Eject / Unload",60, "Eject",      State.EjectKey, function(k)
    State.EjectKey = k
    registerKeybind("Eject", k, function() Eject() end)
end)
--KeybindRow(keybindBox, "Aimbot (Hold)", 92, "AimbotHold", State.AimbotKey, function(k) State.AimbotKey = k end)

local sep = Instance.new("Frame", keybindBox)
sep.Size             = UDim2.new(1,-16,0,1)
sep.Position         = UDim2.new(0,8,0,92)
sep.BackgroundColor3 = Color3.fromRGB(50,50,50)
sep.BorderSizePixel  = 0

Label(keybindBox, "Eject will reset features & unload UI", 98, Color3.fromRGB(200,200,200))
Button(keybindBox, "🚪  Eject Now", 128, nil, function() Eject() end)

Label(keybindBox, "─────────────────────────", 156, Color3.fromRGB(50,50,50))
Label(keybindBox, "Save folder:", 178, Color3.fromRGB(200,200,200))
Label(keybindBox, "IGNITE/arsenal/", 192, Color3.fromRGB(80,200,80))

-- RIGHT: Config Manager
local cfgBox = GroupBox(cfg, "Config Manager",
    UDim2.new(0.5,5,0,25), UDim2.new(0.5,-15,0,310))

local inputBg = Instance.new("Frame", cfgBox)
inputBg.Size             = UDim2.new(1,-16,0,26)
inputBg.Position         = UDim2.new(0,8,0,8)
inputBg.BackgroundColor3 = Color3.fromRGB(14,14,14)
inputBg.BorderSizePixel  = 1
inputBg.BorderColor3     = Color3.fromRGB(60,60,60)
makeCorner(inputBg, 3)

local cfgInput = Instance.new("TextBox", inputBg)
cfgInput.Size                  = UDim2.new(1,-10,1,0)
cfgInput.Position              = UDim2.new(0,6,0,0)
cfgInput.BackgroundTransparency = 1
cfgInput.Text                  = "config"
cfgInput.PlaceholderText       = "Config name..."
cfgInput.TextXAlignment        = Enum.TextXAlignment.Left
cfgInput.TextColor3            = Color3.fromRGB(200,200,200)
cfgInput.PlaceholderColor3     = Color3.fromRGB(90,90,90)
cfgInput.Font                  = Enum.Font.Gotham
cfgInput.TextSize              = 12

local cfgStatus = Instance.new("TextLabel", cfgBox)
cfgStatus.Size                  = UDim2.new(1,-16,0,14)
cfgStatus.Position              = UDim2.new(0,8,0,38)
cfgStatus.BackgroundTransparency = 1
cfgStatus.Text                  = "Ready"
cfgStatus.TextXAlignment        = Enum.TextXAlignment.Left
cfgStatus.TextColor3            = Color3.fromRGB(80,220,80)
cfgStatus.Font                  = Enum.Font.Gotham
cfgStatus.TextSize              = 11

local function setStatus(msg, err)
    cfgStatus.Text      = msg
    cfgStatus.TextColor3 = err
        and Color3.fromRGB(210,80,80) or Color3.fromRGB(80,180,80)
end

Button(cfgBox, "💾 Save", 56, UDim2.new(0.5,-12,0,24), function()
    local name = cfgInput.Text ~= "" and cfgInput.Text or "config"
    SaveManager:SetConfig(name)
    if SaveManager:Save(State) then
        setStatus("Saved: "..name..".json", false)
    else
        setStatus("Save failed!", true)
    end
end)

local loadBtn = Instance.new("TextButton", cfgBox)
loadBtn.Size             = UDim2.new(0.5,-12,0,24)
loadBtn.Position         = UDim2.new(0.5,4,0,56)
loadBtn.BackgroundColor3 = Color3.fromRGB(35,35,35)
loadBtn.BorderSizePixel  = 1
loadBtn.BorderColor3     = Color3.fromRGB(60,60,60)
loadBtn.Text             = "📂 Load"
loadBtn.TextColor3       = Color3.fromRGB(200,200,200)
loadBtn.Font             = Enum.Font.Gotham
loadBtn.TextSize         = 12
makeCorner(loadBtn, 3)
loadBtn.MouseButton1Click:Connect(function()
    local name = cfgInput.Text ~= "" and cfgInput.Text or "config"
    SaveManager:SetConfig(name)
    local data = SaveManager:Load()
    if not data then setStatus("Not found: "..name, true) return end
    ApplyState(data)
    setStatus("Loaded: "..name..".json", false)
end)

Button(cfgBox, "🗑 Delete", 86, UDim2.new(0.5,-12,0,24), function()
    local name = cfgInput.Text ~= "" and cfgInput.Text or "config"
    SaveManager:SetConfig(name)
    SaveManager:Delete()
    setStatus("Deleted: "..name, false)
end)

local refreshBtn = Instance.new("TextButton", cfgBox)
refreshBtn.Size             = UDim2.new(0.5,-12,0,24)
refreshBtn.Position         = UDim2.new(0.5,4,0,86)
refreshBtn.BackgroundColor3 = Color3.fromRGB(35,35,35)
refreshBtn.BorderSizePixel  = 1
refreshBtn.BorderColor3     = Color3.fromRGB(60,60,60)
refreshBtn.Text             = "🔄 Refresh"
refreshBtn.TextColor3       = Color3.fromRGB(200,200,200)
refreshBtn.Font             = Enum.Font.Gotham
refreshBtn.TextSize         = 12
makeCorner(refreshBtn, 3)

Label(cfgBox, "Saved configs:", 116, Color3.fromRGB(120,120,120))

local listFrame = Instance.new("ScrollingFrame", cfgBox)
listFrame.Size                = UDim2.new(1,-16,0,130)
listFrame.Position            = UDim2.new(0,8,0,132)
listFrame.BackgroundColor3    = Color3.fromRGB(16,16,16)
listFrame.BorderSizePixel     = 1
listFrame.BorderColor3        = Color3.fromRGB(45,45,45)
listFrame.ScrollBarThickness  = 4
listFrame.CanvasSize          = UDim2.new(0,0,0,0)
makeCorner(listFrame, 3)

local listLayout = Instance.new("UIListLayout", listFrame)
listLayout.Padding    = UDim.new(0,0)
listLayout.SortOrder  = Enum.SortOrder.LayoutOrder

local listItems = {}

local function rebuildList()
    for _, item in ipairs(listItems) do item:Destroy() end
    listItems = {}
    local configs = SaveManager:ListConfigs()
    if #configs == 0 then
        local empty = Instance.new("TextLabel", listFrame)
        empty.Size                  = UDim2.new(1,0,0,30)
        empty.BackgroundTransparency = 1
        empty.Text                  = "  No configs found"
        empty.TextXAlignment        = Enum.TextXAlignment.Left
        empty.TextColor3            = Color3.fromRGB(80,80,80)
        empty.Font                  = Enum.Font.Gotham
        empty.TextSize              = 11
        table.insert(listItems, empty)
    else
        for i, name in ipairs(configs) do
            local row = Instance.new("TextButton", listFrame)
            row.Size             = UDim2.new(1,0,0,28)
            row.BackgroundColor3 = i%2==0 and Color3.fromRGB(20,20,20) or Color3.fromRGB(24,24,24)
            row.BorderSizePixel  = 0
            row.Text             = ""
            row.LayoutOrder      = i
            table.insert(listItems, row)

            local nameLbl = Instance.new("TextLabel", row)
            nameLbl.Size                  = UDim2.new(0.75,0,1,0)
            nameLbl.Position              = UDim2.new(0,10,0,0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text                  = name .. ".json"
            nameLbl.TextXAlignment        = Enum.TextXAlignment.Left
            nameLbl.TextColor3            = Color3.fromRGB(180,180,180)
            nameLbl.Font                  = Enum.Font.Gotham
            nameLbl.TextSize              = 11

            local useBtn = Instance.new("TextButton", row)
            useBtn.Size             = UDim2.new(0,42,0,20)
            useBtn.Position         = UDim2.new(1,-50,0.5,-10)
            useBtn.BackgroundColor3 = Color3.fromRGB(40,70,110)
            useBtn.BorderSizePixel  = 0
            useBtn.Text             = "Load"
            useBtn.TextColor3       = Color3.fromRGB(160,210,255)
            useBtn.Font             = Enum.Font.GothamBold
            useBtn.TextSize         = 11
            makeCorner(useBtn, 3)

            local function doLoad()
                cfgInput.Text = name
                SaveManager:SetConfig(name)
                local data = SaveManager:Load()
                if data then
                    ApplyState(data)
                    setStatus("Loaded: "..name..".json", false)
                end
            end

            row.MouseButton1Click:Connect(function() cfgInput.Text = name end)
            useBtn.MouseButton1Click:Connect(doLoad)
            row.MouseEnter:Connect(function() row.BackgroundColor3 = Color3.fromRGB(38,38,38) end)
            row.MouseLeave:Connect(function()
                row.BackgroundColor3 = i%2==0 and Color3.fromRGB(20,20,20) or Color3.fromRGB(24,24,24)
            end)
        end
    end
    listFrame.CanvasSize = UDim2.new(0,0,0, listLayout.AbsoluteContentSize.Y)
end

listLayout.Changed:Connect(function()
    listFrame.CanvasSize = UDim2.new(0,0,0, listLayout.AbsoluteContentSize.Y)
end)

refreshBtn.MouseButton1Click:Connect(function()
    rebuildList()
    setStatus("List refreshed", false)
end)

rebuildList()

-- ============================================================
--  EJECT FUNCTION
-- ============================================================

local function FlyCleanup()
    local chr = LocalPlayer.Character
    local hum = chr and chr:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
    local hrp = chr and chr:FindFirstChild("HumanoidRootPart")
    if hrp then
        local bv = hrp:FindFirstChild("__FlyVel")
        local bg = hrp:FindFirstChild("__FlyGyro")
        if bv then bv:Destroy() end
        if bg then bg:Destroy() end
    end
end

function Eject()
    -- Disconnect infinite jump
    if _G.IJ then _G.IJ:Disconnect() end
    -- Reset humanoid stats
    local chr = LocalPlayer.Character
    local hum = chr and chr:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = Original.WalkSpeed
        hum.JumpPower = Original.JumpPower
    end
    -- Restore lighting
    Lighting.TimeOfDay = Original.TimeOfDay
    Lighting.Brightness = Original.Brightness
    Lighting.Ambient = Original.Ambient
    -- Remove all ESP drawings + chams
    for player, _ in pairs(Drawings.ESP) do
        RemoveESP(player)
    end
    for player in pairs(Chams) do
        RemoveChams(player)
    end
    if Drawings.FOVCircle then Drawings.FOVCircle:Remove() end
    -- Unbind aimbot, spinbot, fly
    pcall(function() RunService:UnbindFromRenderStep("__IGNITEAimbot")  end)
    pcall(function() RunService:UnbindFromRenderStep("__IGNITESpinbot") end)
    pcall(function() RunService:UnbindFromRenderStep("__IGNITEFly")     end)
    FlyCleanup()
    -- Destroy UI
    UI:Destroy()
    print("[IGNITE] Ejected.")
end

registerKeybind("Eject", State.EjectKey, Eject)

-- ============================================================
--  UTILITY FUNCTIONS (Arsenal)
-- ============================================================

local function IsAlive(plr)
    local char = plr.Character
    return char
        and char:FindFirstChild("Humanoid")
        and char.Humanoid.Health > 0
        and char:FindFirstChild("HumanoidRootPart")
end


local function SameTeam(plr)
    return plr.Team == LocalPlayer.Team
end

local function WorldToScreen(pos)
    local screenPoint, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPoint.X, screenPoint.Y), onScreen
end

-- Shared, pre-allocated RaycastParams — created once, reused every frame
local _aimRayParams  = RaycastParams.new()
_aimRayParams.FilterType  = Enum.RaycastFilterType.Blacklist
local _espRayParams  = RaycastParams.new()
_espRayParams.FilterType  = Enum.RaycastFilterType.Blacklist
local _chamRayParams = RaycastParams.new()
_chamRayParams.FilterType = Enum.RaycastFilterType.Blacklist
local _trigRayParams = RaycastParams.new()
_trigRayParams.FilterType = Enum.RaycastFilterType.Blacklist

local function GetClosestPlayer()
    local screenCentre = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local camPos       = Camera.CFrame.Position
    local best, bestVal = nil, math.huge
    local mode = State.TargetMode or "Closest to Crosshair"

    _aimRayParams.FilterDescendantsInstances = { LocalPlayer.Character or {} }

    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not IsAlive(player) then continue end
        if State.TeamCheck and SameTeam(player) then continue end

        local char = player.Character
        local part = char:FindFirstChild(State.AimTarget or "Head")
                  or char:FindFirstChild("HumanoidRootPart")
        if not part then continue end

        if mode == "Closest to Crosshair" then
            local screenPos, onScreen = WorldToScreen(part.Position)
            if not onScreen then continue end
            local dist = (screenCentre - screenPos).Magnitude
            if dist < (State.FOV or 90) and dist < bestVal then
                best    = player
                bestVal = dist
            end

        elseif mode == "Distance" then
            -- 3D world distance from camera — no FOV radius gate (infinite)
            local dist = (part.Position - camPos).Magnitude
            if dist < bestVal then
                best    = player
                bestVal = dist
            end

        elseif mode == "Visible" then
            local screenPos, onScreen = WorldToScreen(part.Position)
            if not onScreen then continue end
            local dist = (screenCentre - screenPos).Magnitude
            if dist >= (State.FOV or 90) then continue end

            _aimRayParams.FilterDescendantsInstances = { LocalPlayer.Character or {}, char }
            local dir    = (part.Position - camPos)
            local result = Workspace:Raycast(camPos, dir, _aimRayParams)
            if result then continue end

            if dist < bestVal then
                best    = player
                bestVal = dist
            end
        end
    end

    return best
end

local _skelCache = {}  -- [player] = { char, parts = {...} }

local function GetSkelParts(player)
    local char = player.Character
    if not char then _skelCache[player] = nil; return nil end
    local cached = _skelCache[player]
    if cached and cached.char == char then return cached.parts end
    -- Rebuild cache for this character
    local function S(a, b) return char:FindFirstChild(a) or char:FindFirstChild(b) end
    local parts = {
        Head          = S("Head",          "Head"),
        UpperTorso    = S("UpperTorso",    "Torso"),
        LowerTorso    = S("LowerTorso",    "Torso"),
        LeftUpperArm  = S("LeftUpperArm",  "Left Arm"),
        LeftLowerArm  = S("LeftLowerArm",  "Left Arm"),
        LeftHand      = S("LeftHand",      "Left Arm"),
        RightUpperArm = S("RightUpperArm", "Right Arm"),
        RightLowerArm = S("RightLowerArm", "Right Arm"),
        RightHand     = S("RightHand",     "Right Arm"),
        LeftUpperLeg  = S("LeftUpperLeg",  "Left Leg"),
        LeftLowerLeg  = S("LeftLowerLeg",  "Left Leg"),
        LeftFoot      = S("LeftFoot",      "Left Leg"),
        RightUpperLeg = S("RightUpperLeg", "Right Leg"),
        RightLowerLeg = S("RightLowerLeg", "Right Leg"),
    }
    _skelCache[player] = { char = char, parts = parts }
    return parts
end

Players.PlayerRemoving:Connect(function(p) _skelCache[p] = nil end)

-- ============================================================
--  ESP DRAWING OBJECTS (Arsenal)
-- ============================================================

local function CreateESP(player)
    if Drawings.ESP[player] then return end

    local Box = Drawing.new("Square")
    Box.Visible = false; Box.Color = Color3.new(1,1,1); Box.Thickness = 2
    Box.Filled = false; Box.Transparency = 1

    -- 8 lines for corner box (4 corners × 2 lines each: horizontal + vertical)
    local Corners = {}
    for i = 1, 8 do
        local line = Drawing.new("Line")
        line.Visible = false; line.Thickness = 2; line.Color = Color3.new(1,1,1)
        Corners[i] = line
    end

    local Name = Drawing.new("Text")
    Name.Visible = false; Name.Color = Color3.new(1,1,1); Name.Size = 16
    Name.Center = true; Name.Outline = true; Name.Font = 2

    local Bones = {}
    for i = 1, 12 do
        local line = Drawing.new("Line")
        line.Visible = false; line.Thickness = 1; line.Color = Color3.new(1,1,1)
        Bones[i] = line
    end

    Drawings.ESP[player] = {
        Box = Box, Corners = Corners, Name = Name,
        Bones = Bones
    }
end

function RemoveESP(player)
    local esp = Drawings.ESP[player]
    if not esp then return end
    pcall(function()
        esp.Box.Visible        = false
        esp.Name.Visible       = false
        if esp.Corners then
            for i = 1, #esp.Corners do
                if esp.Corners[i] then esp.Corners[i].Visible = false end
            end
        end
        if esp.Bones then
            for i = 1, #esp.Bones do
                if esp.Bones[i] then esp.Bones[i].Visible = false end
            end
        end
    end)
    for _, obj in pairs(esp) do
        if typeof(obj) == "table" then
            for _, line in pairs(obj) do
                if line then pcall(function() line:Remove() end) end
            end
        else
            if obj then pcall(function() obj:Remove() end) end
        end
    end
    Drawings.ESP[player] = nil
end

-- Spawn / death hooks
local function OnCharacterAdded(player)
    if player == LocalPlayer then return end
    -- small wait so character parts exist before we adorn
    task.wait(0.1)
    CreateESP(player)
    if State.ChamsEnabled and (not State.TeamCheck or not SameTeam(player)) then
        CreateChams(player)
    end
end

local function OnCharacterRemoving(player)
    RemoveESP(player)
    RemoveChams(player)
end

-- Existing players
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        if player.Character then
            CreateESP(player)
            if State.ChamsEnabled and (not State.TeamCheck or not SameTeam(player)) then
                CreateChams(player)
            end
        end
        player.CharacterAdded:Connect(function() OnCharacterAdded(player) end)
        player.CharacterRemoving:Connect(function() OnCharacterRemoving(player) end)
    end
end

-- New players
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function() OnCharacterAdded(player) end)
    player.CharacterRemoving:Connect(function() OnCharacterRemoving(player) end)
end)
Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
    RemoveChams(player)
end)

-- ============================================================
--  MAIN LOOP (Arsenal RenderStepped)
-- ============================================================

-- Lighting change tracking — only write to Lighting when values actually change
local _lastTOD        = -1
local _lastBrightness = -1
local _lastAmbient    = Color3.new(-1,-1,-1)

RunService.RenderStepped:Connect(function()

    -- FOV Circle (always at screen centre)
    if State.AimbotEnabled and State.ShowFOV then
        Drawings.FOVCircle.Visible  = true
        Drawings.FOVCircle.Radius   = State.FOV
        Drawings.FOVCircle.Position = Vector2.new(
            Camera.ViewportSize.X / 2,
            Camera.ViewportSize.Y / 2
        )
        local aimbotKeyHeld = UserInputService:IsKeyDown(State.AimbotKey or Enum.KeyCode.LeftAlt)
        if State.TargetColor and aimbotKeyHeld then
            Drawings.FOVCircle.Color = State.TargetColorVal or Color3.fromRGB(255,165,0)
        else
            Drawings.FOVCircle.Color = State.FOVColor or Color3.new(1,1,1)
        end
    else
        Drawings.FOVCircle.Visible = false
    end

    -- World Lighting — only write when the value actually changed (avoids per-frame Roblox property traffic)
    local wantTOD  = math.clamp(math.floor(State.TimeOfDay or 12), 0, 24)
    local wantBrit = State.Fullbright and 2 or 1
    local wantAmb  = (State.CustomAmbient and State.AmbientColor) and State.AmbientColor or Original.Ambient
    if wantTOD ~= _lastTOD then
        Lighting.TimeOfDay = string.format("%02d:00:00", wantTOD)
        _lastTOD = wantTOD
    end
    if wantBrit ~= _lastBrightness then
        Lighting.Brightness = wantBrit
        _lastBrightness = wantBrit
    end
    if wantAmb ~= _lastAmbient then
        Lighting.Ambient = wantAmb
        _lastAmbient = wantAmb
    end

    -- Movement — only override when boost features are active
    local character = LocalPlayer.Character
    local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        if State.SpeedBoost then
            humanoid.WalkSpeed = State.WalkSpeed or 16
        end
        if State.JumpBoost then
            humanoid.JumpPower = State.JumpPower or 50
        end
    end

    -- Determine current aimbot target for Target Color feature
    local currentTarget = nil
    if State.AimbotEnabled and State.TargetColor
       and UserInputService:IsKeyDown(State.AimbotKey or Enum.KeyCode.LeftAlt) then
        currentTarget = GetClosestPlayer()
    end

    -- ESP Loop
    -- Build a set of current valid players for O(1) lookup
    local validPlayers = {}
    for _, p in pairs(Players:GetPlayers()) do validPlayers[p] = true end

    for player, esp in pairs(Drawings.ESP) do
        -- Remove if player has left the game entirely
        if not validPlayers[player] then
            RemoveESP(player)
            continue
        end

        local alive      = IsAlive(player)
        local shouldShow = alive and (not State.TeamCheck or not SameTeam(player))

        -- Resolve colors: use target color if this is the aimed player, else defaults
        local isTarget   = (player == currentTarget)
        local tc         = State.TargetColorVal or Color3.fromRGB(255,165,0)
        local boxVisCol  = isTarget and tc or (State.BoxVisibleColor   or Color3.new(0,1,0))
        local boxInvCol  = isTarget and tc or (State.BoxInvisibleColor or Color3.new(1,0,0))
        local nameCol    = isTarget and tc or (State.NameColor         or Color3.new(1,1,1))
        local skelCol    = isTarget and tc or (State.SkeletonColor     or Color3.new(1,1,1))

        -- Hide all first
        esp.Box.Visible       = false
        esp.Name.Visible      = false
        if esp.Corners then
            for i = 1, 8 do
                if esp.Corners[i] then esp.Corners[i].Visible = false end
            end
        end
        for i = 1, 12 do
            if esp.Bones[i] then esp.Bones[i].Visible = false end
        end

        if shouldShow and player.Character then
            local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            local head     = player.Character:FindFirstChild("Head")
            local hum      = player.Character:FindFirstChildOfClass("Humanoid")
            if not (rootPart and head) then continue end

            local rootPos, rootOnScreen = WorldToScreen(rootPart.Position)
            local headPos, headOnScreen = WorldToScreen(head.Position + Vector3.new(0, 0.5, 0))
            local legPos,  _            = WorldToScreen(rootPart.Position - Vector3.new(0, 4, 0))

            if not (headOnScreen or rootOnScreen) then continue end

            local height = math.abs(headPos.Y - legPos.Y)
            local width  = height / 2.2

            -- Visibility raycast (reuses pre-allocated params)
            local rayOrigin    = Camera.CFrame.Position
            local rayDirection = (rootPart.Position - rayOrigin).Unit * 1000
            _espRayParams.FilterDescendantsInstances = {LocalPlayer.Character or {}}
            local result  = Workspace:Raycast(rayOrigin, rayDirection, _espRayParams)
            local visible = not result or result.Instance:IsDescendantOf(player.Character)

            -- Box ESP
            if State.BoxESP then
                local bColor    = visible and boxVisCol or boxInvCol
                local bThick    = State.BoxThickness or 2
                local x = rootPos.X - width / 2
                local y = headPos.Y

                if State.BoxType == "Corner Box" then
                    -- Corner length = ~25% of each side
                    local cx = width  * 0.25
                    local cy = height * 0.25
                    local c  = esp.Corners

                    -- Top-left: horizontal + vertical
                    c[1].From = Vector2.new(x,         y);         c[1].To = Vector2.new(x + cx,      y)
                    c[2].From = Vector2.new(x,         y);         c[2].To = Vector2.new(x,            y + cy)
                    -- Top-right: horizontal + vertical
                    c[3].From = Vector2.new(x+width,   y);         c[3].To = Vector2.new(x+width-cx,  y)
                    c[4].From = Vector2.new(x+width,   y);         c[4].To = Vector2.new(x+width,      y + cy)
                    -- Bottom-left: horizontal + vertical
                    c[5].From = Vector2.new(x,         y+height);  c[5].To = Vector2.new(x + cx,      y+height)
                    c[6].From = Vector2.new(x,         y+height);  c[6].To = Vector2.new(x,            y+height-cy)
                    -- Bottom-right: horizontal + vertical
                    c[7].From = Vector2.new(x+width,   y+height);  c[7].To = Vector2.new(x+width-cx,  y+height)
                    c[8].From = Vector2.new(x+width,   y+height);  c[8].To = Vector2.new(x+width,      y+height-cy)

                    for i = 1, 8 do
                        c[i].Color     = bColor
                        c[i].Thickness = bThick
                        c[i].Visible   = true
                    end
                else
                    -- Standard 2D Box
                    esp.Box.Size      = Vector2.new(width, height)
                    esp.Box.Position  = Vector2.new(x, y)
                    esp.Box.Color     = bColor
                    esp.Box.Thickness = bThick
                    esp.Box.Visible   = true
                end
            end

            -- Name ESP
            if State.NameESP then
                esp.Name.Text     = player.DisplayName
                esp.Name.Position = Vector2.new(rootPos.X, headPos.Y - 25)
                esp.Name.Color    = nameCol
                esp.Name.Size     = math.clamp((State.NameThickness or 1) * 14, 10, 32)
                esp.Name.Visible  = true
            end

            -- Skeleton ESP
            if State.SkeletonESP then
                local sp = GetSkelParts(player)
                if sp then
                    local function DrawBone(p1, p2, index)
                        if p1 and p2 and p1.Parent and p2.Parent then
                            local s1, on1 = WorldToScreen(p1.Position)
                            local s2, on2 = WorldToScreen(p2.Position)
                            if on1 or on2 then
                                local line = esp.Bones[index]
                                if line then
                                    line.From      = s1
                                    line.To        = s2
                                    line.Color     = skelCol
                                    line.Thickness = State.SkeletonThickness or 1
                                    line.Visible   = true
                                end
                            end
                        end
                    end
                    DrawBone(sp.Head,          sp.UpperTorso,    1)
                    DrawBone(sp.UpperTorso,    sp.LowerTorso,    2)
                    DrawBone(sp.UpperTorso,    sp.LeftUpperArm,  3)
                    DrawBone(sp.LeftUpperArm,  sp.LeftLowerArm,  4)
                    DrawBone(sp.LeftLowerArm,  sp.LeftHand,      5)
                    DrawBone(sp.UpperTorso,    sp.RightUpperArm, 6)
                    DrawBone(sp.RightUpperArm, sp.RightLowerArm, 7)
                    DrawBone(sp.RightLowerArm, sp.RightHand,     8)
                    DrawBone(sp.LowerTorso,    sp.LeftUpperLeg,  9)
                    DrawBone(sp.LeftUpperLeg,  sp.LeftLowerLeg,  10)
                    DrawBone(sp.LeftLowerLeg,  sp.LeftFoot,      11)
                    DrawBone(sp.LowerTorso,    sp.RightUpperLeg, 12)
                end
            end
        end
    end

    -- Chams: per-frame raycast to swap visible/through-wall color
    if State.ChamsEnabled then
        local opacity      = (State.ChamsOpacity or 0) / 100
        local fillColor    = State.ChamsColor    or Color3.fromRGB(255,50,50)
        local wallColor    = State.ChamsOccluded or Color3.fromRGB(80,20,20)
        local outlineColor = State.ChamsOutline  or Color3.fromRGB(255,255,255)

        for player, h in pairs(Chams) do
            if not validPlayers[player] then
                RemoveChams(player)
                continue
            end
            if State.TeamCheck and SameTeam(player) then
                RemoveChams(player)
                continue
            end
            if not h or not h.Parent then continue end

            -- Override colors for the targeted player
            local isTarget = (player == currentTarget)
            local tc = State.TargetColorVal or Color3.fromRGB(255,165,0)
            local pFill    = isTarget and tc or fillColor
            local pWall    = isTarget and tc or wallColor
            local pOutline = isTarget and tc or outlineColor

            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then h.Enabled = false continue end

            -- Raycast from camera to player root (reuses pre-allocated params)
            _chamRayParams.FilterDescendantsInstances = { LocalPlayer.Character or {}, char }
            local origin    = Camera.CFrame.Position
            local direction = (root.Position - origin)
            local result    = Workspace:Raycast(origin, direction, _chamRayParams)
            local visible   = result == nil

            h.Enabled       = true
            h.OutlineColor  = pOutline

            if visible then
                h.FillColor           = pFill
                h.FillTransparency    = opacity
                h.OutlineTransparency = 0
            else
                if State.VisibleOnly then
                    h.FillTransparency    = 1
                    h.OutlineTransparency = 1
                else
                    h.FillColor           = pWall
                    h.FillTransparency    = math.clamp(opacity + 0.3, 0, 1)
                    h.OutlineTransparency = 0.3
                end
            end
        end

        -- Add missing players (reuses validPlayers set built above)
        for player in pairs(validPlayers) do
            if player == LocalPlayer then continue end
            if not Chams[player] and player.Character
               and player.Character:FindFirstChild("HumanoidRootPart") then
                if not State.TeamCheck or not SameTeam(player) then
                    CreateChams(player)
                end
            end
        end
    end

end)

-- Triggerbot Toggle mode key listener
registerKeybind("TrigbotKey", State.TrigbotKey, function()
    if State.TrigbotEnabled and State.TrigMode == "Toggle" then
        State.TrigbotToggled = not State.TrigbotToggled
    end
end)

-- ============================================================
--  TRIGGERBOT LOOP
--  Fires a left click when the crosshair is over an enemy.
--  Modes:
--    Always       — fires whenever enabled and looking at enemy
--    While Holding — fires only while TrigbotKey is held
--    Toggle       — fires only while TrigbotToggled is true
-- ============================================================

spawn(function()
    local lastFired = 0
    while true do
        task.wait(0.01)  -- 100hz check rate
        if not State.TrigbotEnabled then continue end

        -- Check mode gate
        local modeActive = false
        if State.TrigMode == "Always" then
            modeActive = true
        elseif State.TrigMode == "While Holding" then
            modeActive = UserInputService:IsKeyDown(State.TrigbotKey or Enum.KeyCode.Q)
        elseif State.TrigMode == "Toggle" then
            modeActive = State.TrigbotToggled
        end
        if not modeActive then continue end

        -- Check if crosshair is over an enemy using a raycast from camera centre
        local unitRay = Camera:ScreenPointToRay(
            Camera.ViewportSize.X / 2,
            Camera.ViewportSize.Y / 2
        )
        _trigRayParams.FilterDescendantsInstances = { LocalPlayer.Character or {} }

        local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, _trigRayParams)
        if not result then continue end

        -- Check the hit belongs to an enemy character
        local hitInstance = result.Instance
        local hitChar = hitInstance and hitInstance.Parent
        if not hitChar then continue end

        -- Try both R15 (part parent is char) and accessories (parent.parent)
        local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
            or Players:GetPlayerFromCharacter(hitChar.Parent)
        if not hitPlayer then continue end
        if hitPlayer == LocalPlayer then continue end
        if not IsAlive(hitPlayer) then continue end
        if State.TeamCheck and SameTeam(hitPlayer) then continue end

        -- Distance gate
        local hrp = hitPlayer.Character and hitPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local dist3D = (Camera.CFrame.Position - hrp.Position).Magnitude
            if dist3D > (State.TrigbotDist or 500) then continue end
        end

        -- Respect delay
        local now = tick()
        if now - lastFired < (State.TrigDelay or 80) / 1000 then continue end
        lastFired = now

        -- Fire: simulate left mouse click
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true,  game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end
end)
--  Runs after Roblox camera controller each frame. We write
--  Camera.CFrame directly here — no input simulation, no button
--  events, no CameraType change. Arsenal sees nothing unusual.
-- ============================================================

RunService:BindToRenderStep("__IGNITEAimbot", Enum.RenderPriority.Camera.Value + 1, function()
    if not State.AimbotEnabled then return end
    if not UserInputService:IsKeyDown(State.AimbotKey or Enum.KeyCode.V) then return end

    local target = GetClosestPlayer()
    if not (target and target.Character) then return end

    local partName = State.AimTarget or "Head"
    local part = target.Character:FindFirstChild(partName)
             or target.Character:FindFirstChild("HumanoidRootPart")
    if not part then return end

    local smoothness = math.clamp(State.Smooth or 30, 1, 100)
    local alpha      = math.clamp(1 - (smoothness - 1) / 100, 0.02, 1)
    local targetCF   = CFrame.lookAt(Camera.CFrame.Position, part.Position)
    Camera.CFrame    = Camera.CFrame:Lerp(targetCF, alpha)
end)

-- ============================================================
--  SPINBOT
--  Rotates the HumanoidRootPart around the Y axis every frame.
--  Speed is in degrees per frame (at 60fps ≈ SpinbotSpeed*60 °/s).
-- ============================================================

local _spinAngle = 0

RunService:BindToRenderStep("__IGNITESpinbot", Enum.RenderPriority.Character.Value + 1, function()
    if not State.Spinbot then return end
    local chr = LocalPlayer.Character
    local hrp = chr and chr:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    _spinAngle = (_spinAngle + (State.SpinbotSpeed or 20)) % 360
    hrp.CFrame = CFrame.new(hrp.Position)
        * CFrame.Angles(0, math.rad(_spinAngle), 0)
end)

-- ============================================================
--  FLY
--  Uses BodyVelocity + BodyGyro injected into HumanoidRootPart.
--  WASD moves in camera-relative directions; Space = up, Shift = down.
--  PlatformStand disables Roblox's movement so we have full control.
-- ============================================================

RunService:BindToRenderStep("__IGNITEFly", Enum.RenderPriority.Character.Value + 2, function()
    local chr = LocalPlayer.Character
    local hrp = chr and chr:FindFirstChild("HumanoidRootPart")
    local hum = chr and chr:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return end

    if not State.FlyEnabled then
        -- Clean up if somehow objects are still there
        if hrp:FindFirstChild("__FlyVel") then FlyCleanup() end
        return
    end

    hum.PlatformStand = true

    -- Ensure BodyVelocity exists
    local bv = hrp:FindFirstChild("__FlyVel")
    if not bv then
        bv = Instance.new("BodyVelocity", hrp)
        bv.Name         = "__FlyVel"
        bv.MaxForce     = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity     = Vector3.zero
    end

    -- Ensure BodyGyro exists
    local bg = hrp:FindFirstChild("__FlyGyro")
    if not bg then
        bg = Instance.new("BodyGyro", hrp)
        bg.Name      = "__FlyGyro"
        bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        bg.D         = 100
        bg.CFrame    = hrp.CFrame
    end

    local speed  = State.FlySpeed or 60
    local camCF  = Camera.CFrame
    local moveDir = Vector3.zero

    -- Camera-relative WASD directions (horizontal plane)
    local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
    local right   = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z).Unit

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - forward end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + right   end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - right   end

    -- Vertical
    if UserInputService:IsKeyDown(Enum.KeyCode.Space)      then moveDir = moveDir + Vector3.new(0,1,0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)  then moveDir = moveDir - Vector3.new(0,1,0) end

    -- Normalize only if there's actual input to avoid NaN
    if moveDir.Magnitude > 0 then
        moveDir = moveDir.Unit
    end

    bv.Velocity = moveDir * speed

    -- Keep the character upright and facing camera direction
    bg.CFrame = CFrame.new(hrp.Position, hrp.Position + forward)
end)

-- Clean up fly on character respawn
LocalPlayer.CharacterAdded:Connect(function()
    State.FlyEnabled = false
    if Setters.FlyEnabled then Setters.FlyEnabled(false) end
end)

-- ============================================================
--  AUTOMATIC WEAPON
--  Cycles the trigger rapidly when holding a semi-auto weapon.
--  Detects semi-auto by checking the equipped tool for Arsenal's
--  FireMode configuration (StringValue named "FireMode" = "Semi",
--  or an Attribute "FireMode" = "Semi").
-- ============================================================

local function GetEquippedTool()
    local chr = LocalPlayer.Character
    if not chr then return nil end
    for _, obj in pairs(chr:GetChildren()) do
        if obj:IsA("Tool") then return obj end
    end
    return nil
end

spawn(function()
    local holding = false
    while true do
        task.wait(0.01)
        local chr    = LocalPlayer.Character
        local hum    = chr and chr:FindFirstChildOfClass("Humanoid")
        local inGame = hum and hum.Health > 0
        local tool   = GetEquippedTool()

        if State.AutoWeapon
           and inGame
           and tool
           and not Window.Visible
           and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            if not holding then holding = true end
            -- Cycle the trigger: release then re-press ONLY if still holding
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            task.wait(0.01)
            -- Re-check: if user released LMB during the wait, don't re-press
            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            else
                holding = false
            end
        else
            if holding then
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                holding = false
            end
        end
    end
end)

-- ============================================================
--  APPLY STATE
--  Single function used by every load path (auto-load, Load
--  button, list "Load" button).  Writes State, drives UI
--  Setters, then manually applies side-effects for every key
--  that has live consequences but no Setter.
-- ============================================================

-- Keys that are pure runtime state and must never be restored
-- Keys that are pure runtime state and must never be restored
local _runtimeKeys = { TrigbotToggled = true }

ApplyState = function(data)
    -- 1. Write all values into State first
    for k, v in pairs(data) do
        if not _runtimeKeys[k] and v ~= nil then
            State[k] = v
        end
    end

    -- 2. Drive every UI Setter that exists
    for k, v in pairs(data) do
        if not _runtimeKeys[k] and v ~= nil and Setters[k] then
            pcall(Setters[k], v)
        end
    end

    -- 3. Side-effects for keys that have no Setter ─────────────

    -- Keybinds: re-register listeners so the new keys are live
    registerKeybind("MenuToggle", State.MenuKey, function()
        Window.Visible = not Window.Visible
    end)
    registerKeybind("Eject", State.EjectKey, function() Eject() end)
    registerKeybind("TrigbotKey", State.TrigbotKey, function()
        if State.TrigbotEnabled and State.TrigMode == "Toggle" then
            State.TrigbotToggled = not State.TrigbotToggled
        end
    end)
    -- AimbotKey is read directly from State each frame; no listener needed

    -- Lighting – Fullbright overrides everything else
    if State.Fullbright then
        Lighting.TimeOfDay  = "14:00:00"
        Lighting.Brightness = 2
        Lighting.Ambient    = Color3.fromRGB(178, 178, 178)
    else
        Lighting.TimeOfDay  = string.format("%02d:00:00",
            math.clamp(math.floor(State.TimeOfDay or 12), 0, 24))
        Lighting.Brightness = Original.Brightness
        Lighting.Ambient    = State.CustomAmbient
            and (State.AmbientColor or Original.Ambient)
            or  Original.Ambient
    end

    -- FOV circle
    Drawings.FOVCircle.Radius = State.FOV or 90
    Drawings.FOVCircle.Color  = State.FOVColor or Color3.fromRGB(255, 255, 255)

    -- Humanoid stats (only if the feature toggle is on)
    local chr = LocalPlayer.Character
    local hum = chr and chr:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = State.SpeedBoost and (State.WalkSpeed or 16) or Original.WalkSpeed
        hum.JumpPower = State.JumpBoost  and (State.JumpPower or 50) or Original.JumpPower
    end

    -- Infinite Jump reconnect
    if _G.IJ then _G.IJ:Disconnect(); _G.IJ = nil end
    if State.InfiniteJump then
        _G.IJ = UserInputService.JumpRequest:Connect(function()
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChild("Humanoid")
            if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end

    -- Chams: rebuild highlights to pick up new colors / enabled state
    RefreshAllChams()
    for _, h in pairs(Chams) do
        if h then h.FillTransparency = (State.ChamsOpacity or 0) / 100 end
    end

    -- Spinbot: State is read per-frame, nothing extra needed

    -- Fly: if loading with fly on, it'll activate next frame automatically;
    -- if loading with fly off, make sure any leftover objects are cleaned up
    if not State.FlyEnabled then FlyCleanup() end

    -- ESP colors are read per-frame from State; no extra action needed
end

-- ============================================================
--  INIT
-- ============================================================

switchTab("Combat")

task.delay(0.5, function()
    local data = SaveManager:Load()
    if data then
        ApplyState(data)
        rebuildList()
        print("[IGNITE] Auto-loaded config.")
    end
end)

print("[IGNITE] Loaded.")
