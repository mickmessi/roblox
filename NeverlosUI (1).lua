-- NeverlosUI.lua
-- Neverlose.cc UI recreation — requires NeverlosLib.lua at your repo

-- ── Loaders ──────────────────────────────────────────────────────────────
-- IMPORTANT: Upload NeverlosLib.lua to your GitHub and replace this URL
local Library = loadstring(game:HttpGet('https://raw.githubusercontent.com/mickmessi/roblox/refs/heads/main/NeverlosLib.lua'))()

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

-- ── Tabs (sidebar nav — 2nd arg = category header, shown once per group) ──
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
--  RAGEBOT TAB
-- ════════════════════════════════════════════════════════════════
local RBGeneral = Tabs.Ragebot:AddLeftGroupbox('General')
local RBWeapon  = Tabs.Ragebot:AddRightGroupbox('Weapon')

RBGeneral:AddToggle('RBEnabled',    { Text = 'Enable',         Default = false })
RBGeneral:AddToggle('RBAutoScope',  { Text = 'Auto Scope',     Default = true  })
RBGeneral:AddToggle('RBAutoStop',   { Text = 'Auto Stop',      Default = true  })
RBGeneral:AddToggle('RBAutoCrouch', { Text = 'Auto Crouch',    Default = false })
RBGeneral:AddDivider()
RBGeneral:AddDropdown('RBHitbox', {
    Text    = 'Hitbox',
    Values  = { 'Head', 'Body', 'Nearest' },
    Default = 1,
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
    Text = 'Activation Key',
    Values = { 'Mouse 2', 'Mouse 4', 'Mouse 5', 'Always' },
    Default = 4,
})
RBWeapon:AddDivider()
RBWeapon:AddToggle('RBMultipoint', { Text = 'Multipoint', Default = false })
local MPDep = RBWeapon:AddDependencyBox()
MPDep:AddDropdown('RBMPPoints', {
    Text = 'Points', Values = { 'Top', 'Center', 'Bottom', 'Left', 'Right' },
    Default = 1, Multi = true,
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
--  ANTI-AIM TAB
-- ════════════════════════════════════════════════════════════════
local AAStanding = Tabs.AntiAim:AddLeftGroupbox('Standing')
local AAMoving   = Tabs.AntiAim:AddRightGroupbox('Moving / Air')

AAStanding:AddToggle('AAEnabled', { Text = 'Enable', Default = false })
AAStanding:AddDivider()
AAStanding:AddDropdown('AAPitch',  { Text = 'Pitch',  Values = {'Off','Down','Up','Zero'},              Default = 2 })
AAStanding:AddDropdown('AAYaw',    { Text = 'Yaw',    Values = {'Off','Spin','Jitter','Static','Side'}, Default = 3 })
AAStanding:AddSlider('AAYawOffset',{ Text = 'Yaw Offset', Default = 0, Min = -180, Max = 180, Rounding = 0, Suffix = '°' })
AAStanding:AddDropdown('AADesync', { Text = 'Desync', Values = {'Off','Invert','Freestanding'}, Default = 2 })
AAStanding:AddSlider('AADesyncRange', { Text = 'Desync Range', Default = 60, Min = 0, Max = 60, Rounding = 0, Suffix = '°' })

AAMoving:AddDropdown('AAMovingPitch', { Text = 'Pitch (Moving)', Values = {'Inherit','Down','Up','Zero'},    Default = 1 })
AAMoving:AddDropdown('AAMovingYaw',   { Text = 'Yaw (Moving)',   Values = {'Inherit','Spin','Jitter','Static'}, Default = 1 })
AAMoving:AddDivider()
AAMoving:AddDropdown('AAAirPitch',    { Text = 'Pitch (Air)',    Values = {'Inherit','Down','Up','Zero'},    Default = 1 })
AAMoving:AddDropdown('AAAirYaw',      { Text = 'Yaw (Air)',      Values = {'Inherit','Spin','Jitter','Static'}, Default = 1 })
AAMoving:AddDivider()
AAMoving:AddToggle('AASlowwalk', { Text = 'Slow Walk', Default = false })
local SWDep = AAMoving:AddDependencyBox()
SWDep:AddSlider('AASlowwalkSpeed', { Text = 'Speed', Default = 100, Min = 1, Max = 200, Rounding = 0, Suffix = '%' })
SWDep:SetupDependencies({ { Toggles.AASlowwalk, true } })

-- ════════════════════════════════════════════════════════════════
--  LEGITBOT TAB
-- ════════════════════════════════════════════════════════════════
local LBAimbot  = Tabs.Legitbot:AddLeftGroupbox('Aimbot')
local LBTrigger = Tabs.Legitbot:AddRightGroupbox('Triggerbot')

LBAimbot:AddToggle('LBEnabled', { Text = 'Enable', Default = false })
LBAimbot:AddDropdown('LBKey',    { Text = 'Activation Key', Values = {'Mouse 2','Mouse 4','Shift','Alt'}, Default = 1 })
LBAimbot:AddDropdown('LBHitbox', { Text = 'Hitbox', Values = {'Head','Neck','Chest','Nearest'}, Default = 1 })
LBAimbot:AddSlider('LBFOV',    { Text = 'FOV',    Default = 5,   Min = 1, Max = 180, Rounding = 0, Suffix = '°' })
LBAimbot:AddSlider('LBSmooth', { Text = 'Smooth', Default = 5,   Min = 1, Max = 20,  Rounding = 1 })
LBAimbot:AddSlider('LBRCS_X',  { Text = 'RCS X',  Default = 100, Min = 0, Max = 200, Rounding = 0, Suffix = '%' })
LBAimbot:AddSlider('LBRCS_Y',  { Text = 'RCS Y',  Default = 100, Min = 0, Max = 200, Rounding = 0, Suffix = '%' })
LBAimbot:AddDivider()
LBAimbot:AddToggle('LBAimstep', { Text = 'Aim Step', Default = false })
local ASDep = LBAimbot:AddDependencyBox()
ASDep:AddSlider('LBAimstepSize', { Text = 'Step Size', Default = 3, Min = 1, Max = 30, Rounding = 1 })
ASDep:SetupDependencies({ { Toggles.LBAimstep, true } })

LBTrigger:AddToggle('TBEnabled', { Text = 'Enable', Default = false })
LBTrigger:AddDropdown('TBKey', { Text = 'Activation Key', Values = {'Mouse 2','Mouse 4','Alt','Always'}, Default = 1 })
LBTrigger:AddSlider('TBDelay', { Text = 'Shot Delay',  Default = 50,  Min = 0, Max = 500, Rounding = 0, Suffix = 'ms' })
LBTrigger:AddSlider('TBBurst', { Text = 'Burst Delay', Default = 150, Min = 0, Max = 500, Rounding = 0, Suffix = 'ms' })
LBTrigger:AddDivider()
LBTrigger:AddToggle('TBMinDmg', { Text = 'Min Damage', Default = false })
local TBDep = LBTrigger:AddDependencyBox()
TBDep:AddSlider('TBDamage', { Text = 'Damage', Default = 1, Min = 1, Max = 100, Rounding = 0 })
TBDep:SetupDependencies({ { Toggles.TBMinDmg, true } })

-- ════════════════════════════════════════════════════════════════
--  PLAYERS (VISUALS) TAB
-- ════════════════════════════════════════════════════════════════
local VESP  = Tabs.Players:AddLeftGroupbox('ESP')
local VGlow = Tabs.Players:AddRightGroupbox('Glow')

VESP:AddToggle('ESPEnabled',   { Text = 'Enable',    Default = false })
VESP:AddToggle('ESPEnemyOnly', { Text = 'Enemy Only',Default = true  })
VESP:AddDivider()
VESP:AddToggle('ESPBox', { Text = 'Box', Default = false })
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
VGlow:AddDivider()
local VChams = Tabs.Players:AddRightGroupbox('Chams')
VChams:AddToggle('ChamsEnabled', { Text = 'Enable', Default = false })
VChams:AddDropdown('ChamsMat', { Text = 'Material', Values = {'Flat','Shiny','Reflective'}, Default = 1 })
VChams:AddToggle('ChamsXQZ', { Text = 'Through Walls', Default = false })
VChams:AddLabel('Visible Color'):AddColorPicker('ChamsVisColor', { Default = Color3.fromRGB(52,152,255), Transparency = 0   })
VChams:AddLabel('Occluded Color'):AddColorPicker('ChamsOccColor',{ Default = Color3.fromRGB(60,60,200),  Transparency = 0.4 })

-- ════════════════════════════════════════════════════════════════
--  MAIN (MISC) TAB  — mirrors the NL screenshot layout exactly
-- ════════════════════════════════════════════════════════════════
local MiscMov  = Tabs.Main:AddLeftGroupbox('Movement')
local MiscSpam = Tabs.Main:AddLeftGroupbox('Spammers')
local MiscOth  = Tabs.Main:AddRightGroupbox('Other')
local MiscBuy  = Tabs.Main:AddRightGroupbox('BuyBot')

-- Movement (matches screenshot)
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

-- Spammers
MiscSpam:AddToggle('Clantag',  { Text = 'Clantag',   Default = false })
MiscSpam:AddToggle('ChatSpam', { Text = 'Chat Spam', Default = false })

-- Other
MiscOth:AddToggle('AntiUntrusted',    { Text = 'Anti Untrusted',     Default = false })
MiscOth:AddDropdown('EventLog', {
    Text = 'Event Log',
    Values = { 'Off', 'Damage', 'Hurt', 'Spawn', 'All' },
    Default = 1, Multi = true,
})
MiscOth:AddDropdown('Windows', {
    Text = 'Windows',
    Values = { 'Binds List', 'Spectators', 'Watermark' },
    Default = 1, Multi = true,
})
MiscOth:AddToggle('FilterServerAds',  { Text = 'Filter server ads',   Default = true  })
MiscOth:AddToggle('FilterConsole',    { Text = 'Filter Console',      Default = false })
MiscOth:AddToggle('UnlockCvars',      { Text = 'Unlock Cvars',        Default = false })
MiscOth:AddToggle('FastReload',       { Text = 'Fast Reload',         Default = true  })
MiscOth:AddToggle('FastWeaponSwitch', { Text = 'Fast Weapon Switch',  Default = true  })
MiscOth:AddSlider('FakePing', {
    Text = 'Fake Ping', Default = 0, Min = 0, Max = 200, Rounding = 0, HideMax = true,
})

-- BuyBot
MiscBuy:AddToggle('BuybotEnabled', { Text = 'Enable BuyBot', Default = false })
MiscBuy:AddDropdown('BuybotPrimary', {
    Text = 'Primary',
    Values = { 'AK-47', 'M4A4', 'M4A1-S', 'AWP', 'SG 553', 'AUG', 'FAMAS' },
    Default = 4,
})
MiscBuy:AddDropdown('BuybotSecondary', {
    Text = 'Secondary',
    Values = { 'Glock-18', 'USP-S', 'P2000', 'Desert Eagle', 'R8/Desert Eagle', 'Five-SeveN' },
    Default = 5,
})
MiscBuy:AddDropdown('BuybotEquip', {
    Text = 'Equipment',
    Values = { 'Kevlar', 'Kevlar + Helmet', 'Assaultsuit', 'Zeus', 'Defuse Kit' },
    Default = 2, Multi = true,
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
