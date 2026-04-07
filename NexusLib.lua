-- ================================================================
--   NexusLib v1.0 — A sleek, modular Roblox UI Framework
--   Config system stores to: C:\workspace\
--   Inspired by modern exploit UIs — built from scratch.
-- ================================================================

local NexusLib = {}
NexusLib.__index = NexusLib

-- ── Services ────────────────────────────────────────────────────
local Players         = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local RunService      = game:GetService("RunService")
local HttpService     = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

-- ── Config Path ─────────────────────────────────────────────────
local CONFIG_PATH = "C:\\workspace\\"

-- ── Theme ───────────────────────────────────────────────────────
local Theme = {
    -- Backgrounds
    Background      = Color3.fromRGB(12, 12, 16),
    Surface         = Color3.fromRGB(18, 18, 24),
    SurfaceAlt      = Color3.fromRGB(22, 22, 30),
    Panel           = Color3.fromRGB(26, 26, 36),

    -- Borders
    Border          = Color3.fromRGB(45, 45, 65),
    BorderActive    = Color3.fromRGB(90, 90, 130),

    -- Accent
    Accent          = Color3.fromRGB(100, 80, 220),
    AccentHover     = Color3.fromRGB(120, 100, 240),
    AccentDim       = Color3.fromRGB(60, 48, 140),

    -- Text
    TextPrimary     = Color3.fromRGB(230, 230, 240),
    TextSecondary   = Color3.fromRGB(140, 140, 160),
    TextDisabled    = Color3.fromRGB(75, 75, 95),
    TextAccent      = Color3.fromRGB(160, 140, 255),

    -- States
    Success         = Color3.fromRGB(70, 200, 120),
    Warning         = Color3.fromRGB(220, 170, 60),
    Danger          = Color3.fromRGB(210, 70, 80),

    -- Misc
    Shadow          = Color3.fromRGB(0, 0, 0),
    ToggleOff       = Color3.fromRGB(50, 50, 70),
    ToggleOn        = Color3.fromRGB(100, 80, 220),
    SliderFill      = Color3.fromRGB(100, 80, 220),
    SliderTrack     = Color3.fromRGB(35, 35, 50),
}

-- ── Utility ─────────────────────────────────────────────────────
local Util = {}

function Util.Tween(obj, props, t, style, dir)
    local info = TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
    TweenService:Create(obj, info, props):Play()
end

function Util.Create(class, props, children)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = obj
    end
    return obj
end

function Util.Stroke(parent, color, thickness, transparency)
    return Util.Create("UIStroke", {
        Parent = parent,
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
    })
end

function Util.Corner(parent, radius)
    return Util.Create("UICorner", { Parent = parent, CornerRadius = UDim.new(0, radius or 6) })
end

function Util.Padding(parent, top, right, bottom, left)
    return Util.Create("UIPadding", {
        Parent = parent,
        PaddingTop    = UDim.new(0, top    or 0),
        PaddingRight  = UDim.new(0, right  or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        PaddingLeft   = UDim.new(0, left   or 0),
    })
end

function Util.Hover(btn, normalColor, hoverColor)
    btn.MouseEnter:Connect(function()
        Util.Tween(btn, { BackgroundColor3 = hoverColor }, 0.12)
    end)
    btn.MouseLeave:Connect(function()
        Util.Tween(btn, { BackgroundColor3 = normalColor }, 0.12)
    end)
end

-- ── Config System ────────────────────────────────────────────────
local Config = {}
Config.__index = Config

function Config.new(windowName)
    local self = setmetatable({}, Config)
    self.WindowName = windowName
    self.Path = CONFIG_PATH .. windowName .. "\\"
    self.Data = {}
    return self
end

function Config:_ensureDir()
    -- In a real exploit environment these calls exist
    if not isfolder(self.Path) then
        makefolder(self.Path)
    end
end

function Config:Save(name)
    self:_ensureDir()
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, self.Data)
    if ok then
        writefile(self.Path .. name .. ".json", encoded)
        return true
    end
    return false
end

function Config:Load(name)
    local file = self.Path .. name .. ".json"
    if isfile(file) then
        local ok, decoded = pcall(HttpService.JSONDecode, HttpService, readfile(file))
        if ok then
            self.Data = decoded
            return decoded
        end
    end
    return nil
end

function Config:Delete(name)
    local file = self.Path .. name .. ".json"
    if isfile(file) then
        delfile(file)
        return true
    end
    return false
end

function Config:List()
    self:_ensureDir()
    local files = listfiles(self.Path)
    local configs = {}
    for _, f in ipairs(files) do
        local name = f:match("([^\\]+)%.json$")
        if name then
            table.insert(configs, name)
        end
    end
    return configs
end

function Config:Set(key, value)
    self.Data[key] = value
end

function Config:Get(key, default)
    if self.Data[key] ~= nil then
        return self.Data[key]
    end
    return default
end

-- ── Dragging ────────────────────────────────────────────────────
local function MakeDraggable(handle, frame)
    local dragging, dragStart, startPos = false, nil, nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = input.Position
            startPos  = frame.Position
        end
    end)

    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════
