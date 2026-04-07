local InputService = game:GetService('UserInputService');
local TextService = game:GetService('TextService');
local CoreGui = game:GetService('CoreGui');
local Teams = game:GetService('Teams');
local Players = game:GetService('Players');
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService');
local RenderStepped = RunService.RenderStepped;
local LocalPlayer = Players.LocalPlayer;
local Mouse = LocalPlayer:GetMouse();

local ProtectGui = protectgui or (syn and syn.protect_gui) or (function() end);

local ScreenGui = Instance.new('ScreenGui');
ProtectGui(ScreenGui);

ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global;
ScreenGui.Parent = CoreGui;

local Toggles = {};
local Options = {};

getgenv().Toggles = Toggles;
getgenv().Options = Options;

local Library = {
    Registry = {};
    RegistryMap = {};

    HudRegistry = {};

    -- ═══ NEVERLOSE COLOR PALETTE ═══
    FontColor        = Color3.fromRGB(210, 212, 228);
    SubtextColor     = Color3.fromRGB(120, 124, 160);
    MainColor        = Color3.fromRGB(26, 27, 40);
    BackgroundColor  = Color3.fromRGB(18, 19, 29);
    SidebarColor     = Color3.fromRGB(20, 21, 33);
    ContentColor     = Color3.fromRGB(22, 23, 36);
    AccentColor      = Color3.fromRGB(52, 152, 255);
    AccentColorDark  = Color3.fromRGB(30, 80, 160);
    OutlineColor     = Color3.fromRGB(38, 40, 60);
    HeaderColor      = Color3.fromRGB(14, 15, 24);
    ToggleOffColor   = Color3.fromRGB(42, 44, 66);
    ToggleOnColor    = Color3.fromRGB(52, 152, 255);
    SectionTextColor = Color3.fromRGB(148, 150, 180);
    NavActiveColor   = Color3.fromRGB(30, 32, 50);
    NavHoverColor    = Color3.fromRGB(26, 28, 44);
    RiskColor        = Color3.fromRGB(255, 80, 80);

    Black = Color3.new(0, 0, 0);
    Font  = Enum.Font.GothamMedium,

    OpenedFrames = {};
    DependencyBoxes = {};

    Signals = {};
    ScreenGui = ScreenGui;
};

local RainbowStep = 0
local Hue = 0

table.insert(Library.Signals, RenderStepped:Connect(function(Delta)
    RainbowStep = RainbowStep + Delta

    if RainbowStep >= (1 / 60) then
        RainbowStep = 0

        Hue = Hue + (1 / 400);

        if Hue > 1 then
            Hue = 0;
        end;

        Library.CurrentRainbowHue = Hue;
        Library.CurrentRainbowColor = Color3.fromHSV(Hue, 0.8, 1);
    end
end))

local function GetPlayersString()
    local PlayerList = Players:GetPlayers();

    for i = 1, #PlayerList do
        PlayerList[i] = PlayerList[i].Name;
    end;

    table.sort(PlayerList, function(str1, str2) return str1 < str2 end);

    return PlayerList;
end;

local function GetTeamsString()
    local TeamList = Teams:GetTeams();

    for i = 1, #TeamList do
        TeamList[i] = TeamList[i].Name;
    end;

    table.sort(TeamList, function(str1, str2) return str1 < str2 end);
    
    return TeamList;
end;

function Library:SafeCallback(f, ...)
    if (not f) then
        return;
    end;

    if not Library.NotifyOnError then
        return f(...);
    end;

    local success, event = pcall(f, ...);

    if not success then
        local _, i = event:find(":%d+: ");

        if not i then
            return Library:Notify(event);
        end;

        return Library:Notify(event:sub(i + 1), 3);
    end;
end;

function Library:AttemptSave()
    if Library.SaveManager then
        Library.SaveManager:Save();
    end;
end;

function Library:Create(Class, Properties)
    local _Instance = Class;

    if type(Class) == 'string' then
        _Instance = Instance.new(Class);
    end;

    for Property, Value in next, Properties do
        _Instance[Property] = Value;
    end;

    return _Instance;
end;

function Library:ApplyTextStroke(Inst)
    Inst.TextStrokeTransparency = 1;

    Library:Create('UIStroke', {
        Color = Color3.new(0, 0, 0);
        Thickness = 1;
        LineJoinMode = Enum.LineJoinMode.Miter;
        Parent = Inst;
    });
end;

function Library:CreateLabel(Properties, IsHud)
    local _Instance = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 16;
        TextStrokeTransparency = 0;
    });

    Library:ApplyTextStroke(_Instance);

    Library:AddToRegistry(_Instance, {
        TextColor3 = 'FontColor';
    }, IsHud);

    return Library:Create(_Instance, Properties);
end;

function Library:MakeDraggable(Instance, Cutoff)
    Instance.Active = true;

    Instance.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            local ObjPos = Vector2.new(
                Mouse.X - Instance.AbsolutePosition.X,
                Mouse.Y - Instance.AbsolutePosition.Y
            );

            if ObjPos.Y > (Cutoff or 40) then
                return;
            end;

            while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                Instance.Position = UDim2.new(
                    0,
                    Mouse.X - ObjPos.X + (Instance.Size.X.Offset * Instance.AnchorPoint.X),
                    0,
                    Mouse.Y - ObjPos.Y + (Instance.Size.Y.Offset * Instance.AnchorPoint.Y)
                );

                RenderStepped:Wait();
            end;
        end;
    end)
end;

function Library:AddToolTip(InfoStr, HoverInstance)
    local X, Y = Library:GetTextBounds(InfoStr, Library.Font, 14);
    local Tooltip = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor,
        BorderColor3 = Library.OutlineColor,

        Size = UDim2.fromOffset(X + 5, Y + 4),
        ZIndex = 100,
        Parent = Library.ScreenGui,

        Visible = false,
    })

    local Label = Library:CreateLabel({
        Position = UDim2.fromOffset(3, 1),
        Size = UDim2.fromOffset(X, Y);
        TextSize = 14;
        Text = InfoStr,
        TextColor3 = Library.FontColor,
        TextXAlignment = Enum.TextXAlignment.Left;
        ZIndex = Tooltip.ZIndex + 1,

        Parent = Tooltip;
    });

    Library:AddToRegistry(Tooltip, {
        BackgroundColor3 = 'MainColor';
        BorderColor3 = 'OutlineColor';
    });

    Library:AddToRegistry(Label, {
        TextColor3 = 'FontColor',
    });

    local IsHovering = false

    HoverInstance.MouseEnter:Connect(function()
        if Library:MouseIsOverOpenedFrame() then
            return
        end

        IsHovering = true

        Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        Tooltip.Visible = true

        while IsHovering do
            RunService.Heartbeat:Wait()
            Tooltip.Position = UDim2.fromOffset(Mouse.X + 15, Mouse.Y + 12)
        end
    end)

    HoverInstance.MouseLeave:Connect(function()
        IsHovering = false
        Tooltip.Visible = false
    end)
end

function Library:OnHighlight(HighlightInstance, Instance, Properties, PropertiesDefault)
    HighlightInstance.MouseEnter:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, Properties do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)

    HighlightInstance.MouseLeave:Connect(function()
        local Reg = Library.RegistryMap[Instance];

        for Property, ColorIdx in next, PropertiesDefault do
            Instance[Property] = Library[ColorIdx] or ColorIdx;

            if Reg and Reg.Properties[Property] then
                Reg.Properties[Property] = ColorIdx;
            end;
        end;
    end)
end;

function Library:MouseIsOverOpenedFrame()
    for Frame, _ in next, Library.OpenedFrames do
        local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

        if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
            and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

            return true;
        end;
    end;
end;

function Library:IsMouseOverFrame(Frame)
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize;

    if Mouse.X >= AbsPos.X and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y and Mouse.Y <= AbsPos.Y + AbsSize.Y then

        return true;
    end;
end;

function Library:UpdateDependencyBoxes()
    for _, Depbox in next, Library.DependencyBoxes do
        Depbox:Update();
    end;
end;

function Library:MapValue(Value, MinA, MaxA, MinB, MaxB)
    return (1 - ((Value - MinA) / (MaxA - MinA))) * MinB + ((Value - MinA) / (MaxA - MinA)) * MaxB;
end;

function Library:GetTextBounds(Text, Font, Size, Resolution)
    local Bounds = TextService:GetTextSize(Text, Size, Font, Resolution or Vector2.new(1920, 1080))
    return Bounds.X, Bounds.Y
end;

function Library:GetDarkerColor(Color)
    local H, S, V = Color3.toHSV(Color);
    return Color3.fromHSV(H, S, V / 1.5);
end;
-- AccentColorDark already set in Library table

function Library:AddToRegistry(Instance, Properties, IsHud)
    local Idx = #Library.Registry + 1;
    local Data = {
        Instance = Instance;
        Properties = Properties;
        Idx = Idx;
    };

    table.insert(Library.Registry, Data);
    Library.RegistryMap[Instance] = Data;

    if IsHud then
        table.insert(Library.HudRegistry, Data);
    end;
end;

function Library:RemoveFromRegistry(Instance)
    local Data = Library.RegistryMap[Instance];

    if Data then
        for Idx = #Library.Registry, 1, -1 do
            if Library.Registry[Idx] == Data then
                table.remove(Library.Registry, Idx);
            end;
        end;

        for Idx = #Library.HudRegistry, 1, -1 do
            if Library.HudRegistry[Idx] == Data then
                table.remove(Library.HudRegistry, Idx);
            end;
        end;

        Library.RegistryMap[Instance] = nil;
    end;
end;

function Library:UpdateColorsUsingRegistry()
    -- TODO: Could have an 'active' list of objects
    -- where the active list only contains Visible objects.

    -- IMPL: Could setup .Changed events on the AddToRegistry function
    -- that listens for the 'Visible' propert being changed.
    -- Visible: true => Add to active list, and call UpdateColors function
    -- Visible: false => Remove from active list.

    -- The above would be especially efficient for a rainbow menu color or live color-changing.

    for Idx, Object in next, Library.Registry do
        for Property, ColorIdx in next, Object.Properties do
            if type(ColorIdx) == 'string' then
                Object.Instance[Property] = Library[ColorIdx];
            elseif type(ColorIdx) == 'function' then
                Object.Instance[Property] = ColorIdx()
            end
        end;
    end;
end;

function Library:GiveSignal(Signal)
    -- Only used for signals not attached to library instances, as those should be cleaned up on object destruction by Roblox
    table.insert(Library.Signals, Signal)
end

function Library:Unload()
    -- Unload all of the signals
    for Idx = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Idx)
        Connection:Disconnect()
    end

     -- Call our unload callback, maybe to undo some hooks etc
    if Library.OnUnload then
        Library.OnUnload()
    end

    ScreenGui:Destroy()
end

function Library:OnUnload(Callback)
    Library.OnUnload = Callback
end

Library:GiveSignal(ScreenGui.DescendantRemoving:Connect(function(Instance)
    if Library.RegistryMap[Instance] then
        Library:RemoveFromRegistry(Instance);
    end;
end))

local BaseAddons = {};

