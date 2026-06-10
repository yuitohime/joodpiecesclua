-- =========================================================================
-- [ANTI-CRASH] YUIHUB V17 (INDEPENDENT WAYPOINT, CYCLE FIX, STAT TYPES) - JOOD PIECE
-- =========================================================================

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")

local TargetGui = (gethui and pcall(gethui) and gethui()) or CoreGui
if not pcall(function() local _ = TargetGui.Name end) then TargetGui = LocalPlayer:WaitForChild("PlayerGui") end
for _, gui in pairs(TargetGui:GetChildren()) do if gui.Name == "YuiHub_Jood" then gui:Destroy() end end

-- ============================
-- SOUND SYSTEM (MEOW)
-- ============================
local function PlayMeow()
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://9068000078"
        s.Volume = 1
        s.Parent = CoreGui
        s:Play()
        game:GetService("Debris"):AddItem(s, 2)
    end)
end

-- ============================
-- GLOBAL SETTINGS & CONFIG SYSTEM
-- ============================
_G.Yui = {
    FarmSelectedMob = false, FarmAllMobs = false, FarmSummonBoss = false, AutoFarmWorldBoss = false,
    SelectedWorldBoss = "", SelectedBossToSummon = "", AutoSummonBoss = false, AutoSummonLuffy = false, AutoSummonGojo = false, AutoSummonCellsmax = false, 
    SelectedMobsList = {}, 
    
    Waypoints = {}, FarmWaypoints = false, WaypointDelay = 5,

    KillAuraIsland = false, LockedIslandCenter = nil, IslandRadius = 600,
    AttackDist = 6, AttackPos = "Above", AutoAttack = true, IsNearTarget = false,
    SelectedMainWeapon = "", AutoEquipMain = false,
    CycleWeaponsList = {}, AutoCycleWeapons = false, CycleDelay = 1.0,
    AutoSkill = {Z = false, X = false, C = false, V = false, B = false, F = false}, SkillDelay = 100, TweenSpeed = 350,
    AutoStatEnabled = false, TargetStatsList = {}, StatAmount = 1, StatDelay = 1000,
    TargetBuyItemsList = {}, AutoBuyAllSelected = false, AutoStoreItems = false, SelectedNPC = "",
    AutoRoll = false, RollType = "x1",
    TargetHakiList = {}, AutoRollHaki = false,
    TargetStatTierList = {}, AutoRollStatsTier = false, TargetStatType = "Any", -- NEW: STAT TYPE
    WalkSpeed = 150, JumpPower = 150, EnableWS = false, EnableJP = false, Noclip = false, Fly = false, FlySpeed = 100,
    ConfigName = "Default", AutoLoad = false
}

local ConfigUpdaters = {}
local DefaultValues = {}
local CurrentTarget = nil
local AllDropdowns = {}

local currentWaypointIndex = 1

-- ============================
-- CACHE SYSTEM
-- ============================
local CachedRemotes = { Shop = {}, Store = {}, Summon = {}, Codes = {} }
local StatsRemote = nil

task.spawn(function()
    for _, r in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
            local rName = string.lower(r.Name)
            if string.find(rName, "refund") or string.find(rName, "reset") or string.find(rName, "clear") then continue end
            if not string.find(rName, "bp") and not string.find(rName, "event") then
                if r.Name == "UpgradeStats" and not StatsRemote then StatsRemote = r end
                if string.find(rName, "merchant") or string.find(rName, "buy") or string.find(rName, "shop") then table.insert(CachedRemotes.Shop, r) end
                if string.find(rName, "store") or string.find(rName, "inv") then table.insert(CachedRemotes.Store, r) end
                if string.find(rName, "summon") or string.find(rName, "boss") then table.insert(CachedRemotes.Summon, r) end
                if string.find(rName, "code") or string.find(rName, "redeem") then table.insert(CachedRemotes.Codes, r) end
            end
        end
    end
end)

-- ============================
-- UTILITY FUNCTIONS
-- ============================
local function TrimMobName(name)
    local trimmed = string.match(tostring(name), "^(.-)%s*%d*$")
    return (trimmed and trimmed ~= "") and trimmed or tostring(name)
end

local function IsValidMob(obj)
    if not obj:IsA("Model") then return false end
    if obj == LocalPlayer.Character or Players:GetPlayerFromCharacter(obj) then return false end
    local hum = obj:FindFirstChildOfClass("Humanoid")
    local root = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
    if not hum or not root or hum.Health <= 0 then return false end
    
    local lowerName = string.lower(obj.Name)
    local blacklist = { 
        "dummy", "statue", "base", "nexus", "quest", "merchant", "dealer", "vendor", "npc", "citizen", 
        "seller", "sell", "villager", "shop", "spawn", "stand", "summon", "towerraid", "chest", "drop", 
        "tree", "wood", "leaf", "bush", "hat", "heaven piece hat", "cape", "shirt", "pants", "armor", 
        "accessory", "clothing", "item" 
    }
    for _, word in ipairs(blacklist) do if string.find(lowerName, word) then return false end end
    return true
end

local function CloseAllDropdowns()
    for _, dd in ipairs(AllDropdowns) do dd.Visible = false end
end

local function InteractWithNPC(npcNameMatch)
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") and string.find(string.lower(obj.Name), string.lower(npcNameMatch)) then
            local cd = obj:FindFirstChildOfClass("ClickDetector", true)
            if cd then fireclickdetector(cd) return true end
            local pp = obj:FindFirstChildOfClass("ProximityPrompt", true)
            if pp then fireproximityprompt(pp) return true end
        end
    end
    return false
end

local function CheckPlayerUIForText(targetList, requiredText)
    local found = false
    for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if (gui:IsA("TextLabel") or gui:IsA("TextBox")) and gui.Visible and gui.Text ~= "" then
            local rawText = string.lower(string.gsub(gui.Text, " ", ""))
            for targetItem, isSelected in pairs(targetList) do
                if isSelected then
                    local targetLower = string.lower(string.gsub(targetItem, " ", ""))
                    if string.find(rawText, targetLower) then
                        if requiredText and requiredText ~= "Any" then
                            local reqLower = string.lower(string.gsub(requiredText, " ", ""))
                            if string.find(rawText, reqLower) then
                                found = true break
                            end
                        else
                            found = true break
                        end
                    end
                end
            end
        end
        if found then break end
    end
    return found
end

-- ============================
-- THEME & UI SETUP
-- ============================
local Theme = {
    MainBg = Color3.fromRGB(15, 15, 18), HeaderBg = Color3.fromRGB(22, 22, 25),
    BoxBg = Color3.fromRGB(20, 20, 23), Accent = Color3.fromRGB(0, 170, 255),
    TextTitle = Color3.fromRGB(255, 255, 255), TextSub = Color3.fromRGB(140, 140, 140),
    Stroke = Color3.fromRGB(35, 35, 40)
}

local CustomImageURL = "rbxthumb://type=Asset&id=101378043060345&w=150&h=150"
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "YuiHub_Jood" ScreenGui.Parent = TargetGui ScreenGui.ResetOnSpawn = false

-- FIXED ICON
local OpenIcon = Instance.new("ImageButton", ScreenGui)
OpenIcon.Size = UDim2.new(0, 50, 0, 50) 
OpenIcon.Position = UDim2.new(0, 0, 0.5, -25) 
OpenIcon.BackgroundColor3 = Theme.HeaderBg
OpenIcon.Image = CustomImageURL OpenIcon.Visible = false OpenIcon.Active = true
Instance.new("UICorner", OpenIcon).CornerRadius = UDim.new(0, 8) Instance.new("UIStroke", OpenIcon).Color = Theme.Accent

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 480, 0, 320) 
MainFrame.Position = UDim2.new(0.5, -240, 0.5, -160) 
MainFrame.BackgroundColor3 = Theme.MainBg MainFrame.BorderSizePixel = 0 MainFrame.Active = true MainFrame.Visible = false
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8) 
local MainStroke = Instance.new("UIStroke", MainFrame) MainStroke.Color = Theme.Accent MainStroke.Thickness = 1.5

local dragToggleIcon, dragStartIcon, startPosIcon
OpenIcon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragToggleIcon = true dragStartIcon = input.Position startPosIcon = OpenIcon.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragToggleIcon = false end end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragToggleIcon and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local Delta = input.Position - dragStartIcon
        OpenIcon.Position = UDim2.new(startPosIcon.X.Scale, startPosIcon.X.Offset + Delta.X, startPosIcon.Y.Scale, startPosIcon.Y.Offset + Delta.Y)
    end