--   WINDOW
-- ══════════════════════════════════════════════════════════════════
function NexusLib:CreateWindow(options)
    options = options or {}
    local Title   = options.Title   or "NexusLib"
    local Size    = options.Size    or UDim2.new(0, 620, 0, 440)
    local Pos     = options.Position or UDim2.new(0.5, -310, 0.5, -220)

    -- ── Config system for this window ──────────────────────────
    local cfg = Config.new(Title)

    -- ── Screen GUI ─────────────────────────────────────────────
    local ScreenGui = Util.Create("ScreenGui", {
        Name = "NexusLib_" .. Title,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = gethui and gethui() or LocalPlayer:WaitForChild("PlayerGui"),
    })

    -- ── Main Frame ─────────────────────────────────────────────
    local MainFrame = Util.Create("Frame", {
        Name = "MainFrame",
        Size = Size,
        Position = Pos,
        BackgroundColor3 = Theme.Background,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = ScreenGui,
    })
    Util.Corner(MainFrame, 10)
    Util.Stroke(MainFrame, Theme.Border, 1.5)

    -- Drop shadow (visual layering trick)
    local Shadow = Util.Create("ImageLabel", {
        Name = "Shadow",
        Size = UDim2.new(1, 30, 1, 30),
        Position = UDim2.new(0, -15, 0, -10),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6015897843",
        ImageColor3 = Theme.Shadow,
        ImageTransparency = 0.5,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 0,
        Parent = MainFrame,
    })

    -- ── Title Bar ──────────────────────────────────────────────
    local TitleBar = Util.Create("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = MainFrame,
    })
    -- Accent left border on title bar
    Util.Create("Frame", {
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = TitleBar,
    })

    -- Logo / Icon dot
    local LogoDot = Util.Create("Frame", {
        Size = UDim2.new(0, 10, 0, 10),
        Position = UDim2.new(0, 16, 0.5, -5),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
        Parent = TitleBar,
    })
    Util.Corner(LogoDot, 3)

    local TitleLabel = Util.Create("TextLabel", {
        Size = UDim2.new(1, -120, 1, 0),
        Position = UDim2.new(0, 34, 0, 0),
        BackgroundTransparency = 1,
        Text = Title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
        Parent = TitleBar,
    })

    -- Version label
    local VersionLabel = Util.Create("TextLabel", {
        Size = UDim2.new(0, 60, 1, 0),
        Position = UDim2.new(0, 34, 0, 0),
        AnchorPoint = Vector2.new(0, 0),
        BackgroundTransparency = 1,
        Text = "v1.0",
        TextColor3 = Theme.TextDisabled,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 6,
        -- offset to appear after title
        Parent = TitleBar,
    })
    -- reposition after title
    VersionLabel.Position = UDim2.new(0, 34 + TitleLabel.TextBounds.X + 8, 0, 0)

    -- Close / Minimize buttons
    local function MakeTitleBtn(xOffset, color, hoverColor, symbol)
        local btn = Util.Create("TextButton", {
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(1, xOffset, 0.5, -12),
            BackgroundColor3 = color,
            Text = symbol,
            TextColor3 = Theme.TextSecondary,
            TextSize = 13,
            Font = Enum.Font.GothamBold,
            ZIndex = 7,
            Parent = TitleBar,
        })
        Util.Corner(btn, 5)
        Util.Hover(btn, color, hoverColor)
        return btn
    end

    local CloseBtn    = MakeTitleBtn(-12, Color3.fromRGB(180, 60, 60), Color3.fromRGB(210, 80, 80), "×")
    local MinimizeBtn = MakeTitleBtn(-42, Theme.Panel, Theme.SurfaceAlt, "−")

    MakeDraggable(TitleBar, MainFrame)

    -- Minimize logic
    local minimized = false
    local fullSize  = Size
    MinimizeBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            Util.Tween(MainFrame, { Size = UDim2.new(0, fullSize.X.Offset, 0, 40) }, 0.22, Enum.EasingStyle.Quart)
        else
            Util.Tween(MainFrame, { Size = fullSize }, 0.22, Enum.EasingStyle.Quart)
        end
    end)

    CloseBtn.MouseButton1Click:Connect(function()
        Util.Tween(MainFrame, { Size = UDim2.new(0, fullSize.X.Offset, 0, 0) }, 0.2, Enum.EasingStyle.Quart)
        task.delay(0.22, function() ScreenGui:Destroy() end)
    end)

    -- Bottom border on titlebar
    Util.Create("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Parent = TitleBar,
    })

    -- ── Tab Bar ────────────────────────────────────────────────
    local TabBar = Util.Create("Frame", {
        Name = "TabBar",
        Size = UDim2.new(0, 130, 1, -40),
        Position = UDim2.new(0, 0, 0, 40),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        Parent = MainFrame,
    })

    -- Right border of tab bar
    Util.Create("Frame", {
        Size = UDim2.new(0, 1, 1, 0),
        Position = UDim2.new(1, -1, 0, 0),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel = 0,
        Parent = TabBar,
    })

    local TabList = Util.Create("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -10),
        Position = UDim2.new(0, 0, 0, 8),
        BackgroundTransparency = 1,
        ScrollBarThickness = 0,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Parent = TabBar,
    })

    local TabListLayout = Util.Create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 3),
        Parent = TabList,
    })

    Util.Padding(TabList, 0, 8, 0, 8)

    -- ── Content Area ───────────────────────────────────────────
    local ContentArea = Util.Create("Frame", {
        Name = "ContentArea",
        Size = UDim2.new(1, -130, 1, -40),
        Position = UDim2.new(0, 130, 0, 40),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Parent = MainFrame,
    })

    -- ── Window Object ──────────────────────────────────────────
    local Window = {}
    Window.Tabs = {}
    Window.ActiveTab = nil
    Window.Config = cfg

    local tabButtons = {}

    local function SetActiveTab(tab)
        if Window.ActiveTab == tab then return end
        if Window.ActiveTab then
            Window.ActiveTab.Page.Visible = false
            Util.Tween(tabButtons[Window.ActiveTab], {
                BackgroundColor3 = Color3.fromRGB(0,0,0),
                BackgroundTransparency = 1,
                TextColor3 = Theme.TextSecondary,
            }, 0.15)
        end
        Window.ActiveTab = tab
        tab.Page.Visible = true
        Util.Tween(tabButtons[tab], {
            BackgroundColor3 = Theme.AccentDim,
            BackgroundTransparency = 0,
            TextColor3 = Theme.TextAccent,
        }, 0.15)
    end

    -- ── AddTab ─────────────────────────────────────────────────
    function Window:AddTab(tabOptions)
        tabOptions = tabOptions or {}
        local TabName = tabOptions.Name or "Tab"
        local TabIcon = tabOptions.Icon or ""

        -- Tab Button
        local TabBtn = Util.Create("TextButton", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 1,
            Text = (TabIcon ~= "" and TabIcon .. "  " or "") .. TabName,
            TextColor3 = Theme.TextSecondary,
            TextSize = 12,
            Font = Enum.Font.GothamSemibold,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 4,
            Parent = TabList,
        })
        Util.Corner(TabBtn, 6)
        Util.Padding(TabBtn, 0, 0, 0, 10)

        -- Hover
        TabBtn.MouseEnter:Connect(function()
            if Window.ActiveTab ~= Tab then
                Util.Tween(TabBtn, { BackgroundTransparency = 0.85, BackgroundColor3 = Theme.Panel }, 0.1)
            end
        end)
        TabBtn.MouseLeave:Connect(function()
            if Window.ActiveTab ~= Tab then
                Util.Tween(TabBtn, { BackgroundTransparency = 1 }, 0.1)
            end
        end)

        -- Active indicator strip
        local ActiveStrip = Util.Create("Frame", {
            Size = UDim2.new(0, 3, 0.6, 0),
            Position = UDim2.new(0, -8, 0.2, 0),
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Parent = TabBtn,
        })
        Util.Corner(ActiveStrip, 2)

        -- Tab Page (scrollable)
        local Page = Util.Create("ScrollingFrame", {
            Name = "Page_" .. TabName,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Theme.Accent,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            Visible = false,
            Parent = ContentArea,
        })

        Util.Padding(Page, 10, 10, 10, 10)

        local PageLayout = Util.Create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8),
            Parent = Page,
        })

        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Page.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 20)
        end)

        -- Update canvas for tab list
        TabListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            TabList.CanvasSize = UDim2.new(0, 0, 0, TabListLayout.AbsoluteContentSize.Y + 10)
        end)

        local Tab = { Page = Page, Name = TabName, Groups = {} }
        tabButtons[Tab] = TabBtn
        table.insert(Window.Tabs, Tab)

        TabBtn.MouseButton1Click:Connect(function()
            SetActiveTab(Tab)
            -- animate strip
            Util.Tween(ActiveStrip, { BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0.2, 0) }, 0.15)
        end)

        -- Deactivate strip on other tabs
        for _, otherTab in pairs(Window.Tabs) do
            if otherTab ~= Tab then
                -- handled by SetActiveTab
            end
        end

        if #Window.Tabs == 1 then
            SetActiveTab(Tab)
            Util.Tween(ActiveStrip, { BackgroundTransparency = 0, Position = UDim2.new(0, 0, 0.2, 0) }, 0.15)
        end

        -- ── AddGroupbox ──────────────────────────────────────────
        function Tab:AddGroupbox(groupOptions)
            groupOptions = groupOptions or {}
            local GroupName = groupOptions.Name or "Group"

            local GroupFrame = Util.Create("Frame", {
                Name = "Group_" .. GroupName,
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = Theme.Panel,
                BorderSizePixel = 0,
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = Page,
            })
            Util.Corner(GroupFrame, 8)
            Util.Stroke(GroupFrame, Theme.Border, 1)

            -- Header bar of groupbox
            local GroupHeader = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundColor3 = Theme.SurfaceAlt,
                BorderSizePixel = 0,
                Parent = GroupFrame,
            })
            Util.Corner(GroupHeader, 8)

            -- Flatten bottom corners of header
            Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 8),
                Position = UDim2.new(0, 0, 1, -8),
                BackgroundColor3 = Theme.SurfaceAlt,
                BorderSizePixel = 0,
                Parent = GroupHeader,
            })

            local GroupLabel = Util.Create("TextLabel", {
                Size = UDim2.new(1, -16, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = GroupName:upper(),
                TextColor3 = Theme.TextSecondary,
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                LetterSpacingScaled = 0.08,
                Parent = GroupHeader,
            })

            -- Accent left edge
            Util.Create("Frame", {
                Size = UDim2.new(0, 2, 0.5, 0),
                Position = UDim2.new(0, 0, 0.25, 0),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                Parent = GroupHeader,
            })

            -- Content list inside group
            local GroupContent = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                Position = UDim2.new(0, 0, 0, 28),
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                Parent = GroupFrame,
            })

            local GroupLayout = Util.Create("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 2),
                Parent = GroupContent,
            })
            Util.Padding(GroupContent, 6, 10, 8, 10)

            local Group = {}

            -- ─── TOGGLE ───────────────────────────────────────────
            function Group:AddToggle(opts)
                opts = opts or {}
                local Label   = opts.Label   or "Toggle"
                local Default = opts.Default or false
                local Callback = opts.Callback or function() end
                local Flag    = opts.Flag

                local state = Default

                local Row = Util.Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundTransparency = 1,
                    Parent = GroupContent,
                })

                local LabelText = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -50, 1, 0),
                    BackgroundTransparency = 1,
                    Text = Label,
                    TextColor3 = Theme.TextPrimary,
                    TextSize = 13,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Row,
                })

                -- Track
                local Track = Util.Create("Frame", {
                    Size = UDim2.new(0, 38, 0, 20),
                    Position = UDim2.new(1, -38, 0.5, -10),
                    BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff,
                    BorderSizePixel = 0,
                    Parent = Row,
                })
                Util.Corner(Track, 10)

                -- Knob
                local Knob = Util.Create("Frame", {
                    Size = UDim2.new(0, 14, 0, 14),
                    Position = state and UDim2.new(0, 21, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
                    BackgroundColor3 = Theme.TextPrimary,
                    BorderSizePixel = 0,
                    Parent = Track,
                })
                Util.Corner(Knob, 7)

                local Clickable = Util.Create("TextButton", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = "",
                    Parent = Row,
                })

                local function UpdateVisual()
                    Util.Tween(Track, { BackgroundColor3 = state and Theme.ToggleOn or Theme.ToggleOff }, 0.15)
                    Util.Tween(Knob, { Position = state and UDim2.new(0, 21, 0.5, -7) or UDim2.new(0, 3, 0.5, -7) }, 0.15)
                end

                Clickable.MouseButton1Click:Connect(function()
                    state = not state
                    UpdateVisual()
                    Callback(state)
                    if Flag then cfg:Set(Flag, state) end
                end)

                -- Hover
                Clickable.MouseEnter:Connect(function()
                    Util.Tween(LabelText, { TextColor3 = Theme.TextAccent }, 0.1)
                end)
                Clickable.MouseLeave:Connect(function()
                    Util.Tween(LabelText, { TextColor3 = Theme.TextPrimary }, 0.1)
                end)

                local Toggle = {}
                function Toggle:Set(val)
                    state = val
                    UpdateVisual()
                    Callback(state)
                    if Flag then cfg:Set(Flag, state) end
                end
                function Toggle:Get() return state end
                return Toggle
            end

            -- ─── SLIDER ───────────────────────────────────────────
            function Group:AddSlider(opts)
                opts = opts or {}
                local Label   = opts.Label   or "Slider"
                local Min     = opts.Min     or 0
                local Max     = opts.Max     or 100
                local Default = opts.Default or Min
                local Suffix  = opts.Suffix  or ""
                local Decimals = opts.Decimals or 0
                local Callback = opts.Callback or function() end
                local Flag    = opts.Flag

                local value = math.clamp(Default, Min, Max)

                local Wrapper = Util.Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 44),
                    BackgroundTransparency = 1,
                    Parent = GroupContent,
                })

                local Top = Util.Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 20),
                    BackgroundTransparency = 1,
                    Parent = Wrapper,
                })

                local LabelText = Util.Create("TextLabel", {
                    Size = UDim2.new(0.6, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = Label,
                    TextColor3 = Theme.TextPrimary,
                    TextSize = 13,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Top,
                })

                local ValueLabel = Util.Create("TextLabel", {
                    Size = UDim2.new(0.4, 0, 1, 0),
                    Position = UDim2.new(0.6, 0, 0, 0),
                    BackgroundTransparency = 1,
                    Text = tostring(value) .. Suffix,
                    TextColor3 = Theme.TextAccent,
                    TextSize = 12,
                    Font = Enum.Font.GothamSemibold,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = Top,
                })

                -- Track
                local TrackBg = Util.Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 6),
                    Position = UDim2.new(0, 0, 0, 28),
                    BackgroundColor3 = Theme.SliderTrack,
                    BorderSizePixel = 0,
                    Parent = Wrapper,
                })
                Util.Corner(TrackBg, 3)

                local Fill = Util.Create("Frame", {
                    Size = UDim2.new((value - Min) / (Max - Min), 0, 1, 0),
                    BackgroundColor3 = Theme.SliderFill,
                    BorderSizePixel = 0,
                    Parent = TrackBg,
                })
                Util.Corner(Fill, 3)

                -- Knob
                local Knob = Util.Create("Frame", {
                    Size = UDim2.new(0, 14, 0, 14),
                    Position = UDim2.new((value - Min) / (Max - Min), -7, 0.5, -7),
                    BackgroundColor3 = Theme.TextPrimary,
                    BorderSizePixel = 0,
                    Parent = TrackBg,
                })
                Util.Corner(Knob, 7)
                Util.Stroke(Knob, Theme.Accent, 1.5)

                -- Interaction
                local dragging = false

                local function UpdateSlider(xPos)
                    local rel = math.clamp((xPos - TrackBg.AbsolutePosition.X) / TrackBg.AbsoluteSize.X, 0, 1)
                    local raw = Min + rel * (Max - Min)
                    local mult = 10 ^ Decimals
                    value = math.floor(raw * mult + 0.5) / mult
                    Fill.Size = UDim2.new(rel, 0, 1, 0)
                    Knob.Position = UDim2.new(rel, -7, 0.5, -7)
                    ValueLabel.Text = tostring(value) .. Suffix
                    Callback(value)
                    if Flag then cfg:Set(Flag, value) end
                end

                local InputCapture = Util.Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 22),
                    Position = UDim2.new(0, 0, 0, 20),
                    BackgroundTransparency = 1,
                    Text = "",
                    Parent = Wrapper,
                })

                InputCapture.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        UpdateSlider(inp.Position.X)
                    end
                end)
                InputCapture.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)

                UserInputService.InputChanged:Connect(function(inp)
                    if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                        UpdateSlider(inp.Position.X)
                    end
                end)

                local Slider = {}
                function Slider:Set(val)
                    value = math.clamp(val, Min, Max)
                    local rel = (value - Min) / (Max - Min)
                    Fill.Size = UDim2.new(rel, 0, 1, 0)
                    Knob.Position = UDim2.new(rel, -7, 0.5, -7)
                    ValueLabel.Text = tostring(value) .. Suffix
                    Callback(value)
                    if Flag then cfg:Set(Flag, value) end
                end
                function Slider:Get() return value end
                return Slider
            end

            -- ─── DROPDOWN ─────────────────────────────────────────
            function Group:AddDropdown(opts)
                opts = opts or {}
                local Label   = opts.Label   or "Dropdown"
                local Items   = opts.Items   or {}
                local Default = opts.Default or nil
                local Callback = opts.Callback or function() end
                local Flag    = opts.Flag

                local selected = Default
                local isOpen   = false

                local Wrapper = Util.Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 52),
                    BackgroundTransparency = 1,
                    ClipsDescendants = false,
                    ZIndex = 10,
                    Parent = GroupContent,
                })

                local LabelText = Util.Create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    Text = Label,
                    TextColor3 = Theme.TextSecondary,
                    TextSize = 11,
                    Font = Enum.Font.GothamSemibold,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Wrapper,
                })

                local DropBtn = Util.Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 28),
                    Position = UDim2.new(0, 0, 0, 20),
                    BackgroundColor3 = Theme.SurfaceAlt,
                    BorderSizePixel = 0,
                    Text = "",
                    ZIndex = 11,
                    Parent = Wrapper,
                })
                Util.Corner(DropBtn, 6)
                Util.Stroke(DropBtn, Theme.Border, 1)

                local SelectedLabel = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -30, 1, 0),
                    Position = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Text = selected or "Select...",
                    TextColor3 = selected and Theme.TextPrimary or Theme.TextDisabled,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 12,
                    Parent = DropBtn,
                })

                local Arrow = Util.Create("TextLabel", {
                    Size = UDim2.new(0, 20, 1, 0),
                    Position = UDim2.new(1, -24, 0, 0),
                    BackgroundTransparency = 1,
                    Text = "▾",
                    TextColor3 = Theme.TextSecondary,
                    TextSize = 14,
                    Font = Enum.Font.GothamBold,
                    ZIndex = 12,
                    Parent = DropBtn,
                })

                -- Dropdown list
                local DropList = Util.Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    Position = UDim2.new(0, 0, 1, 4),
                    BackgroundColor3 = Theme.Panel,
                    BorderSizePixel = 0,
                    ClipsDescendants = true,
                    ZIndex = 20,
                    Visible = false,
                    Parent = DropBtn,
                })
                Util.Corner(DropList, 6)
                Util.Stroke(DropList, Theme.Border, 1)

                local ListLayout = Util.Create("UIListLayout", {
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = DropList,
                })
                Util.Padding(DropList, 4, 4, 4, 4)

                local itemHeight = 26
                local maxVisible = 5
                local totalHeight = #Items * itemHeight + 8

                local function PopulateList()
                    for _, child in pairs(DropList:GetChildren()) do
                        if child:IsA("TextButton") then child:Destroy() end
                    end
                    for _, item in ipairs(Items) do
                        local ItemBtn = Util.Create("TextButton", {
                            Size = UDim2.new(1, 0, 0, itemHeight),
                            BackgroundColor3 = item == selected and Theme.AccentDim or Color3.fromRGB(0,0,0),
                            BackgroundTransparency = item == selected and 0 or 1,
                            Text = item,
                            TextColor3 = item == selected and Theme.TextAccent or Theme.TextPrimary,
                            TextSize = 12,
                            Font = Enum.Font.Gotham,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            ZIndex = 21,
                            Parent = DropList,
                        })
                        Util.Corner(ItemBtn, 4)
                        Util.Padding(ItemBtn, 0, 0, 0, 8)

                        ItemBtn.MouseEnter:Connect(function()
                            if item ~= selected then
                                Util.Tween(ItemBtn, { BackgroundTransparency = 0.6, BackgroundColor3 = Theme.Border }, 0.1)
                            end
                        end)
                        ItemBtn.MouseLeave:Connect(function()
                            if item ~= selected then
                                Util.Tween(ItemBtn, { BackgroundTransparency = 1 }, 0.1)
                            end
                        end)

                        ItemBtn.MouseButton1Click:Connect(function()
                            selected = item
                            SelectedLabel.Text = item
                            SelectedLabel.TextColor3 = Theme.TextPrimary
                            PopulateList()
                            Callback(selected)
                            if Flag then cfg:Set(Flag, selected) end
                            -- close
                            isOpen = false
                            Util.Tween(DropList, { Size = UDim2.new(1, 0, 0, 0) }, 0.15)
                            Util.Tween(Arrow, { Rotation = 0 }, 0.15)
                            task.delay(0.15, function() DropList.Visible = false end)
                        end)
                    end
                end
                PopulateList()

                DropBtn.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    DropList.Visible = true
                    local targetH = isOpen and math.min(totalHeight, maxVisible * itemHeight + 8) or 0
                    Util.Tween(DropList, { Size = UDim2.new(1, 0, 0, targetH) }, 0.18)
                    Util.Tween(Arrow, { Rotation = isOpen and 180 or 0 }, 0.15)
                    if not isOpen then
                        task.delay(0.18, function() DropList.Visible = false end)
                    end
                end)

                Util.Hover(DropBtn, Theme.SurfaceAlt, Theme.Panel)

                local Dropdown = {}
                function Dropdown:Set(val)
                    selected = val
                    SelectedLabel.Text = val
                    SelectedLabel.TextColor3 = Theme.TextPrimary
                    Callback(selected)
                    if Flag then cfg:Set(Flag, selected) end
                end
                function Dropdown:GetItems() return Items end
                function Dropdown:Get() return selected end
                return Dropdown
            end

            -- ─── MULTI SELECT ─────────────────────────────────────
            function Group:AddMultiSelect(opts)
                opts = opts or {}
                local Label    = opts.Label    or "Multi Select"
                local Items    = opts.Items    or {}
                local Defaults = opts.Defaults or {}
                local Callback  = opts.Callback  or function() end
                local Flag     = opts.Flag

                local selected = {}
                for _, v in ipairs(Defaults) do selected[v] = true end

                local isOpen = false

                local function GetSelected()
                    local out = {}
                    for k, v in pairs(selected) do if v then table.insert(out, k) end end
                    return out
                end

                local function Summary()
                    local s = GetSelected()
                    if #s == 0 then return "None selected" end
                    if #s == #Items then return "All selected" end
                    return table.concat(s, ", ")
                end

                local Wrapper = Util.Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 52),
                    BackgroundTransparency = 1,
                    ClipsDescendants = false,
                    ZIndex = 9,
                    Parent = GroupContent,
                })

                Util.Create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    Text = Label,
                    TextColor3 = Theme.TextSecondary,
                    TextSize = 11,
                    Font = Enum.Font.GothamSemibold,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Wrapper,
                })

                local MBtn = Util.Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 28),
                    Position = UDim2.new(0, 0, 0, 20),
                    BackgroundColor3 = Theme.SurfaceAlt,
                    BorderSizePixel = 0,
                    Text = "",
                    ZIndex = 10,
                    Parent = Wrapper,
                })
                Util.Corner(MBtn, 6)
                Util.Stroke(MBtn, Theme.Border, 1)

                local SummaryLabel = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -30, 1, 0),
                    Position = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Text = Summary(),
                    TextColor3 = #GetSelected() > 0 and Theme.TextPrimary or Theme.TextDisabled,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 11,
                    ClipsDescendants = true,
                    Parent = MBtn,
                })

                local Arrow = Util.Create("TextLabel", {
                    Size = UDim2.new(0, 20, 1, 0),
                    Position = UDim2.new(1, -24, 0, 0),
                    BackgroundTransparency = 1,
                    Text = "▾",
                    TextColor3 = Theme.TextSecondary,
                    TextSize = 14,
                    Font = Enum.Font.GothamBold,
                    ZIndex = 11,
                    Parent = MBtn,
                })

                local DropList = Util.Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 0),
                    Position = UDim2.new(0, 0, 1, 4),
                    BackgroundColor3 = Theme.Panel,
                    BorderSizePixel = 0,
                    ClipsDescendants = true,
                    ZIndex = 20,
                    Visible = false,
                    Parent = MBtn,
                })
                Util.Corner(DropList, 6)
                Util.Stroke(DropList, Theme.Border, 1)
                Util.Padding(DropList, 4, 4, 4, 4)
                Util.Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = DropList })

                local itemH = 26
                local maxV  = 5

                local function Rebuild()
                    for _, c in pairs(DropList:GetChildren()) do
                        if c:IsA("Frame") then c:Destroy() end
                    end

                    for _, item in ipairs(Items) do
                        local isChecked = selected[item] == true

                        local Row = Util.Create("Frame", {
                            Size = UDim2.new(1, 0, 0, itemH),
                            BackgroundColor3 = isChecked and Theme.AccentDim or Color3.fromRGB(0,0,0),
                            BackgroundTransparency = isChecked and 0 or 1,
                            ZIndex = 21,
                            Parent = DropList,
                        })
                        Util.Corner(Row, 4)

                        -- Checkbox
                        local CB = Util.Create("Frame", {
                            Size = UDim2.new(0, 14, 0, 14),
                            Position = UDim2.new(0, 8, 0.5, -7),
                            BackgroundColor3 = isChecked and Theme.Accent or Theme.ToggleOff,
                            BorderSizePixel = 0,
                            ZIndex = 22,
                            Parent = Row,
                        })
                        Util.Corner(CB, 3)

                        if isChecked then
                            Util.Create("TextLabel", {
                                Size = UDim2.new(1, 0, 1, 0),
                                BackgroundTransparency = 1,
                                Text = "✓",
                                TextColor3 = Theme.TextPrimary,
                                TextSize = 10,
                                Font = Enum.Font.GothamBold,
                                ZIndex = 23,
                                Parent = CB,
                            })
                        end

                        Util.Create("TextLabel", {
                            Size = UDim2.new(1, -32, 1, 0),
                            Position = UDim2.new(0, 28, 0, 0),
                            BackgroundTransparency = 1,
                            Text = item,
                            TextColor3 = isChecked and Theme.TextAccent or Theme.TextPrimary,
                            TextSize = 12,
                            Font = Enum.Font.Gotham,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            ZIndex = 22,
                            Parent = Row,
                        })

                        local ClickBtn = Util.Create("TextButton", {
                            Size = UDim2.new(1, 0, 1, 0),
                            BackgroundTransparency = 1,
                            Text = "",
                            ZIndex = 24,
                            Parent = Row,
                        })

                        ClickBtn.MouseButton1Click:Connect(function()
                            selected[item] = not selected[item]
                            SummaryLabel.Text = Summary()
                            SummaryLabel.TextColor3 = #GetSelected() > 0 and Theme.TextPrimary or Theme.TextDisabled
                            Callback(GetSelected())
                            if Flag then cfg:Set(Flag, GetSelected()) end
                            Rebuild()
                        end)

                        ClickBtn.MouseEnter:Connect(function()
                            if not selected[item] then
                                Util.Tween(Row, { BackgroundTransparency = 0.75, BackgroundColor3 = Theme.Border }, 0.08)
                            end
                        end)
                        ClickBtn.MouseLeave:Connect(function()
                            if not selected[item] then
                                Util.Tween(Row, { BackgroundTransparency = 1 }, 0.08)
                            end
                        end)
                    end
                end
                Rebuild()

                MBtn.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    DropList.Visible = true
                    local h = isOpen and math.min(#Items * itemH + 8, maxV * itemH + 8) or 0
                    Util.Tween(DropList, { Size = UDim2.new(1, 0, 0, h) }, 0.18)
                    Util.Tween(Arrow, { Rotation = isOpen and 180 or 0 }, 0.15)
                    if not isOpen then task.delay(0.18, function() DropList.Visible = false end) end
                end)

                local MS = {}
                function MS:Get() return GetSelected() end
                function MS:Set(tbl)
                    selected = {}
                    for _, v in ipairs(tbl) do selected[v] = true end
                    SummaryLabel.Text = Summary()
                    Rebuild()
                end
                return MS
            end

            -- ─── COLOR PICKER ─────────────────────────────────────
            function Group:AddColorPicker(opts)
                opts = opts or {}
                local Label    = opts.Label    or "Color"
                local Default  = opts.Default  or Color3.fromRGB(255, 100, 100)
                local Callback  = opts.Callback  or function() end
                local Flag     = opts.Flag

                local color = Default
                local hue, sat, val = Color3.toHSV(color)
                local isOpen = false

                local Wrapper = Util.Create("Frame", {
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundTransparency = 1,
                    ClipsDescendants = false,
                    ZIndex = 8,
                    Parent = GroupContent,
                })

                local LabelText = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -50, 1, 0),
                    BackgroundTransparency = 1,
                    Text = Label,
                    TextColor3 = Theme.TextPrimary,
                    TextSize = 13,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Wrapper,
                })

                -- Swatch button
                local Swatch = Util.Create("TextButton", {
                    Size = UDim2.new(0, 36, 0, 20),
                    Position = UDim2.new(1, -36, 0.5, -10),
                    BackgroundColor3 = color,
                    BorderSizePixel = 0,
                    Text = "",
                    ZIndex = 9,
                    Parent = Wrapper,
                })
                Util.Corner(Swatch, 5)
                Util.Stroke(Swatch, Theme.Border, 1.5)

                -- Picker popup
                local Picker = Util.Create("Frame", {
                    Size = UDim2.new(0, 200, 0, 0),
                    Position = UDim2.new(1, -200, 1, 6),
                    BackgroundColor3 = Theme.Panel,
                    BorderSizePixel = 0,
                    ClipsDescendants = true,
                    ZIndex = 30,
                    Visible = false,
                    Parent = Wrapper,
                })
                Util.Corner(Picker, 8)
                Util.Stroke(Picker, Theme.Border, 1)

                local function MakeGradient(frame, colorSeq, transSeq, dir)
                    local grad = Util.Create("UIGradient", {
                        Color = colorSeq,
                        Transparency = transSeq or NumberSequence.new(0),
                        Rotation = dir or 0,
                        Parent = frame,
                    })
                    return grad
                end

                -- SV square
                local SVBox = Util.Create("ImageButton", {
                    Size = UDim2.new(1, -16, 0, 120),
                    Position = UDim2.new(0, 8, 0, 8),
                    BackgroundColor3 = Color3.fromHSV(hue, 1, 1),
                    BorderSizePixel = 0,
                    ZIndex = 31,
                    Image = "",
                    Parent = Picker,
                })
                Util.Corner(SVBox, 4)

                -- White to transparent gradient (left to right)
                MakeGradient(SVBox,
                    ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
                        ColorSequenceKeypoint.new(1, Color3.new(1,1,1)),
                    }),
                    NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0),
                        NumberSequenceKeypoint.new(1, 1),
                    }), 0
                )

                -- Black gradient overlay (top to bottom) — separate frame
                local BlackOverlay = Util.Create("Frame", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundColor3 = Color3.new(0,0,0),
                    BackgroundTransparency = 0,
                    BorderSizePixel = 0,
                    ZIndex = 32,
                    Parent = SVBox,
                })
                Util.Corner(BlackOverlay, 4)
                MakeGradient(BlackOverlay,
                    ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.new(0,0,0)),
                        ColorSequenceKeypoint.new(1, Color3.new(0,0,0)),
                    }),
                    NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(1, 0),
                    }), 90
                )

                -- SV cursor
                local SVCursor = Util.Create("Frame", {
                    Size = UDim2.new(0, 10, 0, 10),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(sat, 0, 1 - val, 0),
                    BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0,
                    ZIndex = 35,
                    Parent = SVBox,
                })
                Util.Corner(SVCursor, 5)
                Util.Stroke(SVCursor, Color3.new(0,0,0), 1.5)

                -- Hue bar
                local HueBar = Util.Create("ImageButton", {
                    Size = UDim2.new(1, -16, 0, 12),
                    Position = UDim2.new(0, 8, 0, 136),
                    BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0,
                    ZIndex = 31,
                    Image = "",
                    Parent = Picker,
                })
                Util.Corner(HueBar, 4)

                local hueColors = {}
                for i = 0, 6 do
                    table.insert(hueColors, ColorSequenceKeypoint.new(i/6, Color3.fromHSV(i/6, 1, 1)))
                end
                MakeGradient(HueBar, ColorSequence.new(hueColors), NumberSequence.new(0), 0)

                -- Hue cursor
                local HueCursor = Util.Create("Frame", {
                    Size = UDim2.new(0, 4, 1, 4),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(hue, 0, 0.5, 0),
                    BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0,
                    ZIndex = 33,
                    Parent = HueBar,
                })
                Util.Corner(HueCursor, 2)
                Util.Stroke(HueCursor, Color3.new(0,0,0), 1)

                -- Hex label
                local HexLabel = Util.Create("TextLabel", {
                    Size = UDim2.new(1, -16, 0, 22),
                    Position = UDim2.new(0, 8, 0, 156),
                    BackgroundColor3 = Theme.SurfaceAlt,
                    BorderSizePixel = 0,
                    Text = "#" .. string.format("%02X%02X%02X",
                        math.floor(color.R*255),
                        math.floor(color.G*255),
                        math.floor(color.B*255)),
                    TextColor3 = Theme.TextSecondary,
                    TextSize = 11,
                    Font = Enum.Font.Code,
                    ZIndex = 32,
                    Parent = Picker,
                })
                Util.Corner(HexLabel, 4)

                -- Close button
                local DoneBtn = Util.Create("TextButton", {
                    Size = UDim2.new(1, -16, 0, 22),
                    Position = UDim2.new(0, 8, 0, 182),
                    BackgroundColor3 = Theme.AccentDim,
                    BorderSizePixel = 0,
                    Text = "Apply",
                    TextColor3 = Theme.TextAccent,
                    TextSize = 12,
                    Font = Enum.Font.GothamSemibold,
                    ZIndex = 32,
                    Parent = Picker,
                })
                Util.Corner(DoneBtn, 4)

                local function UpdateColor()
                    color = Color3.fromHSV(hue, sat, val)
                    Swatch.BackgroundColor3 = color
                    SVBox.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
                    HexLabel.Text = "#" .. string.format("%02X%02X%02X",
                        math.floor(color.R*255), math.floor(color.G*255), math.floor(color.B*255))
                    Callback(color)
                    if Flag then cfg:Set(Flag, { color.R, color.G, color.B }) end
                end

                local draggingSV  = false
                local draggingHue = false

                SVBox.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 then
                        draggingSV = true
                        local rx = math.clamp((i.Position.X - SVBox.AbsolutePosition.X) / SVBox.AbsoluteSize.X, 0, 1)
                        local ry = math.clamp((i.Position.Y - SVBox.AbsolutePosition.Y) / SVBox.AbsoluteSize.Y, 0, 1)
                        sat = rx; val = 1 - ry
                        SVCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
                        UpdateColor()
                    end
                end)
                SVBox.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingSV = false end
                end)

                HueBar.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 then
                        draggingHue = true
                        hue = math.clamp((i.Position.X - HueBar.AbsolutePosition.X) / HueBar.AbsoluteSize.X, 0, 1)
                        HueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
                        UpdateColor()
                    end
                end)
                HueBar.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingHue = false end
                end)

                UserInputService.InputChanged:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseMovement then
                        if draggingSV then
                            local rx = math.clamp((i.Position.X - SVBox.AbsolutePosition.X) / SVBox.AbsoluteSize.X, 0, 1)
                            local ry = math.clamp((i.Position.Y - SVBox.AbsolutePosition.Y) / SVBox.AbsoluteSize.Y, 0, 1)
                            sat = rx; val = 1 - ry
                            SVCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
                            UpdateColor()
                        end
                        if draggingHue then
                            hue = math.clamp((i.Position.X - HueBar.AbsolutePosition.X) / HueBar.AbsoluteSize.X, 0, 1)
                            HueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
                            UpdateColor()
                        end
                    end
                end)

                Swatch.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    Picker.Visible = true
                    local targetH = isOpen and 212 or 0
                    Util.Tween(Picker, { Size = UDim2.new(0, 200, 0, targetH) }, 0.18)
                    if not isOpen then task.delay(0.18, function() Picker.Visible = false end) end
                end)

                DoneBtn.MouseButton1Click:Connect(function()
                    isOpen = false
                    Util.Tween(Picker, { Size = UDim2.new(0, 200, 0, 0) }, 0.18)
                    task.delay(0.18, function() Picker.Visible = false end)
                end)

                local CP = {}
                function CP:Set(c)
                    color = c
                    hue, sat, val = Color3.toHSV(c)
                    Swatch.BackgroundColor3 = c
                    SVCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
                    HueCursor.Position = UDim2.new(hue, 0, 0.5, 0)
                    SVBox.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
                    HexLabel.Text = "#" .. string.format("%02X%02X%02X",
                        math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255))
                    Callback(color)
                end
                function CP:Get() return color end
                return CP
            end

            -- ─── LABEL ────────────────────────────────────────────
            function Group:AddLabel(opts)
                opts = opts or {}
                local Text = opts.Text or ""

                local Lbl = Util.Create("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 22),
                    BackgroundTransparency = 1,
                    Text = Text,
                    TextColor3 = Theme.TextSecondary,
                    TextSize = 12,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    Parent = GroupContent,
                })

                local Lbl2 = {}
                function Lbl2:Set(t) Lbl.Text = t end
                return Lbl2
            end

            -- ─── BUTTON ───────────────────────────────────────────
            function Group:AddButton(opts)
                opts = opts or {}
                local Label    = opts.Label    or "Button"
                local Callback  = opts.Callback  or function() end

                local Btn = Util.Create("TextButton", {
                    Size = UDim2.new(1, 0, 0, 28),
                    BackgroundColor3 = Theme.AccentDim,
                    BorderSizePixel = 0,
                    Text = Label,
                    TextColor3 = Theme.TextAccent,
                    TextSize = 13,
                    Font = Enum.Font.GothamSemibold,
                    Parent = GroupContent,
                })
                Util.Corner(Btn, 6)
                Util.Stroke(Btn, Theme.Accent, 1)

                Util.Hover(Btn, Theme.AccentDim, Theme.Accent)

                Btn.MouseButton1Click:Connect(function()
                    Util.Tween(Btn, { BackgroundColor3 = Theme.Accent }, 0.08)
                    task.delay(0.12, function()
                        Util.Tween(Btn, { BackgroundColor3 = Theme.AccentDim }, 0.15)
                    end)
                    Callback()
                end)

                return Btn
            end

            return Group
        end

        -- ── Config Panel (special tab) ─────────────────────────
        function Tab:AddConfigPanel()
            local cfgGroup = self:AddGroupbox({ Name = "Config Manager" })

            -- Save / Load / Delete buttons with name input
            local nameInput = Util.Create("TextBox", {
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundColor3 = Theme.SurfaceAlt,
                BorderSizePixel = 0,
                Text = "",
                PlaceholderText = "Config name...",
                PlaceholderColor3 = Theme.TextDisabled,
                TextColor3 = Theme.TextPrimary,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                ClearTextOnFocus = false,
                Parent = Tab.Page,
            })
            Util.Corner(nameInput, 6)
            Util.Stroke(nameInput, Theme.Border, 1)
            Util.Padding(nameInput, 0, 0, 0, 10)

            -- Buttons row
            local BtnRow = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 28),
                BackgroundTransparency = 1,
                Parent = Tab.Page,
            })

            local BtnLayout = Util.Create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 6),
                Parent = BtnRow,
            })

            local function MkBtn(text, color, hoverC)
                local b = Util.Create("TextButton", {
                    Size = UDim2.new(0.33, -4, 1, 0),
                    BackgroundColor3 = color,
                    BorderSizePixel = 0,
                    Text = text,
                    TextColor3 = Theme.TextPrimary,
                    TextSize = 12,
                    Font = Enum.Font.GothamSemibold,
                    Parent = BtnRow,
                })
                Util.Corner(b, 6)
                Util.Hover(b, color, hoverC)
                return b
            end

            local SaveBtn   = MkBtn("💾 Save",   Theme.AccentDim, Theme.Accent)
            local LoadBtn   = MkBtn("📂 Load",   Theme.Panel,     Theme.SurfaceAlt)
            local DeleteBtn = MkBtn("🗑 Delete", Color3.fromRGB(80,30,30), Theme.Danger)

            -- List frame
            local ListFrame = Util.Create("Frame", {
                Size = UDim2.new(1, 0, 0, 120),
                BackgroundColor3 = Theme.Surface,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Parent = Tab.Page,
            })
            Util.Corner(ListFrame, 6)
            Util.Stroke(ListFrame, Theme.Border, 1)

            local ListScroll = Util.Create("ScrollingFrame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 3,
                ScrollBarImageColor3 = Theme.Accent,
                CanvasSize = UDim2.new(0, 0, 0, 0),
                Parent = ListFrame,
            })
            Util.Padding(ListScroll, 4, 6, 4, 6)

            local ListLayout = Util.Create("UIListLayout", {
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 3),
                Parent = ListScroll,
            })

            ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                ListScroll.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 8)
            end)

            local function RefreshList()
                for _, c in pairs(ListScroll:GetChildren()) do
                    if c:IsA("TextButton") then c:Destroy() end
                end
                local configs = cfg:List()
                if #configs == 0 then
                    Util.Create("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 28),
                        BackgroundTransparency = 1,
                        Text = "No configs saved.",
                        TextColor3 = Theme.TextDisabled,
                        TextSize = 11,
                        Font = Enum.Font.Gotham,
                        Name = "__empty",
                        Parent = ListScroll,
                    })
                else
                    -- Remove empty label
                    local e = ListScroll:FindFirstChild("__empty")
                    if e then e:Destroy() end
                end
                for _, name in ipairs(configs) do
                    local entry = Util.Create("TextButton", {
                        Size = UDim2.new(1, 0, 0, 26),
                        BackgroundColor3 = Theme.SurfaceAlt,
                        BorderSizePixel = 0,
                        Text = "📄  " .. name,
                        TextColor3 = Theme.TextPrimary,
                        TextSize = 12,
                        Font = Enum.Font.Gotham,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Parent = ListScroll,
                    })
                    Util.Corner(entry, 4)
                    Util.Padding(entry, 0, 0, 0, 8)

                    entry.MouseButton1Click:Connect(function()
                        nameInput.Text = name
                    end)
                    Util.Hover(entry, Theme.SurfaceAlt, Theme.Panel)
                end
            end

            RefreshList()

            SaveBtn.MouseButton1Click:Connect(function()
                local name = nameInput.Text
                if name == "" then return end
                cfg:Save(name)
                RefreshList()
            end)

            LoadBtn.MouseButton1Click:Connect(function()
                local name = nameInput.Text
                if name == "" then return end
                cfg:Load(name)
            end)

            DeleteBtn.MouseButton1Click:Connect(function()
                local name = nameInput.Text
                if name == "" then return end
                cfg:Delete(name)
                nameInput.Text = ""
                RefreshList()
            end)
        end

        return Tab
    end

    return Window
end

return NexusLib