do
    local Funcs = {};

    function Funcs:AddColorPicker(Idx, Info)
        local ToggleLabel = self.TextLabel;
        -- local Container = self.Container;

        assert(Info.Default, 'AddColorPicker: Missing default value.');

        local ColorPicker = {
            Value = Info.Default;
            Transparency = Info.Transparency or 0;
            Type = 'ColorPicker';
            Title = type(Info.Title) == 'string' and Info.Title or 'Color picker',
            Callback = Info.Callback or function(Color) end;
        };

        function ColorPicker:SetHSVFromRGB(Color)
            local H, S, V = Color3.toHSV(Color);

            ColorPicker.Hue = H;
            ColorPicker.Sat = S;
            ColorPicker.Vib = V;
        end;

        ColorPicker:SetHSVFromRGB(ColorPicker.Value);

        local DisplayFrame = Library:Create('Frame', {
            BackgroundColor3 = ColorPicker.Value;
            BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(0, 28, 0, 14);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        -- Transparency image taken from https://github.com/matas3535/SplixPrivateDrawingLibrary/blob/main/Library.lua cus i'm lazy
        local CheckerFrame = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(0, 27, 0, 13);
            ZIndex = 5;
            Image = 'http://www.roblox.com/asset/?id=12977615774';
            Visible = not not Info.Transparency;
            Parent = DisplayFrame;
        });

        -- 1/16/23
        -- Rewrote this to be placed inside the Library ScreenGui
        -- There was some issue which caused RelativeOffset to be way off
        -- Thus the color picker would never show

        local PickerFrameOuter = Library:Create('Frame', {
            Name = 'Color';
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18),
            Size = UDim2.fromOffset(230, Info.Transparency and 271 or 253);
            Visible = false;
            ZIndex = 15;
            Parent = ScreenGui,
        });

        DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            PickerFrameOuter.Position = UDim2.fromOffset(DisplayFrame.AbsolutePosition.X, DisplayFrame.AbsolutePosition.Y + 18);
        end)

        local PickerFrameInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 16;
            Parent = PickerFrameOuter;
        });

        local Highlight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 2);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 4, 0, 25);
            Size = UDim2.new(0, 200, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local SatVibMapInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = SatVibMapOuter;
        });

        local SatVibMap = Library:Create('ImageLabel', {
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Image = 'rbxassetid://4155801252';
            Parent = SatVibMapInner;
        });

        local CursorOuter = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Size = UDim2.new(0, 6, 0, 6);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ImageColor3 = Color3.new(0, 0, 0);
            ZIndex = 19;
            Parent = SatVibMap;
        });

        local CursorInner = Library:Create('ImageLabel', {
            Size = UDim2.new(0, CursorOuter.Size.X.Offset - 2, 0, CursorOuter.Size.Y.Offset - 2);
            Position = UDim2.new(0, 1, 0, 1);
            BackgroundTransparency = 1;
            Image = 'http://www.roblox.com/asset/?id=9619665977';
            ZIndex = 20;
            Parent = CursorOuter;
        })

        local HueSelectorOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.new(0, 208, 0, 25);
            Size = UDim2.new(0, 15, 0, 200);
            ZIndex = 17;
            Parent = PickerFrameInner;
        });

        local HueSelectorInner = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(1, 1, 1);
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18;
            Parent = HueSelectorOuter;
        });

        local HueCursor = Library:Create('Frame', { 
            BackgroundColor3 = Color3.new(1, 1, 1);
            AnchorPoint = Vector2.new(0, 0.5);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 18;
            Parent = HueSelectorInner;
        });

        local HueBoxOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(4, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            ZIndex = 18,
            Parent = PickerFrameInner;
        });

        local HueBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 18,
            Parent = HueBoxOuter;
        });

        Library:Create('UIGradient', {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(212, 212, 212))
            });
            Rotation = 90;
            Parent = HueBoxInner;
        });

        local HueBox = Library:Create('TextBox', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = 'Hex color',
            Text = '#FFFFFF',
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 20,
            Parent = HueBoxInner;
        });

        Library:ApplyTextStroke(HueBox);

        local RgbBoxBase = Library:Create(HueBoxOuter:Clone(), {
            Position = UDim2.new(0.5, 2, 0, 228),
            Size = UDim2.new(0.5, -6, 0, 20),
            Parent = PickerFrameInner
        });

        local RgbBox = Library:Create(RgbBoxBase.Frame:FindFirstChild('TextBox'), {
            Text = '255, 255, 255',
            PlaceholderText = 'RGB color',
            TextColor3 = Library.FontColor
        });

        local TransparencyBoxOuter, TransparencyBoxInner, TransparencyCursor;
        
        if Info.Transparency then 
            TransparencyBoxOuter = Library:Create('Frame', {
                BorderColor3 = Color3.new(0, 0, 0);
                Position = UDim2.fromOffset(4, 251);
                Size = UDim2.new(1, -8, 0, 15);
                ZIndex = 19;
                Parent = PickerFrameInner;
            });

            TransparencyBoxInner = Library:Create('Frame', {
                BackgroundColor3 = ColorPicker.Value;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 19;
                Parent = TransparencyBoxOuter;
            });

            Library:AddToRegistry(TransparencyBoxInner, { BorderColor3 = 'OutlineColor' });

            Library:Create('ImageLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Image = 'http://www.roblox.com/asset/?id=12978095818';
                ZIndex = 20;
                Parent = TransparencyBoxInner;
            });

            TransparencyCursor = Library:Create('Frame', { 
                BackgroundColor3 = Color3.new(1, 1, 1);
                AnchorPoint = Vector2.new(0.5, 0);
                BorderColor3 = Color3.new(0, 0, 0);
                Size = UDim2.new(0, 1, 1, 0);
                ZIndex = 21;
                Parent = TransparencyBoxInner;
            });
        end;

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 14);
            Position = UDim2.fromOffset(5, 5);
            TextXAlignment = Enum.TextXAlignment.Left;
            TextSize = 14;
            Text = ColorPicker.Title,--Info.Default;
            TextWrapped = false;
            ZIndex = 16;
            Parent = PickerFrameInner;
        });


        local ContextMenu = {}
        do
            ContextMenu.Options = {}
            ContextMenu.Container = Library:Create('Frame', {
                BorderColor3 = Color3.new(),
                ZIndex = 14,

                Visible = false,
                Parent = ScreenGui
            })

            ContextMenu.Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.BackgroundColor;
                BorderColor3 = Library.OutlineColor;
                BorderMode = Enum.BorderMode.Inset;
                Size = UDim2.fromScale(1, 1);
                ZIndex = 15;
                Parent = ContextMenu.Container;
            });

            Library:Create('UIListLayout', {
                Name = 'Layout',
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = ContextMenu.Inner;
            });

            Library:Create('UIPadding', {
                Name = 'Padding',
                PaddingLeft = UDim.new(0, 4),
                Parent = ContextMenu.Inner,
            });

            local function updateMenuPosition()
                ContextMenu.Container.Position = UDim2.fromOffset(
                    (DisplayFrame.AbsolutePosition.X + DisplayFrame.AbsoluteSize.X) + 4,
                    DisplayFrame.AbsolutePosition.Y + 1
                )
            end

            local function updateMenuSize()
                local menuWidth = 60
                for i, label in next, ContextMenu.Inner:GetChildren() do
                    if label:IsA('TextLabel') then
                        menuWidth = math.max(menuWidth, label.TextBounds.X)
                    end
                end

                ContextMenu.Container.Size = UDim2.fromOffset(
                    menuWidth + 8,
                    ContextMenu.Inner.Layout.AbsoluteContentSize.Y + 4
                )
            end

            DisplayFrame:GetPropertyChangedSignal('AbsolutePosition'):Connect(updateMenuPosition)
            ContextMenu.Inner.Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(updateMenuSize)

            task.spawn(updateMenuPosition)
            task.spawn(updateMenuSize)

            Library:AddToRegistry(ContextMenu.Inner, {
                BackgroundColor3 = 'BackgroundColor';
                BorderColor3 = 'OutlineColor';
            });

            function ContextMenu:Show()
                self.Container.Visible = true
            end

            function ContextMenu:Hide()
                self.Container.Visible = false
            end

            function ContextMenu:AddOption(Str, Callback)
                if type(Callback) ~= 'function' then
                    Callback = function() end
                end

                local Button = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, 0, 0, 15);
                    TextSize = 13;
                    Text = Str;
                    ZIndex = 16;
                    Parent = self.Inner;
                    TextXAlignment = Enum.TextXAlignment.Left,
                });

                Library:OnHighlight(Button, Button, 
                    { TextColor3 = 'AccentColor' },
                    { TextColor3 = 'FontColor' }
                );

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                    end

                    Callback()
                end)
            end

            ContextMenu:AddOption('Copy color', function()
                Library.ColorClipboard = ColorPicker.Value
                Library:Notify('Copied color!', 2)
            end)

            ContextMenu:AddOption('Paste color', function()
                if not Library.ColorClipboard then
                    return Library:Notify('You have not copied a color!', 2)
                end
                ColorPicker:SetValueRGB(Library.ColorClipboard)
            end)


            ContextMenu:AddOption('Copy HEX', function()
                pcall(setclipboard, ColorPicker.Value:ToHex())
                Library:Notify('Copied hex code to clipboard!', 2)
            end)

            ContextMenu:AddOption('Copy RGB', function()
                pcall(setclipboard, table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', '))
                Library:Notify('Copied RGB values to clipboard!', 2)
            end)

        end

        Library:AddToRegistry(PickerFrameInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor'; });
        Library:AddToRegistry(SatVibMapInner, { BackgroundColor3 = 'BackgroundColor'; BorderColor3 = 'OutlineColor'; });

        Library:AddToRegistry(HueBoxInner, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBoxBase.Frame, { BackgroundColor3 = 'MainColor'; BorderColor3 = 'OutlineColor'; });
        Library:AddToRegistry(RgbBox, { TextColor3 = 'FontColor', });
        Library:AddToRegistry(HueBox, { TextColor3 = 'FontColor', });

        local SequenceTable = {};

        for Hue = 0, 1, 0.1 do
            table.insert(SequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)));
        end;

        local HueSelectorGradient = Library:Create('UIGradient', {
            Color = ColorSequence.new(SequenceTable);
            Rotation = 90;
            Parent = HueSelectorInner;
        });

        HueBox.FocusLost:Connect(function(enter)
            if enter then
                local success, result = pcall(Color3.fromHex, HueBox.Text)
                if success and typeof(result) == 'Color3' then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(result)
                end
            end

            ColorPicker:Display()
        end)

        RgbBox.FocusLost:Connect(function(enter)
            if enter then
                local r, g, b = RgbBox.Text:match('(%d+),%s*(%d+),%s*(%d+)')
                if r and g and b then
                    ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color3.toHSV(Color3.fromRGB(r, g, b))
                end
            end

            ColorPicker:Display()
        end)

        function ColorPicker:Display()
            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib);
            SatVibMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1);

            Library:Create(DisplayFrame, {
                BackgroundColor3 = ColorPicker.Value;
                BackgroundTransparency = ColorPicker.Transparency;
                BorderColor3 = Library:GetDarkerColor(ColorPicker.Value);
            });

            if TransparencyBoxInner then
                TransparencyBoxInner.BackgroundColor3 = ColorPicker.Value;
                TransparencyCursor.Position = UDim2.new(1 - ColorPicker.Transparency, 0, 0, 0);
            end;

            CursorOuter.Position = UDim2.new(ColorPicker.Sat, 0, 1 - ColorPicker.Vib, 0);
            HueCursor.Position = UDim2.new(0, 0, ColorPicker.Hue, 0);

            HueBox.Text = '#' .. ColorPicker.Value:ToHex()
            RgbBox.Text = table.concat({ math.floor(ColorPicker.Value.R * 255), math.floor(ColorPicker.Value.G * 255), math.floor(ColorPicker.Value.B * 255) }, ', ')

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value);
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value);
        end;

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func;
            Func(ColorPicker.Value)
        end;

        function ColorPicker:Show()
            for Frame, Val in next, Library.OpenedFrames do
                if Frame.Name == 'Color' then
                    Frame.Visible = false;
                    Library.OpenedFrames[Frame] = nil;
                end;
            end;

            PickerFrameOuter.Visible = true;
            Library.OpenedFrames[PickerFrameOuter] = true;
        end;

        function ColorPicker:Hide()
            PickerFrameOuter.Visible = false;
            Library.OpenedFrames[PickerFrameOuter] = nil;
        end;

        function ColorPicker:SetValue(HSV, Transparency)
            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3]);

            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Transparency or 0;
            ColorPicker:SetHSVFromRGB(Color);
            ColorPicker:Display();
        end;

        SatVibMap.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinX = SatVibMap.AbsolutePosition.X;
                    local MaxX = MinX + SatVibMap.AbsoluteSize.X;
                    local MouseX = math.clamp(Mouse.X, MinX, MaxX);

                    local MinY = SatVibMap.AbsolutePosition.Y;
                    local MaxY = MinY + SatVibMap.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Sat = (MouseX - MinX) / (MaxX - MinX);
                    ColorPicker.Vib = 1 - ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        HueSelectorInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local MinY = HueSelectorInner.AbsolutePosition.Y;
                    local MaxY = MinY + HueSelectorInner.AbsoluteSize.Y;
                    local MouseY = math.clamp(Mouse.Y, MinY, MaxY);

                    ColorPicker.Hue = ((MouseY - MinY) / (MaxY - MinY));
                    ColorPicker:Display();

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        DisplayFrame.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if PickerFrameOuter.Visible then
                    ColorPicker:Hide()
                else
                    ContextMenu:Hide()
                    ColorPicker:Show()
                end;
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ContextMenu:Show()
                ColorPicker:Hide()
            end
        end);

        if TransparencyBoxInner then
            TransparencyBoxInner.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                        local MinX = TransparencyBoxInner.AbsolutePosition.X;
                        local MaxX = MinX + TransparencyBoxInner.AbsoluteSize.X;
                        local MouseX = math.clamp(Mouse.X, MinX, MaxX);

                        ColorPicker.Transparency = 1 - ((MouseX - MinX) / (MaxX - MinX));

                        ColorPicker:Display();

                        RenderStepped:Wait();
                    end;

                    Library:AttemptSave();
                end;
            end);
        end;

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = PickerFrameOuter.AbsolutePosition, PickerFrameOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ColorPicker:Hide();
                end;

                if not Library:IsMouseOverFrame(ContextMenu.Container) then
                    ContextMenu:Hide()
                end
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton2 and ContextMenu.Container.Visible then
                if not Library:IsMouseOverFrame(ContextMenu.Container) and not Library:IsMouseOverFrame(DisplayFrame) then
                    ContextMenu:Hide()
                end
            end
        end))

        ColorPicker:Display();
        ColorPicker.DisplayFrame = DisplayFrame

        Options[Idx] = ColorPicker;

        return self;
    end;

    function Funcs:AddKeyPicker(Idx, Info)
        local ParentObj = self;
        local ToggleLabel = self.TextLabel;
        local Container = self.Container;

        assert(Info.Default, 'AddKeyPicker: Missing default value.');

        local KeyPicker = {
            Value = Info.Default;
            Toggled = false;
            Mode = Info.Mode or 'Toggle'; -- Always, Toggle, Hold
            Type = 'KeyPicker';
            Callback = Info.Callback or function(Value) end;
            ChangedCallback = Info.ChangedCallback or function(New) end;

            SyncToggleState = Info.SyncToggleState or false;
        };

        if KeyPicker.SyncToggleState then
            Info.Modes = { 'Toggle' }
            Info.Mode = 'Toggle'
        end

        local PickOuter = Library:Create('Frame', {
            BackgroundColor3 = Color3.new(0, 0, 0);
            BorderColor3 = Color3.new(0, 0, 0);
            Size = UDim2.new(0, 28, 0, 15);
            ZIndex = 6;
            Parent = ToggleLabel;
        });

        local PickInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 7;
            Parent = PickOuter;
        });

        Library:AddToRegistry(PickInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 13;
            Text = Info.Default;
            TextWrapped = true;
            ZIndex = 8;
            Parent = PickInner;
        });

        local ModeSelectOuter = Library:Create('Frame', {
            BorderColor3 = Color3.new(0, 0, 0);
            Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
            Size = UDim2.new(0, 60, 0, 45 + 2);
            Visible = false;
            ZIndex = 14;
            Parent = ScreenGui;
        });

        ToggleLabel:GetPropertyChangedSignal('AbsolutePosition'):Connect(function()
            ModeSelectOuter.Position = UDim2.fromOffset(ToggleLabel.AbsolutePosition.X + ToggleLabel.AbsoluteSize.X + 4, ToggleLabel.AbsolutePosition.Y + 1);
        end);

        local ModeSelectInner = Library:Create('Frame', {
            BackgroundColor3 = Library.BackgroundColor;
            BorderColor3 = Library.OutlineColor;
            BorderMode = Enum.BorderMode.Inset;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 15;
            Parent = ModeSelectOuter;
        });

        Library:AddToRegistry(ModeSelectInner, {
            BackgroundColor3 = 'BackgroundColor';
            BorderColor3 = 'OutlineColor';
        });

        Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ModeSelectInner;
        });

        local ContainerLabel = Library:CreateLabel({
            TextXAlignment = Enum.TextXAlignment.Left;
            Size = UDim2.new(1, 0, 0, 18);
            TextSize = 13;
            Visible = false;
            ZIndex = 110;
            Parent = Library.KeybindContainer;
        },  true);

        local Modes = Info.Modes or { 'Always', 'Toggle', 'Hold' };
        local ModeButtons = {};

        for Idx, Mode in next, Modes do
            local ModeButton = {};

            local Label = Library:CreateLabel({
                Active = false;
                Size = UDim2.new(1, 0, 0, 15);
                TextSize = 13;
                Text = Mode;
                ZIndex = 16;
                Parent = ModeSelectInner;
            });

            function ModeButton:Select()
                for _, Button in next, ModeButtons do
                    Button:Deselect();
                end;

                KeyPicker.Mode = Mode;

                Label.TextColor3 = Library.AccentColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'AccentColor';

                ModeSelectOuter.Visible = false;
            end;

            function ModeButton:Deselect()
                KeyPicker.Mode = nil;

                Label.TextColor3 = Library.FontColor;
                Library.RegistryMap[Label].Properties.TextColor3 = 'FontColor';
            end;

            Label.InputBegan:Connect(function(Input)
                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                    ModeButton:Select();
                    Library:AttemptSave();
                end;
            end);

            if Mode == KeyPicker.Mode then
                ModeButton:Select();
            end;

            ModeButtons[Mode] = ModeButton;
        end;

        function KeyPicker:Update()
            if Info.NoUI then
                return;
            end;

            local State = KeyPicker:GetState();

            ContainerLabel.Text = string.format('[%s] %s (%s)', KeyPicker.Value, Info.Text, KeyPicker.Mode);

            ContainerLabel.Visible = true;
            ContainerLabel.TextColor3 = State and Library.AccentColor or Library.FontColor;

            Library.RegistryMap[ContainerLabel].Properties.TextColor3 = State and 'AccentColor' or 'FontColor';

            local YSize = 0
            local XSize = 0

            for _, Label in next, Library.KeybindContainer:GetChildren() do
                if Label:IsA('TextLabel') and Label.Visible then
                    YSize = YSize + 18;
                    if (Label.TextBounds.X > XSize) then
                        XSize = Label.TextBounds.X
                    end
                end;
            end;

            Library.KeybindFrame.Size = UDim2.new(0, math.max(XSize + 10, 210), 0, YSize + 23)
        end;

        function KeyPicker:GetState()
            if KeyPicker.Mode == 'Always' then
                return true;
            elseif KeyPicker.Mode == 'Hold' then
                if KeyPicker.Value == 'None' then
                    return false;
                end

                local Key = KeyPicker.Value;

                if Key == 'MB1' or Key == 'MB2' then
                    return Key == 'MB1' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                        or Key == 'MB2' and InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2);
                else
                    return InputService:IsKeyDown(Enum.KeyCode[KeyPicker.Value]);
                end;
            else
                return KeyPicker.Toggled;
            end;
        end;

        function KeyPicker:SetValue(Data)
            local Key, Mode = Data[1], Data[2];
            DisplayLabel.Text = Key;
            KeyPicker.Value = Key;
            ModeButtons[Mode]:Select();
            KeyPicker:Update();
        end;

        function KeyPicker:OnClick(Callback)
            KeyPicker.Clicked = Callback
        end

        function KeyPicker:OnChanged(Callback)
            KeyPicker.Changed = Callback
            Callback(KeyPicker.Value)
        end

        if ParentObj.Addons then
            table.insert(ParentObj.Addons, KeyPicker)
        end

        function KeyPicker:DoClick()
            if ParentObj.Type == 'Toggle' and KeyPicker.SyncToggleState then
                ParentObj:SetValue(not ParentObj.Value)
            end

            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)
        end

        local Picking = false;

        PickOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Picking = true;

                DisplayLabel.Text = '';

                local Break;
                local Text = '';

                task.spawn(function()
                    while (not Break) do
                        if Text == '...' then
                            Text = '';
                        end;

                        Text = Text .. '.';
                        DisplayLabel.Text = Text;

                        wait(0.4);
                    end;
                end);

                wait(0.2);

                local Event;
                Event = InputService.InputBegan:Connect(function(Input)
                    local Key;

                    if Input.UserInputType == Enum.UserInputType.Keyboard then
                        Key = Input.KeyCode.Name;
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        Key = 'MB1';
                    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
                        Key = 'MB2';
                    end;

                    Break = true;
                    Picking = false;

                    DisplayLabel.Text = Key;
                    KeyPicker.Value = Key;

                    Library:SafeCallback(KeyPicker.ChangedCallback, Input.KeyCode or Input.UserInputType)
                    Library:SafeCallback(KeyPicker.Changed, Input.KeyCode or Input.UserInputType)

                    Library:AttemptSave();

                    Event:Disconnect();
                end);
            elseif Input.UserInputType == Enum.UserInputType.MouseButton2 and not Library:MouseIsOverOpenedFrame() then
                ModeSelectOuter.Visible = true;
            end;
        end);

        Library:GiveSignal(InputService.InputBegan:Connect(function(Input)
            if (not Picking) then
                if KeyPicker.Mode == 'Toggle' then
                    local Key = KeyPicker.Value;

                    if Key == 'MB1' or Key == 'MB2' then
                        if Key == 'MB1' and Input.UserInputType == Enum.UserInputType.MouseButton1
                        or Key == 'MB2' and Input.UserInputType == Enum.UserInputType.MouseButton2 then
                            KeyPicker.Toggled = not KeyPicker.Toggled
                            KeyPicker:DoClick()
                        end;
                    elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                        if Input.KeyCode.Name == Key then
                            KeyPicker.Toggled = not KeyPicker.Toggled;
                            KeyPicker:DoClick()
                        end;
                    end;
                end;

                KeyPicker:Update();
            end;

            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ModeSelectOuter.AbsolutePosition, ModeSelectOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    ModeSelectOuter.Visible = false;
                end;
            end;
        end))

        Library:GiveSignal(InputService.InputEnded:Connect(function(Input)
            if (not Picking) then
                KeyPicker:Update();
            end;
        end))

        KeyPicker:Update();

        Options[Idx] = KeyPicker;

        return self;
    end;

    BaseAddons.__index = Funcs;
    BaseAddons.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