end)

OpenIcon.MouseButton1Click:Connect(function() 
    PlayMeow()
    MainFrame.Visible = not MainFrame.Visible 
    CloseAllDropdowns()
end)

local Header = Instance.new("Frame", MainFrame)
Header.Size = UDim2.new(1, -20, 0, 60) Header.Position = UDim2.new(0, 10, 0, 10) Header.BackgroundColor3 = Theme.HeaderBg
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 8) Instance.new("UIStroke", Header).Color = Theme.Stroke

local BlueLine = Instance.new("Frame", Header) BlueLine.Size = UDim2.new(0, 3, 0, 30) BlueLine.Position = UDim2.new(0, 15, 0, 15) BlueLine.BackgroundColor3 = Theme.Accent Instance.new("UICorner", BlueLine).CornerRadius = UDim.new(1, 0)
local HubName = Instance.new("TextLabel", Header) HubName.Size = UDim2.new(0, 300, 0, 25) HubName.Position = UDim2.new(0, 30, 0, 17) HubName.BackgroundTransparency = 1 
HubName.Text = '<font color="rgb(0,170,255)">Yui</font> HUB - JOOD PIECE'
HubName.RichText = true HubName.TextColor3 = Theme.TextTitle HubName.Font = Enum.Font.GothamBold HubName.TextSize = 18 HubName.TextXAlignment = Enum.TextXAlignment.Left

local MinimizeBtn = Instance.new("TextButton", Header) MinimizeBtn.Size = UDim2.new(0, 30, 0, 30) MinimizeBtn.Position = UDim2.new(1, -65, 0, 15) MinimizeBtn.BackgroundTransparency = 1 MinimizeBtn.Text = "—" MinimizeBtn.TextColor3 = Theme.TextTitle MinimizeBtn.Font = Enum.Font.GothamBold MinimizeBtn.TextSize = 14
MinimizeBtn.MouseButton1Click:Connect(function() 
    PlayMeow() 
    MainFrame.Visible = false 
    CloseAllDropdowns() 
end)

local CloseBtn = Instance.new("TextButton", Header) CloseBtn.Size = UDim2.new(0, 30, 0, 30) CloseBtn.Position = UDim2.new(1, -35, 0, 15) CloseBtn.BackgroundTransparency = 1 CloseBtn.Text = "✕" CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80) CloseBtn.Font = Enum.Font.GothamBold CloseBtn.TextSize = 14
CloseBtn.MouseButton1Click:Connect(function() PlayMeow() ScreenGui:Destroy() end)

local dragToggle, dragInput, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        _G.IsDraggingUI = true dragToggle = true dragStart = input.Position startPos = MainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragToggle = false _G.IsDraggingUI = false end end)
    end
end)
Header.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragToggle then
        local Delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + Delta.X, startPos.Y.Scale, startPos.Y.Offset + Delta.Y)
    end
end)

local Sidebar = Instance.new("ScrollingFrame", MainFrame)
Sidebar.Size = UDim2.new(0, 115, 1, -90) Sidebar.Position = UDim2.new(0, 10, 0, 80) Sidebar.BackgroundTransparency = 1 
Sidebar.ScrollBarThickness = 2 Sidebar.ScrollBarImageColor3 = Theme.Accent
local SidebarLayout = Instance.new("UIListLayout", Sidebar) SidebarLayout.Padding = UDim.new(0, 5)

SidebarLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Sidebar.CanvasSize = UDim2.new(0, 0, 0, SidebarLayout.AbsoluteContentSize.Y + 15)
end)

local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size = UDim2.new(1, -140, 1, -90) ContentArea.Position = UDim2.new(0, 130, 0, 80) ContentArea.BackgroundTransparency = 1

local Tabs = {}
local function CreateTab(name, isActive)
    local TabBtn = Instance.new("TextButton", Sidebar) TabBtn.Size = UDim2.new(1, -5, 0, 30) TabBtn.BackgroundColor3 = isActive and Theme.BoxBg or Theme.MainBg TabBtn.Text = "  " .. name TabBtn.TextColor3 = isActive and Theme.TextTitle or Theme.TextSub TabBtn.Font = Enum.Font.GothamBold TabBtn.TextSize = 11 TabBtn.TextXAlignment = Enum.TextXAlignment.Left Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 6)
    local ActiveLine = Instance.new("Frame", TabBtn) ActiveLine.Size = UDim2.new(0, 3, 0.6, 0) ActiveLine.Position = UDim2.new(0, 0, 0.2, 0) ActiveLine.BackgroundColor3 = Theme.Accent ActiveLine.Visible = isActive Instance.new("UICorner", ActiveLine).CornerRadius = UDim.new(1, 0)

    local Page = Instance.new("Frame", ContentArea) Page.Size = UDim2.new(1, 0, 1, 0) Page.BackgroundTransparency = 1 Page.Visible = isActive
    local LeftCol = Instance.new("ScrollingFrame", Page) LeftCol.Size = UDim2.new(0.49, 0, 1, 0) LeftCol.BackgroundTransparency = 1 LeftCol.ScrollBarThickness = 2 local LeftLayout = Instance.new("UIListLayout", LeftCol) LeftLayout.Padding = UDim.new(0, 10)
    local RightCol = Instance.new("ScrollingFrame", Page) RightCol.Size = UDim2.new(0.49, 0, 1, 0) RightCol.Position = UDim2.new(0.51, 0, 0, 0) RightCol.BackgroundTransparency = 1 RightCol.ScrollBarThickness = 2 local RightLayout = Instance.new("UIListLayout", RightCol) RightLayout.Padding = UDim.new(0, 10)

    LeftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() LeftCol.CanvasSize = UDim2.new(0, 0, 0, LeftLayout.AbsoluteContentSize.Y + 20) end)
    RightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() RightCol.CanvasSize = UDim2.new(0, 0, 0, RightLayout.AbsoluteContentSize.Y + 20) end)

    table.insert(Tabs, {Btn = TabBtn, Line = ActiveLine, Page = Page})
    TabBtn.MouseButton1Click:Connect(function()
        PlayMeow()
        for _, tab in pairs(Tabs) do tab.Btn.BackgroundColor3 = Theme.MainBg tab.Btn.TextColor3 = Theme.TextSub tab.Line.Visible = false tab.Page.Visible = false end
        TabBtn.BackgroundColor3 = Theme.BoxBg TabBtn.TextColor3 = Theme.TextTitle ActiveLine.Visible = true Page.Visible = true
        CloseAllDropdowns()
    end)
    return LeftCol, RightCol
end

local function CreateSection(titleText, parentCol)
    local Box = Instance.new("Frame", parentCol) Box.BackgroundColor3 = Theme.BoxBg Box.Size = UDim2.new(1, 0, 0, 50) Instance.new("UICorner", Box).CornerRadius = UDim.new(0, 6)
    local Stroke = Instance.new("UIStroke", Box) Stroke.Color = Theme.Accent Stroke.Thickness = 1.2
    
    local Title = Instance.new("TextLabel", Box) Title.Size = UDim2.new(1, -20, 0, 20) Title.Position = UDim2.new(0, 10, 0, 5) Title.BackgroundTransparency = 1 Title.Text = titleText Title.TextColor3 = Theme.Accent Title.Font = Enum.Font.GothamBold Title.TextSize = 11 Title.TextXAlignment = Enum.TextXAlignment.Left
    local Line = Instance.new("Frame", Box) Line.Size = UDim2.new(1, -20, 0, 1) Line.Position = UDim2.new(0, 10, 0, 25) Line.BackgroundColor3 = Theme.Stroke Line.BorderSizePixel = 0
    
    local Container = Instance.new("Frame", Box) Container.Size = UDim2.new(1, -20, 1, -35) Container.Position = UDim2.new(0, 10, 0, 30) Container.BackgroundTransparency = 1 local Layout = Instance.new("UIListLayout", Container) Layout.Padding = UDim.new(0, 8)
    Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() Box.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y + 40) end)
    return Container
end