local BaseGroupbox = {};

do
    local Funcs = {};

    function Funcs:AddBlank(Size)
        local Groupbox = self;
        local Container = Groupbox.Container;

        Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, Size);
            ZIndex = 1;
            Parent = Container;
        });
    end;

    function Funcs:AddLabel(Text, DoesWrap)
        local Label = {};

        local Groupbox = self;
        local Container = Groupbox.Container;

        local TextLabel = Library:CreateLabel({
            Size = UDim2.new(1, -4, 0, 15);
            TextSize = 14;
            Text = Text;
            TextWrapped = DoesWrap or false,
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        if DoesWrap then
            local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
            TextLabel.Size = UDim2.new(1, -4, 0, Y)
        else
            Library:Create('UIListLayout', {
                Padding = UDim.new(0, 4);
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Right;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TextLabel;
            });
        end

        Label.TextLabel = TextLabel;
        Label.Container = Container;

        function Label:SetText(Text)
            TextLabel.Text = Text

            if DoesWrap then
                local Y = select(2, Library:GetTextBounds(Text, Library.Font, 14, Vector2.new(TextLabel.AbsoluteSize.X, math.huge)))
                TextLabel.Size = UDim2.new(1, -4, 0, Y)
            end

            Groupbox:Resize();
        end

        if (not DoesWrap) then
            setmetatable(Label, BaseAddons);
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Label;
    end;

    function Funcs:AddButton(...)
        -- TODO: Eventually redo this
        local Button = {};
        local function ProcessButtonParams(Class, Obj, ...)
            local Props = select(1, ...)
            if type(Props) == 'table' then
                Obj.Text = Props.Text
                Obj.Func = Props.Func
                Obj.DoubleClick = Props.DoubleClick
                Obj.Tooltip = Props.Tooltip
            else
                Obj.Text = select(1, ...)
                Obj.Func = select(2, ...)
            end

            assert(type(Obj.Func) == 'function', 'AddButton: `Func` callback is missing.');
        end

        ProcessButtonParams('Button', Button, ...)

        local Groupbox = self;
        local Container = Groupbox.Container;

        local function CreateBaseButton(Button)
            local Outer = Library:Create('Frame', {
                BackgroundColor3 = Library.ToggleOffColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, -4, 0, 22);
                ZIndex = 5;
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, 5); Parent = Outer });

            local Inner = Library:Create('Frame', {
                BackgroundColor3 = Library.ToggleOffColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = Outer;
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, 5); Parent = Inner });
            Library:AddToRegistry(Inner, { BackgroundColor3 = 'ToggleOffColor' });

            local Label = Library:Create('TextLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 1, 0);
                Font = Library.Font;
                TextColor3 = Library.FontColor;
                TextSize = 13;
                Text = Button.Text;
                TextStrokeTransparency = 1;
                ZIndex = 7;
                Parent = Inner;
            });
            Library:Create('UIStroke', { Color = Color3.new(0,0,0); Thickness = 1; LineJoinMode = Enum.LineJoinMode.Miter; Parent = Label });
            Library:AddToRegistry(Label, { TextColor3 = 'FontColor' });

            -- Hover: lighten button bg
            Outer.MouseEnter:Connect(function()
                TweenService:Create(Inner, TweenInfo.new(0.1), { BackgroundColor3 = Library.NavActiveColor }):Play()
            end)
            Outer.MouseLeave:Connect(function()
                TweenService:Create(Inner, TweenInfo.new(0.1), { BackgroundColor3 = Library.ToggleOffColor }):Play()
            end)

            Library:AddToRegistry(Outer, { BorderColor3 = 'Black' });

            return Outer, Inner, Label
        end

        local function InitEvents(Button)
            local function WaitForEvent(event, timeout, validator)
                local bindable = Instance.new('BindableEvent')
                local connection = event:Once(function(...)

                    if type(validator) == 'function' and validator(...) then
                        bindable:Fire(true)
                    else
                        bindable:Fire(false)
                    end
                end)
                task.delay(timeout, function()
                    connection:disconnect()
                    bindable:Fire(false)
                end)
                return bindable.Event:Wait()
            end

            local function ValidateClick(Input)
                if Library:MouseIsOverOpenedFrame() then
                    return false
                end

                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                    return false
                end

                return true
            end

            Button.Outer.InputBegan:Connect(function(Input)
                if not ValidateClick(Input) then return end
                if Button.Locked then return end

                if Button.DoubleClick then
                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'AccentColor' })

                    Button.Label.TextColor3 = Library.AccentColor
                    Button.Label.Text = 'Are you sure?'
                    Button.Locked = true

                    local clicked = WaitForEvent(Button.Outer.InputBegan, 0.5, ValidateClick)

                    Library:RemoveFromRegistry(Button.Label)
                    Library:AddToRegistry(Button.Label, { TextColor3 = 'FontColor' })

                    Button.Label.TextColor3 = Library.FontColor
                    Button.Label.Text = Button.Text
                    task.defer(rawset, Button, 'Locked', false)

                    if clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    return
                end

                Library:SafeCallback(Button.Func);
            end)
        end

        Button.Outer, Button.Inner, Button.Label = CreateBaseButton(Button)
        Button.Outer.Parent = Container

        InitEvents(Button)

        function Button:AddTooltip(tooltip)
            if type(tooltip) == 'string' then
                Library:AddToolTip(tooltip, self.Outer)
            end
            return self
        end


        function Button:AddButton(...)
            local SubButton = {}

            ProcessButtonParams('SubButton', SubButton, ...)

            self.Outer.Size = UDim2.new(0.5, -2, 0, 20)

            SubButton.Outer, SubButton.Inner, SubButton.Label = CreateBaseButton(SubButton)

            SubButton.Outer.Position = UDim2.new(1, 3, 0, 0)
            SubButton.Outer.Size = UDim2.fromOffset(self.Outer.AbsoluteSize.X - 2, self.Outer.AbsoluteSize.Y)
            SubButton.Outer.Parent = self.Outer

            function SubButton:AddTooltip(tooltip)
                if type(tooltip) == 'string' then
                    Library:AddToolTip(tooltip, self.Outer)
                end
                return SubButton
            end

            if type(SubButton.Tooltip) == 'string' then
                SubButton:AddTooltip(SubButton.Tooltip)
            end

            InitEvents(SubButton)
            return SubButton
        end

        if type(Button.Tooltip) == 'string' then
            Button:AddTooltip(Button.Tooltip)
        end

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        return Button;
    end;

    function Funcs:AddDivider()
        local Groupbox = self;
        local Container = self.Container

        local Divider = {
            Type = 'Divider',
        }

        Groupbox:AddBlank(2);
        local DividerOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.OutlineColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 1);
            ZIndex = 5;
            Parent = Container;
        });
        Library:AddToRegistry(DividerOuter, { BackgroundColor3 = 'OutlineColor' });

        local DividerInner = DividerOuter; -- kept for compat

        Groupbox:AddBlank(6);
        Groupbox:Resize();
    end

    function Funcs:AddInput(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Textbox = {
            Value = Info.Default or '';
            Numeric = Info.Numeric or false;
            Finished = Info.Finished or false;
            Type = 'Input';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local InputLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 0, 15);
            TextSize = 14;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 5;
            Parent = Container;
        });

        Groupbox:AddBlank(1);

        local TextBoxOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.ToggleOffColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, -4, 0, 22);
            ZIndex = 5;
            Parent = Container;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 5); Parent = TextBoxOuter });
        Library:AddToRegistry(TextBoxOuter, { BackgroundColor3 = 'ToggleOffColor' });

        local TextBoxInner = Library:Create('Frame', {
            BackgroundColor3 = Library.ToggleOffColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = TextBoxOuter;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 5); Parent = TextBoxInner });
        Library:AddToRegistry(TextBoxInner, { BackgroundColor3 = 'ToggleOffColor' });

        Library:OnHighlight(TextBoxOuter, TextBoxOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, TextBoxOuter)
        end

        -- NL: no gradient on textbox

        local Container = Library:Create('Frame', {
            BackgroundTransparency = 1;
            ClipsDescendants = true;

            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);

            ZIndex = 7;
            Parent = TextBoxInner;
        })

        local Box = Library:Create('TextBox', {
            BackgroundTransparency = 1;

            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.fromScale(5, 1),

            Font = Library.Font;
            PlaceholderColor3 = Color3.fromRGB(190, 190, 190);
            PlaceholderText = Info.Placeholder or '';

            Text = Info.Default or '';
            TextColor3 = Library.FontColor;
            TextSize = 14;
            TextStrokeTransparency = 0;
            TextXAlignment = Enum.TextXAlignment.Left;

            ZIndex = 7;
            Parent = Container;
        });

        Library:ApplyTextStroke(Box);

        function Textbox:SetValue(Text)
            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength);
            end;

            if Textbox.Numeric then
                if (not tonumber(Text)) and Text:len() > 0 then
                    Text = Textbox.Value
                end
            end

            Textbox.Value = Text;
            Box.Text = Text;

            Library:SafeCallback(Textbox.Callback, Textbox.Value);
            Library:SafeCallback(Textbox.Changed, Textbox.Value);
        end;

        if Textbox.Finished then
            Box.FocusLost:Connect(function(enter)
                if not enter then return end

                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end)
        else
            Box:GetPropertyChangedSignal('Text'):Connect(function()
                Textbox:SetValue(Box.Text);
                Library:AttemptSave();
            end);
        end

        -- https://devforum.roblox.com/t/how-to-make-textboxes-follow-current-cursor-position/1368429/6
        -- thank you nicemike40 :)

        local function Update()
            local PADDING = 2
            local reveal = Container.AbsoluteSize.X

            if not Box:IsFocused() or Box.TextBounds.X <= reveal - 2 * PADDING then
                -- we aren't focused, or we fit so be normal
                Box.Position = UDim2.new(0, PADDING, 0, 0)
            else
                -- we are focused and don't fit, so adjust position
                local cursor = Box.CursorPosition
                if cursor ~= -1 then
                    -- calculate pixel width of text from start to cursor
                    local subtext = string.sub(Box.Text, 1, cursor-1)
                    local width = TextService:GetTextSize(subtext, Box.TextSize, Box.Font, Vector2.new(math.huge, math.huge)).X

                    -- check if we're inside the box with the cursor
                    local currentCursorPos = Box.Position.X.Offset + width

                    -- adjust if necessary
                    if currentCursorPos < PADDING then
                        Box.Position = UDim2.fromOffset(PADDING-width, 0)
                    elseif currentCursorPos > reveal - PADDING - 1 then
                        Box.Position = UDim2.fromOffset(reveal-width-PADDING-1, 0)
                    end
                end
            end
        end

        task.spawn(Update)

        Box:GetPropertyChangedSignal('Text'):Connect(Update)
        Box:GetPropertyChangedSignal('CursorPosition'):Connect(Update)
        Box.FocusLost:Connect(Update)
        Box.Focused:Connect(Update)

        Library:AddToRegistry(Box, {
            TextColor3 = 'FontColor';
        });

        function Textbox:OnChanged(Func)
            Textbox.Changed = Func;
            Func(Textbox.Value);
        end;

        Groupbox:AddBlank(5);
        Groupbox:Resize();

        Options[Idx] = Textbox;

        return Textbox;
    end;

    function Funcs:AddToggle(Idx, Info)
        assert(Info.Text, 'AddInput: Missing `Text` string.')

        local Toggle = {
            Value = Info.Default or false;
            Type = 'Toggle';

            Callback = Info.Callback or function(Value) end;
            Addons = {},
            Risky = Info.Risky,
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        -- ── NL-style row: label on left, pill switch on right ──
        -- Outer row frame (full width, 20px tall)
        local ToggleOuter = Library:Create('Frame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(1, -4, 0, 20);
            ZIndex = 5;
            Parent = Container;
        });

        -- Invisible inner (kept for registry compat)
        local ToggleInner = Library:Create('Frame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = ToggleOuter;
        });

        Library:AddToRegistry(ToggleInner, {
            BackgroundColor3 = 'MainColor';
            BorderColor3 = 'OutlineColor';
        });

        -- Text label (left side)
        local ToggleLabel = Library:CreateLabel({
            Size = UDim2.new(1, -46, 1, 0);
            Position = UDim2.new(0, 0, 0, 0);
            TextSize = 13;
            Text = Info.Text;
            TextXAlignment = Enum.TextXAlignment.Left;
            ZIndex = 6;
            Parent = ToggleInner;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 4);
            FillDirection = Enum.FillDirection.Horizontal;
            HorizontalAlignment = Enum.HorizontalAlignment.Right;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = ToggleLabel;
        });

        -- Pill track (36x18 pill on the right)
        local PillTrack = Library:Create('Frame', {
            AnchorPoint = Vector2.new(1, 0.5);
            Position = UDim2.new(1, 0, 0.5, 0);
            Size = UDim2.new(0, 36, 0, 18);
            BackgroundColor3 = Library.ToggleOffColor;
            BorderSizePixel = 0;
            ZIndex = 7;
            Parent = ToggleInner;
        });

        Library:Create('UICorner', {
            CornerRadius = UDim.new(1, 0);
            Parent = PillTrack;
        });

        Library:AddToRegistry(PillTrack, {
            BackgroundColor3 = 'ToggleOffColor';
        });

        -- Pill knob (circle that slides)
        local PillKnob = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0, 0.5);
            Position = UDim2.new(0, 2, 0.5, 0);
            Size = UDim2.new(0, 14, 0, 14);
            BackgroundColor3 = Color3.fromRGB(180, 182, 210);
            BorderSizePixel = 0;
            ZIndex = 8;
            Parent = PillTrack;
        });

        Library:Create('UICorner', {
            CornerRadius = UDim.new(1, 0);
            Parent = PillKnob;
        });

        -- Clickable region
        local ToggleRegion = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 9;
            Parent = ToggleOuter;
        });

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, ToggleRegion)
        end

        function Toggle:UpdateColors()
            Toggle:Display();
        end;

        function Toggle:Display()
            -- Animate pill
            local onPos  = UDim2.new(0, 20, 0.5, 0)
            local offPos = UDim2.new(0, 2,  0.5, 0)
            local onClr  = Library.ToggleOnColor
            local offClr = Library.ToggleOffColor
            local knobOnClr  = Color3.fromRGB(255, 255, 255)
            local knobOffClr = Color3.fromRGB(180, 182, 210)

            TweenService:Create(PillKnob, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                Position = Toggle.Value and onPos or offPos;
                BackgroundColor3 = Toggle.Value and knobOnClr or knobOffClr;
            }):Play();
            TweenService:Create(PillTrack, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                BackgroundColor3 = Toggle.Value and onClr or offClr;
            }):Play();

            Library.RegistryMap[ToggleInner].Properties.BackgroundColor3 = Toggle.Value and 'AccentColor' or 'MainColor';
            Library.RegistryMap[ToggleInner].Properties.BorderColor3 = Toggle.Value and 'AccentColorDark' or 'OutlineColor';
        end;

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func;
            Func(Toggle.Value);
        end;

        function Toggle:SetValue(Bool)
            Bool = (not not Bool);

            Toggle.Value = Bool;
            Toggle:Display();

            for _, Addon in next, Toggle.Addons do
                if Addon.Type == 'KeyPicker' and Addon.SyncToggleState then
                    Addon.Toggled = Bool
                    Addon:Update()
                end
            end

            Library:SafeCallback(Toggle.Callback, Toggle.Value);
            Library:SafeCallback(Toggle.Changed, Toggle.Value);
            Library:UpdateDependencyBoxes();
        end;

        ToggleRegion.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                Toggle:SetValue(not Toggle.Value) -- Why was it not like this from the start?
                Library:AttemptSave();
            end;
        end);

        if Toggle.Risky then
            Library:RemoveFromRegistry(ToggleLabel)
            ToggleLabel.TextColor3 = Library.RiskColor
            Library:AddToRegistry(ToggleLabel, { TextColor3 = 'RiskColor' })
        end

        Toggle:Display();
        Groupbox:AddBlank(Info.BlankSize or 4);
        Groupbox:Resize();

        Toggle.TextLabel = ToggleLabel;
        Toggle.Container = Container;
        setmetatable(Toggle, BaseAddons);

        Toggles[Idx] = Toggle;

        Library:UpdateDependencyBoxes();

        return Toggle;
    end;

    function Funcs:AddSlider(Idx, Info)
        assert(Info.Default, 'AddSlider: Missing default value.');
        assert(Info.Text, 'AddSlider: Missing slider text.');
        assert(Info.Min, 'AddSlider: Missing minimum value.');
        assert(Info.Max, 'AddSlider: Missing maximum value.');
        assert(Info.Rounding, 'AddSlider: Missing rounding value.');

        local Slider = {
            Value = Info.Default;
            Min = Info.Min;
            Max = Info.Max;
            Rounding = Info.Rounding;
            MaxSize = 232;
            Type = 'Slider';
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        if not Info.Compact then
            Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        local SliderOuter = Library:Create('Frame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(1, -4, 0, 13);
            ZIndex = 5;
            Parent = Container;
        });

        Library:AddToRegistry(SliderOuter, {
            BorderColor3 = 'Black';
        });

        -- NL-style: dark track
        local SliderInner = Library:Create('Frame', {
            BackgroundColor3 = Library.ToggleOffColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 5);
            Position = UDim2.new(0, 0, 0.5, -2);
            ZIndex = 6;
            Parent = SliderOuter;
        });

        Library:Create('UICorner', {
            CornerRadius = UDim.new(1, 0);
            Parent = SliderInner;
        });

        Library:AddToRegistry(SliderInner, {
            BackgroundColor3 = 'ToggleOffColor';
            BorderColor3 = 'OutlineColor';
        });

        -- NL-style: blue fill
        local Fill = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(0, 0, 1, 0);
            ZIndex = 7;
            Parent = SliderInner;
        });

        Library:Create('UICorner', {
            CornerRadius = UDim.new(1, 0);
            Parent = Fill;
        });

        Library:AddToRegistry(Fill, {
            BackgroundColor3 = 'AccentColor';
            BorderColor3 = 'AccentColorDark';
        });

        -- Knob dot on the slider
        local SliderKnob = Library:Create('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            Position = UDim2.new(0, 0, 0.5, 0);
            Size = UDim2.new(0, 11, 0, 11);
            BackgroundColor3 = Color3.fromRGB(255, 255, 255);
            BorderSizePixel = 0;
            ZIndex = 8;
            Parent = SliderInner;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0); Parent = SliderKnob });

        -- Invisible right border hider (kept for compat)
        local HideBorderRight = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Position = UDim2.new(1, 0, 0, 0);
            Size = UDim2.new(0, 1, 1, 0);
            ZIndex = 8;
            Parent = Fill;
        });

        Library:AddToRegistry(HideBorderRight, {
            BackgroundColor3 = 'AccentColor';
        });

        local DisplayLabel = Library:CreateLabel({
            Size = UDim2.new(1, 0, 1, 0);
            TextSize = 14;
            Text = 'Infinite';
            ZIndex = 9;
            Parent = SliderInner;
        });

        Library:OnHighlight(SliderOuter, SliderOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, SliderOuter)
        end

        function Slider:UpdateColors()
            Fill.BackgroundColor3 = Library.AccentColor;
            Fill.BorderColor3 = Library.AccentColorDark;
        end;

        function Slider:Display()
            local Suffix = Info.Suffix or '';

            if Info.Compact then
                DisplayLabel.Text = Info.Text .. ': ' .. Slider.Value .. Suffix
            elseif Info.HideMax then
                DisplayLabel.Text = string.format('%s', Slider.Value .. Suffix)
            else
                DisplayLabel.Text = string.format('%s/%s', Slider.Value .. Suffix, Slider.Max .. Suffix);
            end

            local X = math.ceil(Library:MapValue(Slider.Value, Slider.Min, Slider.Max, 0, Slider.MaxSize));
            Fill.Size = UDim2.new(0, X, 1, 0);
            SliderKnob.Position = UDim2.new(0, math.clamp(X, 0, Slider.MaxSize), 0.5, 0);

            HideBorderRight.Visible = not (X == Slider.MaxSize or X == 0);
        end;

        function Slider:OnChanged(Func)
            Slider.Changed = Func;
            Func(Slider.Value);
        end;

        local function Round(Value)
            if Slider.Rounding == 0 then
                return math.floor(Value);
            end;


            return tonumber(string.format('%.' .. Slider.Rounding .. 'f', Value))
        end;

        function Slider:GetValueFromXOffset(X)
            return Round(Library:MapValue(X, 0, Slider.MaxSize, Slider.Min, Slider.Max));
        end;

        function Slider:SetValue(Str)
            local Num = tonumber(Str);

            if (not Num) then
                return;
            end;

            Num = math.clamp(Num, Slider.Min, Slider.Max);

            Slider.Value = Num;
            Slider:Display();

            Library:SafeCallback(Slider.Callback, Slider.Value);
            Library:SafeCallback(Slider.Changed, Slider.Value);
        end;

        SliderInner.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                local mPos = Mouse.X;
                local gPos = Fill.Size.X.Offset;
                local Diff = mPos - (Fill.AbsolutePosition.X + gPos);

                while InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
                    local nMPos = Mouse.X;
                    local nX = math.clamp(gPos + (nMPos - mPos) + Diff, 0, Slider.MaxSize);

                    local nValue = Slider:GetValueFromXOffset(nX);
                    local OldValue = Slider.Value;
                    Slider.Value = nValue;

                    Slider:Display();

                    if nValue ~= OldValue then
                        Library:SafeCallback(Slider.Callback, Slider.Value);
                        Library:SafeCallback(Slider.Changed, Slider.Value);
                    end;

                    RenderStepped:Wait();
                end;

                Library:AttemptSave();
            end;
        end);

        Slider:Display();
        Groupbox:AddBlank(Info.BlankSize or 6);
        Groupbox:Resize();

        Options[Idx] = Slider;

        return Slider;
    end;

    function Funcs:AddDropdown(Idx, Info)
        if Info.SpecialType == 'Player' then
            Info.Values = GetPlayersString();
            Info.AllowNull = true;
        elseif Info.SpecialType == 'Team' then
            Info.Values = GetTeamsString();
            Info.AllowNull = true;
        end;

        assert(Info.Values, 'AddDropdown: Missing dropdown value list.');
        assert(Info.AllowNull or Info.Default, 'AddDropdown: Missing default value. Pass `AllowNull` as true if this was intentional.')

        if (not Info.Text) then
            Info.Compact = true;
        end;

        local Dropdown = {
            Values = Info.Values;
            Value = Info.Multi and {};
            Multi = Info.Multi;
            Type = 'Dropdown';
            SpecialType = Info.SpecialType; -- can be either 'Player' or 'Team'
            Callback = Info.Callback or function(Value) end;
        };

        local Groupbox = self;
        local Container = Groupbox.Container;

        local RelativeOffset = 0;

        if not Info.Compact then
            local DropdownLabel = Library:CreateLabel({
                Size = UDim2.new(1, 0, 0, 10);
                TextSize = 14;
                Text = Info.Text;
                TextXAlignment = Enum.TextXAlignment.Left;
                TextYAlignment = Enum.TextYAlignment.Bottom;
                ZIndex = 5;
                Parent = Container;
            });

            Groupbox:AddBlank(3);
        end

        for _, Element in next, Container:GetChildren() do
            if not Element:IsA('UIListLayout') then
                RelativeOffset = RelativeOffset + Element.Size.Y.Offset;
            end;
        end;

        local DropdownOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.ToggleOffColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, -4, 0, 22);
            ZIndex = 5;
            Parent = Container;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 5); Parent = DropdownOuter });
        Library:AddToRegistry(DropdownOuter, { BackgroundColor3 = 'ToggleOffColor' });

        local DropdownInner = Library:Create('Frame', {
            BackgroundColor3 = Library.ToggleOffColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 6;
            Parent = DropdownOuter;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 5); Parent = DropdownInner });
        Library:AddToRegistry(DropdownInner, { BackgroundColor3 = 'ToggleOffColor' });

        -- NL: no gradient on dropdowns        local DropdownArrow = Library:Create('ImageLabel', {
            AnchorPoint = Vector2.new(0, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(1, -16, 0.5, 0);
            Size = UDim2.new(0, 12, 0, 12);
            Image = 'http://www.roblox.com/asset/?id=6282522798';
            ZIndex = 8;
            Parent = DropdownInner;
        });

        local ItemList = Library:CreateLabel({
            Position = UDim2.new(0, 5, 0, 0);
            Size = UDim2.new(1, -5, 1, 0);
            TextSize = 14;
            Text = '--';
            TextXAlignment = Enum.TextXAlignment.Left;
            TextWrapped = true;
            ZIndex = 7;
            Parent = DropdownInner;
        });

        Library:OnHighlight(DropdownOuter, DropdownOuter,
            { BorderColor3 = 'AccentColor' },
            { BorderColor3 = 'Black' }
        );

        if type(Info.Tooltip) == 'string' then
            Library:AddToolTip(Info.Tooltip, DropdownOuter)
        end

        local MAX_DROPDOWN_ITEMS = 8;

        local ListOuter = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            ZIndex = 20;
            Visible = false;
            Parent = ScreenGui;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = ListOuter });
        Library:Create('UIStroke', { Color = Library.OutlineColor; Thickness = 1; Parent = ListOuter });
        Library:AddToRegistry(ListOuter, { BackgroundColor3 = 'MainColor' });

        local function RecalculateListPosition()
            ListOuter.Position = UDim2.fromOffset(DropdownOuter.AbsolutePosition.X, DropdownOuter.AbsolutePosition.Y + DropdownOuter.Size.Y.Offset + 1);
        end;

        local function RecalculateListSize(YSize)
            ListOuter.Size = UDim2.fromOffset(DropdownOuter.AbsoluteSize.X, YSize or (MAX_DROPDOWN_ITEMS * 20 + 2))
        end;

        RecalculateListPosition();
        RecalculateListSize();

        DropdownOuter:GetPropertyChangedSignal('AbsolutePosition'):Connect(RecalculateListPosition);

        local ListInner = Library:Create('Frame', {
            BackgroundColor3 = Library.MainColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListOuter;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = ListInner });
        Library:AddToRegistry(ListInner, { BackgroundColor3 = 'MainColor' });

        local Scrolling = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            CanvasSize = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            ZIndex = 21;
            Parent = ListInner;

            TopImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',
            BottomImage = 'rbxasset://textures/ui/Scroll/scroll-middle.png',

            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Library.AccentColor,
        });

        Library:AddToRegistry(Scrolling, {
            ScrollBarImageColor3 = 'AccentColor'
        })

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 0);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Scrolling;
        });

        function Dropdown:Display()
            local Values = Dropdown.Values;
            local Str = '';

            if Info.Multi then
                for Idx, Value in next, Values do
                    if Dropdown.Value[Value] then
                        Str = Str .. Value .. ', ';
                    end;
                end;

                Str = Str:sub(1, #Str - 2);
            else
                Str = Dropdown.Value or '';
            end;

            ItemList.Text = (Str == '' and '--' or Str);
        end;

        function Dropdown:GetActiveValues()
            if Info.Multi then
                local T = {};

                for Value, Bool in next, Dropdown.Value do
                    table.insert(T, Value);
                end;

                return T;
            else
                return Dropdown.Value and 1 or 0;
            end;
        end;

        function Dropdown:BuildDropdownList()
            local Values = Dropdown.Values;
            local Buttons = {};

            for _, Element in next, Scrolling:GetChildren() do
                if not Element:IsA('UIListLayout') then
                    Element:Destroy();
                end;
            end;

            local Count = 0;

            for Idx, Value in next, Values do
                local Table = {};

                Count = Count + 1;

                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Library.MainColor;
                    BorderColor3 = Library.OutlineColor;
                    BorderMode = Enum.BorderMode.Middle;
                    Size = UDim2.new(1, -1, 0, 20);
                    ZIndex = 23;
                    Active = true,
                    Parent = Scrolling;
                });

                Library:AddToRegistry(Button, {
                    BackgroundColor3 = 'MainColor';
                    BorderColor3 = 'OutlineColor';
                });

                local ButtonLabel = Library:CreateLabel({
                    Active = false;
                    Size = UDim2.new(1, -6, 1, 0);
                    Position = UDim2.new(0, 6, 0, 0);
                    TextSize = 14;
                    Text = Value;
                    TextXAlignment = Enum.TextXAlignment.Left;
                    ZIndex = 25;
                    Parent = Button;
                });

                Library:OnHighlight(Button, Button,
                    { BorderColor3 = 'AccentColor', ZIndex = 24 },
                    { BorderColor3 = 'OutlineColor', ZIndex = 23 }
                );

                local Selected;

                if Info.Multi then
                    Selected = Dropdown.Value[Value];
                else
                    Selected = Dropdown.Value == Value;
                end;

                function Table:UpdateButton()
                    if Info.Multi then
                        Selected = Dropdown.Value[Value];
                    else
                        Selected = Dropdown.Value == Value;
                    end;

                    ButtonLabel.TextColor3 = Selected and Library.AccentColor or Library.FontColor;
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = Selected and 'AccentColor' or 'FontColor';
                end;

                ButtonLabel.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                        local Try = not Selected;

                        if Dropdown:GetActiveValues() == 1 and (not Try) and (not Info.AllowNull) then
                        else
                            if Info.Multi then
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value[Value] = true;
                                else
                                    Dropdown.Value[Value] = nil;
                                end;
                            else
                                Selected = Try;

                                if Selected then
                                    Dropdown.Value = Value;
                                else
                                    Dropdown.Value = nil;
                                end;

                                for _, OtherButton in next, Buttons do
                                    OtherButton:UpdateButton();
                                end;
                            end;

                            Table:UpdateButton();
                            Dropdown:Display();

                            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
                            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);

                            Library:AttemptSave();
                        end;
                    end;
                end);

                Table:UpdateButton();
                Dropdown:Display();

                Buttons[Button] = Table;
            end;

            Scrolling.CanvasSize = UDim2.fromOffset(0, (Count * 20) + 1);

            local Y = math.clamp(Count * 20, 0, MAX_DROPDOWN_ITEMS * 20) + 1;
            RecalculateListSize(Y);
        end;

        function Dropdown:SetValues(NewValues)
            if NewValues then
                Dropdown.Values = NewValues;
            end;

            Dropdown:BuildDropdownList();
        end;

        function Dropdown:OpenDropdown()
            ListOuter.Visible = true;
            Library.OpenedFrames[ListOuter] = true;
            DropdownArrow.Rotation = 180;
        end;

        function Dropdown:CloseDropdown()
            ListOuter.Visible = false;
            Library.OpenedFrames[ListOuter] = nil;
            DropdownArrow.Rotation = 0;
        end;

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func;
            Func(Dropdown.Value);
        end;

        function Dropdown:SetValue(Val)
            if Dropdown.Multi then
                local nTable = {};

                for Value, Bool in next, Val do
                    if table.find(Dropdown.Values, Value) then
                        nTable[Value] = true
                    end;
                end;

                Dropdown.Value = nTable;
            else
                if (not Val) then
                    Dropdown.Value = nil;
                elseif table.find(Dropdown.Values, Val) then
                    Dropdown.Value = Val;
                end;
            end;

            Dropdown:BuildDropdownList();

            Library:SafeCallback(Dropdown.Callback, Dropdown.Value);
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value);
        end;

        DropdownOuter.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                if ListOuter.Visible then
                    Dropdown:CloseDropdown();
                else
                    Dropdown:OpenDropdown();
                end;
            end;
        end);

        InputService.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                local AbsPos, AbsSize = ListOuter.AbsolutePosition, ListOuter.AbsoluteSize;

                if Mouse.X < AbsPos.X or Mouse.X > AbsPos.X + AbsSize.X
                    or Mouse.Y < (AbsPos.Y - 20 - 1) or Mouse.Y > AbsPos.Y + AbsSize.Y then

                    Dropdown:CloseDropdown();
                end;
            end;
        end);

        Dropdown:BuildDropdownList();
        Dropdown:Display();

        local Defaults = {}

        if type(Info.Default) == 'string' then
            local Idx = table.find(Dropdown.Values, Info.Default)
            if Idx then
                table.insert(Defaults, Idx)
            end
        elseif type(Info.Default) == 'table' then
            for _, Value in next, Info.Default do
                local Idx = table.find(Dropdown.Values, Value)
                if Idx then
                    table.insert(Defaults, Idx)
                end
            end
        elseif type(Info.Default) == 'number' and Dropdown.Values[Info.Default] ~= nil then
            table.insert(Defaults, Info.Default)
        end

        if next(Defaults) then
            for i = 1, #Defaults do
                local Index = Defaults[i]
                if Info.Multi then
                    Dropdown.Value[Dropdown.Values[Index]] = true
                else
                    Dropdown.Value = Dropdown.Values[Index];
                end

                if (not Info.Multi) then break end
            end

            Dropdown:BuildDropdownList();
            Dropdown:Display();
        end

        Groupbox:AddBlank(Info.BlankSize or 5);
        Groupbox:Resize();

        Options[Idx] = Dropdown;

        return Dropdown;
    end;

    function Funcs:AddDependencyBox()
        local Depbox = {
            Dependencies = {};
        };
        
        local Groupbox = self;
        local Container = Groupbox.Container;

        local Holder = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 0);
            Visible = false;
            Parent = Container;
        });

        local Frame = Library:Create('Frame', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 1, 0);
            Visible = true;
            Parent = Holder;
        });

        local Layout = Library:Create('UIListLayout', {
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            Parent = Frame;
        });

        function Depbox:Resize()
            Holder.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y);
            Groupbox:Resize();
        end;

        Layout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
            Depbox:Resize();
        end);

        Holder:GetPropertyChangedSignal('Visible'):Connect(function()
            Depbox:Resize();
        end);

        function Depbox:Update()
            for _, Dependency in next, Depbox.Dependencies do
                local Elem = Dependency[1];
                local Value = Dependency[2];

                if Elem.Type == 'Toggle' and Elem.Value ~= Value then
                    Holder.Visible = false;
                    Depbox:Resize();
                    return;
                end;
            end;

            Holder.Visible = true;
            Depbox:Resize();
        end;

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in next, Dependencies do
                assert(type(Dependency) == 'table', 'SetupDependencies: Dependency is not of type `table`.');
                assert(Dependency[1], 'SetupDependencies: Dependency is missing element argument.');
                assert(Dependency[2] ~= nil, 'SetupDependencies: Dependency is missing value argument.');
            end;

            Depbox.Dependencies = Dependencies;
            Depbox:Update();
        end;

        Depbox.Container = Frame;

        setmetatable(Depbox, BaseGroupbox);

        table.insert(Library.DependencyBoxes, Depbox);

        return Depbox;
    end;

    BaseGroupbox.__index = Funcs;
    BaseGroupbox.__namecall = function(Table, Key, ...)
        return Funcs[Key](...);
    end;