local function CreateToggle(configKey, labelText, default, parentBox, callback)
    DefaultValues[configKey] = default
    local Frame = Instance.new("Frame", parentBox) Frame.Size = UDim2.new(1, 0, 0, 26) Frame.BackgroundTransparency = 1 Frame.ZIndex = 3
    local Label = Instance.new("TextLabel", Frame) Label.Size = UDim2.new(1, -50, 1, 0) Label.BackgroundTransparency = 1 Label.Text = labelText Label.TextColor3 = Theme.TextTitle Label.Font = Enum.Font.GothamBold Label.TextSize = 10 Label.TextXAlignment = Enum.TextXAlignment.Left Label.ZIndex = 3
    local Bg = Instance.new("TextButton", Frame) Bg.Size = UDim2.new(0, 32, 0, 16) Bg.Position = UDim2.new(1, -32, 0.5, -8) Bg.BackgroundColor3 = default and Theme.Accent or Theme.MainBg Bg.Text = "" Bg.ZIndex = 3 Instance.new("UICorner", Bg).CornerRadius = UDim.new(1, 0) Instance.new("UIStroke", Bg).Color = Theme.Stroke
    local Knob = Instance.new("Frame", Bg) Knob.Size = UDim2.new(0, 12, 0, 12) Knob.Position = default and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6) Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255) Knob.ZIndex = 4 Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

    local isOn = default
    local function setVal(v)
        isOn = v
        TweenService:Create(Knob, TweenInfo.new(0.2), {Position = isOn and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)}):Play() 
        TweenService:Create(Bg, TweenInfo.new(0.2), {BackgroundColor3 = isOn and Theme.Accent or Theme.MainBg}):Play() 
        callback(v)
    end
    Bg.MouseButton1Click:Connect(function() PlayMeow() setVal(not isOn) end)
    if configKey then ConfigUpdaters[configKey] = setVal end
    return setVal
end

local function CreateMultiDropdown(configKey, labelStr, parentBox, globalList)
    DefaultValues[configKey] = {}
    local Frame = Instance.new("Frame", parentBox) Frame.Size = UDim2.new(1, 0, 0, 26) Frame.BackgroundTransparency = 1 Frame.ZIndex = 3
    local Label = Instance.new("TextLabel", Frame) Label.Size = UDim2.new(0.4, 0, 1, 0) Label.BackgroundTransparency = 1 Label.Text = labelStr Label.TextColor3 = Theme.TextTitle Label.Font = Enum.Font.GothamBold Label.TextSize = 10 Label.TextXAlignment = Enum.TextXAlignment.Left Label.ZIndex = 3
    local Btn = Instance.new("TextButton", Frame) Btn.Size = UDim2.new(0.6, 0, 1, 0) Btn.Position = UDim2.new(0.4, 0, 0, 0) Btn.BackgroundColor3 = Theme.MainBg Btn.TextColor3 = Theme.TextSub Btn.Font = Enum.Font.Gotham Btn.TextSize = 10 Btn.Text = "Select ▼" Btn.ZIndex = 3 Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 4) Instance.new("UIStroke", Btn).Color = Theme.Stroke
    local FloatFrame = Instance.new("ScrollingFrame", ScreenGui) FloatFrame.Size = UDim2.new(0, 160, 0, 150) FloatFrame.BackgroundColor3 = Theme.HeaderBg FloatFrame.ZIndex = 999 FloatFrame.Visible = false FloatFrame.ScrollBarThickness = 2 Instance.new("UICorner", FloatFrame).CornerRadius = UDim.new(0, 4) Instance.new("UIStroke", FloatFrame).Color = Theme.Accent Instance.new("UIListLayout", FloatFrame)
    table.insert(AllDropdowns, FloatFrame)

    RunService.RenderStepped:Connect(function() if FloatFrame.Visible then FloatFrame.Position = UDim2.new(0, Btn.AbsolutePosition.X - (160 - Btn.AbsoluteSize.X), 0, Btn.AbsolutePosition.Y + Btn.AbsoluteSize.Y + 2) end end)
    local isOpen = false Btn.MouseButton1Click:Connect(function() PlayMeow() CloseAllDropdowns() isOpen = not isOpen FloatFrame.Visible = isOpen end)

    local buttons = {}
    local function populate(itemList)
        for _, v in pairs(FloatFrame:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        local h = 0 buttons = {}
        for _, item in ipairs(itemList) do
            local b = Instance.new("TextButton", FloatFrame) b.Size = UDim2.new(1, 0, 0, 25) 
            b.Font = Enum.Font.GothamBold b.TextSize = 9 b.TextXAlignment = Enum.TextXAlignment.Center b.ZIndex = 1000
            b.Text = item
            
            local function updateVisual(state)
                globalList[item] = state
                if state then b.BackgroundColor3 = Theme.Accent b.TextColor3 = Color3.fromRGB(255, 255, 255) else b.BackgroundColor3 = Theme.HeaderBg b.TextColor3 = Theme.TextSub end
            end
            updateVisual(globalList[item] or false)
            buttons[item] = updateVisual

            h = h + 25
            b.MouseButton1Click:Connect(function() PlayMeow() updateVisual(not globalList[item]) end)
        end
        FloatFrame.CanvasSize = UDim2.new(0, 0, 0, h)
    end
    
    if configKey then
        ConfigUpdaters[configKey] = function(loadedList)
            for k, v in pairs(globalList) do globalList[k] = false if buttons[k] then buttons[k](false) end end
            for k, v in pairs(loadedList) do if v and buttons[k] then buttons[k](true) end end
        end
    end
    return populate
end

local function CreateDropdown(configKey, labelStr, defaultStr, parentBox, callback)
    DefaultValues[configKey] = defaultStr
    local Frame = Instance.new("Frame", parentBox) Frame.Size = UDim2.new(1, 0, 0, 26) Frame.BackgroundTransparency = 1 Frame.ZIndex = 3
    local Label = Instance.new("TextLabel", Frame) Label.Size = UDim2.new(0.5, 0, 1, 0) Label.BackgroundTransparency = 1 Label.Text = labelStr Label.TextColor3 = Theme.TextTitle Label.Font = Enum.Font.GothamBold Label.TextSize = 10 Label.TextXAlignment = Enum.TextXAlignment.Left Label.ZIndex = 3
    local Btn = Instance.new("TextButton", Frame) Btn.Size = UDim2.new(0.5, 0, 1, 0) Btn.Position = UDim2.new(0.5, 0, 0, 0) Btn.BackgroundColor3 = Theme.MainBg Btn.TextColor3 = Theme.TextSub Btn.Font = Enum.Font.Gotham Btn.TextSize = 10 Btn.Text = defaultStr .. " ▼" Btn.ZIndex = 3 Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 4) Instance.new("UIStroke", Btn).Color = Theme.Stroke
    local FloatFrame = Instance.new("ScrollingFrame", ScreenGui) FloatFrame.Size = UDim2.new(0, 140, 0, 100) FloatFrame.BackgroundColor3 = Theme.HeaderBg FloatFrame.ZIndex = 999 FloatFrame.Visible = false FloatFrame.ScrollBarThickness = 2 Instance.new("UICorner", FloatFrame).CornerRadius = UDim.new(0, 4) Instance.new("UIStroke", FloatFrame).Color = Theme.Accent Instance.new("UIListLayout", FloatFrame)
    table.insert(AllDropdowns, FloatFrame)

    RunService.RenderStepped:Connect(function() if FloatFrame.Visible then FloatFrame.Position = UDim2.new(0, Btn.AbsolutePosition.X - (140 - Btn.AbsoluteSize.X), 0, Btn.AbsolutePosition.Y + Btn.AbsoluteSize.Y + 2) end end)
    local isOpen = false Btn.MouseButton1Click:Connect(function() PlayMeow() CloseAllDropdowns() isOpen = not isOpen FloatFrame.Visible = isOpen end)

    local function setVal(v) Btn.Text = v .. " ▼" callback(v) end
    if configKey then ConfigUpdaters[configKey] = setVal end

    local function populate(itemList)
        for _, v in pairs(FloatFrame:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
        local h = 0
        for _, item in ipairs(itemList) do
            local b = Instance.new("TextButton", FloatFrame) b.Size = UDim2.new(1, 0, 0, 25) b.BackgroundColor3 = Theme.HeaderBg b.TextColor3 = Theme.TextTitle b.Text = "  " .. item b.Font = Enum.Font.Gotham b.TextSize = 10 b.TextXAlignment = Enum.TextXAlignment.Left b.ZIndex = 1000
            h = h + 25
            b.MouseButton1Click:Connect(function() PlayMeow() setVal(item) isOpen = false FloatFrame.Visible = false end)
        end
        FloatFrame.CanvasSize = UDim2.new(0, 0, 0, h)
    end
    return populate
end

local function CreateButton(text, parentBox, callback)
    local Btn = Instance.new("TextButton", parentBox) Btn.Size = UDim2.new(1, 0, 0, 25) Btn.BackgroundColor3 = Theme.MainBg Btn.TextColor3 = Theme.TextTitle Btn.Font = Enum.Font.GothamBold Btn.TextSize = 10 Btn.Text = text Btn.ZIndex = 3 Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 4) Instance.new("UIStroke", Btn).Color = Theme.Stroke
    Btn.MouseButton1Click:Connect(function() PlayMeow() callback() end)