end;

-- < Create other UI elements >
do
    Library.NotificationArea = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 40);
        Size = UDim2.new(0, 300, 0, 200);
        ZIndex = 100;
        Parent = ScreenGui;
    });

    Library:Create('UIListLayout', {
        Padding = UDim.new(0, 4);
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = Library.NotificationArea;
    });

    -- ── NL-style watermark ───────────────────────────────────────────────
    local WatermarkOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 10, 0, 10);
        Size = UDim2.new(0, 213, 0, 24);
        ZIndex = 200;
        Visible = false;
        Parent = ScreenGui;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = WatermarkOuter });
    Library:Create('UIStroke', { Color = Library.OutlineColor; Thickness = 1; Parent = WatermarkOuter });
    Library:AddToRegistry(WatermarkOuter, { BackgroundColor3 = 'MainColor' });

    -- Blue left accent pill
    local WatermarkAccent = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(0, 3, 0, 14);
        AnchorPoint = Vector2.new(0, 0.5);
        Position = UDim2.new(0, 6, 0.5, 0);
        ZIndex = 201;
        Parent = WatermarkOuter;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(1, 0); Parent = WatermarkAccent });
    Library:AddToRegistry(WatermarkAccent, { BackgroundColor3 = 'AccentColor' });

    local WatermarkLabel = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 16, 0, 0);
        Size = UDim2.new(1, -20, 1, 0);
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 13;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextStrokeTransparency = 1;
        ZIndex = 202;
        Parent = WatermarkOuter;
    });
    Library:Create('UIStroke', { Color = Color3.new(0,0,0); Thickness = 1; LineJoinMode = Enum.LineJoinMode.Miter; Parent = WatermarkLabel });
    Library:AddToRegistry(WatermarkLabel, { TextColor3 = 'FontColor' });

    Library.Watermark = WatermarkOuter;
    Library.WatermarkText = WatermarkLabel;
    Library:MakeDraggable(Library.Watermark);

    -- ── NL-style keybind frame ───────────────────────────────────────────
    local KeybindOuter = Library:Create('Frame', {
        AnchorPoint = Vector2.new(0, 0.5);
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 10, 0.5, 0);
        Size = UDim2.new(0, 180, 0, 20);
        Visible = false;
        ZIndex = 100;
        Parent = ScreenGui;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = KeybindOuter });
    Library:Create('UIStroke', { Color = Library.OutlineColor; Thickness = 1; Parent = KeybindOuter });
    Library:AddToRegistry(KeybindOuter, { BackgroundColor3 = 'MainColor' }, true);

    local KeybindInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = KeybindOuter;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = KeybindInner });
    Library:AddToRegistry(KeybindInner, { BackgroundColor3 = 'MainColor' }, true);

    -- Top accent bar (thin)
    local ColorFrame = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 2);
        ZIndex = 102;
        Parent = KeybindInner;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = ColorFrame });
    Library:AddToRegistry(ColorFrame, { BackgroundColor3 = 'AccentColor' }, true);

    local KeybindLabel = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 0, 20);
        Position = UDim2.fromOffset(8, 2);
        Font = Enum.Font.GothamBold;
        TextColor3 = Library.SectionTextColor;
        TextSize = 11;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextStrokeTransparency = 1;
        Text = 'KEYBINDS';
        ZIndex = 104;
        Parent = KeybindInner;
    });
    Library:AddToRegistry(KeybindLabel, { TextColor3 = 'SectionTextColor' }, true);

    local KeybindContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Size = UDim2.new(1, 0, 1, -20);
        Position = UDim2.new(0, 0, 0, 20);
        ZIndex = 1;
        Parent = KeybindInner;
    });

    Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = KeybindContainer;
    });

    Library:Create('UIPadding', {
        PaddingLeft = UDim.new(0, 5),
        Parent = KeybindContainer,
    })

    Library.KeybindFrame = KeybindOuter;
    Library.KeybindContainer = KeybindContainer;
    Library:MakeDraggable(KeybindOuter);
end;

function Library:SetWatermarkVisibility(Bool)
    Library.Watermark.Visible = Bool;
end;

function Library:SetWatermark(Text)
    local X, Y = Library:GetTextBounds(Text, Library.Font, 13);
    Library.Watermark.Size = UDim2.new(0, X + 32, 0, 24);
    Library:SetWatermarkVisibility(true);
    Library.WatermarkText.Text = Text;
end;

function Library:Notify(Text, Time)
    local XSize, YSize = Library:GetTextBounds(Text, Library.Font, 13);
    YSize = YSize + 10

    local NotifyOuter = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 100, 0, 10);
        Size = UDim2.new(0, 0, 0, YSize);
        ClipsDescendants = true;
        ZIndex = 100;
        Parent = Library.NotificationArea;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = NotifyOuter });
    Library:Create('UIStroke', { Color = Library.OutlineColor; Thickness = 1; Parent = NotifyOuter });
    Library:AddToRegistry(NotifyOuter, { BackgroundColor3 = 'MainColor' }, true);

    local NotifyInner = Library:Create('Frame', {
        BackgroundColor3 = Library.MainColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 101;
        Parent = NotifyOuter;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = NotifyInner });

    -- NL blue left accent bar
    local LeftColor = Library:Create('Frame', {
        BackgroundColor3 = Library.AccentColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(0, 3, 1, 0);
        ZIndex = 104;
        Parent = NotifyOuter;
    });
    Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = LeftColor });
    Library:AddToRegistry(LeftColor, { BackgroundColor3 = 'AccentColor' }, true);

    local NotifyLabel = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 12, 0, 0);
        Size = UDim2.new(1, -16, 1, 0);
        Font = Library.Font;
        TextColor3 = Library.FontColor;
        TextSize = 13;
        Text = Text;
        TextXAlignment = Enum.TextXAlignment.Left;
        TextWrapped = true;
        TextStrokeTransparency = 1;
        ZIndex = 103;
        Parent = NotifyInner;
    });
    Library:Create('UIStroke', { Color = Color3.new(0,0,0); Thickness = 1; LineJoinMode = Enum.LineJoinMode.Miter; Parent = NotifyLabel });
    Library:AddToRegistry(NotifyLabel, { TextColor3 = 'FontColor' }, true);

    pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, XSize + 30, 0, YSize), 'Out', 'Quad', 0.3, true);

    task.spawn(function()
        wait(Time or 5);
        pcall(NotifyOuter.TweenSize, NotifyOuter, UDim2.new(0, 0, 0, YSize), 'Out', 'Quad', 0.3, true);
        wait(0.3);
        NotifyOuter:Destroy();
    end);