end

local function CreateSlider(configKey, labelText, min, max, default, parentBox, callback)
    DefaultValues[configKey] = default
    local Frame = Instance.new("Frame", parentBox) Frame.Size = UDim2.new(1, 0, 0, 36) Frame.BackgroundTransparency = 1 Frame.ZIndex = 3
    local Label = Instance.new("TextLabel", Frame) Label.Size = UDim2.new(1, 0, 0, 15) Label.BackgroundTransparency = 1 Label.Text = labelText Label.TextColor3 = Theme.TextTitle Label.Font = Enum.Font.GothamBold Label.TextSize = 10 Label.TextXAlignment = Enum.TextXAlignment.Left Label.ZIndex = 3
    local ValLabel = Instance.new("TextLabel", Frame) ValLabel.Size = UDim2.new(1, 0, 0, 15) ValLabel.BackgroundTransparency = 1 ValLabel.Text = tostring(default) ValLabel.TextColor3 = Theme.TextSub ValLabel.Font = Enum.Font.Gotham ValLabel.TextSize = 10 ValLabel.TextXAlignment = Enum.TextXAlignment.Right ValLabel.ZIndex = 3
    local Track = Instance.new("Frame", Frame) Track.Size = UDim2.new(1, 0, 0, 4) Track.Position = UDim2.new(0, 0, 0, 20) Track.BackgroundColor3 = Theme.MainBg Track.ZIndex = 3 Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0) Instance.new("UIStroke", Track).Color = Theme.Stroke
    local Fill = Instance.new("Frame", Track) Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0) Fill.BackgroundColor3 = Theme.Accent Fill.ZIndex = 3 Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)
    local Knob = Instance.new("TextButton", Fill) Knob.Size = UDim2.new(0, 12, 0, 12) Knob.Position = UDim2.new(1, -6, 0.5, -6) Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255) Knob.Text = "" Knob.ZIndex = 4 Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

    local drag = false
    local function setVal(v)
        v = math.clamp(v, min, max)
        Fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
        ValLabel.Text = tostring(v) callback(v)
    end
    if configKey then ConfigUpdaters[configKey] = setVal end

    local function update(input)
        local rel = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * rel) setVal(val)
    end
    Knob.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then drag = true end end)
    Track.InputBegan:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then drag = true update(inp) end end)
    UserInputService.InputEnded:Connect(function(inp) if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then drag = false end end)
    UserInputService.InputChanged:Connect(function(inp) if drag and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then update(inp) end end)
end

local function CreateTextBox(configKey, labelText, default, parentBox, callback)
    local Frame = Instance.new("Frame", parentBox) Frame.Size = UDim2.new(1, 0, 0, 26) Frame.BackgroundTransparency = 1 Frame.ZIndex = 3
    local Label = Instance.new("TextLabel", Frame) Label.Size = UDim2.new(0.5, 0, 1, 0) Label.BackgroundTransparency = 1 Label.Text = labelText Label.TextColor3 = Theme.TextTitle Label.Font = Enum.Font.GothamBold Label.TextSize = 10 Label.TextXAlignment = Enum.TextXAlignment.Left Label.ZIndex = 3
    local Input = Instance.new("TextBox", Frame) Input.Size = UDim2.new(0.5, 0, 0, 20) Input.Position = UDim2.new(0.5, 0, 0.5, -10) Input.BackgroundColor3 = Theme.MainBg Input.TextColor3 = Theme.TextTitle Input.Font = Enum.Font.Gotham Input.TextSize = 10 Input.Text = tostring(default) Input.ZIndex = 3
    Instance.new("UICorner", Input).CornerRadius = UDim.new(0, 4) Instance.new("UIStroke", Input).Color = Theme.Stroke
    
    if configKey then
        DefaultValues[configKey] = default
        ConfigUpdaters[configKey] = function(v) Input.Text = tostring(v) callback(v) end
    end
    Input.FocusLost:Connect(function() callback(Input.Text) end)
end

-- ============================
-- INIT TABS
-- ============================
local MainL, MainR = CreateTab("Farm Mobs", true)
local BossL, BossR = CreateTab("Boss & Aura", false)
local SkillL, SkillR = CreateTab("Auto Skills", false)
local ShopL, ShopR = CreateTab("Shop & Store", false)
local StatL, StatR = CreateTab("Stats & Codes", false)
local PlayerL, PlayerR = CreateTab("Local Player", false)
local SysL, SysR = CreateTab("Server & Cfg", false)

-- ====== TAB: MAIN FARM ======
local WaypointBox = CreateSection("Island Waypoint System", MainL)
local WaypointDrop = CreateDropdown("SelectedWaypoint", "Saved Islands List", "None", WaypointBox, function(v) end)

local function UpdateWaypointDropdownUI()
    local list = {}
    for i, _ in ipairs(_G.Yui.Waypoints) do table.insert(list, "Island " .. i) end
    if #list == 0 then list = {"None"} end
    WaypointDrop(list)
end

CreateButton("Save Current Island Position", WaypointBox, function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local pos = char.HumanoidRootPart.Position
        table.insert(_G.Yui.Waypoints, {X = pos.X, Y = pos.Y, Z = pos.Z})
        UpdateWaypointDropdownUI()
    end
end)
CreateButton("Clear All Saved Islands", WaypointBox, function()
    _G.Yui.Waypoints = {} UpdateWaypointDropdownUI()
end)
CreateSlider("WaypointDelay", "Teleport Delay (s)", 1, 60, 5, WaypointBox, function(v) _G.Yui.WaypointDelay = v end)
CreateToggle("FarmWaypoints", "Enable Auto Teleport Loop", false, WaypointBox, function(v) _G.Yui.FarmWaypoints = v end)

-- CHỨC NĂNG TELEPORT ĐỘC LẬP HOÀN TOÀN
task.spawn(function()
    while true do
        task.wait(_G.Yui.WaypointDelay)
        if _G.Yui.FarmWaypoints and #_G.Yui.Waypoints > 0 then
            pcall(function()
                local char = LocalPlayer.Character
                if char and char.PrimaryPart then
                    currentWaypointIndex = currentWaypointIndex + 1
                    if currentWaypointIndex > #_G.Yui.Waypoints then currentWaypointIndex = 1 end
                    local wp = _G.Yui.Waypoints[currentWaypointIndex]
                    char.PrimaryPart.CFrame = CFrame.new(wp.X, wp.Y + 10, wp.Z)
                end
            end)
        end
    end
end)

local FarmSetBox = CreateSection("Farming Mobs", MainL)
local UpdateMultiMob = CreateMultiDropdown("SelectedMobsList", "Select Mobs", FarmSetBox, _G.Yui.SelectedMobsList)
CreateButton("Scan All Mobs", FarmSetBox, function()
    local temp = {} local list = {}
    for _, obj in pairs(Workspace:GetDescendants()) do
        if IsValidMob(obj) then
            local bName = TrimMobName(obj.Name)
            if not temp[bName] then temp[bName] = true table.insert(list, bName) end
        end
    end
    table.sort(list) UpdateMultiMob(list)
end)
CreateToggle("FarmSelectedMob", "Farm Selected Mobs", false, FarmSetBox, function(v) _G.Yui.FarmSelectedMob = v end)
CreateToggle("FarmAllMobs", "Farm All Mobs", false, FarmSetBox, function(v) _G.Yui.FarmAllMobs = v end)

local MainWepBox = CreateSection("Auto Equip Weapon", MainR)
local UpdateMainWep = CreateDropdown("SelectedMainWeapon", "Select Weapon", "None", MainWepBox, function(v) _G.Yui.SelectedMainWeapon = v end)
CreateButton("Refresh Weapons", MainWepBox, function()
    local t = {} 
    for _, v in pairs(LocalPlayer.Backpack:GetChildren()) do if v:IsA("Tool") then table.insert(t, v.Name) end end
    for _, v in pairs(LocalPlayer.Character:GetChildren()) do if v:IsA("Tool") then table.insert(t, v.Name) end end
    UpdateMainWep(t)
end)
CreateToggle("AutoEquipMain", "Auto Equip", false, MainWepBox, function(v) _G.Yui.AutoEquipMain = v end)