end;

function Library:CreateWindow(...)
    local Arguments = { ... }
    local Config = { AnchorPoint = Vector2.zero }

    if type(...) == 'table' then
        Config = ...;
    else
        Config.Title = Arguments[1]
        Config.AutoShow = Arguments[2] or false;
    end

    if type(Config.Title) ~= 'string' then Config.Title = 'No title' end
    if type(Config.TabPadding) ~= 'number' then Config.TabPadding = 0 end
    if type(Config.MenuFadeTime) ~= 'number' then Config.MenuFadeTime = 0.2 end

    if typeof(Config.Position) ~= 'UDim2' then Config.Position = UDim2.fromOffset(175, 50) end
    if typeof(Config.Size) ~= 'UDim2' then Config.Size = UDim2.fromOffset(790, 530) end

    if Config.Center then
        Config.AnchorPoint = Vector2.new(0.5, 0.5)
        Config.Position = UDim2.fromScale(0.5, 0.5)
    end

    local Window = {
        Tabs = {};
    };

    -- ── Outermost shadow frame ──────────────────────────────────────────
    local Outer = Library:Create('Frame', {
        AnchorPoint = Config.AnchorPoint,
        BackgroundColor3 = Library.BackgroundColor;
        BorderSizePixel = 0;
        Position = Config.Position,
        Size = Config.Size,
        Visible = false;
        ZIndex = 1;
        Parent = ScreenGui;
    });

    Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = Outer });

    Library:Create('UIStroke', {
        Color = Library.OutlineColor;
        Thickness = 1;
        Parent = Outer;
    });

    Library:MakeDraggable(Outer, 40);

    -- ── Header bar (NL top bar) ─────────────────────────────────────────
    local Header = Library:Create('Frame', {
        BackgroundColor3 = Library.HeaderColor;
        BorderSizePixel = 0;
        Size = UDim2.new(1, 0, 0, 44);
        ZIndex = 2;
        Parent = Outer;
    });

    Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = Header });

    -- Bottom fill to square off the bottom corners of the header
    Library:Create('Frame', {
        BackgroundColor3 = Library.HeaderColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0.5, 0);
        Size = UDim2.new(1, 0, 0.5, 0);
        ZIndex = 2;
        Parent = Header;
    });

    Library:AddToRegistry(Header, { BackgroundColor3 = 'HeaderColor' });

    -- Header title (NEVERLOSE style bold white caps)
    local WindowLabel = Library:Create('TextLabel', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 18, 0, 0);
        Size = UDim2.new(0, 200, 1, 0);
        Font = Enum.Font.GothamBlack;
        TextColor3 = Color3.fromRGB(255, 255, 255);
        TextSize = 16;
        Text = (Config.Title or 'MENU'):upper();
        TextXAlignment = Enum.TextXAlignment.Left;
        TextStrokeTransparency = 1;
        ZIndex = 3;
        Parent = Header;
    });

    Library:Create('UIStroke', { Color = Color3.new(0,0,0); Thickness = 1; LineJoinMode = Enum.LineJoinMode.Miter; Parent = WindowLabel });

    -- Thin accent underline on header
    Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 1, -1);
        Size = UDim2.new(1, 0, 0, 1);
        ZIndex = 3;
        Parent = Header;
    });

    -- ── Body (below header) ─────────────────────────────────────────────
    local Body = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 44);
        Size = UDim2.new(1, 0, 1, -44);
        ZIndex = 1;
        Parent = Outer;
    });

    -- ── Left sidebar ────────────────────────────────────────────────────
    local Sidebar = Library:Create('Frame', {
        BackgroundColor3 = Library.SidebarColor;
        BorderSizePixel = 0;
        Size = UDim2.new(0, 185, 1, 0);
        ZIndex = 2;
        Parent = Body;
    });

    Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = Sidebar });

    -- Square off right side corners
    Library:Create('Frame', {
        BackgroundColor3 = Library.SidebarColor;
        BorderSizePixel = 0;
        Position = UDim2.new(1, -6, 0, 0);
        Size = UDim2.new(0, 6, 1, 0);
        ZIndex = 2;
        Parent = Sidebar;
    });

    Library:AddToRegistry(Sidebar, { BackgroundColor3 = 'SidebarColor' });

    -- Sidebar scrollable nav
    local NavScroll = Library:Create('ScrollingFrame', {
        BackgroundTransparency = 1;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0, 6);
        Size = UDim2.new(1, 0, 1, -6);
        CanvasSize = UDim2.new(0, 0, 0, 0);
        BottomImage = ''; TopImage = '';
        ScrollBarThickness = 0;
        ZIndex = 3;
        Parent = Sidebar;
    });

    local NavLayout = Library:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Vertical;
        SortOrder = Enum.SortOrder.LayoutOrder;
        Parent = NavScroll;
    });

    NavLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
        NavScroll.CanvasSize = UDim2.fromOffset(0, NavLayout.AbsoluteContentSize.Y);
    end);

    -- ── Right content area ───────────────────────────────────────────────
    local ContentArea = Library:Create('Frame', {
        BackgroundColor3 = Library.ContentColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 185, 0, 0);
        Size = UDim2.new(1, -185, 1, 0);
        ZIndex = 1;
        Parent = Body;
    });

    Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = ContentArea });

    Library:Create('Frame', {
        BackgroundColor3 = Library.ContentColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(0, 6, 1, 0);
        ZIndex = 1;
        Parent = ContentArea;
    });

    Library:AddToRegistry(ContentArea, { BackgroundColor3 = 'ContentColor' });

    -- Tab container (holds all tab frames)
    local TabContainer = Library:Create('Frame', {
        BackgroundTransparency = 1;
        Position = UDim2.new(0, 0, 0, 0);
        Size = UDim2.new(1, 0, 1, 0);
        ZIndex = 2;
        Parent = ContentArea;
    });

    -- ── Vertical divider between sidebar and content ─────────────────────
    Library:Create('Frame', {
        BackgroundColor3 = Library.OutlineColor;
        BorderSizePixel = 0;
        Position = UDim2.new(0, 184, 0, 0);
        Size = UDim2.new(0, 1, 1, 0);
        ZIndex = 3;
        Parent = Body;
    });

    local MainSectionOuter = ContentArea;
    local MainSectionInner = ContentArea;
    local TabArea = NavScroll;

    -- Helper: create a sidebar section category label
    local function AddNavCategory(Text)
        local CatLabel = Library:Create('TextLabel', {
            BackgroundTransparency = 1;
            Size = UDim2.new(1, 0, 0, 28);
            Font = Enum.Font.GothamBold;
            TextColor3 = Library.SectionTextColor;
            TextSize = 11;
            Text = Text:upper();
            TextXAlignment = Enum.TextXAlignment.Left;
            TextStrokeTransparency = 1;
            ZIndex = 4;
            Parent = NavScroll;
        });
        Library:Create('UIPadding', { PaddingLeft = UDim.new(0, 14); Parent = CatLabel });
        Library:AddToRegistry(CatLabel, { TextColor3 = 'SectionTextColor' });
    end

    function Window:SetWindowTitle(Title)
        WindowLabel.Text = Title:upper();
    end;

    function Window:AddTab(Name, Category)
        local Tab = {
            Groupboxes = {};
            Tabboxes = {};
        };

        -- ── NL sidebar nav item ──────────────────────────────────────────
        -- If a Category string is supplied, insert a category label first
        if type(Category) == 'string' and Category ~= '' then
            local CatLabel = Library:Create('TextLabel', {
                BackgroundTransparency = 1;
                Size = UDim2.new(1, 0, 0, 26);
                Font = Enum.Font.GothamBold;
                TextColor3 = Library.SectionTextColor;
                TextSize = 10;
                Text = Category:upper();
                TextXAlignment = Enum.TextXAlignment.Left;
                TextStrokeTransparency = 1;
                ZIndex = 4;
                Parent = NavScroll;
            });
            Library:Create('UIPadding', { PaddingLeft = UDim.new(0, 14); Parent = CatLabel });
            Library:AddToRegistry(CatLabel, { TextColor3 = 'SectionTextColor' });
        end

        -- Nav button row (full sidebar width, 34px tall)
        local TabButton = Library:Create('Frame', {
            BackgroundColor3 = Color3.fromRGB(0,0,0);
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Size = UDim2.new(1, 0, 0, 34);
            ZIndex = 4;
            Parent = NavScroll;
        });

        -- Active left accent bar (hidden by default)
        local ActiveBar = Library:Create('Frame', {
            BackgroundColor3 = Library.AccentColor;
            BorderSizePixel = 0;
            Size = UDim2.new(0, 3, 0, 18);
            AnchorPoint = Vector2.new(0, 0.5);
            Position = UDim2.new(0, 0, 0.5, 0);
            ZIndex = 6;
            Visible = false;
            Parent = TabButton;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(1, 0); Parent = ActiveBar });
        Library:AddToRegistry(ActiveBar, { BackgroundColor3 = 'AccentColor' });

        -- Active highlight background
        local ActiveBg = Library:Create('Frame', {
            BackgroundColor3 = Library.NavActiveColor;
            BorderSizePixel = 0;
            Size = UDim2.new(1, -6, 1, -4);
            AnchorPoint = Vector2.new(0, 0.5);
            Position = UDim2.new(0, 6, 0.5, 0);
            ZIndex = 5;
            Visible = false;
            Parent = TabButton;
        });
        Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = ActiveBg });
        Library:AddToRegistry(ActiveBg, { BackgroundColor3 = 'NavActiveColor' });

        -- Tab label text
        local TabButtonLabel = Library:Create('TextLabel', {
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 20, 0, 0);
            Size = UDim2.new(1, -20, 1, 0);
            Font = Library.Font;
            TextColor3 = Library.SubtextColor;
            TextSize = 13;
            Text = Name;
            TextXAlignment = Enum.TextXAlignment.Left;
            TextStrokeTransparency = 1;
            ZIndex = 7;
            Parent = TabButton;
        });
        Library:AddToRegistry(TabButtonLabel, { TextColor3 = 'SubtextColor' });
        Library:Create('UIStroke', { Color = Color3.new(0,0,0); Thickness = 1; LineJoinMode = Enum.LineJoinMode.Miter; Parent = TabButtonLabel });

        -- Hover highlight
        TabButton.MouseEnter:Connect(function()
            if not TabFrame.Visible then
                TweenService:Create(TabButtonLabel, TweenInfo.new(0.1), { TextColor3 = Library.FontColor }):Play()
            end
        end)
        TabButton.MouseLeave:Connect(function()
            if not TabFrame.Visible then
                TweenService:Create(TabButtonLabel, TweenInfo.new(0.1), { TextColor3 = Library.SubtextColor }):Play()
            end
        end)

        -- ── Content TabFrame ────────────────────────────────────────────
        local TabFrame = Library:Create('Frame', {
            Name = 'TabFrame';
            BackgroundTransparency = 1;
            Position = UDim2.new(0, 0, 0, 0);
            Size = UDim2.new(1, 0, 1, 0);
            Visible = false;
            ZIndex = 2;
            Parent = TabContainer;
        });

        -- Two-column scrollable sides
        local LeftSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0, 10, 0, 10);
            Size = UDim2.new(0.5, -15, 1, -20);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = ''; TopImage = '';
            ScrollBarThickness = 2;
            ScrollBarImageColor3 = Library.OutlineColor;
            ZIndex = 2;
            Parent = TabFrame;
        });

        local RightSide = Library:Create('ScrollingFrame', {
            BackgroundTransparency = 1;
            BorderSizePixel = 0;
            Position = UDim2.new(0.5, 5, 0, 10);
            Size = UDim2.new(0.5, -15, 1, -20);
            CanvasSize = UDim2.new(0, 0, 0, 0);
            BottomImage = ''; TopImage = '';
            ScrollBarThickness = 2;
            ScrollBarImageColor3 = Library.OutlineColor;
            ZIndex = 2;
            Parent = TabFrame;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = LeftSide;
        });

        Library:Create('UIListLayout', {
            Padding = UDim.new(0, 8);
            FillDirection = Enum.FillDirection.Vertical;
            SortOrder = Enum.SortOrder.LayoutOrder;
            HorizontalAlignment = Enum.HorizontalAlignment.Center;
            Parent = RightSide;
        });

        for _, Side in next, { LeftSide, RightSide } do
            Side:WaitForChild('UIListLayout'):GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
                Side.CanvasSize = UDim2.fromOffset(0, Side.UIListLayout.AbsoluteContentSize.Y + 10);
            end);
        end;

        function Tab:ShowTab()
            for _, T in next, Window.Tabs do
                T:HideTab();
            end;
            -- Activate nav item
            ActiveBar.Visible = true;
            ActiveBg.Visible = true;
            TabButtonLabel.TextColor3 = Library.FontColor;
            Library.RegistryMap[TabButtonLabel].Properties.TextColor3 = 'FontColor';
            TabFrame.Visible = true;
        end;

        function Tab:HideTab()
            ActiveBar.Visible = false;
            ActiveBg.Visible = false;
            TabButtonLabel.TextColor3 = Library.SubtextColor;
            if Library.RegistryMap[TabButtonLabel] then
                Library.RegistryMap[TabButtonLabel].Properties.TextColor3 = 'SubtextColor';
            end;
            TabFrame.Visible = false;
        end;

        function Tab:SetLayoutOrder(Position)
            TabButton.LayoutOrder = Position;
        end;

        function Tab:AddGroupbox(Info)
            local Groupbox = {};

            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.ContentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 507 + 2);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });

            Library:Create('UICorner', {
                CornerRadius = UDim.new(0, 4);
                Parent = BoxOuter;
            });

            Library:AddToRegistry(BoxOuter, {
                BackgroundColor3 = 'ContentColor';
                BorderColor3 = 'OutlineColor';
            });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.ContentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 1, 0);
                Position = UDim2.new(0, 0, 0, 0);
                ZIndex = 4;
                Parent = BoxOuter;
            });

            Library:Create('UICorner', {
                CornerRadius = UDim.new(0, 4);
                Parent = BoxInner;
            });

            Library:AddToRegistry(BoxInner, {
                BackgroundColor3 = 'ContentColor';
            });

            -- NL section header: just text, no accent bar
            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.OutlineColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 1);
                Position = UDim2.new(0, 0, 0, 22);
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:AddToRegistry(Highlight, {
                BackgroundColor3 = 'OutlineColor';
            });

            local GroupboxLabel = Library:CreateLabel({
                Size = UDim2.new(1, -8, 0, 22);
                Position = UDim2.new(0, 8, 0, 0);
                TextSize = 13;
                Text = Info.Name;
                TextColor3 = Library.SectionTextColor;
                Font = Enum.Font.GothamBold;
                TextXAlignment = Enum.TextXAlignment.Left;
                ZIndex = 5;
                Parent = BoxInner;
            });

            Library:AddToRegistry(GroupboxLabel, {
                TextColor3 = 'SectionTextColor';
            });

            local Container = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 8, 0, 26);
                Size = UDim2.new(1, -16, 1, -26);
                ZIndex = 1;
                Parent = BoxInner;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Vertical;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = Container;
            });

            function Groupbox:Resize()
                local Size = 0;

                for _, Element in next, Groupbox.Container:GetChildren() do
                    if (not Element:IsA('UIListLayout')) and Element.Visible then
                        Size = Size + Element.Size.Y.Offset;
                    end;
                end;

                BoxOuter.Size = UDim2.new(1, 0, 0, 26 + Size + 8);
            end;

            Groupbox.Container = Container;
            setmetatable(Groupbox, BaseGroupbox);

            Groupbox:AddBlank(3);
            Groupbox:Resize();

            Tab.Groupboxes[Info.Name] = Groupbox;

            return Groupbox;
        end;

        function Tab:AddLeftGroupbox(Name)
            return Tab:AddGroupbox({ Side = 1; Name = Name; });
        end;

        function Tab:AddRightGroupbox(Name)
            return Tab:AddGroupbox({ Side = 2; Name = Name; });
        end;

        function Tab:AddTabbox(Info)
            local Tabbox = {
                Tabs = {};
            };

            -- NL: tabbox outer is same dark card as groupbox
            local BoxOuter = Library:Create('Frame', {
                BackgroundColor3 = Library.ContentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 0, 0);
                ZIndex = 2;
                Parent = Info.Side == 1 and LeftSide or RightSide;
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = BoxOuter });
            Library:AddToRegistry(BoxOuter, { BackgroundColor3 = 'ContentColor' });

            local BoxInner = Library:Create('Frame', {
                BackgroundColor3 = Library.ContentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 4;
                Parent = BoxOuter;
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, 4); Parent = BoxInner });
            Library:AddToRegistry(BoxInner, { BackgroundColor3 = 'ContentColor' });

            -- Pill tab bar background
            local TabbarBg = Library:Create('Frame', {
                BackgroundColor3 = Library.ToggleOffColor;
                BorderSizePixel = 0;
                Position = UDim2.new(0, 8, 0, 8);
                Size = UDim2.new(1, -16, 0, 24);
                ZIndex = 5;
                Parent = BoxInner;
            });
            Library:Create('UICorner', { CornerRadius = UDim.new(0, 6); Parent = TabbarBg });
            Library:AddToRegistry(TabbarBg, { BackgroundColor3 = 'ToggleOffColor' });

            local TabboxButtons = Library:Create('Frame', {
                BackgroundTransparency = 1;
                Position = UDim2.new(0, 0, 0, 0);
                Size = UDim2.new(1, 0, 1, 0);
                ZIndex = 6;
                Parent = TabbarBg;
            });

            Library:Create('UIListLayout', {
                FillDirection = Enum.FillDirection.Horizontal;
                HorizontalAlignment = Enum.HorizontalAlignment.Left;
                SortOrder = Enum.SortOrder.LayoutOrder;
                Parent = TabboxButtons;
            });

            -- Dummy accent bar (kept for compat with old code)
            local Highlight = Library:Create('Frame', {
                BackgroundColor3 = Library.AccentColor;
                BorderSizePixel = 0;
                Size = UDim2.new(0, 0, 0, 0);
                ZIndex = 10;
                Parent = BoxInner;
            });
            Library:AddToRegistry(Highlight, { BackgroundColor3 = 'AccentColor' });

            function Tabbox:AddTab(Name)
                local Tab = {};

                -- NL: pill button
                local Button = Library:Create('Frame', {
                    BackgroundColor3 = Color3.fromRGB(0,0,0);
                    BackgroundTransparency = 1;
                    BorderSizePixel = 0;
                    Size = UDim2.new(0.5, 0, 1, 0);
                    ZIndex = 7;
                    Parent = TabboxButtons;
                });

                local ButtonBg = Library:Create('Frame', {
                    BackgroundColor3 = Library.NavActiveColor;
                    BorderSizePixel = 0;
                    Size = UDim2.new(1, -4, 1, -4);
                    AnchorPoint = Vector2.new(0.5, 0.5);
                    Position = UDim2.new(0.5, 0, 0.5, 0);
                    Visible = false;
                    ZIndex = 8;
                    Parent = Button;
                });
                Library:Create('UICorner', { CornerRadius = UDim.new(0, 5); Parent = ButtonBg });
                Library:AddToRegistry(ButtonBg, { BackgroundColor3 = 'NavActiveColor' });

                local ButtonLabel = Library:Create('TextLabel', {
                    BackgroundTransparency = 1;
                    Size = UDim2.new(1, 0, 1, 0);
                    Font = Library.Font;
                    TextColor3 = Library.SubtextColor;
                    TextSize = 12;
                    Text = Name;
                    TextXAlignment = Enum.TextXAlignment.Center;
                    TextStrokeTransparency = 1;
                    ZIndex = 9;
                    Parent = Button;
                });
                Library:AddToRegistry(ButtonLabel, { TextColor3 = 'SubtextColor' });

                local Block = Library:Create('Frame', { -- kept for compat
                    BackgroundTransparency = 1;
                    BorderSizePixel = 0;
                    Size = UDim2.new(0, 0, 0, 0);
                    Visible = false;
                    ZIndex = 9;
                    Parent = Button;
                });
                Library:AddToRegistry(Block, { BackgroundColor3 = 'ContentColor' });

                local Container = Library:Create('Frame', {
                    BackgroundTransparency = 1;
                    Position = UDim2.new(0, 8, 0, 40);
                    Size = UDim2.new(1, -16, 1, -40);
                    ZIndex = 1;
                    Visible = false;
                    Parent = BoxInner;
                });

                Library:Create('UIListLayout', {
                    FillDirection = Enum.FillDirection.Vertical;
                    SortOrder = Enum.SortOrder.LayoutOrder;
                    Parent = Container;
                });

                function Tab:Show()
                    for _, T in next, Tabbox.Tabs do
                        T:Hide();
                    end;

                    Container.Visible = true;
                    Block.Visible = true;
                    ButtonBg.Visible = true;
                    ButtonLabel.TextColor3 = Library.FontColor;
                    Library.RegistryMap[ButtonLabel].Properties.TextColor3 = 'FontColor';

                    Tab:Resize();
                end;

                function Tab:Hide()
                    Container.Visible = false;
                    Block.Visible = false;
                    ButtonBg.Visible = false;
                    ButtonLabel.TextColor3 = Library.SubtextColor;
                    if Library.RegistryMap[ButtonLabel] then
                        Library.RegistryMap[ButtonLabel].Properties.TextColor3 = 'SubtextColor';
                    end;
                end;

                function Tab:Resize()
                    local TabCount = 0;
                    for _ in next, Tabbox.Tabs do TabCount += 1 end;

                    for _, Btn in next, TabboxButtons:GetChildren() do
                        if not Btn:IsA('UIListLayout') then
                            Btn.Size = UDim2.new(1 / TabCount, 0, 1, 0);
                        end;
                    end;

                    if not Container.Visible then return end;

                    local Size = 0;
                    for _, Element in next, Tab.Container:GetChildren() do
                        if not Element:IsA('UIListLayout') and Element.Visible then
                            Size += Element.Size.Y.Offset;
                        end;
                    end;

                    BoxOuter.Size = UDim2.new(1, 0, 0, 40 + Size + 8);
                end;

                Button.InputBegan:Connect(function(Input)
                    if Input.UserInputType == Enum.UserInputType.MouseButton1 and not Library:MouseIsOverOpenedFrame() then
                        Tab:Show();
                        Tab:Resize();
                    end;
                end);

                Tab.Container = Container;
                Tabbox.Tabs[Name] = Tab;
                setmetatable(Tab, BaseGroupbox);
                Tab:AddBlank(3);
                Tab:Resize();

                if #TabboxButtons:GetChildren() == 2 then
                    Tab:Show();
                end;

                return Tab;
            end;

            Tab.Tabboxes[Info.Name or ''] = Tabbox;

            return Tabbox;
        end;

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 1; });
        end;

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Name = Name, Side = 2; });
        end;

        TabButton.InputBegan:Connect(function(Input)
            if Input.UserInputType == Enum.UserInputType.MouseButton1 then
                Tab:ShowTab();
            end;
        end);

        -- First tab added shows by default
        local tabCount = 0
        for _ in next, Window.Tabs do tabCount = tabCount + 1 end
        if tabCount == 0 then
            task.defer(function() Tab:ShowTab() end)
        end

        Window.Tabs[Name] = Tab;
        return Tab;
    end;

    local ModalElement = Library:Create('TextButton', {
        BackgroundTransparency = 1;
        Size = UDim2.new(0, 0, 0, 0);
        Visible = true;
        Text = '';
        Modal = false;
        Parent = ScreenGui;
    });

    local TransparencyCache = {};
    local Toggled = false;
    local Fading = false;

    function Library:Toggle()
        if Fading then
            return;
        end;

        local FadeTime = Config.MenuFadeTime;
        Fading = true;
        Toggled = (not Toggled);
        ModalElement.Modal = Toggled;

        if Toggled then
            -- A bit scuffed, but if we're going from not toggled -> toggled we want to show the frame immediately so that the fade is visible.
            Outer.Visible = true;

            task.spawn(function()
                -- TODO: add cursor fade?
                local State = InputService.MouseIconEnabled;

                local Cursor = Drawing.new('Triangle');
                Cursor.Thickness = 1;
                Cursor.Filled = true;
                Cursor.Visible = true;

                local CursorOutline = Drawing.new('Triangle');
                CursorOutline.Thickness = 1;
                CursorOutline.Filled = false;
                CursorOutline.Color = Color3.new(0, 0, 0);
                CursorOutline.Visible = true;

                while Toggled and ScreenGui.Parent do
                    InputService.MouseIconEnabled = false;

                    local mPos = InputService:GetMouseLocation();

                    Cursor.Color = Library.AccentColor;

                    Cursor.PointA = Vector2.new(mPos.X, mPos.Y);
                    Cursor.PointB = Vector2.new(mPos.X + 16, mPos.Y + 6);
                    Cursor.PointC = Vector2.new(mPos.X + 6, mPos.Y + 16);

                    CursorOutline.PointA = Cursor.PointA;
                    CursorOutline.PointB = Cursor.PointB;
                    CursorOutline.PointC = Cursor.PointC;

                    RenderStepped:Wait();
                end;

                InputService.MouseIconEnabled = State;

                Cursor:Remove();
                CursorOutline:Remove();
            end);
        end;

        for _, Desc in next, Outer:GetDescendants() do
            local Properties = {};

            if Desc:IsA('ImageLabel') then
                table.insert(Properties, 'ImageTransparency');
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('TextLabel') or Desc:IsA('TextBox') then
                table.insert(Properties, 'TextTransparency');
            elseif Desc:IsA('Frame') or Desc:IsA('ScrollingFrame') then
                table.insert(Properties, 'BackgroundTransparency');
            elseif Desc:IsA('UIStroke') then
                table.insert(Properties, 'Transparency');
            end;

            local Cache = TransparencyCache[Desc];

            if (not Cache) then
                Cache = {};
                TransparencyCache[Desc] = Cache;
            end;

            for _, Prop in next, Properties do
                if not Cache[Prop] then
                    Cache[Prop] = Desc[Prop];
                end;

                if Cache[Prop] == 1 then
                    continue;
                end;

                TweenService:Create(Desc, TweenInfo.new(FadeTime, Enum.EasingStyle.Linear), { [Prop] = Toggled and Cache[Prop] or 1 }):Play();
            end;
        end;

        task.wait(FadeTime);

        Outer.Visible = Toggled;

        Fading = false;
    end

    Library:GiveSignal(InputService.InputBegan:Connect(function(Input, Processed)
        if type(Library.ToggleKeybind) == 'table' and Library.ToggleKeybind.Type == 'KeyPicker' then
            if Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Library.ToggleKeybind.Value then
                task.spawn(Library.Toggle)
            end
        elseif Input.KeyCode == Enum.KeyCode.RightControl or (Input.KeyCode == Enum.KeyCode.RightShift and (not Processed)) then
            task.spawn(Library.Toggle)
        end
    end))

    if Config.AutoShow then task.spawn(Library.Toggle) end

    Window.Holder = Outer;

    return Window;