-- FIX: AUTO EQUIP VŨ KHÍ KHÔNG CẦN CÓ QUÁI
task.spawn(function()
    while task.wait(0.5) do
        if _G.Yui.AutoEquipMain and _G.Yui.SelectedMainWeapon ~= "" then
            pcall(function()
                local char = LocalPlayer.Character
                local bp = LocalPlayer.Backpack
                if char and bp then
                    local tool = bp:FindFirstChild(_G.Yui.SelectedMainWeapon)
                    if tool then char.Humanoid:EquipTool(tool) end
                end
            end)
        end
    end
end)

local ConfigBox = CreateSection("Farming Config", MainR)
CreateToggle("AutoAttack", "Auto Attack", true, ConfigBox, function(v) _G.Yui.AutoAttack = v end)
local UpdatePosDropdown = CreateDropdown("AttackPos", "Attack Position", "Above", ConfigBox, function(v) _G.Yui.AttackPos = v end)
UpdatePosDropdown({"Above", "Below", "Behind", "Front"})
CreateSlider("AttackDist", "Attack Distance", 1, 30, 6, ConfigBox, function(v) _G.Yui.AttackDist = v end)

-- ====== TAB: BOSS & AURA ======
local BossBox = CreateSection("World Bosses", BossL)
local UpdateWorldBoss = CreateDropdown("SelectedWorldBoss", "Select World Boss", "Doraemon", BossBox, function(v) _G.Yui.SelectedWorldBoss = v end)
UpdateWorldBoss({"Doraemon", "Speed", "Akaza", "Vergil", "Itachi", "Spaceship"})
CreateToggle("AutoFarmWorldBoss", "Auto Farm World Boss", false, BossBox, function(v) _G.Yui.AutoFarmWorldBoss = v end)

local SummonBox = CreateSection("Summon Boss", BossR)
local UpdateSummonBoss = CreateDropdown("SelectedBossToSummon", "Select Boss to Summon", "Flashy Flash", SummonBox, function(v) _G.Yui.SelectedBossToSummon = v end)
UpdateSummonBoss({"Flashy Flash", "Sukuna", "Aizen", "Kokushibo", "Sung Jinwoo", "Okarun", "Modulo", "Modulo Yuji", "Homelander"})
CreateToggle("AutoSummonBoss", "Auto Summon Boss", false, SummonBox, function(v) _G.Yui.AutoSummonBoss = v end)
CreateToggle("FarmSummonBoss", "Farm Summoned Boss", false, SummonBox, function(v) _G.Yui.FarmSummonBoss = v end)

local Gear5Box = CreateSection("Event Boss", BossR)
CreateToggle("AutoSummonLuffy", "Auto Summon Luffy (Gear 5)", false, Gear5Box, function(v) _G.Yui.AutoSummonLuffy = v end)
CreateToggle("AutoSummonGojo", "Auto Summon Gojo", false, Gear5Box, function(v) _G.Yui.AutoSummonGojo = v end)
CreateToggle("AutoSummonCellsmax", "Auto Summon Cells Max", false, Gear5Box, function(v) _G.Yui.AutoSummonCellsmax = v end)

local AuraBox = CreateSection("Kill Around (Aura)", BossL)
CreateToggle("KillAuraIsland", "Kill Around", false, AuraBox, function(v) 
    _G.Yui.KillAuraIsland = v 
    if v and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
        _G.Yui.LockedIslandCenter = LocalPlayer.Character.HumanoidRootPart.Position 
    else _G.Yui.LockedIslandCenter = nil end 
end)
CreateSlider("IslandRadius", "Aura Range", 100, 1500, 600, AuraBox, function(v) _G.Yui.IslandRadius = v end)

-- ====== TAB: AUTO SKILLS ======
local WepSkillBox = CreateSection("Weapons Cycle", SkillL)
local UpdateMultiWep = CreateMultiDropdown("CycleWeaponsList", "Select Power Cycle", WepSkillBox, _G.Yui.CycleWeaponsList)
CreateButton("Load Weapons", WepSkillBox, function()
    local t = {} 
    for _, v in pairs(LocalPlayer.Backpack:GetChildren()) do if v:IsA("Tool") then table.insert(t, v.Name) end end
    for _, v in pairs(LocalPlayer.Character:GetChildren()) do if v:IsA("Tool") then table.insert(t, v.Name) end end
    UpdateMultiWep(t)
end)
CreateToggle("AutoCycleWeapons", "Auto Cycle Powers", false, WepSkillBox, function(v) _G.Yui.AutoCycleWeapons = v end)
CreateSlider("CycleDelay", "Cycle Delay (Sec)", 1, 10, 1, WepSkillBox, function(v) _G.Yui.CycleDelay = v end)

-- FIX: CHU TRÌNH ĐỔI VŨ KHÍ LUÂN PHIÊN MƯỢT MÀ, KHÔNG CẦN QUÁI
local currentCycleIndex = 1
task.spawn(function()
    while true do
        task.wait(_G.Yui.CycleDelay)
        if _G.Yui.AutoCycleWeapons then
            pcall(function()
                local activeWeapons = {}
                for name, isEnabled in pairs(_G.Yui.CycleWeaponsList) do
                    if isEnabled then table.insert(activeWeapons, name) end
                end
                
                if #activeWeapons > 0 then
                    currentCycleIndex = currentCycleIndex + 1
                    if currentCycleIndex > #activeWeapons then currentCycleIndex = 1 end
                    
                    local wepToEquip = activeWeapons[currentCycleIndex]
                    local char = LocalPlayer.Character
                    local bp = LocalPlayer.Backpack
                    if char and bp then
                        local tool = bp:FindFirstChild(wepToEquip) or char:FindFirstChild(wepToEquip)
                        if tool and tool.Parent == bp then
                            char.Humanoid:EquipTool(tool)
                        end
                    end
                end
            end)
        end
    end
end)

local SkillBoxList = CreateSection("Skill Keys", SkillR)
local keyList = {"Z","X","C","V","B","F"}
for _, key in ipairs(keyList) do
    CreateToggle("AutoSkill_"..key, "Auto Skill ["..key.."]", false, SkillBoxList, function(v) _G.Yui.AutoSkill[key] = v end)
end
CreateSlider("SkillDelay", "Skill Delay (ms)", 0, 2000, 100, SkillBoxList, function(v) _G.Yui.SkillDelay = v end)

-- FIX: XẢ SKILL VÔ ĐIỀU KIỆN, KHÔNG CẦN CÓ QUÁI
task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            for key, isEnabled in pairs(_G.Yui.AutoSkill) do
                if isEnabled then
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[key], false, game) 
                    task.wait(0.05) 
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[key], false, game) 
                    task.wait(_G.Yui.SkillDelay / 1000)
                end
            end
        end)
    end
end)

-- ====== TAB: SHOP & STORE ======
local RollStatBox = CreateSection("Auto Roll Stats", ShopL)
local UpdateStatTiers = CreateMultiDropdown("TargetStatTierList", "Select Tiers", RollStatBox, _G.Yui.TargetStatTierList)
UpdateStatTiers({"Z", "SSS", "SS", "S", "A", "B", "C", "D", "E", "F"})

-- ĐÃ THÊM: CHO PHÉP CHỌN LOẠI CHỈ SỐ CẦN ROLL
local UpdateStatTypes = CreateDropdown("TargetStatType", "Select Stat Type", "Any", RollStatBox, function(v) _G.Yui.TargetStatType = v end)
UpdateStatTypes({"Any", "Health", "Melee", "Sword", "Defense", "Special", "Luck"})
CreateToggle("AutoRollStatsTier", "Auto Roll Stats", false, RollStatBox, function(v) _G.Yui.AutoRollStatsTier = v end)

local RollHakiBox = CreateSection("Auto Roll Haki Color", ShopR)
local UpdateHakiColors = CreateMultiDropdown("TargetHakiList", "Select Colors", RollHakiBox, _G.Yui.TargetHakiList)
UpdateHakiColors({"Blue", "Green", "Pink", "Red"})
CreateToggle("AutoRollHaki", "Auto Roll Haki", false, RollHakiBox, function(v) _G.Yui.AutoRollHaki = v end)

local ShopBox = CreateSection("Auto Buy (Merchant)", ShopL)
local UpdateShopDrop = CreateMultiDropdown("TargetBuyItemsList", "Select Items to Buy", ShopBox, _G.Yui.TargetBuyItemsList)
UpdateShopDrop({"Race Reroll", "Trait Reroll", "Clan Reroll", "Raid Ticket", "Summon Orb", "Holy Fragment", "Rush Ticket", "Stats Key"})
CreateToggle("AutoBuyAllSelected", "Auto Buy Items", false, ShopBox, function(v) _G.Yui.AutoBuyAllSelected = v end)

local RandomBox = CreateSection("Auto Random / Gacha", ShopR)
local UpdateRollType = CreateDropdown("RollType", "Select Roll Type", "x1", RandomBox, function(v) _G.Yui.RollType = v end)
UpdateRollType({"x1", "x5"})
CreateToggle("AutoRoll", "Auto Random (Roll)", false, RandomBox, function(v) _G.Yui.AutoRoll = v end)

local StoreBox = CreateSection("Smart Inventory Store", ShopR)
CreateToggle("AutoStoreItems", "Auto Store Items", false, StoreBox, function(v) _G.Yui.AutoStoreItems = v end)

-- ====== TAB: STATS & CODES ======
local StatBox = CreateSection("Auto Stats", StatL)
local UpdateStatDrop = CreateMultiDropdown("TargetStatsList", "Select Stats", StatBox, _G.Yui.TargetStatsList)
UpdateStatDrop({"Melee", "Defense", "Sword", "Special"})
CreateTextBox("StatAmount", "Input Amount", 1, StatBox, function(v) _G.Yui.StatAmount = v end)
CreateToggle("AutoStatEnabled", "Auto Allocate Stats", false, StatBox, function(v) _G.Yui.AutoStatEnabled = v end)
CreateSlider("StatDelay", "Upgrade Delay (ms)", 100, 10000, 1000, StatBox, function(v) _G.Yui.StatDelay = v end)

local CodeBox = CreateSection("Redeem Codes", StatR)
CreateButton("Redeem All Codes", CodeBox, function()
    task.spawn(function()
        local FullCodesList = { "FREETEMPV", "HOMELANDER", "X2LUCKDROP", "Release!", "SorryforDelays1", "NextUpdateSoon!", "Manybugsfixed!", "ContentCreator2", "EarlyAccess2", "LORDBOROS", "WTHSPACESHIP", "3MVISITS", "GEAR5", "NEWTOKENSHOP", "NEWEVENTSOON", "VERGIL", "RAINBOWHAKI", "BIGQOLUPD", "GILGAMESH", "INFCASTLE", "WHERESTHENPC", "UPDATEDELAYYY", "SJWUPD", "2MVISITS", "TITLE", "SLAYERUPDATE", "SORRY4SHUTDOWN", "SORRY4DELAY", "APRILFOOLSEVENT", "5KSUBYT", "1.5MVISITS", "1MVISITS", "850KVISITS", "600KVISITS", "250KVISITS", "150KVISITS", "50KVISITS", "RIP GRANDMA" }
        for _, code in ipairs(FullCodesList) do
            for _, r in pairs(CachedRemotes.Codes) do pcall(function() if r:IsA("RemoteEvent") then r:FireServer(code) elseif r:IsA("RemoteFunction") then r:InvokeServer(code) end end) end
            task.wait(0.5)
        end
    end)
end)

-- ====== TAB: LOCAL PLAYER ======
local MoveBox = CreateSection("Movement", PlayerL)
CreateToggle("EnableWS", "WalkSpeed", false, MoveBox, function(v) _G.Yui.EnableWS = v end)
CreateSlider("WalkSpeed", "Speed Value", 16, 500, 150, MoveBox, function(v) _G.Yui.WalkSpeed = v end)
CreateToggle("EnableJP", "JumpPower", false, MoveBox, function(v) _G.Yui.EnableJP = v end)
CreateSlider("JumpPower", "Jump Value", 50, 500, 150, MoveBox, function(v) _G.Yui.JumpPower = v end)

local StatusBox = CreateSection("Status", PlayerR)
CreateToggle("Noclip", "Noclip", false, StatusBox, function(v) _G.Yui.Noclip = v end)
CreateToggle("Fly", "Fly", false, StatusBox, function(v) _G.Yui.Fly = v end)
CreateSlider("FlySpeed", "Fly Speed", 20, 300, 100, StatusBox, function(v) _G.Yui.FlySpeed = v end)

-- ====== TAB: SERVER & SETTINGS ======
local SrvBox = CreateSection("Server Management", SysL)
CreateButton("Boost FPS", SrvBox, function()
    for _, v in pairs(Workspace:GetDescendants()) do if v:IsA("Texture") or v:IsA("Decal") then v:Destroy() elseif v:IsA("BasePart") then v.Material = Enum.Material.SmoothPlastic end end
    game.Lighting.GlobalShadows = false
end)
CreateButton("Rejoin Server", SrvBox, function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
CreateButton("Hop Server", SrvBox, function()
    pcall(function()
        local req = (syn and syn.request) or request or http_request or (fluxus and fluxus.request)
        if req then local res = req({Url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100", Method = "GET"})
            if res.StatusCode == 200 then local json = HttpService:JSONDecode(res.Body)
                for _, v in pairs(json.data) do if v.id ~= game.JobId and v.playing > 0 and v.playing < v.maxPlayers then TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, LocalPlayer) break end end
            end
        end
    end)
end)

-- SAVE / LOAD LOGIC
local function GetSaves()
    local saves = {}
    if listfiles and isfolder and isfolder("YuiHub_Jood") then
        for _, file in ipairs(listfiles("YuiHub_Jood")) do
            if string.find(file, "%.json$") then
                local name = file:match("([^/\\]+)%.json$") or file:match("(.+)%.json$")
                if name then table.insert(saves, name) end
            end
        end
    end
    if #saves == 0 then return {"Default"} end
    return saves
end

local CfgBox = CreateSection("Settings & Config", SysR)
local SelectedSave = _G.Yui.ConfigName
local UpdateSaveDrop
UpdateSaveDrop = CreateDropdown("SelectedSaveFile", "Select Save", SelectedSave, CfgBox, function(v) SelectedSave = v end)
UpdateSaveDrop(GetSaves())

local newSaveInputName = "MySave"
CreateTextBox(nil, "File Name", "MySave", CfgBox, function(v) newSaveInputName = v end)

CreateButton("Create Save", CfgBox, function()
    if writefile and makefolder then
        if not isfolder("YuiHub_Jood") then makefolder("YuiHub_Jood") end
        local saveName = newSaveInputName
        if saveName == "" then saveName = "Default" end
        writefile("YuiHub_Jood/"..saveName..".json", HttpService:JSONEncode(_G.Yui))
        
        local newSaves = GetSaves()
        UpdateSaveDrop(newSaves)
        if ConfigUpdaters["SelectedSaveFile"] then ConfigUpdaters["SelectedSaveFile"](saveName) end
    end
end)

CreateButton("Load Selected Save", CfgBox, function()
    if readfile and isfile and isfile("YuiHub_Jood/"..SelectedSave..".json") then
        local data = HttpService:JSONDecode(readfile("YuiHub_Jood/"..SelectedSave..".json"))
        for k, v in pairs(data) do if ConfigUpdaters[k] then ConfigUpdaters[k](v) end end
        _G.Yui.ConfigName = SelectedSave
        UpdateWaypointDropdownUI()
    end
end)

CreateToggle("Auto Load Menu", "Auto Load Menu", false, CfgBox, function(v)
    _G.Yui.AutoLoad = v
    if writefile and makefolder then
        if not isfolder("YuiHub_Jood") then makefolder("YuiHub_Jood") end
        writefile("YuiHub_Jood/autoload.txt", v and _G.Yui.ConfigName or "")
    end
end)

CreateButton("Reset Menu", CfgBox, function()
    for k, default in pairs(DefaultValues) do if ConfigUpdaters[k] then ConfigUpdaters[k](default) end end
end)


-- ============================
-- INTRO ANIMATION & LOADING BAR
-- ============================
local function PlayIntroSequence()
    PlayMeow()
    
    -- TẠO HIỆU ỨNG LOGO LƯỚT TỪ TRÊN XUỐNG VÀ XOAY TRÒN ĐÚNG CHUẨN
    local IntroLogo = Instance.new("ImageLabel", ScreenGui)
    IntroLogo.Size = UDim2.new(0, 120, 0, 120)
    IntroLogo.Position = UDim2.new(0.5, -60, -0.5, 0)
    IntroLogo.BackgroundTransparency = 1
    IntroLogo.Image = CustomImageURL

    TweenService:Create(IntroLogo, TweenInfo.new(1, Enum.EasingStyle.Bounce), {Position = UDim2.new(0.5, -60, 0.5, -60)}):Play()
    task.wait(1.2)
    TweenService:Create(IntroLogo, TweenInfo.new(0.6, Enum.EasingStyle.Linear), {Rotation = 360}):Play()
    task.wait(0.6)

    TweenService:Create(IntroLogo, TweenInfo.new(0.3), {Size = UDim2.new(0, 0, 0, 0), Position = UDim2.new(0.5, 0, 0.5, 0), ImageTransparency = 1}):Play()
    task.wait(0.2)
    IntroLogo:Destroy()

    -- THANH LOAD CÓ KÈM LOGO GÓC PHẢI
    local LoadFrame = Instance.new("Frame", ScreenGui)
    LoadFrame.Size = UDim2.new(0, 220, 0, 50)
    LoadFrame.Position = UDim2.new(1, -240, 1, -70)
    LoadFrame.BackgroundColor3 = Theme.HeaderBg
    Instance.new("UICorner", LoadFrame).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", LoadFrame).Color = Theme.Accent

    local LoadIcon = Instance.new("ImageLabel", LoadFrame)
    LoadIcon.Size = UDim2.new(0, 30, 0, 30)
    LoadIcon.Position = UDim2.new(0, 10, 0.5, -15)
    LoadIcon.BackgroundTransparency = 1
    LoadIcon.Image = CustomImageURL
    
    local LoadText = Instance.new("TextLabel", LoadFrame)
    LoadText.Size = UDim2.new(1, -50, 0, 20)
    LoadText.Position = UDim2.new(0, 45, 0, 5)
    LoadText.BackgroundTransparency = 1
    LoadText.Text = "Loading YuiHub..."
    LoadText.TextColor3 = Theme.Accent
    LoadText.Font = Enum.Font.GothamBold
    LoadText.TextSize = 12
    LoadText.TextXAlignment = Enum.TextXAlignment.Left
    
    local BarBg = Instance.new("Frame", LoadFrame)
    BarBg.Size = UDim2.new(1, -55, 0, 8)
    BarBg.Position = UDim2.new(0, 45, 0, 30)
    BarBg.BackgroundColor3 = Theme.MainBg
    Instance.new("UICorner", BarBg).CornerRadius = UDim.new(1, 0)
    
    local BarFill = Instance.new("Frame", BarBg)
    BarFill.Size = UDim2.new(0, 0, 1, 0)
    BarFill.BackgroundColor3 = Theme.Accent
    Instance.new("UICorner", BarFill).CornerRadius = UDim.new(1, 0)
    
    TweenService:Create(BarFill, TweenInfo.new(2.5, Enum.EasingStyle.Linear), {Size = UDim2.new(1, 0, 1, 0)}):Play()
    task.wait(2.5)
    
    LoadText.Text = "Loaded Successfully!"
    task.wait(0.5)
    LoadFrame:Destroy()
    
    MainFrame.Size = UDim2.new(0, 0, 0, 0)
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    MainFrame.Visible = true
    OpenIcon.Visible = true 
    TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Size = UDim2.new(0, 480, 0, 320), Position = UDim2.new(0.5, -240, 0.5, -160)}):Play()