end;

local function OnPlayerChange()
    local PlayerList = GetPlayersString();

    for _, Value in next, Options do
        if Value.Type == 'Dropdown' and Value.SpecialType == 'Player' then
            Value:SetValues(PlayerList);
        end;
    end;
end;

Players.PlayerAdded:Connect(OnPlayerChange);
Players.PlayerRemoving:Connect(OnPlayerChange);

getgenv().Library = Library
return Library
-- ═══════════════════════════════════════════════════════════════════════════
--  NEVERLOSE UI  —  menu definition starts here
-- ═══════════════════════════════════════════════════════════════════════════

local addonRepo   = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local ThemeManager = loadstring(game:HttpGet(addonRepo .. 'addons/ThemeManager.lua'))()
local SaveManager  = loadstring(game:HttpGet(addonRepo .. 'addons/SaveManager.lua'))()

-- ── Window ────────────────────────────────────────────────────────────────
local Window = Library:CreateWindow({
    Title        = 'neverlose',
    Center       = true,
    AutoShow     = true,
    TabPadding   = 0,
    MenuFadeTime = 0.2,
})

-- ── Tabs ──────────────────────────────────────────────────────────────────
local Tabs = {
    Ragebot   = Window:AddTab('Ragebot',   'Aimbot'),
    AntiAim   = Window:AddTab('Anti Aim'),
    Legitbot  = Window:AddTab('Legitbot'),

    Players   = Window:AddTab('Players',   'Visuals'),
    Weapon    = Window:AddTab('Weapon'),
    Grenades  = Window:AddTab('Grenades'),
    World     = Window:AddTab('World'),
    View      = Window:AddTab('View'),

    Main      = Window:AddTab('Main',      'Miscellaneous'),
    Inventory = Window:AddTab('Inventory'),
    Scripts   = Window:AddTab('Scripts'),
    Configs   = Window:AddTab('Configs'),
}

-- ════════════════════════════════════════════════════════════════
--  RAGEBOT
-- ════════════════════════════════════════════════════════════════
local RBGeneral = Tabs.Ragebot:AddLeftGroupbox('General')
local RBWeapon  = Tabs.Ragebot:AddRightGroupbox('Weapon')