end

task.spawn(PlayIntroSequence)

task.spawn(function()
    if readfile and isfile and isfile("YuiHub_Jood/autoload.txt") then
        local cfgName = readfile("YuiHub_Jood/autoload.txt")
        if cfgName ~= "" and isfile("YuiHub_Jood/"..cfgName..".json") then
            local data = HttpService:JSONDecode(readfile("YuiHub_Jood/"..cfgName..".json"))
            for k, v in pairs(data) do if ConfigUpdaters[k] then ConfigUpdaters[k](v) end end
            UpdateWaypointDropdownUI()
        end
    end
end)

-- ============================
-- CORE LOGIC
-- ============================

local function checkStockErrorUI()
    for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if gui:IsA("TextLabel") and string.find(string.lower(gui.Text), "not enough stock") and gui.Visible then return true end
    end
    return false
end

-- Vòng lặp Auto Summon Event Boss
task.spawn(function()
    while task.wait(1) do
        if _G.Yui.AutoSummonLuffy then pcall(function() InteractWithNPC("Luffy") InteractWithNPC("Gear 5") end) end
        if _G.Yui.AutoSummonGojo then pcall(function() InteractWithNPC("Gojo") end) end
        if _G.Yui.AutoSummonCellsmax then pcall(function() InteractWithNPC("Cells") InteractWithNPC("Cell Max") InteractWithNPC("Cellsmax") end) end
    end
end)

-- Vòng lặp Roll Haki / Stats (FIX NHẬN DIỆN CHỮ)
task.spawn(function()
    while task.wait(1) do
        if _G.Yui.AutoRollHaki then
            pcall(function()
                if CheckPlayerUIForText(_G.Yui.TargetHakiList) then
                    _G.Yui.AutoRollHaki = false
                    if ConfigUpdaters["AutoRollHaki"] then ConfigUpdaters["AutoRollHaki"](false) end
                else InteractWithNPC("HakiColorNPC") end
            end)
        end
        if _G.Yui.AutoRollStatsTier then
            pcall(function()
                if CheckPlayerUIForText(_G.Yui.TargetStatTierList, _G.Yui.TargetStatType) then
                    _G.Yui.AutoRollStatsTier = false
                    if ConfigUpdaters["AutoRollStatsTier"] then ConfigUpdaters["AutoRollStatsTier"](false) end
                else 
                    if not InteractWithNPC("RollStat") then InteractWithNPC("StatNPC") end
                end
            end)
        end
    end
end)

local function isSafeToStore(tool)
    if tool.Parent == LocalPlayer.Character then return false end
    local lowerName = string.lower(tool.Name)
    local blacklistedWords = { "combat", "melee", "blade", "katana", "haki", "style", "fist", "gun", "sniper", "special", "df", "dragon", "vampire", "art", "magic", "breath", "adam", "aizen", "akatsuki", "akaza", "black leg", "bomb", "boros", "buso", "candycane", "cid", "doraemon", "flashy", "gear", "gilgamesh", "gohan", "gojo", "goku", "homelander", "itachi", "itadori", "ken", "kirito", "kokushibo", "kranui", "mui", "okarun", "qin", "sjw", "sand", "shanks", "steve", "sukuna", "twoh", "yoru", "yuji", "vergil" }
    for _, word in ipairs(blacklistedWords) do if string.find(lowerName, word) then return false end end
    return true 
end

task.spawn(function()
    while task.wait(2) do
        if _G.Yui.AutoStoreItems then
            pcall(function()
                for _, tool in pairs(LocalPlayer.Backpack:GetChildren()) do
                    if tool:IsA("Tool") and isSafeToStore(tool) then
                        for _, r in pairs(CachedRemotes.Store) do
                            pcall(function() if r:IsA("RemoteEvent") then r:FireServer("Add", tool.Name, 1) elseif r:IsA("RemoteFunction") then r:InvokeServer("Add", tool.Name, 1) end end)
                        end
                    end
                end
            end)
        end
    end
end)

local MerchantCooldown = {}
local SysRandomItem = game:GetService("ReplicatedStorage"):WaitForChild("System"):WaitForChild("RandomItem")

task.spawn(function()
    while task.wait(1) do
        if _G.Yui.AutoBuyAllSelected then
            pcall(function()
                for itemName, isSelected in pairs(_G.Yui.TargetBuyItemsList) do
                    if isSelected and (not MerchantCooldown[itemName] or tick() > MerchantCooldown[itemName]) then
                        for _, r in pairs(CachedRemotes.Shop) do
                            pcall(function()
                                local res
                                if r:IsA("RemoteEvent") then r:FireServer({["ItemName"] = itemName, ["Action"] = "Buy", ["Amount"] = 1})
                                elseif r:IsA("RemoteFunction") then res = r:InvokeServer({["ItemName"] = itemName, ["Action"] = "Buy", ["Amount"] = 1}) end
                                if res == false or res == "Sold Out" or res == "Max" or checkStockErrorUI() then MerchantCooldown[itemName] = tick() + 10 end
                            end)
                        end
                    end
                end
            end)
        end
        if _G.Yui.AutoRoll and SysRandomItem then
            pcall(function()
                local amount = tonumber(string.match(_G.Yui.RollType, "%d+")) or 1
                SysRandomItem:FireServer(amount)
            end)
        end
        if _G.Yui.AutoSummonBoss and _G.Yui.SelectedBossToSummon ~= "" then
            pcall(function()
                for _, r in pairs(CachedRemotes.Summon) do
                    if r:IsA("RemoteEvent") then r:FireServer(_G.Yui.SelectedBossToSummon) elseif r:IsA("RemoteFunction") then r:InvokeServer(_G.Yui.SelectedBossToSummon) end
                end
            end)
        end
    end
end)

local statMapping = { ["Melee"] = "Strength", ["Defense"] = "Defense", ["Sword"] = "Sword", ["Special"] = "DF" }
task.spawn(function()
    while true do
        task.wait(_G.Yui.StatDelay / 1000)
        if _G.Yui.AutoStatEnabled and StatsRemote then
            pcall(function()
                local amt = tonumber(_G.Yui.StatAmount) or 1 amt = math.floor(amt)
                for statName, isSelected in pairs(_G.Yui.TargetStatsList) do
                    if isSelected then
                        local realStatName = statMapping[statName] 
                        pcall(function()
                            if amt == 1 then
                                if StatsRemote:IsA("RemoteEvent") then StatsRemote:FireServer(realStatName) elseif StatsRemote:IsA("RemoteFunction") then StatsRemote:InvokeServer(realStatName) end
                            else
                                if StatsRemote:IsA("RemoteEvent") then StatsRemote:FireServer(realStatName, amt) elseif StatsRemote:IsA("RemoteFunction") then StatsRemote:InvokeServer(realStatName, amt) end
                            end
                        end)
                        task.wait(_G.Yui.StatDelay / 1000)
                    end
                end
            end)
        end
    end
end)

local function getBestTarget()
    if _G.Yui.AutoRollHaki or _G.Yui.AutoRollStatsTier then return nil end
    local char = LocalPlayer.Character if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = char.HumanoidRootPart.Position

    if _G.Yui.AutoFarmWorldBoss and _G.Yui.SelectedWorldBoss ~= "" then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and string.find(string.lower(obj.Name), string.lower(_G.Yui.SelectedWorldBoss)) and not string.find(string.lower(obj.Name), "sell") then
                local hum = obj:FindFirstChildOfClass("Humanoid") local root = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
                if hum and root and hum.Health > 0 then return obj end
            end
        end
    end

    if _G.Yui.FarmSummonBoss and _G.Yui.SelectedBossToSummon ~= "" then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and string.find(string.lower(obj.Name), string.lower(_G.Yui.SelectedBossToSummon)) and not string.find(string.lower(obj.Name), "sell") then
                local hum = obj:FindFirstChildOfClass("Humanoid") local root = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
                if hum and root and hum.Health > 0 then return obj end
            end
        end
    end

    local target, shortest = nil, math.huge
    if _G.Yui.KillAuraIsland and not _G.Yui.LockedIslandCenter then _G.Yui.LockedIslandCenter = myPos end

    for _, obj in pairs(Workspace:GetDescendants()) do
        if IsValidMob(obj) then
            local root = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso")
            if not root then continue end
            if _G.Yui.KillAuraIsland and _G.Yui.LockedIslandCenter then
                local distToCenter = (_G.Yui.LockedIslandCenter - root.Position).Magnitude
                if distToCenter > _G.Yui.IslandRadius then continue end
            end
            
            local distToMe = (myPos - root.Position).Magnitude
            local lowerName = string.lower(obj.Name) local bName = TrimMobName(obj.Name) local isAnyBossObj = string.find(lowerName, "boss")
            local isValidForCurrentMode = false
            
            if _G.Yui.FarmSelectedMob and _G.Yui.SelectedMobsList[bName] then isValidForCurrentMode = true
            elseif _G.Yui.FarmAllMobs and not isAnyBossObj then isValidForCurrentMode = true
            elseif _G.Yui.KillAuraIsland and not isAnyBossObj then isValidForCurrentMode = true end 
            
            if isValidForCurrentMode and distToMe < shortest then shortest = distToMe target = obj end
        end
    end

    if not target and _G.Yui.FarmAllMobs then
        char.HumanoidRootPart.CFrame = CFrame.new(math.random(-5000, 5000), 500, math.random(-5000, 5000))
        task.wait(1)
    end

    return target
end

task.spawn(function()
    while task.wait(0.5) do
        if _G.Yui.FarmAllMobs or _G.Yui.FarmSelectedMob or _G.Yui.KillAuraIsland or _G.Yui.AutoFarmWorldBoss or _G.Yui.FarmSummonBoss then 
            CurrentTarget = getBestTarget() 
        else 
            CurrentTarget = nil 
        end
    end
end)

task.spawn(function()
    while true do
        local dt = task.wait()
        if CurrentTarget and not _G.Yui.AutoRollHaki and not _G.Yui.AutoRollStatsTier then
            pcall(function()
                local charRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not charRoot then return end
                local mobRoot = CurrentTarget.PrimaryPart or CurrentTarget:FindFirstChild("HumanoidRootPart") or CurrentTarget:FindFirstChild("Torso")
                local cframeOffset = CFrame.new(0, _G.Yui.AttackDist, 0)
                if _G.Yui.AttackPos == "Behind" then cframeOffset = CFrame.new(0, 0, _G.Yui.AttackDist) elseif _G.Yui.AttackPos == "Below" then cframeOffset = CFrame.new(0, -_G.Yui.AttackDist, 0) end
                
                local targetPos = mobRoot.CFrame * cframeOffset
                local dist = (charRoot.Position - targetPos.Position).Magnitude
                
                if dist > 3000 then
                    charRoot.CFrame = targetPos
                    _G.Yui.IsNearTarget = false
                    task.wait(0.2)
                elseif dist > 15 then
                    _G.Yui.IsNearTarget = false
                    local speed = _G.Yui.TweenSpeed
                    if dist > 2000 then speed = speed * 8 elseif dist > 500 then speed = speed * 4 end
                    local step = speed * dt local dir = (targetPos.Position - charRoot.Position).Unit
                    charRoot.CFrame = charRoot.CFrame + (dir * step) charRoot.Velocity = Vector3.new(0, 0, 0)
                else
                    _G.Yui.IsNearTarget = true charRoot.CFrame = targetPos charRoot.Velocity = Vector3.new(0, 0, 0)
                end
            end)
        else 
            _G.Yui.IsNearTarget = false 
        end
    end
end)

-- AUTO ATTACK FIX
task.spawn(function()
    while true do
        task.wait(0.2) 
        if _G.Yui.AutoAttack and _G.Yui.IsNearTarget and CurrentTarget then
            pcall(function()
                local char = LocalPlayer.Character
                if char then 
                    local tool = char:FindFirstChildOfClass("Tool") 
                    if tool then 
                        tool:Activate() 
                    end 
                end
            end)
        end
    end
end)

RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if _G.Yui.EnableWS and not _G.Yui.Fly then hum.WalkSpeed = _G.Yui.WalkSpeed end
            if _G.Yui.EnableJP and not _G.Yui.Fly then hum.UseJumpPower = true hum.JumpPower = _G.Yui.JumpPower end
        end
    end
end)

RunService.Stepped:Connect(function()
    if (_G.Yui.FarmAllMobs or _G.Yui.FarmSelectedMob or _G.Yui.KillAuraIsland or _G.Yui.Noclip or _G.Yui.Fly or _G.Yui.AutoFarmWorldBoss or _G.Yui.FarmSummonBoss) and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
    end
end)

task.spawn(function()
    while RunService.RenderStepped:Wait() do
        if _G.Yui.Fly and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hum and root then
                root.Velocity = Vector3.new(0, 0, 0)
                local flyVelocity = hum.MoveDirection * _G.Yui.FlySpeed
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then flyVelocity = flyVelocity + Vector3.new(0, _G.Yui.FlySpeed, 0) end
                root.Velocity = flyVelocity
            end
        end
    end
end)