RBGeneral:AddToggle('RBEnabled',    { Text = 'Enable',            Default = false })
RBGeneral:AddToggle('RBAutoScope',  { Text = 'Auto Scope',        Default = true  })
RBGeneral:AddToggle('RBAutoStop',   { Text = 'Auto Stop',         Default = true  })
RBGeneral:AddToggle('RBAutoCrouch', { Text = 'Auto Crouch',       Default = false })
RBGeneral:AddDivider()
RBGeneral:AddDropdown('RBHitbox', {
    Text = 'Hitbox', Values = {'Head','Body','Nearest'}, Default = 1,
})
RBGeneral:AddSlider('RBHitchance', {
    Text = 'Hitchance', Default = 50, Min = 1, Max = 100, Rounding = 0, Suffix = '%',
})
RBGeneral:AddSlider('RBMinDmg', {
    Text = 'Min Damage', Default = 40, Min = 1, Max = 200, Rounding = 0,
})
RBGeneral:AddDivider()
RBGeneral:AddToggle('RBBaim',      { Text = 'Body Aim Fallback', Default = true  })
RBGeneral:AddToggle('RBSafePoint', { Text = 'Safe Point',        Default = false })

RBWeapon:AddDropdown('RBKey', {
    Text = 'Activation Key', Values = {'Mouse 2','Mouse 4','Mouse 5','Always'}, Default = 4,
})
RBWeapon:AddDivider()
RBWeapon:AddToggle('RBMultipoint', { Text = 'Multipoint', Default = false })
local MPDep = RBWeapon:AddDependencyBox()
MPDep:AddDropdown('RBMPPoints', {
    Text = 'Points', Values = {'Top','Center','Bottom','Left','Right'}, Default = 1, Multi = true,
})
MPDep:AddSlider('RBMPScale', {
    Text = 'Scale', Default = 100, Min = 1, Max = 100, Rounding = 0, Suffix = '%',
})
MPDep:SetupDependencies({ { Toggles.RBMultipoint, true } })
RBWeapon:AddDivider()
RBWeapon:AddToggle('RBFakelag', { Text = 'Fakelag', Default = false })
local FLDep = RBWeapon:AddDependencyBox()
FLDep:AddSlider('RBFLTicks', {
    Text = 'Ticks', Default = 14, Min = 1, Max = 14, Rounding = 0,
})
FLDep:SetupDependencies({ { Toggles.RBFakelag, true } })

-- ════════════════════════════════════════════════════════════════
--  ANTI-AIM
-- ════════════════════════════════════════════════════════════════
local AALeft  = Tabs.AntiAim:AddLeftGroupbox('Standing')
local AARight = Tabs.AntiAim:AddRightGroupbox('Moving / Air')

AALeft:AddToggle('AAEnabled', { Text = 'Enable', Default = false })
AALeft:AddDivider()
AALeft:AddDropdown('AAPitch',  { Text = 'Pitch',  Values = {'Off','Down','Up','Zero'},               Default = 2 })
AALeft:AddDropdown('AAYaw',    { Text = 'Yaw',    Values = {'Off','Spin','Jitter','Static','Side'},  Default = 3 })
AALeft:AddSlider('AAYawOffset',{ Text = 'Yaw Offset', Default = 0, Min = -180, Max = 180, Rounding = 0, Suffix = '°' })
AALeft:AddDropdown('AADesync', { Text = 'Desync', Values = {'Off','Invert','Freestanding'}, Default = 2 })
AALeft:AddSlider('AADesyncRange',{ Text = 'Desync Range', Default = 60, Min = 0, Max = 60, Rounding = 0, Suffix = '°' })

AARight:AddDropdown('AAMovePitch', { Text = 'Pitch (Moving)', Values = {'Inherit','Down','Up','Zero'},     Default = 1 })
AARight:AddDropdown('AAMoveYaw',   { Text = 'Yaw (Moving)',   Values = {'Inherit','Spin','Jitter','Static'}, Default = 1 })
AARight:AddDivider()
AARight:AddDropdown('AAAirPitch',  { Text = 'Pitch (Air)',    Values = {'Inherit','Down','Up','Zero'},     Default = 1 })
AARight:AddDropdown('AAAirYaw',    { Text = 'Yaw (Air)',      Values = {'Inherit','Spin','Jitter','Static'}, Default = 1 })
AARight:AddDivider()
AARight:AddToggle('AASlowwalk', { Text = 'Slow Walk', Default = false })
local SWDep = AARight:AddDependencyBox()
SWDep:AddSlider('AASlowwalkSpeed', { Text = 'Speed', Default = 100, Min = 1, Max = 200, Rounding = 0, Suffix = '%' })
SWDep:SetupDependencies({ { Toggles.AASlowwalk, true } })

-- ════════════════════════════════════════════════════════════════
--  LEGITBOT
-- ════════════════════════════════════════════════════════════════
local LBLeft  = Tabs.Legitbot:AddLeftGroupbox('Aimbot')
local LBRight = Tabs.Legitbot:AddRightGroupbox('Triggerbot')

LBLeft:AddToggle('LBEnabled', { Text = 'Enable', Default = false })
LBLeft:AddDropdown('LBKey',    { Text = 'Activation Key', Values = {'Mouse 2','Mouse 4','Shift','Alt'}, Default = 1 })
LBLeft:AddDropdown('LBHitbox', { Text = 'Hitbox', Values = {'Head','Neck','Chest','Nearest'}, Default = 1 })
LBLeft:AddSlider('LBFOV',    { Text = 'FOV',    Default = 5,   Min = 1, Max = 180, Rounding = 0, Suffix = '°' })
LBLeft:AddSlider('LBSmooth', { Text = 'Smooth', Default = 5,   Min = 1, Max = 20,  Rounding = 1 })
LBLeft:AddSlider('LBRCS_X',  { Text = 'RCS X',  Default = 100, Min = 0, Max = 200, Rounding = 0, Suffix = '%' })
LBLeft:AddSlider('LBRCS_Y',  { Text = 'RCS Y',  Default = 100, Min = 0, Max = 200, Rounding = 0, Suffix = '%' })
LBLeft:AddDivider()
LBLeft:AddToggle('LBAimstep', { Text = 'Aim Step', Default = false })
local ASDep = LBLeft:AddDependencyBox()
ASDep:AddSlider('LBAimstepSize', { Text = 'Step Size', Default = 3, Min = 1, Max = 30, Rounding = 1 })
ASDep:SetupDependencies({ { Toggles.LBAimstep, true } })

LBRight:AddToggle('TBEnabled', { Text = 'Enable', Default = false })
LBRight:AddDropdown('TBKey', { Text = 'Activation Key', Values = {'Mouse 2','Mouse 4','Alt','Always'}, Default = 1 })
LBRight:AddSlider('TBDelay', { Text = 'Shot Delay',  Default = 50,  Min = 0, Max = 500, Rounding = 0, Suffix = 'ms' })
LBRight:AddSlider('TBBurst', { Text = 'Burst Delay', Default = 150, Min = 0, Max = 500, Rounding = 0, Suffix = 'ms' })
LBRight:AddDivider()
LBRight:AddToggle('TBMinDmg', { Text = 'Min Damage', Default = false })
local TBDep = LBRight:AddDependencyBox()
TBDep:AddSlider('TBDamage', { Text = 'Damage', Default = 1, Min = 1, Max = 100, Rounding = 0 })
TBDep:SetupDependencies({ { Toggles.TBMinDmg, true } })

-- ════════════════════════════════════════════════════════════════
--  PLAYERS (VISUALS)
-- ════════════════════════════════════════════════════════════════
local VESP   = Tabs.Players:AddLeftGroupbox('ESP')
local VGlow  = Tabs.Players:AddRightGroupbox('Glow')
local VChams = Tabs.Players:AddRightGroupbox('Chams')

VESP:AddToggle('ESPEnabled',   { Text = 'Enable',    Default = false })
VESP:AddToggle('ESPEnemyOnly', { Text = 'Enemy Only',Default = true  })
VESP:AddDivider()
VESP:AddToggle('ESPBox',    { Text = 'Box',        Default = false })
VESP:AddDropdown('ESPBoxType', { Text = 'Box Type', Values = {'Full','Corners'}, Default = 1 })
VESP:AddLabel('Box Color'):AddColorPicker('ESPBoxColor', { Default = Color3.fromRGB(255,255,255), Transparency = 0 })
VESP:AddDivider()
VESP:AddToggle('ESPSkeleton', { Text = 'Skeleton',   Default = false })
VESP:AddToggle('ESPName',     { Text = 'Name',       Default = true  })
VESP:AddToggle('ESPHealth',   { Text = 'Health Bar', Default = true  })
VESP:AddToggle('ESPDistance', { Text = 'Distance',   Default = false })
VESP:AddToggle('ESPWeapon',   { Text = 'Weapon',     Default = false })

VGlow:AddToggle('GlowEnabled', { Text = 'Enable', Default = false })
VGlow:AddDropdown('GlowStyle', { Text = 'Style', Values = {'Normal','Flat','Rim','Pulse'}, Default = 1 })
VGlow:AddLabel('Enemy Color'):AddColorPicker('GlowEnemyColor', { Default = Color3.fromRGB(235,80,80),  Transparency = 0.3 })
VGlow:AddLabel('Team Color'):AddColorPicker('GlowTeamColor',   { Default = Color3.fromRGB(80,180,235), Transparency = 0.3 })

VChams:AddToggle('ChamsEnabled', { Text = 'Enable', Default = false })
VChams:AddDropdown('ChamsMat', { Text = 'Material', Values = {'Flat','Shiny','Reflective'}, Default = 1 })
VChams:AddToggle('ChamsXQZ', { Text = 'Through Walls', Default = false })
VChams:AddLabel('Visible Color'):AddColorPicker('ChamsVisColor',  { Default = Color3.fromRGB(52,152,255), Transparency = 0   })
VChams:AddLabel('Occluded Color'):AddColorPicker('ChamsOccColor', { Default = Color3.fromRGB(60,60,200),  Transparency = 0.4 })

-- ════════════════════════════════════════════════════════════════
--  MAIN (MISC) — mirrors the NL screenshot
-- ════════════════════════════════════════════════════════════════
local MiscMov  = Tabs.Main:AddLeftGroupbox('Movement')
local MiscSpam = Tabs.Main:AddLeftGroupbox('Spammers')
local MiscOth  = Tabs.Main:AddRightGroupbox('Other')
local MiscBuy  = Tabs.Main:AddRightGroupbox('BuyBot')

MiscMov:AddToggle('AutoJump',     { Text = 'Auto Jump',     Default = false })
MiscMov:AddToggle('AutoStrafe',   { Text = 'Auto Strafe',   Default = false })
MiscMov:AddSlider('MoveSmoothing',{ Text = 'Smoothing', Default = 28, Min = 0, Max = 100, Rounding = 0, Compact = true })
MiscMov:AddToggle('WASDStrafe',   { Text = 'WASD Strafe',   Default = true  })
MiscMov:AddToggle('CircleStrafe', { Text = 'Circle Strafe', Default = false })
MiscMov:AddToggle('QuickStop',    { Text = 'Quick Stop',    Default = true  })
MiscMov:AddToggle('StrafeAssist', { Text = 'Strafe Assist', Default = true  })
MiscMov:AddToggle('AutoPeek',     { Text = 'Auto Peek',     Default = false })
MiscMov:AddToggle('EdgeJump',     { Text = 'Edge Jump',     Default = false })
MiscMov:AddToggle('InfinityDuck', { Text = 'Infinity Duck', Default = true  })
MiscMov:AddToggle('Blockbot',     { Text = 'Blockbot',      Default = false })

MiscSpam:AddToggle('Clantag',  { Text = 'Clantag',   Default = false })
MiscSpam:AddToggle('ChatSpam', { Text = 'Chat Spam', Default = false })

MiscOth:AddToggle('AntiUntrusted',    { Text = 'Anti Untrusted',    Default = false })
MiscOth:AddDropdown('EventLog', {
    Text = 'Event Log', Values = {'Off','Damage','Hurt','Spawn','All'}, Default = 1, Multi = true,
})
MiscOth:AddDropdown('Windows', {
    Text = 'Windows', Values = {'Binds List','Spectators','Watermark'}, Default = 1, Multi = true,
})
MiscOth:AddToggle('FilterServerAds',  { Text = 'Filter server ads',  Default = true  })
MiscOth:AddToggle('FilterConsole',    { Text = 'Filter Console',     Default = false })
MiscOth:AddToggle('UnlockCvars',      { Text = 'Unlock Cvars',       Default = false })
MiscOth:AddToggle('FastReload',       { Text = 'Fast Reload',        Default = true  })
MiscOth:AddToggle('FastWeaponSwitch', { Text = 'Fast Weapon Switch', Default = true  })
MiscOth:AddSlider('FakePing', {
    Text = 'Fake Ping', Default = 0, Min = 0, Max = 200, Rounding = 0, HideMax = true,
})

MiscBuy:AddToggle('BuybotEnabled', { Text = 'Enable BuyBot', Default = false })
MiscBuy:AddDropdown('BuybotPrimary', {
    Text = 'Primary', Values = {'AK-47','M4A4','M4A1-S','AWP','SG 553','AUG','FAMAS'}, Default = 4,
})
MiscBuy:AddDropdown('BuybotSecondary', {
    Text = 'Secondary', Values = {'Glock-18','USP-S','P2000','Desert Eagle','R8/Desert Eagle','Five-SeveN'}, Default = 5,
})
MiscBuy:AddDropdown('BuybotEquip', {
    Text = 'Equipment', Values = {'Kevlar','Kevlar + Helmet','Assaultsuit','Zeus','Defuse Kit'}, Default = 2, Multi = true,
})

-- ════════════════════════════════════════════════════════════════
--  CONFIGS TAB
-- ════════════════════════════════════════════════════════════════
local CfgGroup = Tabs.Configs:AddLeftGroupbox('Menu')
CfgGroup:AddButton('Unload', function() Library:Unload() end)
CfgGroup:AddLabel('Menu Bind'):AddKeyPicker('MenuKeybind', {
    Default = 'End', NoUI = true, Text = 'Menu Keybind',
})
Library.ToggleKeybind = Options.MenuKeybind

-- ── Addons ────────────────────────────────────────────────────────────────
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('NeverlosUI')
SaveManager:SetFolder('NeverlosUI/configs')
SaveManager:BuildConfigSection(Tabs.Configs)
ThemeManager:ApplyToTab(Tabs.Configs)
SaveManager:LoadAutoloadConfig()

-- ── Watermark ─────────────────────────────────────────────────────────────
Library:SetWatermarkVisibility(true)

local FrameTimer, FrameCounter, FPS = tick(), 0, 60
local WMConn = game:GetService('RunService').RenderStepped:Connect(function()
    FrameCounter += 1
    if (tick() - FrameTimer) >= 1 then
        FPS = FrameCounter; FrameTimer = tick(); FrameCounter = 0
    end
    Library:SetWatermark(('neverlose | %d fps | %d ms'):format(
        math.floor(FPS),
        math.floor(game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue())
    ))
end)

Library.KeybindFrame.Visible = true

Library:OnUnload(function()
    WMConn:Disconnect()
    Library.Unloaded = true
end)
