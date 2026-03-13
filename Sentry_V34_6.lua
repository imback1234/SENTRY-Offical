-- ============================================================
-- SENTRY
-- Coded by: Mrgrumeti
-- ============================================================
-- Compatible with: Xeon, Synapse X, KRNL, Fluxus, Arceus X
-- Press INSERT to toggle menu
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")

-- ===================================================================
-- CONFIG
-- ===================================================================
local Config = {
    ShowMenu = true,
    MenuKey = Enum.KeyCode.Insert,
    
    -- Combat
    VisibleCheck = true,
    TeamCheck = true,
    Crosshair = false,
    
    -- Microwave Hub's Aimbot (mouse-tracked FOV, direct lerp)
    Aimbot = false,
    AimbotFOV = 150,
    AimbotSmoothing = 15,        -- divided by 100 → 0.15 lerp alpha
    AimbotShowFOV = true,
    
    -- Sentry Aimbot (OG — bone targeting, dynamic smooth, prediction)
    OGAimbot = false,
    OGAimbotFOV = 250,
    OGAimbotSmoothing = 45,
    OGAimbotBone = "Head",
    OGAimbotDynamicSmooth = true,
    OGAimbotPrediction = 3,
    OGAimbotShowFOV = true,
    
    -- Neon Hub's Aimbot (Neon Space Universal Delta — CHEESE_BOY)
    -- Camera-center FOV, smoothness lerp (0=instant snap), wall check, per-team filter
    NeonAimbot = false,
    NeonAimbotFOV = 100,
    NeonAimbotSmoothing = 0,       -- 0 = instant snap, higher = smoother lerp
    NeonAimbotBone = "Head",       -- Head, UpperTorso, HumanoidRootPart
    NeonAimbotWallCheck = true,
    NeonAimbotTeamFilter = false,  -- per-team aim filtering (Neon-style)
    NeonAimbotShowFOV = true,
    
    -- Sentry ESP v2 (Complete Rewrite — Corner Box + Tracers + VisCheck)
    ESP = false,
    ESPCornerBox = true,
    ESPHealth = true,
    ESPNames = true,
    ESPDistance = true,
    ESPTracers = false,
    ESPHeadDot = false,
    ESPToolName = true,
    ESPFlags = false,
    ESPVisCheck = false,
    ESPOffscreen = false,
    ESPTeamColor = true,
    ESPMaxDist = 2000,
    ESPSkeleton = false,
    ESPCharms = false,
    PinkCharms = false,
    CharmFillTransparency = 0.65,
    CharmOutlineTransparency = 0.0,
    KOFeed = false,
    
    -- Player
    InfiniteJump = false,
    SuperSpeed = false,
    SpeedAmount = 50,
    SuperJump = false,
    JumpAmount = 100,
    
    -- Movement
    Fly = false,
    FlySpeed = 50,
    Noclip = false,
    
    -- Stealth Fly (Multi-Method Anti-Cheat Evasion)
    StealthFly = false,
    StealthFlySpeed = 80,
    StealthFlyMethod = 1, -- 1=Ghost(Seat), 2=Micro(CFrame), 3=Phantom(Velocity)
    
    -- Silver Surfer (Cosmic Board Fly)
    SilverSurfer = false,
    SilverSurferMode = 2, -- 1=Slow, 2=Medium, 3=Fast
    
    -- Troll
    Spinbot = false,
    SpinSpeed = 30,
    ClickTP = false,
    Slingshot = false,
    
    -- HUD
    FPSCounter = false,
    PingCounter = false,
    
    -- Premium
    Triggerbot = false,
    TriggerbotDelay = 12,
}

-- ===================================================================
-- VARIABLES
-- ===================================================================
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local CharmObjects = {}
local Flying = false
local FlyObjects = {}

-- Stealth Fly state
local StealthFlying = false
local StealthFlyConn = nil
local StealthFlyParts = {} -- cleanup table for created instances
local LastValidPos = nil   -- anti-rubberband tracking

-- Spinbot state
local SpinbotConnection = nil
local SpinAngle = 0

-- ClickTP state
local ClickTPConnection = nil

-- Slingshot state
local SlingshotConnection = nil
local slingshotCooldown = false
-- Triggerbot state
local TriggerbotConn = nil
local lastTriggerTime = 0

local DrawingSupported = pcall(function() return Drawing.new("Line") end)

-- ESP v2: forward-declare externally needed functions (implementation scoped below)
local CreateESP2, HideESP2, UpdateESP2, RemoveESP2, ESP2_Tick

-- ===================================================================
-- AIMBOT VARIABLES
-- ===================================================================
local AimbotTarget = nil
local FOVCircle, FOVGlow, FOVCenterDot = nil, nil, nil
local OGFOVCircle, OGFOVGlow, OGFOVCenterDot = nil, nil, nil
local NeonFOVCircle, NeonFOVGlow, NeonFOVCenterDot = nil, nil, nil
local NeonTeamAimSettings = {}  -- per-team aimbot filter (Neon style)
local aimRayParams = RaycastParams.new()
aimRayParams.FilterType = Enum.RaycastFilterType.Exclude

if DrawingSupported then
    -- Microwave Hub's Aimbot FOV (yellow)
    FOVGlow = Drawing.new("Circle")
    FOVGlow.Color = Color3.fromRGB(200, 200, 0)
    FOVGlow.Thickness = 3.5
    FOVGlow.Filled = false
    FOVGlow.Transparency = 0.25
    FOVGlow.NumSides = 72
    FOVGlow.Visible = false
    FOVGlow.ZIndex = 9

    FOVCircle = Drawing.new("Circle")
    FOVCircle.Color = Color3.fromRGB(255, 255, 0)
    FOVCircle.Thickness = 1.5
    FOVCircle.Filled = false
    FOVCircle.Transparency = 0.85
    FOVCircle.NumSides = 72
    FOVCircle.Visible = false
    FOVCircle.ZIndex = 10

    FOVCenterDot = Drawing.new("Circle")
    FOVCenterDot.Color = Color3.fromRGB(255, 255, 0)
    FOVCenterDot.Thickness = 1
    FOVCenterDot.Filled = true
    FOVCenterDot.Transparency = 0.9
    FOVCenterDot.Radius = 3
    FOVCenterDot.NumSides = 16
    FOVCenterDot.Visible = false
    FOVCenterDot.ZIndex = 10

    -- Sentry OG Aimbot FOV (cyan)
    OGFOVGlow = Drawing.new("Circle")
    OGFOVGlow.Color = Color3.fromRGB(0, 180, 220)
    OGFOVGlow.Thickness = 3.5
    OGFOVGlow.Filled = false
    OGFOVGlow.Transparency = 0.25
    OGFOVGlow.NumSides = 72
    OGFOVGlow.Visible = false
    OGFOVGlow.ZIndex = 9

    OGFOVCircle = Drawing.new("Circle")
    OGFOVCircle.Color = Color3.fromRGB(0, 220, 255)
    OGFOVCircle.Thickness = 1.5
    OGFOVCircle.Filled = false
    OGFOVCircle.Transparency = 0.85
    OGFOVCircle.NumSides = 72
    OGFOVCircle.Visible = false
    OGFOVCircle.ZIndex = 10

    OGFOVCenterDot = Drawing.new("Circle")
    OGFOVCenterDot.Color = Color3.fromRGB(0, 220, 255)
    OGFOVCenterDot.Thickness = 1
    OGFOVCenterDot.Filled = true
    OGFOVCenterDot.Transparency = 0.9
    OGFOVCenterDot.Radius = 3
    OGFOVCenterDot.NumSides = 16
    OGFOVCenterDot.Visible = false
    OGFOVCenterDot.ZIndex = 10

    -- Neon Hub's Aimbot FOV (purple/magenta)
    NeonFOVGlow = Drawing.new("Circle")
    NeonFOVGlow.Color = Color3.fromRGB(140, 0, 200)
    NeonFOVGlow.Thickness = 3.5
    NeonFOVGlow.Filled = false
    NeonFOVGlow.Transparency = 0.25
    NeonFOVGlow.NumSides = 72
    NeonFOVGlow.Visible = false
    NeonFOVGlow.ZIndex = 9

    NeonFOVCircle = Drawing.new("Circle")
    NeonFOVCircle.Color = Color3.fromRGB(180, 0, 255)
    NeonFOVCircle.Thickness = 1.5
    NeonFOVCircle.Filled = false
    NeonFOVCircle.Transparency = 0.85
    NeonFOVCircle.NumSides = 72
    NeonFOVCircle.Visible = false
    NeonFOVCircle.ZIndex = 10

    NeonFOVCenterDot = Drawing.new("Circle")
    NeonFOVCenterDot.Color = Color3.fromRGB(180, 0, 255)
    NeonFOVCenterDot.Thickness = 1
    NeonFOVCenterDot.Filled = true
    NeonFOVCenterDot.Transparency = 0.9
    NeonFOVCenterDot.Radius = 3
    NeonFOVCenterDot.NumSides = 16
    NeonFOVCenterDot.Visible = false
    NeonFOVCenterDot.ZIndex = 10
end

-- ===================================================================
-- UTILITY FUNCTIONS
-- ===================================================================
local function GetCharacter(player)
    return player and player.Character
end

local function GetRootPart(character)
    return character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso"))
end

local function GetHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function IsAlive(player)
    local character = GetCharacter(player)
    local humanoid = GetHumanoid(character)
    return character and humanoid and humanoid.Health > 0
end

local function GetDistance(part1, part2)
    if not part1 or not part2 then return math.huge end
    return (part1.Position - part2.Position).Magnitude
end

local function WorldToScreen(position)
    local screenPoint, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(screenPoint.X, screenPoint.Y), onScreen
end

local function IsVisible(targetPart)
    if not Config.VisibleCheck then return true end
    local character = GetCharacter(LocalPlayer)
    local root = GetRootPart(character)
    if not root or not targetPart then return false end
    local ray = Ray.new(root.Position, (targetPart.Position - root.Position).Unit * 1000)
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, {character})
    return hit and hit:IsDescendantOf(targetPart.Parent)
end

-- ===================================================================
-- AIMBOT (Microwave Hub's — Mouse-Tracked FOV, Direct Lerp)
-- ===================================================================
local function GetClosestTarget()
    local closest, dist = nil, Config.AimbotFOV
    local mousePos = UserInputService:GetMouseLocation()

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end

        if Config.TeamCheck and plr.Team and plr.Team == LocalPlayer.Team then continue end

        local ch = GetCharacter(plr)
        if not ch then continue end

        local hum = GetHumanoid(ch)
        if not hum or hum.Health <= 0 then continue end

        local root = ch:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
        if onScreen then
            local mag = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
            if mag < dist then
                dist = mag
                closest = root
            end
        end
    end

    return closest
end

local function UpdateAimbotFOV()
    if not DrawingSupported then return end
    local show = Config.Aimbot and Config.AimbotShowFOV
    local mousePos = UserInputService:GetMouseLocation()

    if FOVCircle then
        FOVCircle.Position = mousePos
        FOVCircle.Radius = Config.AimbotFOV
        FOVCircle.Visible = show
    end
    if FOVGlow then
        FOVGlow.Position = mousePos
        FOVGlow.Radius = Config.AimbotFOV
        FOVGlow.Visible = show
    end
    if FOVCenterDot then
        FOVCenterDot.Position = mousePos
        FOVCenterDot.Visible = show
    end
end

local function DoAimbot()
    Camera = workspace.CurrentCamera
    if not Config.Aimbot then
        if FOVCircle then FOVCircle.Visible = false end
        if FOVGlow then FOVGlow.Visible = false end
        if FOVCenterDot then FOVCenterDot.Visible = false end
        return
    end

    UpdateAimbotFOV()

    -- Hold RMB to lock
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        return
    end

    local target = GetClosestTarget()
    if target then
        local camCF = Camera.CFrame
        local newCF = CFrame.new(camCF.Position, target.Position)
        Camera.CFrame = camCF:Lerp(newCF, Config.AimbotSmoothing / 100)
    end
end

-- ===================================================================
-- AIMBOT (Sentry OG — Bone Targeting, Dynamic Smooth, Prediction)
-- ===================================================================
local function GetBestBone(character)
    if not character then return nil end
    local part = character:FindFirstChild(Config.OGAimbotBone)
    if part then return part end
    return character:FindFirstChild("Head")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Torso")
end

local function GetClosestEnemy()
    local myChar = GetCharacter(LocalPlayer)
    local myRoot = GetRootPart(myChar)
    if not myRoot then return nil end

    aimRayParams.FilterDescendantsInstances = { myChar }

    local best, bestDist = nil, Config.OGAimbotFOV
    local vs     = Camera.ViewportSize
    local ctr    = Vector2.new(vs.X * 0.5, vs.Y * 0.5)
    local camPos = Camera.CFrame.Position

    for _, plr in pairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end

        if Config.TeamCheck and plr.Team and plr.Team == LocalPlayer.Team then continue end

        local ch = GetCharacter(plr)
        if not ch then continue end

        local hum = GetHumanoid(ch)
        if not hum or hum.Health <= 0 then continue end

        local bone = GetBestBone(ch)
        if not bone then continue end

        local sp, onScreen = Camera:WorldToViewportPoint(bone.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(sp.X, sp.Y) - ctr).Magnitude
        if dist > Config.OGAimbotFOV then continue end

        if Config.VisibleCheck then
            local hit = workspace:Raycast(camPos, bone.Position - camPos, aimRayParams)
            if hit and not hit.Instance:IsDescendantOf(ch) then continue end
        end

        if dist < bestDist then
            bestDist = dist
            best = bone
        end
    end

    return best, bestDist
end

local function UpdateOGAimbotFOV()
    if not DrawingSupported then return end
    local show = Config.OGAimbot and Config.OGAimbotShowFOV
    local vs = Camera.ViewportSize
    local center = Vector2.new(vs.X * 0.5, vs.Y * 0.5)

    if OGFOVCircle then
        OGFOVCircle.Position = center
        OGFOVCircle.Radius = Config.OGAimbotFOV
        OGFOVCircle.Visible = show
    end
    if OGFOVGlow then
        OGFOVGlow.Position = center
        OGFOVGlow.Radius = Config.OGAimbotFOV
        OGFOVGlow.Visible = show
    end
    if OGFOVCenterDot then
        OGFOVCenterDot.Position = center
        OGFOVCenterDot.Visible = show
    end
end

local function DoOGAimbot()
    Camera = workspace.CurrentCamera
    if not Config.OGAimbot then
        if OGFOVCircle then OGFOVCircle.Visible = false end
        if OGFOVGlow then OGFOVGlow.Visible = false end
        if OGFOVCenterDot then OGFOVCenterDot.Visible = false end
        return
    end

    UpdateOGAimbotFOV()

    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        return
    end

    local target, targetScreenDist = GetClosestEnemy()
    if not target then return end

    local aimPos = target.Position
    local predStrength = Config.OGAimbotPrediction / 100

    if predStrength > 0 then
        local targetChar = target.Parent
        if targetChar then
            local rootPart = targetChar:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local vel = rootPart.AssemblyLinearVelocity or rootPart.Velocity
                aimPos = aimPos + (vel * predStrength)
            end
        end
    end

    local smoothing = Config.OGAimbotSmoothing / 100

    if Config.OGAimbotDynamicSmooth and targetScreenDist then
        local ratio = math.clamp(targetScreenDist / math.max(Config.OGAimbotFOV, 1), 0, 1)
        local smoothMin = math.max(smoothing - 0.10, 0.15)
        local smoothMax = math.min(smoothing + 0.30, 0.90)
        smoothing = smoothMin + (smoothMax - smoothMin) * ratio
    end

    Camera.CFrame = Camera.CFrame:Lerp(
        CFrame.lookAt(Camera.CFrame.Position, aimPos),
        smoothing
    )
end

-- ===================================================================
-- AIMBOT (Neon Hub's — Camera-Center FOV, Smooth Lerp, Instant Snap)
-- From: Neon Space Universal Delta (CHEESE_BOY / Scriptblox)
-- Uses screen-center FOV (not mouse-tracked), smoothness=0 snaps
-- instantly, higher values lerp. Wall check via Raycast. Per-team
-- filter support (NeonTeamAimSettings table).
-- ===================================================================
local function GetNeonBone(character)
    if not character then return nil end
    local part = character:FindFirstChild(Config.NeonAimbotBone)
    if part then return part end
    return character:FindFirstChild("Head")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("HumanoidRootPart")
        or character:FindFirstChild("Torso")
end

local function NeonWallCheck(targetPart)
    if not Config.NeonAimbotWallCheck then return true end
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {GetCharacter(LocalPlayer)}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, direction, params)
    return result and result.Instance:IsDescendantOf(targetPart.Parent)
end

local function FindNeonTarget()
    local bestTarget, bestDist = nil, math.huge
    local screenCenter = Camera.ViewportSize / 2

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if not plr.Character then continue end

        local humanoid = plr.Character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        -- Global team check (shared Config.TeamCheck)
        if Config.TeamCheck and plr.Team and plr.Team == LocalPlayer.Team then continue end

        -- Neon-style per-team filter
        if Config.NeonAimbotTeamFilter then
            local teamName = plr.Team and plr.Team.Name
            if teamName and NeonTeamAimSettings[teamName] == false then continue end
        end

        local bone = GetNeonBone(plr.Character)
        if not bone then continue end

        local screenPos, onScreen = Camera:WorldToViewportPoint(bone.Position)
        if not onScreen then continue end

        local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
        if dist < Config.NeonAimbotFOV and dist < bestDist then
            if NeonWallCheck(bone) then
                bestDist = dist
                bestTarget = bone
            end
        end
    end

    return bestTarget
end

local function UpdateNeonAimbotFOV()
    if not DrawingSupported then return end
    local show = Config.NeonAimbot and Config.NeonAimbotShowFOV
    local center = Camera.ViewportSize / 2

    if NeonFOVCircle then
        NeonFOVCircle.Position = center
        NeonFOVCircle.Radius = Config.NeonAimbotFOV
        NeonFOVCircle.Visible = show
    end
    if NeonFOVGlow then
        NeonFOVGlow.Position = center
        NeonFOVGlow.Radius = Config.NeonAimbotFOV
        NeonFOVGlow.Visible = show
    end
    if NeonFOVCenterDot then
        NeonFOVCenterDot.Position = center
        NeonFOVCenterDot.Visible = show
    end
end

local function DoNeonAimbot()
    Camera = workspace.CurrentCamera
    if not Config.NeonAimbot then
        if NeonFOVCircle then NeonFOVCircle.Visible = false end
        if NeonFOVGlow then NeonFOVGlow.Visible = false end
        if NeonFOVCenterDot then NeonFOVCenterDot.Visible = false end
        return
    end

    UpdateNeonAimbotFOV()

    -- Hold RMB to engage (consistent with other Sentry aimbots)
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        return
    end

    local target = FindNeonTarget()
    if not target then return end

    if Config.NeonAimbotSmoothing == 0 then
        -- Instant snap (Neon default behavior)
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
    else
        -- Smooth lerp (higher = slower tracking)
        Camera.CFrame = Camera.CFrame:Lerp(
            CFrame.new(Camera.CFrame.Position, target.Position),
            1 / (Config.NeonAimbotSmoothing * 2)
        )
    end
end


-- ===================================================================
-- ESP (COMPLETE)
-- ===================================================================

-- ===================================================================
-- SENTRY ESP v2 — COMPLETE REWRITE
-- Corner Boxes • Health Bar • Names • Distance • Tracers
-- Head Dots • Tool Display • Vis-Check Color Shift
-- Off-Screen Arrows • Distance Fade • Movement Flags
-- Universal R6/R15 • Drawing-Library Safe • Xeno Ready
-- ===================================================================
do -- scoped to free local registers (Luau 200-register limit)
local ESP2Objects = {}
local espRayParams = RaycastParams.new()
espRayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Performance: frame stagger + vis-check cache
local espFrameNum = 0
local espCache = {} -- [player] = {lastFrame, visResult, visFrame}

-- Pre-baked colors (avoid creating Color3 every frame)
local CLR_VIS_YES = Color3.fromRGB(85, 255, 85)
local CLR_VIS_NO  = Color3.fromRGB(255, 55, 55)
local CLR_WHITE   = Color3.fromRGB(255, 255, 255)
local CLR_DIST    = Color3.fromRGB(200, 200, 200)
local CLR_TOOL    = Color3.fromRGB(255, 200, 80)
local CLR_FLAGS   = Color3.fromRGB(200, 255, 200)
local CLR_BLACK   = Color3.new(0, 0, 0)

local function ESP2_IsTargetVisible(character, targetPos)
    local camPos = Camera.CFrame.Position
    local direction = targetPos - camPos
    local localChar = GetCharacter(LocalPlayer)
    if not localChar then return false end
    espRayParams.FilterDescendantsInstances = {localChar}
    local result = workspace:Raycast(camPos, direction, espRayParams)
    if result then
        return result.Instance:IsDescendantOf(character)
    end
    return true
end

local function ESP2_GetFlags(character, humanoid)
    local flags = {}
    local rootPart = GetRootPart(character)
    if not rootPart then return "" end
    local state = humanoid:GetState()
    if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
        table.insert(flags, "JMP")
    end
    local vel = rootPart.AssemblyLinearVelocity or rootPart.Velocity
    local hSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
    if hSpeed > 28 then
        table.insert(flags, "FAST")
    end
    return table.concat(flags, " ")
end

CreateESP2 = function(player)
    if not DrawingSupported then return end
    if ESP2Objects[player] then return end
    local esp = {}

    -- Corner box: 8 outline lines + 8 main lines
    esp.CO = {}
    esp.CL = {}
    for i = 1, 8 do
        local o = Drawing.new("Line")
        o.Thickness = 3
        o.Color = Color3.new(0, 0, 0)
        o.Visible = false
        o.ZIndex = 1
        esp.CO[i] = o
        local l = Drawing.new("Line")
        l.Thickness = 1.2
        l.Visible = false
        l.ZIndex = 2
        esp.CL[i] = l
    end

    -- Health bar background + foreground
    esp.HBG = Drawing.new("Line")
    esp.HBG.Thickness = 4
    esp.HBG.Color = Color3.fromRGB(15, 15, 15)
    esp.HBG.Visible = false
    esp.HBG.ZIndex = 1

    esp.HBar = Drawing.new("Line")
    esp.HBar.Thickness = 2
    esp.HBar.Visible = false
    esp.HBar.ZIndex = 2

    -- Name text
    esp.Name = Drawing.new("Text")
    esp.Name.Size = 13
    esp.Name.Center = true
    esp.Name.Outline = true
    esp.Name.OutlineColor = Color3.new(0, 0, 0)
    esp.Name.Visible = false
    esp.Name.ZIndex = 3

    -- Distance text
    esp.Dist = Drawing.new("Text")
    esp.Dist.Size = 12
    esp.Dist.Center = true
    esp.Dist.Outline = true
    esp.Dist.OutlineColor = Color3.new(0, 0, 0)
    esp.Dist.Visible = false
    esp.Dist.ZIndex = 3

    -- Tool text
    esp.Tool = Drawing.new("Text")
    esp.Tool.Size = 11
    esp.Tool.Center = true
    esp.Tool.Outline = true
    esp.Tool.OutlineColor = Color3.new(0, 0, 0)
    esp.Tool.Color = Color3.fromRGB(255, 200, 80)
    esp.Tool.Visible = false
    esp.Tool.ZIndex = 3

    -- Flags text
    esp.Flags = Drawing.new("Text")
    esp.Flags.Size = 11
    esp.Flags.Center = false
    esp.Flags.Outline = true
    esp.Flags.OutlineColor = Color3.new(0, 0, 0)
    esp.Flags.Color = Color3.fromRGB(200, 255, 200)
    esp.Flags.Visible = false
    esp.Flags.ZIndex = 3

    -- Tracer outline + main
    esp.TrO = Drawing.new("Line")
    esp.TrO.Thickness = 3
    esp.TrO.Color = Color3.new(0, 0, 0)
    esp.TrO.Visible = false
    esp.TrO.ZIndex = 0

    esp.Tracer = Drawing.new("Line")
    esp.Tracer.Thickness = 1.2
    esp.Tracer.Visible = false
    esp.Tracer.ZIndex = 1

    -- Head dot
    esp.HDot = Drawing.new("Circle")
    esp.HDot.Thickness = 1
    esp.HDot.Filled = true
    esp.HDot.Radius = 3
    esp.HDot.NumSides = 16
    esp.HDot.Visible = false
    esp.HDot.ZIndex = 4

    -- Off-screen arrow: 2 chevron lines + 1 center dot
    esp.ArrL = {}
    for i = 1, 2 do
        local al = Drawing.new("Line")
        al.Thickness = 2
        al.Visible = false
        al.ZIndex = 5
        esp.ArrL[i] = al
    end
    esp.ArrD = Drawing.new("Circle")
    esp.ArrD.Thickness = 1
    esp.ArrD.Filled = true
    esp.ArrD.Radius = 4
    esp.ArrD.NumSides = 12
    esp.ArrD.Visible = false
    esp.ArrD.ZIndex = 5

    ESP2Objects[player] = esp
end

HideESP2 = function(esp)
    for i = 1, 8 do
        esp.CO[i].Visible = false
        esp.CL[i].Visible = false
    end
    esp.HBG.Visible = false
    esp.HBar.Visible = false
    esp.Name.Visible = false
    esp.Dist.Visible = false
    esp.Tool.Visible = false
    esp.Flags.Visible = false
    esp.TrO.Visible = false
    esp.Tracer.Visible = false
    esp.HDot.Visible = false
    for i = 1, 2 do esp.ArrL[i].Visible = false end
    esp.ArrD.Visible = false
end

UpdateESP2 = function(player, frameNum, localRootPos, vpSize)
    if player == LocalPlayer then return end
    local esp = ESP2Objects[player]
    if (not Config.ESP and not Config.ESPTracers) or not DrawingSupported then
        if esp then HideESP2(esp) end
        return
    end
    if not esp then CreateESP2(player); esp = ESP2Objects[player] end
    if not esp then return end

    local character = GetCharacter(player)
    local rootPart = GetRootPart(character)
    local humanoid = GetHumanoid(character)

    if not (character and rootPart and humanoid and humanoid.Health > 0) then
        HideESP2(esp)
        return
    end

    -- Distance cull
    if not localRootPos then HideESP2(esp); return end
    local dist = (rootPart.Position - localRootPos).Magnitude
    if dist > Config.ESPMaxDist then HideESP2(esp); return end

    -- Team filter
    if Config.TeamCheck and player.Team and player.Team == LocalPlayer.Team then
        HideESP2(esp); return
    end

    -- Frame stagger: skip update if not due (close=every frame, mid=2, far=4)
    local cache = espCache[player]
    if not cache then
        cache = {lastFrame = 0, visResult = true, visFrame = 0}
        espCache[player] = cache
    end
    local interval = 1
    if dist > 600 then interval = 4
    elseif dist > 200 then interval = 2 end
    if (frameNum - cache.lastFrame) < interval then return end
    cache.lastFrame = frameNum

    -- Distance-based fade
    local fadeBegin = Config.ESPMaxDist * 0.7
    local alpha = 1
    if dist > fadeBegin then
        alpha = math.clamp(1 - (dist - fadeBegin) / (Config.ESPMaxDist - fadeBegin), 0.15, 1)
    end

    -- Color: vis-check (CACHED) > team color > white
    local color
    if Config.ESPVisCheck then
        if (frameNum - cache.visFrame) >= 8 then
            cache.visResult = ESP2_IsTargetVisible(character, rootPart.Position)
            cache.visFrame = frameNum
        end
        color = cache.visResult and CLR_VIS_YES or CLR_VIS_NO
    elseif Config.ESPTeamColor and player.Team then
        color = player.Team.TeamColor.Color
    else
        color = CLR_WHITE
    end

    -- Project to viewport
    local sp3 = Camera:WorldToViewportPoint(rootPart.Position)
    local onScreen = sp3.Z > 0
    local screenPos = Vector2.new(sp3.X, sp3.Y)

    local inBounds = onScreen
        and sp3.X > -100 and sp3.X < vpSize.X + 100
        and sp3.Y > -100 and sp3.Y < vpSize.Y + 100

    if inBounds then
        -- ======== HIDE OFF-SCREEN ELEMENTS ========
        for i = 1, 2 do esp.ArrL[i].Visible = false end
        esp.ArrD.Visible = false

        -- ======== BOUNDING BOX MATH ========
        local head = character:FindFirstChild("Head")
        if not head then HideESP2(esp); return end
        local headWorld = head.Position + Vector3.new(0, 0.6, 0)
        local feetWorld = rootPart.Position - Vector3.new(0, 3.0, 0)
        local h3 = Camera:WorldToViewportPoint(headWorld)
        local f3 = Camera:WorldToViewportPoint(feetWorld)
        local boxH = math.abs(h3.Y - f3.Y)
        local boxW = boxH * 0.55
        local cx = screenPos.X
        local cy = screenPos.Y
        local x1 = cx - boxW * 0.5
        local y1 = cy - boxH * 0.5
        local x2 = cx + boxW * 0.5
        local y2 = cy + boxH * 0.5
        local cLen = math.max(boxH * 0.2, 5)

        -- ======== CORNER BOX ========
        if Config.ESP and Config.ESPCornerBox then
            -- 8 corners: TL-H, TL-V, TR-H, TR-V, BL-H, BL-V, BR-H, BR-V
            local pts = {
                {Vector2.new(x1, y1), Vector2.new(x1 + cLen, y1)},
                {Vector2.new(x1, y1), Vector2.new(x1, y1 + cLen)},
                {Vector2.new(x2, y1), Vector2.new(x2 - cLen, y1)},
                {Vector2.new(x2, y1), Vector2.new(x2, y1 + cLen)},
                {Vector2.new(x1, y2), Vector2.new(x1 + cLen, y2)},
                {Vector2.new(x1, y2), Vector2.new(x1, y2 - cLen)},
                {Vector2.new(x2, y2), Vector2.new(x2 - cLen, y2)},
                {Vector2.new(x2, y2), Vector2.new(x2, y2 - cLen)},
            }
            for i = 1, 8 do
                esp.CO[i].From = pts[i][1]
                esp.CO[i].To = pts[i][2]
                esp.CO[i].Transparency = alpha
                esp.CO[i].Visible = true
                esp.CL[i].From = pts[i][1]
                esp.CL[i].To = pts[i][2]
                esp.CL[i].Color = color
                esp.CL[i].Transparency = alpha
                esp.CL[i].Visible = true
            end
        else
            for i = 1, 8 do
                esp.CO[i].Visible = false
                esp.CL[i].Visible = false
            end
        end

        -- ======== HEALTH BAR ========
        if Config.ESP and Config.ESPHealth then
            local pct = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
            local barX = x1 - 6
            esp.HBG.From = Vector2.new(barX, y2)
            esp.HBG.To = Vector2.new(barX, y1)
            esp.HBG.Transparency = alpha
            esp.HBG.Visible = true
            esp.HBar.From = Vector2.new(barX, y2)
            esp.HBar.To = Vector2.new(barX, y2 - boxH * pct)
            esp.HBar.Color = Color3.fromRGB(255 * (1 - pct), 255 * pct, 0)
            esp.HBar.Transparency = alpha
            esp.HBar.Visible = true
        else
            esp.HBG.Visible = false
            esp.HBar.Visible = false
        end

        -- ======== NAME TAG ========
        if Config.ESP and Config.ESPNames then
            local dName = player.DisplayName
            if dName ~= player.Name then
                esp.Name.Text = dName .. " [" .. player.Name .. "]"
            else
                esp.Name.Text = player.Name
            end
            esp.Name.Position = Vector2.new(cx, y1 - 16)
            esp.Name.Color = color
            esp.Name.Transparency = alpha
            esp.Name.Visible = true
        else
            esp.Name.Visible = false
        end

        -- ======== DISTANCE ========
        local bottomOffset = 4
        if Config.ESP and Config.ESPDistance then
            esp.Dist.Text = math.floor(dist) .. " stds"
            esp.Dist.Position = Vector2.new(cx, y2 + bottomOffset)
            esp.Dist.Color = CLR_DIST
            esp.Dist.Transparency = alpha
            esp.Dist.Visible = true
            bottomOffset = bottomOffset + 14
        else
            esp.Dist.Visible = false
        end

        -- ======== TOOL DISPLAY ========
        if Config.ESP and Config.ESPToolName then
            local tool = character:FindFirstChildOfClass("Tool")
            if tool then
                esp.Tool.Text = tool.Name
                esp.Tool.Position = Vector2.new(cx, y2 + bottomOffset)
                esp.Tool.Transparency = alpha
                esp.Tool.Visible = true
                bottomOffset = bottomOffset + 13
            else
                esp.Tool.Visible = false
            end
        else
            esp.Tool.Visible = false
        end

        -- ======== FLAGS ========
        if Config.ESP and Config.ESPFlags then
            local fStr = ESP2_GetFlags(character, humanoid)
            if fStr ~= "" then
                esp.Flags.Text = fStr
                esp.Flags.Position = Vector2.new(x2 + 4, y1)
                esp.Flags.Transparency = alpha
                esp.Flags.Visible = true
            else
                esp.Flags.Visible = false
            end
        else
            esp.Flags.Visible = false
        end

        -- ======== TRACER ========
        if Config.ESPTracers then
            local bottom = Vector2.new(vpSize.X * 0.5, vpSize.Y)
            esp.TrO.From = bottom
            esp.TrO.To = Vector2.new(cx, y2)
            esp.TrO.Transparency = alpha * 0.6
            esp.TrO.Visible = true
            esp.Tracer.From = bottom
            esp.Tracer.To = Vector2.new(cx, y2)
            esp.Tracer.Color = Color3.fromRGB(0, 220, 255)
            esp.Tracer.Transparency = alpha * 0.8
            esp.Tracer.Visible = true
        else
            esp.TrO.Visible = false
            esp.Tracer.Visible = false
        end

        -- ======== HEAD DOT ========
        if Config.ESP and Config.ESPHeadDot and head then
            local hdp = Camera:WorldToViewportPoint(head.Position)
            esp.HDot.Position = Vector2.new(hdp.X, hdp.Y)
            esp.HDot.Color = color
            esp.HDot.Transparency = alpha
            esp.HDot.Visible = true
        else
            esp.HDot.Visible = false
        end

    else
        -- ======== OFF SCREEN — hide all on-screen elements ========
        for i = 1, 8 do
            esp.CO[i].Visible = false
            esp.CL[i].Visible = false
        end
        esp.HBG.Visible = false
        esp.HBar.Visible = false
        esp.Name.Visible = false
        esp.Dist.Visible = false
        esp.Tool.Visible = false
        esp.Flags.Visible = false
        esp.TrO.Visible = false
        esp.Tracer.Visible = false
        esp.HDot.Visible = false

        -- ======== OFF-SCREEN ARROWS ========
        if Config.ESP and Config.ESPOffscreen then
            local cX = vpSize.X * 0.5
            local cY = vpSize.Y * 0.5
            local dx = sp3.X - cX
            local dy = sp3.Y - cY
            local ang = math.atan2(dy, dx)
            if sp3.Z < 0 then ang = ang + math.pi end
            local pad = 50
            local eX = cX + math.cos(ang) * (cX - pad)
            local eY = cY + math.sin(ang) * (cY - pad)
            eX = math.clamp(eX, pad, vpSize.X - pad)
            eY = math.clamp(eY, pad, vpSize.Y - pad)
            local aSize = 14
            local perpAng = ang + math.pi * 0.5
            local tipX = eX + math.cos(ang) * aSize
            local tipY = eY + math.sin(ang) * aSize
            local b1x = eX + math.cos(perpAng) * aSize * 0.45
            local b1y = eY + math.sin(perpAng) * aSize * 0.45
            local b2x = eX - math.cos(perpAng) * aSize * 0.45
            local b2y = eY - math.sin(perpAng) * aSize * 0.45
            esp.ArrL[1].From = Vector2.new(b1x, b1y)
            esp.ArrL[1].To = Vector2.new(tipX, tipY)
            esp.ArrL[1].Color = color
            esp.ArrL[1].Transparency = alpha
            esp.ArrL[1].Visible = true
            esp.ArrL[2].From = Vector2.new(b2x, b2y)
            esp.ArrL[2].To = Vector2.new(tipX, tipY)
            esp.ArrL[2].Color = color
            esp.ArrL[2].Transparency = alpha
            esp.ArrL[2].Visible = true
            esp.ArrD.Position = Vector2.new(eX, eY)
            esp.ArrD.Color = color
            esp.ArrD.Transparency = alpha
            esp.ArrD.Visible = true
        else
            for i = 1, 2 do esp.ArrL[i].Visible = false end
            esp.ArrD.Visible = false
        end
    end
end

RemoveESP2 = function(player)
    local esp = ESP2Objects[player]
    if not esp then return end
    for i = 1, 8 do
        pcall(function() esp.CO[i]:Remove() end)
        pcall(function() esp.CL[i]:Remove() end)
    end
    pcall(function() esp.HBG:Remove() end)
    pcall(function() esp.HBar:Remove() end)
    pcall(function() esp.Name:Remove() end)
    pcall(function() esp.Dist:Remove() end)
    pcall(function() esp.Tool:Remove() end)
    pcall(function() esp.Flags:Remove() end)
    pcall(function() esp.TrO:Remove() end)
    pcall(function() esp.Tracer:Remove() end)
    pcall(function() esp.HDot:Remove() end)
    for i = 1, 2 do pcall(function() esp.ArrL[i]:Remove() end) end
    pcall(function() esp.ArrD:Remove() end)
    ESP2Objects[player] = nil
    espCache[player] = nil
end

-- ESP2_Tick: called once per frame from render loop. Handles frame counting,
-- caches localRoot + vpSize once, then iterates all players.
ESP2_Tick = function()
    espFrameNum = espFrameNum + 1
    local localChar = GetCharacter(LocalPlayer)
    local localRoot = GetRootPart(localChar)
    local localRootPos = localRoot and localRoot.Position or nil
    local vpSize = Camera.ViewportSize
    for _, player in pairs(Players:GetPlayers()) do
        UpdateESP2(player, espFrameNum, localRootPos, vpSize)
    end
end

end -- close ESP2 do-scope

-- ===================================================================
-- CROSSHAIR (Matte Grey X — IIFE scoped)
-- ===================================================================
;(function()
    local GAP, ARM = 6, 20
    local CLR = Color3.fromRGB(155, 155, 160)
    local OL = Color3.new(0, 0, 0)
    local xhO, xhL = {}, {}
    if DrawingSupported then
        for i = 1, 4 do
            local o = Drawing.new("Line"); o.Thickness = 3; o.Color = OL; o.Transparency = 0.5; o.Visible = false; o.ZIndex = 50; xhO[i] = o
            local l = Drawing.new("Line"); l.Thickness = 1.2; l.Color = CLR; l.Transparency = 1; l.Visible = false; l.ZIndex = 51; xhL[i] = l
        end
    end
    Config._XH = function()
        if not DrawingSupported or not Config.Crosshair then
            for i = 1, 4 do if xhO[i] then xhO[i].Visible = false; xhL[i].Visible = false end end
            return
        end
        local vp = Camera.ViewportSize
        local cx, cy = vp.X * 0.5, vp.Y * 0.5
        local d = 0.7071
        local gx, gy = GAP * d, GAP * d
        local ax, ay = (GAP + ARM) * d, (GAP + ARM) * d
        local pts = {
            {Vector2.new(cx - gx, cy - gy), Vector2.new(cx - ax, cy - ay)},
            {Vector2.new(cx + gx, cy + gy), Vector2.new(cx + ax, cy + ay)},
            {Vector2.new(cx + gx, cy - gy), Vector2.new(cx + ax, cy - ay)},
            {Vector2.new(cx - gx, cy + gy), Vector2.new(cx - ax, cy + ay)},
        }
        for i = 1, 4 do
            xhO[i].From = pts[i][1]; xhO[i].To = pts[i][2]; xhO[i].Visible = true
            xhL[i].From = pts[i][1]; xhL[i].To = pts[i][2]; xhL[i].Visible = true
        end
    end
end)()
-- ===================================================================
-- SKELETON ESP (Neon Cyan — double-layered glow lines)
-- ===================================================================
-- Draws lines between character joints to form a stick figure.
-- Each bone = 2 Drawing lines: thick transparent glow underneath
-- + thin bright line on top = neon effect (same trick as FOV circles).
-- Supports R15 (14 connections) and R6 (5 connections) characters.
-- ===================================================================
local SkeletonObjects = {}

-- R15 bone connections (PartA → PartB)
local R15Bones = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"UpperTorso", "RightUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LowerTorso", "RightUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

-- R6 fallback connections
local R6Bones = {
    {"Head", "Torso"},
    {"Torso", "Left Arm"},
    {"Torso", "Right Arm"},
    {"Torso", "Left Leg"},
    {"Torso", "Right Leg"},
}

local function CreateSkeleton(player)
    if not DrawingSupported then return end
    if SkeletonObjects[player] then return end

    -- 4-layer neon bloom per bone (14 bones × 4 layers = 56 lines per player)
    -- Layer 1: outermost bloom — wide, soft, atmospheric bleed
    -- Layer 2: mid glow — the color body
    -- Layer 3: inner glow — where the neon pops
    -- Layer 4: core — white-hot center like a real neon tube
    local bones = {}
    for i = 1, 14 do
        -- Layer 1: Outermost bloom (wide soft teal haze)
        local bloom = Drawing.new("Line")
        bloom.Color = Color3.fromRGB(0, 120, 160)
        bloom.Thickness = 9
        bloom.Transparency = 0.12
        bloom.Visible = false
        bloom.ZIndex = 3

        -- Layer 2: Mid glow (cyan body)
        local glow = Drawing.new("Line")
        glow.Color = Color3.fromRGB(0, 180, 230)
        glow.Thickness = 5.5
        glow.Transparency = 0.3
        glow.Visible = false
        glow.ZIndex = 4

        -- Layer 3: Inner glow (bright vivid cyan)
        local inner = Drawing.new("Line")
        inner.Color = Color3.fromRGB(0, 230, 255)
        inner.Thickness = 3
        inner.Transparency = 0.65
        inner.Visible = false
        inner.ZIndex = 5

        -- Layer 4: Core (white-hot center — the neon filament)
        local core = Drawing.new("Line")
        core.Color = Color3.fromRGB(180, 245, 255)
        core.Thickness = 1.5
        core.Transparency = 0.95
        core.Visible = false
        core.ZIndex = 6

        table.insert(bones, {bloom = bloom, glow = glow, inner = inner, core = core})
    end

    SkeletonObjects[player] = bones
end

local function UpdateSkeleton(player)
    if not Config.ESPSkeleton or not DrawingSupported or player == LocalPlayer then return end

    local skel = SkeletonObjects[player]
    if not skel then
        CreateSkeleton(player)
        skel = SkeletonObjects[player]
    end
    if not skel then return end

    local character = GetCharacter(player)
    local humanoid = GetHumanoid(character)

    if not (character and humanoid and humanoid.Health > 0) then
        for _, bone in pairs(skel) do
            bone.bloom.Visible = false
            bone.glow.Visible = false
            bone.inner.Visible = false
            bone.core.Visible = false
        end
        return
    end

    -- Detect R15 vs R6
    local isR15 = character:FindFirstChild("UpperTorso") ~= nil
    local boneMap = isR15 and R15Bones or R6Bones
    local boneCount = #boneMap

    for i, bone in ipairs(skel) do
        if i > boneCount then
            bone.bloom.Visible = false
            bone.glow.Visible = false
            bone.inner.Visible = false
            bone.core.Visible = false
        else
            local conn = boneMap[i]
            local partA = character:FindFirstChild(conn[1])
            local partB = character:FindFirstChild(conn[2])

            if partA and partB then
                local screenA, onScreenA = WorldToScreen(partA.Position)
                local screenB, onScreenB = WorldToScreen(partB.Position)

                if onScreenA and onScreenB then
                    bone.bloom.From = screenA
                    bone.bloom.To = screenB
                    bone.bloom.Visible = true

                    bone.glow.From = screenA
                    bone.glow.To = screenB
                    bone.glow.Visible = true

                    bone.inner.From = screenA
                    bone.inner.To = screenB
                    bone.inner.Visible = true

                    bone.core.From = screenA
                    bone.core.To = screenB
                    bone.core.Visible = true
                else
                    bone.bloom.Visible = false
                    bone.glow.Visible = false
                    bone.inner.Visible = false
                    bone.core.Visible = false
                end
            else
                bone.bloom.Visible = false
                bone.glow.Visible = false
                bone.inner.Visible = false
                bone.core.Visible = false
            end
        end
    end
end

local function RemoveSkeleton(player)
    local skel = SkeletonObjects[player]
    if skel then
        for _, bone in pairs(skel) do
            pcall(function() bone.bloom:Remove() end)
            pcall(function() bone.glow:Remove() end)
            pcall(function() bone.inner:Remove() end)
            pcall(function() bone.core:Remove() end)
        end
        SkeletonObjects[player] = nil
    end
end

-- ===================================================================
-- CHARMS (Highlight-based wall ESP — team-colored glow)
-- ===================================================================
local function ApplyCharm(player)
    if player == LocalPlayer then return end
    local character = GetCharacter(player)
    if not character then return end

    if CharmObjects[player] then
        pcall(function() CharmObjects[player]:Destroy() end)
        CharmObjects[player] = nil
    end

    if not Config.ESPCharms then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "Sentry_Charm"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = true

    -- Color logic: Pink overrides team color when enabled
    if Config.PinkCharms then
        highlight.FillColor = Color3.fromRGB(255, 140, 180)
        highlight.OutlineColor = Color3.fromRGB(255, 200, 220)
    elseif player.Team then
        highlight.FillColor = player.Team.TeamColor.Color
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    else
        highlight.FillColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineColor = Color3.fromRGB(200, 200, 200)
    end

    highlight.FillTransparency = Config.CharmFillTransparency
    highlight.OutlineTransparency = Config.CharmOutlineTransparency
    highlight.Parent = character
    CharmObjects[player] = highlight

    player.CharacterAdded:Connect(function(newChar)
        task.wait(0.5)
        if not Config.ESPCharms then return end
        pcall(function()
            if CharmObjects[player] then CharmObjects[player]:Destroy() end
        end)
        local h = Instance.new("Highlight")
        h.Name = "Sentry_Charm"
        h.Adornee = newChar
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Enabled = true
        if Config.PinkCharms then
            h.FillColor = Color3.fromRGB(255, 140, 180)
            h.OutlineColor = Color3.fromRGB(255, 200, 220)
        elseif player.Team then
            h.FillColor = player.Team.TeamColor.Color
            h.OutlineColor = Color3.fromRGB(255, 255, 255)
        else
            h.FillColor = Color3.fromRGB(255, 255, 255)
            h.OutlineColor = Color3.fromRGB(200, 200, 200)
        end
        h.FillTransparency = Config.CharmFillTransparency
        h.OutlineTransparency = Config.CharmOutlineTransparency
        h.Parent = newChar
        CharmObjects[player] = h
    end)
end

local function RemoveCharm(player)
    if CharmObjects[player] then
        pcall(function() CharmObjects[player]:Destroy() end)
        CharmObjects[player] = nil
    end
end

local function RefreshAllCharms()
    for p, _ in pairs(CharmObjects) do
        RemoveCharm(p)
    end
    if Config.ESPCharms then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then ApplyCharm(p) end
        end
    end
end


-- ===================================================================
-- PLAYER MODIFICATIONS
-- ===================================================================

local function ApplyMods()
    local character = GetCharacter(LocalPlayer)
    local humanoid = GetHumanoid(character)
    
    if not humanoid then return end
    
    if Config.SuperSpeed then
        humanoid.WalkSpeed = Config.SpeedAmount
    else
        humanoid.WalkSpeed = 16
    end
    
    if Config.SuperJump then
        humanoid.JumpPower = Config.JumpAmount
    else
        humanoid.JumpPower = 50
    end
end

-- ===================================================================
-- FLY
-- ===================================================================
local function StartFly()
    local character = GetCharacter(LocalPlayer)
    local rootPart = GetRootPart(character)
    
    if not rootPart or Flying then return end
    
    Flying = true
    
    local bg = Instance.new("BodyGyro")
    bg.P = 9e4
    bg.maxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.cframe = rootPart.CFrame
    bg.Parent = rootPart
    
    local bv = Instance.new("BodyVelocity")
    bv.velocity = Vector3.new(0, 0, 0)
    bv.maxForce = Vector3.new(9e9, 9e9, 9e9)
    bv.Parent = rootPart
    
    FlyObjects = {bg, bv}
    
    local con
    con = RunService.RenderStepped:Connect(function()
        if not Config.Fly or not Flying then
            con:Disconnect()
            StopFly()
            return
        end
        
        if not rootPart or not rootPart.Parent then
            con:Disconnect()
            StopFly()
            return
        end
        
        local speed = Config.FlySpeed
        local cam = Camera.CFrame
        
        bg.cframe = cam
        bv.velocity = Vector3.new(0, 0, 0)
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            bv.velocity = bv.velocity + cam.LookVector * speed
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            bv.velocity = bv.velocity - cam.LookVector * speed
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            bv.velocity = bv.velocity - cam.RightVector * speed
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            bv.velocity = bv.velocity + cam.RightVector * speed
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            bv.velocity = bv.velocity + Vector3.new(0, speed, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            bv.velocity = bv.velocity - Vector3.new(0, speed, 0)
        end
    end)
end

local function StopFly()
    Flying = false
    for _, obj in pairs(FlyObjects) do
        pcall(function() obj:Destroy() end)
    end
    FlyObjects = {}
end

-- ===================================================================
-- STEALTH FLY (Multi-Method Anti-Cheat Evasion)
-- ===================================================================
-- Method 1: GHOST FLY (Seat Spoof)
--   Creates an invisible VehicleSeat and welds you into it.
--   Server sees "player is seated in vehicle" — most anti-cheats
--   skip seated players because legitimate vehicles exist.
--   Seat CFrame is moved each frame for flight.
--
-- Method 2: MICRO FLY (Capped CFrame Steps)
--   Moves in tiny CFrame increments capped at ~1.5 studs per frame.
--   Velocity is set to MATCH the CFrame delta (not zeroed — zeroing
--   is what gets you caught). State spoofed to Climbing (not Running,
--   which is suspicious while airborne). Gravity manually countered
--   without PlatformStand (which anti-cheats flag directly).
--
-- Method 3: PHANTOM FLY (Velocity Injection)
--   Uses AssemblyLinearVelocity directly — no BodyVelocity instances
--   for anti-cheat to scan/destroy. Counters gravity each frame by
--   adding upward velocity. State set to Physics (looks like external
--   force). Includes anti-rubberband: if position suddenly jumps
--   backward, it detects the server correction and re-applies.
-- ===================================================================
local StealthMethodNames = {"Ghost (Seat)", "Micro (CFrame)", "Phantom (Velocity)"}
local SFSliderUpdateFn = nil -- forward ref: set after slider UI is created

local function CleanupStealthParts()
    for _, obj in pairs(StealthFlyParts) do
        pcall(function() obj:Destroy() end)
    end
    StealthFlyParts = {}
end

local function StartStealthFly()
    local character = GetCharacter(LocalPlayer)
    local rootPart = GetRootPart(character)
    local humanoid = GetHumanoid(character)
    if not rootPart or not humanoid or StealthFlying then return end

    StealthFlying = true
    LastValidPos = rootPart.CFrame
    local method = Config.StealthFlyMethod

    -- ===============================================================
    -- METHOD 1: GHOST FLY (Seat Spoof)
    -- ===============================================================
    if method == 1 then
        -- Create invisible seat
        local seat = Instance.new("VehicleSeat")
        seat.Name = "Sentry_GhostSeat"
        seat.Size = Vector3.new(2, 0.2, 2)
        seat.Transparency = 1
        seat.CanCollide = false
        seat.Anchored = false
        seat.Massless = true
        seat.CFrame = rootPart.CFrame
        seat.Parent = workspace

        -- Weld player to seat
        local weld = Instance.new("Weld")
        weld.Part0 = seat
        weld.Part1 = rootPart
        weld.C0 = CFrame.new(0, 1.5, 0)
        weld.Parent = seat

        -- Force sit
        humanoid.Sit = true

        table.insert(StealthFlyParts, seat)
        table.insert(StealthFlyParts, weld)

        -- Small delay to let sit register
        task.wait(0.1)

        StealthFlyConn = RunService.RenderStepped:Connect(function(dt)
            if not Config.StealthFly or not StealthFlying then
                StealthFlyConn:Disconnect()
                StealthFlyConn = nil
                pcall(function() humanoid.Sit = false end)
                CleanupStealthParts()
                StealthFlying = false
                return
            end

            local char = GetCharacter(LocalPlayer)
            local root = GetRootPart(char)
            if not root or not root.Parent then
                StealthFlyConn:Disconnect()
                StealthFlyConn = nil
                CleanupStealthParts()
                StealthFlying = false
                return
            end

            -- Keep seated (anti-cheat can unseat you)
            pcall(function() humanoid.Sit = true end)

            -- Build movement
            local cam = Camera.CFrame
            local speed = Config.StealthFlySpeed
            local moveDir = Vector3.zero

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDir = moveDir + cam.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDir = moveDir - cam.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDir = moveDir - cam.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDir = moveDir + cam.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDir = moveDir + Vector3.new(0, 0.7, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveDir = moveDir - Vector3.new(0, 0.7, 0)
            end

            if moveDir.Magnitude > 0 then
                moveDir = moveDir.Unit * speed * dt
            end

            -- Move the seat (player follows via weld)
            local newPos = seat.CFrame.Position + moveDir
            local lookDir = cam.LookVector
            local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z)
            if flatLook.Magnitude > 0.01 then
                seat.CFrame = CFrame.lookAt(newPos, newPos + flatLook) * CFrame.new(0, 0, 0)
            else
                seat.CFrame = CFrame.new(newPos)
            end

            -- Kill seat physics
            seat.Velocity = Vector3.zero
            seat.AssemblyLinearVelocity = Vector3.zero
            seat.AssemblyAngularVelocity = Vector3.zero

            -- Noclip while flying
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end)

    -- ===============================================================
    -- METHOD 2: MICRO FLY (Capped CFrame Steps)
    -- ===============================================================
    elseif method == 2 then
        local MAX_STEP = 1.8 -- studs per frame cap (looks like fast walking)

        StealthFlyConn = RunService.RenderStepped:Connect(function(dt)
            if not Config.StealthFly or not StealthFlying then
                StealthFlyConn:Disconnect()
                StealthFlyConn = nil
                StealthFlying = false
                return
            end

            local char = GetCharacter(LocalPlayer)
            local root = GetRootPart(char)
            local hum = GetHumanoid(char)
            if not root or not root.Parent or not hum then
                StealthFlyConn:Disconnect()
                StealthFlyConn = nil
                StealthFlying = false
                return
            end

            -- State spoof: Climbing looks natural for vertical movement
            -- Running while airborne is suspicious; Climbing isn't
            hum:ChangeState(Enum.HumanoidStateType.Climbing)

            -- Cancel gravity without PlatformStand (PlatformStand is flagged)
            -- Instead, counter gravity via velocity each frame
            local gravityCounter = Vector3.new(0, workspace.Gravity * dt, 0)

            -- Build movement
            local cam = Camera.CFrame
            local speed = Config.StealthFlySpeed
            local moveDir = Vector3.zero

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDir = moveDir + cam.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDir = moveDir - cam.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDir = moveDir - cam.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDir = moveDir + cam.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDir = moveDir + Vector3.new(0, 0.8, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveDir = moveDir - Vector3.new(0, 0.8, 0)
            end

            local step = Vector3.zero
            if moveDir.Magnitude > 0 then
                step = moveDir.Unit * math.min(speed * dt, MAX_STEP)
            end

            -- Apply CFrame micro-step
            local oldPos = root.Position
            local newPos = oldPos + step
            local lookDir = cam.LookVector
            local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z)
            if flatLook.Magnitude > 0.01 then
                root.CFrame = CFrame.lookAt(newPos, newPos + flatLook)
            else
                root.CFrame = CFrame.new(newPos) * (root.CFrame - root.CFrame.Position)
            end

            -- Set velocity to MATCH the delta (not zero — zero is suspicious)
            -- Server sees: "position changed, velocity matches" = consistent
            local frameVel = (step / math.max(dt, 0.001)) + gravityCounter
            root.Velocity = frameVel
            root.AssemblyLinearVelocity = frameVel
            root.AssemblyAngularVelocity = Vector3.zero

            -- Noclip
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end

            LastValidPos = root.CFrame
        end)

    -- ===============================================================
    -- METHOD 3: PHANTOM FLY (Aggressive Velocity — Never Idle)
    -- ===============================================================
    -- Key insight from testing: server rubberbands you when you're
    -- stationary in midair. Solution: ALWAYS inject forward velocity.
    -- When no keys pressed, drift forward at minimum speed.
    -- Velocity applied twice per frame (pre and post physics).
    -- Anti-gravity cranked up. Anti-rubberband fights back instantly.
    -- ===============================================================
    elseif method == 3 then
        -- Phantom needs max speed or server rubberbands you
        Config.StealthFlySpeed = 100
        if SFSliderUpdateFn then SFSliderUpdateFn() end

        local RUBBERBAND_THRESHOLD = 15 -- studs — tighter detection
        local MIN_DRIFT_SPEED = 12     -- always moving at least this fast
        local ANTIGRAV_MULT = 5.0      -- aggressive gravity counter
        local lastFramePos = rootPart.Position
        local rbCooldown = 0           -- anti-rubberband spam limiter

        -- Apply velocity — called multiple times per frame
        local function InjectVelocity(root, vel)
            root.Velocity = vel
            root.AssemblyLinearVelocity = vel
            root.AssemblyAngularVelocity = Vector3.zero
        end

        StealthFlyConn = RunService.RenderStepped:Connect(function(dt)
            if not Config.StealthFly or not StealthFlying then
                StealthFlyConn:Disconnect()
                StealthFlyConn = nil
                StealthFlying = false
                return
            end

            local char = GetCharacter(LocalPlayer)
            local root = GetRootPart(char)
            local hum = GetHumanoid(char)
            if not root or not root.Parent or not hum then
                StealthFlyConn:Disconnect()
                StealthFlyConn = nil
                StealthFlying = false
                return
            end

            -- Anti-rubberband: detect server correction and fight it
            local currentPos = root.Position
            local posDelta = (currentPos - lastFramePos).Magnitude
            rbCooldown = math.max(rbCooldown - dt, 0)
            if LastValidPos and posDelta > RUBBERBAND_THRESHOLD and rbCooldown <= 0 then
                -- Server yanked us — snap back to where we were
                pcall(function()
                    root.CFrame = LastValidPos
                end)
                -- Immediately re-inject velocity so we blast through
                local cam = Camera.CFrame
                InjectVelocity(root, cam.LookVector * Config.StealthFlySpeed * 1.5)
                currentPos = LastValidPos.Position
                rbCooldown = 0.15 -- don't spam corrections
            end

            -- State: Physics — tells server an external force is acting
            hum:ChangeState(Enum.HumanoidStateType.Physics)

            -- Build desired velocity from input
            local cam = Camera.CFrame
            local speed = Config.StealthFlySpeed
            local desiredVel = Vector3.zero
            local hasInput = false

            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                desiredVel = desiredVel + cam.LookVector * speed
                hasInput = true
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                desiredVel = desiredVel - cam.LookVector * speed
                hasInput = true
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                desiredVel = desiredVel - cam.RightVector * speed
                hasInput = true
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                desiredVel = desiredVel + cam.RightVector * speed
                hasInput = true
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                desiredVel = desiredVel + Vector3.new(0, speed * 0.8, 0)
                hasInput = true
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                desiredVel = desiredVel - Vector3.new(0, speed * 0.8, 0)
                hasInput = true
            end

            -- NEVER IDLE: if no keys pressed, drift forward along camera
            -- This is the key — server catches you if velocity drops to zero midair
            if not hasInput then
                desiredVel = cam.LookVector * MIN_DRIFT_SPEED
            end

            -- Aggressive anti-gravity — overshoot slightly to stay buoyant
            local antigrav = Vector3.new(0, workspace.Gravity * dt * ANTIGRAV_MULT, 0)
            local finalVel = desiredVel + antigrav

            -- First injection (pre-physics)
            InjectVelocity(root, finalVel)

            -- Face camera direction
            local lookDir = cam.LookVector
            local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z)
            if flatLook.Magnitude > 0.01 then
                root.CFrame = CFrame.lookAt(root.Position, root.Position + flatLook)
            end

            -- Second injection (post-CFrame, fights engine overwrite)
            InjectVelocity(root, finalVel)

            -- Noclip
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end

            lastFramePos = root.Position
            LastValidPos = root.CFrame
        end)
    end
end

local function StopStealthFly()
    if StealthFlyConn then
        StealthFlyConn:Disconnect()
        StealthFlyConn = nil
    end
    CleanupStealthParts()
    StealthFlying = false
    local hum = GetHumanoid(GetCharacter(LocalPlayer))
    if hum then
        pcall(function()
            hum.PlatformStand = false
            hum.AutoRotate = true
            hum.Sit = false
        end)
    end
end

-- ===================================================================
-- SILVER SURFER (Cosmic Board Fly)
-- ===================================================================
-- Creates a chrome surfboard under the player with cyan neon
-- underglow and cosmic particle trail. BodyGyro + BodyVelocity
-- flight. Board tilts with movement — pitches forward on accel,
-- banks into turns, leans back on climb. Default speed 150.
-- ===================================================================
local SurferFlying = false
local SurferConn = nil
local SurferParts = {}
local surferPitch = 0
local surferRoll = 0

local SurferModeNames = {"Slow", "Medium", "Fast"}
local SurferModeSpeeds = {80, 150, 500}

local function CleanupSurferParts()
    for _, obj in pairs(SurferParts) do
        pcall(function() obj:Destroy() end)
    end
    SurferParts = {}
end

local function StartSilverSurfer()
    local character = GetCharacter(LocalPlayer)
    local rootPart = GetRootPart(character)
    local humanoid = GetHumanoid(character)
    if not rootPart or not humanoid or SurferFlying then return end

    SurferFlying = true
    surferPitch = 0
    surferRoll = 0

    -- ============ BUILD THE BOARD ============
    -- ONE single Part + Sphere mesh = clean elongated oval.
    -- No overlapping pieces, no seams, no blobs. Just an ellipsoid
    -- scaled long and thin like the actual Silver Surfer reference.

    -- === THE BOARD (single piece) ===
    local board = Instance.new("Part")
    board.Name = "Sentry_SilverBoard"
    board.Size = Vector3.new(2.4, 0.8, 8.0)
    board.Color = Color3.fromRGB(135, 135, 140)
    board.Material = Enum.Material.Metal
    board.Reflectance = 0.12
    board.Transparency = 0
    board.CanCollide = false
    board.Anchored = false
    board.Massless = true
    board.TopSurface = Enum.SurfaceType.Smooth
    board.BottomSurface = Enum.SurfaceType.Smooth
    board.CFrame = rootPart.CFrame * CFrame.new(0, -3, 0)
    board.Parent = workspace
    table.insert(SurferParts, board)

    local boardMesh = Instance.new("SpecialMesh")
    boardMesh.MeshType = Enum.MeshType.Sphere
    boardMesh.Scale = Vector3.new(1, 0.07, 1)
    boardMesh.Parent = board
    table.insert(SurferParts, boardMesh)

    -- === STRINGER (thin dark centerline) ===
    local stringer = Instance.new("Part")
    stringer.Name = "Sentry_Stringer"
    stringer.Size = Vector3.new(0.05, 0.5, 7.2)
    stringer.Color = Color3.fromRGB(45, 45, 48)
    stringer.Material = Enum.Material.Metal
    stringer.Reflectance = 0.05
    stringer.CanCollide = false
    stringer.Anchored = false
    stringer.Massless = true
    stringer.Parent = workspace
    table.insert(SurferParts, stringer)

    local stringerMesh = Instance.new("SpecialMesh")
    stringerMesh.MeshType = Enum.MeshType.Sphere
    stringerMesh.Scale = Vector3.new(1, 0.04, 1)
    stringerMesh.Parent = stringer
    table.insert(SurferParts, stringerMesh)

    local stringerWeld = Instance.new("Weld")
    stringerWeld.Part0 = board
    stringerWeld.Part1 = stringer
    stringerWeld.C0 = CFrame.new(0, 0.025, 0)
    stringerWeld.Parent = board
    table.insert(SurferParts, stringerWeld)

    -- === FINS (thruster: 1 center + 2 side) ===
    local centerFin = Instance.new("WedgePart")
    centerFin.Name = "Sentry_CenterFin"
    centerFin.Size = Vector3.new(0.06, 0.45, 0.35)
    centerFin.Color = Color3.fromRGB(55, 58, 65)
    centerFin.Material = Enum.Material.SmoothPlastic
    centerFin.Reflectance = 0.15
    centerFin.CanCollide = false
    centerFin.Anchored = false
    centerFin.Massless = true
    centerFin.Parent = workspace
    table.insert(SurferParts, centerFin)

    local cfWeld = Instance.new("Weld")
    cfWeld.Part0 = board
    cfWeld.Part1 = centerFin
    cfWeld.C0 = CFrame.new(0, -0.04, 2.8) * CFrame.Angles(math.rad(180), 0, 0)
    cfWeld.Parent = board
    table.insert(SurferParts, cfWeld)

    for _, sideX in pairs({-0.55, 0.55}) do
        local sideFin = Instance.new("WedgePart")
        sideFin.Name = "Sentry_SideFin"
        sideFin.Size = Vector3.new(0.05, 0.32, 0.26)
        sideFin.Color = Color3.fromRGB(55, 58, 65)
        sideFin.Material = Enum.Material.SmoothPlastic
        sideFin.Reflectance = 0.15
        sideFin.CanCollide = false
        sideFin.Anchored = false
        sideFin.Massless = true
        sideFin.Parent = workspace
        table.insert(SurferParts, sideFin)

        local sfWeld = Instance.new("Weld")
        sfWeld.Part0 = board
        sfWeld.Part1 = sideFin
        local toeAngle = sideX > 0 and math.rad(10) or math.rad(-10)
        sfWeld.C0 = CFrame.new(sideX, -0.04, 2.2) * CFrame.Angles(math.rad(180), toeAngle, 0)
        sfWeld.Parent = board
        table.insert(SurferParts, sfWeld)
    end

    -- ============ WELD BOARD TO PLAYER ============
    local boardWeld = Instance.new("Weld")
    boardWeld.Part0 = rootPart
    boardWeld.Part1 = board
    boardWeld.C0 = CFrame.new(0, -2.95, 0)
    boardWeld.Parent = rootPart
    table.insert(SurferParts, boardWeld)

    -- ============ FLIGHT (CFrame + Spring Physics) ============
    -- Pure CFrame movement — no BodyVelocity, no fall animation.
    -- Spring-damped tilt for organic board feel. Idle hover bob.
    -- Yaw carve on turns so the board actually rotates its heading.

    local pitchVel = 0
    local rollVel = 0
    local yawVel = 0
    local yawOffset = 0
    local hoverPhase = math.random() * math.pi * 2  -- random start phase
    local idleRollPhase = math.random() * math.pi * 2

    local SPRING = 28      -- spring stiffness
    local DAMP = 0.88      -- velocity retention (higher = more overshoot)
    local HOVER_AMP = 0.16 -- idle bob amplitude (studs)
    local HOVER_FREQ = 1.6 -- idle bob frequency (Hz)

    SurferConn = RunService.RenderStepped:Connect(function(dt)
        if not Config.SilverSurfer or not SurferFlying then
            SurferConn:Disconnect()
            SurferConn = nil
            StopSilverSurfer()
            return
        end

        local char = GetCharacter(LocalPlayer)
        local root = GetRootPart(char)
        local hum = GetHumanoid(char)
        if not root or not root.Parent or not hum then
            SurferConn:Disconnect()
            SurferConn = nil
            CleanupSurferParts()
            SurferFlying = false
            return
        end

        -- Force standing pose every frame
        hum:ChangeState(Enum.HumanoidStateType.Running)
        hum.PlatformStand = false

        local cam = Camera.CFrame
        local speed = SurferModeSpeeds[Config.SilverSurferMode] or 150

        -- Input
        local fwd = 0
        local strafe = 0
        local vert = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then fwd = fwd + 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then fwd = fwd - 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then strafe = strafe - 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then strafe = strafe + 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vert = vert + 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vert = vert - 1 end

        -- Movement delta from camera orientation
        local moveDir = Vector3.zero
        if fwd ~= 0 then moveDir = moveDir + cam.LookVector * fwd end
        if strafe ~= 0 then moveDir = moveDir + cam.RightVector * strafe end
        if vert ~= 0 then moveDir = moveDir + Vector3.new(0, vert, 0) end

        local delta = Vector3.zero
        local currentSpeed = 0
        if moveDir.Magnitude > 0 then
            delta = moveDir.Unit * speed * dt
            currentSpeed = speed
        end

        -- === SPRING-DAMPED TILT ===
        -- Target angles: nose dips on accel, rises on brake/climb, banks into turns
        local targetPitch = math.rad(-22 * fwd + 10 * vert)
        local targetRoll = math.rad(-30 * strafe)
        local targetYaw = math.rad(-6 * strafe) -- board heading carves into turn

        -- Spring update (F = -k*x, velocity damped)
        pitchVel = (pitchVel + (targetPitch - surferPitch) * SPRING * dt) * DAMP
        rollVel = (rollVel + (targetRoll - surferRoll) * SPRING * dt) * DAMP
        yawVel = (yawVel + (targetYaw - yawOffset) * SPRING * 0.6 * dt) * DAMP

        surferPitch = surferPitch + pitchVel * dt
        surferRoll = surferRoll + rollVel * dt
        yawOffset = yawOffset + yawVel * dt

        -- === IDLE HOVER BOB ===
        hoverPhase = hoverPhase + dt * HOVER_FREQ * math.pi * 2
        idleRollPhase = idleRollPhase + dt * 0.7 * math.pi * 2
        local hoverY = math.sin(hoverPhase) * HOVER_AMP
        local idleRoll = math.sin(idleRollPhase) * math.rad(1.5) -- tiny natural sway

        -- === BUILD FINAL CFRAME ===
        local newPos = root.Position + delta + Vector3.new(0, hoverY * dt * 8, 0)
        local lookDir = cam.LookVector
        local flatLook = Vector3.new(lookDir.X, 0, lookDir.Z)

        if flatLook.Magnitude > 0.01 then
            flatLook = flatLook.Unit
            -- Apply yaw carve offset to heading
            local baseCF = CFrame.lookAt(newPos, newPos + flatLook)
            root.CFrame = baseCF
                * CFrame.Angles(0, yawOffset, 0)
                * CFrame.Angles(surferPitch, 0, surferRoll + idleRoll)
        else
            root.CFrame = CFrame.new(newPos)
                * CFrame.Angles(surferPitch, yawOffset, surferRoll + idleRoll)
        end

        -- Kill all physics
        root.Velocity = Vector3.zero
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        -- Noclip
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

local function StopSilverSurfer()
    if SurferConn then
        SurferConn:Disconnect()
        SurferConn = nil
    end
    CleanupSurferParts()
    SurferFlying = false
    surferPitch = 0
    surferRoll = 0
    -- Reset humanoid state so character doesn't stay locked
    local hum = GetHumanoid(GetCharacter(LocalPlayer))
    if hum then
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            hum.PlatformStand = false
            hum.AutoRotate = true
        end)
    end
end

-- ===================================================================
-- NOCLIP
-- ===================================================================
local NoclipConnection = nil
local function ToggleNoclip()
    if NoclipConnection then
        NoclipConnection:Disconnect()
        NoclipConnection = nil
    end
    
    if Config.Noclip then
        NoclipConnection = RunService.Stepped:Connect(function()
            local character = GetCharacter(LocalPlayer)
            if character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end

-- ===================================================================
-- SPINBOT
-- ===================================================================
local function StartSpinbot()
    if SpinbotConnection then return end
    SpinbotConnection = RunService.Heartbeat:Connect(function(dt)
        if not Config.Spinbot then return end
        local character = GetCharacter(LocalPlayer)
        local rootPart = GetRootPart(character)
        if not rootPart then return end
        SpinAngle = SpinAngle + (Config.SpinSpeed * dt * 10)
        rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, math.rad(SpinAngle), 0)
    end)
end

local function StopSpinbot()
    if SpinbotConnection then
        SpinbotConnection:Disconnect()
        SpinbotConnection = nil
    end
    SpinAngle = 0
end

-- ===================================================================
-- CLICK TO TELEPORT (Ctrl + Click to TP where your mouse points)
-- ===================================================================
local function StartClickTP()
    if ClickTPConnection then return end
    ClickTPConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if not Config.ClickTP then return end

        -- Mouse left click
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Only teleport when holding Ctrl
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
                local myChar = GetCharacter(LocalPlayer)
                local myRoot = GetRootPart(myChar)
                if not myRoot then return end

                local mouse = LocalPlayer:GetMouse()
                local target = mouse.Hit
                if target then
                    -- Teleport to click position, offset up a bit so we don't clip into the ground
                    myRoot.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
                end
            end
        end
    end)
end

local function StopClickTP()
    if ClickTPConnection then
        ClickTPConnection:Disconnect()
        ClickTPConnection = nil
    end
end

local function StartSlingshot()
    if SlingshotConnection then return end
    SlingshotConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if not Config.Slingshot then return end
        if slingshotCooldown then return end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
                local char = GetCharacter(LocalPlayer)
                local root = GetRootPart(char)
                if not root then return end

                local mouse = LocalPlayer:GetMouse()
                local target = mouse.Hit
                if not target then return end

                slingshotCooldown = true

                -- Direction from player to click point
                local toTarget = (target.Position - root.Position)
                local dir = toTarget.Unit
                local launchForce = 320

                -- Noclip briefly
                local noclipParts = {}
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                        table.insert(noclipParts, part)
                    end
                end

                -- Velocity burst toward click point + upward arc
                root.AssemblyLinearVelocity = dir * launchForce + Vector3.new(0, 80, 0)

                -- Re-enable collisions
                task.delay(0.8, function()
                    for _, part in pairs(noclipParts) do
                        if part and part.Parent then
                            part.CanCollide = true
                        end
                    end
                end)

                -- Cooldown reset
                task.delay(1.2, function()
                    slingshotCooldown = false
                end)
            end
        end
    end)
end

local function StopSlingshot()
    if SlingshotConnection then
        SlingshotConnection:Disconnect()
        SlingshotConnection = nil
    end
    slingshotCooldown = false
end

-- ===================================================================
-- TRIGGERBOT (Auto-fire when crosshair is over enemy)
-- ===================================================================
local triggerRayParams = RaycastParams.new()
triggerRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function TriggerClick()
    local ok = pcall(function() mouse1click() end)
    if not ok then
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.defer(function()
                vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
        end)
    end
end

local function DoTriggerbot()
    if not Config.Triggerbot then return end
    local now = tick()
    if now - lastTriggerTime < Config.TriggerbotDelay / 100 then return end
    Camera = workspace.CurrentCamera
    local myChar = GetCharacter(LocalPlayer)
    if not myChar then return end
    triggerRayParams.FilterDescendantsInstances = {myChar}
    local origin = Camera.CFrame.Position
    local direction = Camera.CFrame.LookVector * 1000
    local result = workspace:Raycast(origin, direction, triggerRayParams)
    if not result or not result.Instance then return end
    local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
    if not hitModel then return end
    local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
    if not hitPlayer or hitPlayer == LocalPlayer then return end
    if Config.TeamCheck and hitPlayer.Team and hitPlayer.Team == LocalPlayer.Team then return end
    local hitHumanoid = hitModel:FindFirstChildOfClass("Humanoid")
    if not hitHumanoid or hitHumanoid.Health <= 0 then return end
    lastTriggerTime = now
    TriggerClick()
end

-- ===================================================================
-- FONT DEFINITIONS (Amatic SC)
-- ===================================================================
local AmaticFont = Font.new("rbxasset://fonts/families/AmaticSC.json", Enum.FontWeight.Regular)
local AmaticBold = Font.new("rbxasset://fonts/families/AmaticSC.json", Enum.FontWeight.Bold)

-- ===================================================================
-- GUI MENU (PITCH BLACK ROUNDED THEME WITH MINIMIZE)
-- ===================================================================
local Authenticated = true

local ScreenGui = Instance.new("ScreenGui")
local MainFrame = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local Container = Instance.new("ScrollingFrame")
local Credits = Instance.new("TextLabel")

ScreenGui.Name = "SentryMenu"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

-- Main menu starts HIDDEN until password is entered
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.1, 0, 0.1, 0)
MainFrame.Size = UDim2.new(0, 540, 0, 700)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Visible = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 16)

-- Loading overlay (bobbing arrow spinner, covers menu)
;(function()
    local TweenService = game:GetService("TweenService")
    local Veil = Instance.new("Frame"); Veil.Name = "LoadVeil"; Veil.Parent = MainFrame
    Veil.BackgroundColor3 = Color3.fromRGB(12,12,14); Veil.BackgroundTransparency = 0.02
    Veil.BorderSizePixel = 0; Veil.Size = UDim2.new(1,0,1,0); Veil.ZIndex = 90
    Instance.new("UICorner", Veil).CornerRadius = UDim.new(0, 16)
    local SB = Instance.new("Frame"); SB.Parent = Veil; SB.BackgroundTransparency = 1
    SB.AnchorPoint = Vector2.new(0.5,0.5); SB.Position = UDim2.new(0.5,0,0.48,0)
    SB.Size = UDim2.new(0,44,0,44); SB.ZIndex = 91
    local R, DOTS, DS = 15, 18, 2.6
    local CLR = Color3.fromRGB(195,195,200)
    for i = 0, DOTS-1 do
        local t = i/(DOTS-1); local deg = -300*t; local rad = math.rad(deg)
        local dot = Instance.new("Frame"); dot.Parent = SB
        dot.BackgroundColor3 = CLR; dot.BackgroundTransparency = t*0.88; dot.BorderSizePixel = 0
        dot.AnchorPoint = Vector2.new(0.5,0.5)
        dot.Position = UDim2.new(0.5, math.sin(rad)*R, 0.5, -math.cos(rad)*R)
        dot.Size = UDim2.new(0,DS,0,DS); dot.ZIndex = 92
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    end
    for _, side in ipairs({-38, 38}) do
        local bar = Instance.new("Frame"); bar.Parent = SB; bar.BackgroundColor3 = CLR
        bar.BackgroundTransparency = 0; bar.BorderSizePixel = 0
        bar.AnchorPoint = Vector2.new(0.5,0); bar.Position = UDim2.new(0.5,0,0.5,-R)
        bar.Size = UDim2.new(0,2,0,5.5); bar.Rotation = side; bar.ZIndex = 93
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    end
    local ang, bt, base = 0, 0, 0.48
    local sc = RunService.RenderStepped:Connect(function(dt)
        ang = ang + dt*240; bt = bt + dt
        SB.Rotation = ang; SB.Position = UDim2.new(0.5,0,base,math.sin(bt*2.2)*8)
    end)
    task.spawn(function()
        task.wait(2.4)
        TweenService:Create(Veil, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency=1}):Play()
        for _, ch in pairs(SB:GetChildren()) do
            if ch:IsA("Frame") then TweenService:Create(ch, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {BackgroundTransparency=1}):Play() end
        end
        task.wait(0.55); sc:Disconnect(); Veil:Destroy()
    end)
end)()


-- ===================================================================
-- KO FEED (Simple kill tracker — anchored to right side of menu)
-- ===================================================================
-- Detection: monitors all enemy humanoid health via HealthChanged.
-- When health hits 0, that player's name gets added to the feed.
-- No creator tags, no proximity — same system ESP health uses.
-- ===================================================================
local KOList = {}
local KOConnections = {}
local KO_FADE_TIME = 8
local KO_MAX = 10

-- KO container — positioned just right of MainFrame
local KOFrame = Instance.new("Frame")
KOFrame.Name = "KOFeed"
KOFrame.Parent = ScreenGui
KOFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
KOFrame.BackgroundTransparency = 0.15
KOFrame.BorderSizePixel = 0
KOFrame.Position = UDim2.new(0.1, 550, 0.1, 0) -- right next to menu (menu is at 0.1,0 width 420)
KOFrame.Size = UDim2.new(0, 180, 0, 34) -- grows with entries
KOFrame.ClipsDescendants = true
KOFrame.Visible = false
KOFrame.ZIndex = 40
Instance.new("UICorner", KOFrame).CornerRadius = UDim.new(0, 10)

-- Small "KO" label at top
local KOTitle = Instance.new("TextLabel")
KOTitle.Parent = KOFrame
KOTitle.BackgroundTransparency = 1
KOTitle.Position = UDim2.new(0, 8, 0, 2)
KOTitle.Size = UDim2.new(1, -16, 0, 26)
KOTitle.FontFace = AmaticBold
KOTitle.Text = "KO"
KOTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
KOTitle.TextSize = 26
KOTitle.TextXAlignment = Enum.TextXAlignment.Left
KOTitle.ZIndex = 41

local TotalKOs = 0

local function RefreshKOFeed()
    for _, child in pairs(KOFrame:GetChildren()) do
        if child:IsA("TextLabel") and child.Name == "KOEntry" then
            child:Destroy()
        end
    end

    local now = tick()
    local fresh = {}
    for _, entry in ipairs(KOList) do
        if now - entry.time < KO_FADE_TIME then
            table.insert(fresh, entry)
        end
    end
    KOList = fresh

    if not Config.KOFeed or #KOList == 0 then
        KOFrame.Visible = false
        return
    end

    KOFrame.Visible = true

    local entryH = 22
    local startY = 30
    local shown = math.min(#KOList, KO_MAX)

    for i = 1, shown do
        local entry = KOList[#KOList - shown + i]
        if not entry then continue end

        local age = now - entry.time
        local alpha = math.clamp(1 - (age / KO_FADE_TIME), 0.15, 1)

        local label = Instance.new("TextLabel")
        label.Name = "KOEntry"
        label.Parent = KOFrame
        label.BackgroundTransparency = 1
        label.Position = UDim2.new(0, 8, 0, startY + (i - 1) * entryH)
        label.Size = UDim2.new(1, -16, 0, entryH)
        label.FontFace = AmaticFont
        label.Text = entry.name
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextTransparency = 1 - alpha
        label.TextSize = 22
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.ZIndex = 41
    end

    KOFrame.Size = UDim2.new(0, 180, 0, startY + shown * entryH + 4)
end

local function RegisterKO(playerName)
    TotalKOs = TotalKOs + 1
    table.insert(KOList, {name = playerName, time = tick()})
    KOTitle.Text = "KO  " .. tostring(TotalKOs)
    RefreshKOFeed()
end

-- Auto-fade: clean expired entries
task.spawn(function()
    while true do
        task.wait(1)
        if Config.KOFeed and #KOList > 0 then
            RefreshKOFeed()
        end
    end
end)

-- Kill detection via HealthChanged — same way ESP tracks health
-- When any enemy humanoid health drops to 0, register KO
local function HookPlayerDeath(player)
    if player == LocalPlayer then return end
    if KOConnections[player] then return end

    local connections = {}

    local function OnCharacterAdded(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid then return end

        local wasAlive = humanoid.Health > 0

        local hpConn = humanoid.HealthChanged:Connect(function(newHealth)
            if not Config.KOFeed then return end
            if wasAlive and newHealth <= 0 then
                RegisterKO(player.DisplayName)
            end
            wasAlive = newHealth > 0
        end)

        table.insert(connections, hpConn)
    end

    local char = GetCharacter(player)
    if char then
        task.spawn(function() OnCharacterAdded(char) end)
    end

    local charConn = player.CharacterAdded:Connect(function(newChar)
        task.spawn(function() OnCharacterAdded(newChar) end)
    end)

    table.insert(connections, charConn)
    KOConnections[player] = connections
end

local function UnhookPlayerDeath(player)
    if KOConnections[player] then
        for _, conn in pairs(KOConnections[player]) do
            pcall(function() conn:Disconnect() end)
        end
        KOConnections[player] = nil
    end
end

-- ===================================================================
-- FPS & PING HUD (Always-visible overlay — top-right corner)
-- ===================================================================
-- FPS: Counts frames per second using RenderStepped delta time.
-- Ping: Uses GetNetworkPing() (returns seconds, ×1000 for ms).
-- Styled to match Sentry: pitch black, Amatic SC, cyan text.
-- ===================================================================

local FPSPingFrame = Instance.new("Frame")
FPSPingFrame.Name = "Sentry_HUD"
FPSPingFrame.Parent = ScreenGui
FPSPingFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
FPSPingFrame.BackgroundTransparency = 0.15
FPSPingFrame.BorderSizePixel = 0
FPSPingFrame.Position = UDim2.new(1, -135, 0, 6)
FPSPingFrame.Size = UDim2.new(0, 130, 0, 50)
FPSPingFrame.ZIndex = 50
FPSPingFrame.Visible = false
Instance.new("UICorner", FPSPingFrame).CornerRadius = UDim.new(0, 10)

local FPSLabel = Instance.new("TextLabel")
FPSLabel.Name = "FPS"
FPSLabel.Parent = FPSPingFrame
FPSLabel.BackgroundTransparency = 1
FPSLabel.Position = UDim2.new(0, 10, 0, 2)
FPSLabel.Size = UDim2.new(1, -14, 0, 22)
FPSLabel.FontFace = AmaticBold
FPSLabel.Text = "FPS: --"
FPSLabel.TextColor3 = Color3.fromRGB(235, 230, 220)
FPSLabel.TextSize = 26
FPSLabel.TextXAlignment = Enum.TextXAlignment.Left
FPSLabel.ZIndex = 51

local PingLabel = Instance.new("TextLabel")
PingLabel.Name = "Ping"
PingLabel.Parent = FPSPingFrame
PingLabel.BackgroundTransparency = 1
PingLabel.Position = UDim2.new(0, 10, 0, 24)
PingLabel.Size = UDim2.new(1, -14, 0, 22)
PingLabel.FontFace = AmaticBold
PingLabel.Text = "Ping: --"
PingLabel.TextColor3 = Color3.fromRGB(235, 230, 220)
PingLabel.TextSize = 26
PingLabel.TextXAlignment = Enum.TextXAlignment.Left
PingLabel.ZIndex = 51

-- FPS tracking variables
local fpsFrameCount = 0
local fpsLastTime = tick()
local fpsDisplay = 0

-- Update FPS counter every 0.5s for smooth display
RunService.RenderStepped:Connect(function()
    fpsFrameCount = fpsFrameCount + 1
    local now = tick()
    local elapsed = now - fpsLastTime
    if elapsed >= 0.5 then
        fpsDisplay = math.floor(fpsFrameCount / elapsed)
        fpsFrameCount = 0
        fpsLastTime = now

        -- Update FPS label
        if Config.FPSCounter then
            FPSLabel.Visible = true
            FPSLabel.Text = "FPS: " .. tostring(fpsDisplay)
        else
            FPSLabel.Visible = false
        end

        -- Update Ping label
        if Config.PingCounter then
            PingLabel.Visible = true
            local pingOk, pingVal = pcall(function()
                return math.floor(LocalPlayer:GetNetworkPing() * 1000)
            end)
            if not pingOk then
                -- Fallback: try Stats service
                pingOk, pingVal = pcall(function()
                    return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
                end)
            end
            if pingOk and pingVal then
                PingLabel.Text = "Ping: " .. tostring(pingVal) .. "ms"
            else
                PingLabel.Text = "Ping: N/A"
            end
        else
            PingLabel.Visible = false
        end

        -- Hide entire frame if both counters are off
        FPSPingFrame.Visible = Config.FPSCounter or Config.PingCounter

        -- Resize frame if only one counter is showing
        if Config.FPSCounter and Config.PingCounter then
            FPSPingFrame.Size = UDim2.new(0, 130, 0, 50)
            PingLabel.Position = UDim2.new(0, 10, 0, 24)
        elseif Config.FPSCounter then
            FPSPingFrame.Size = UDim2.new(0, 130, 0, 28)
        elseif Config.PingCounter then
            FPSPingFrame.Size = UDim2.new(0, 130, 0, 28)
            PingLabel.Position = UDim2.new(0, 10, 0, 2)
        end
    end
end)

-- ===================================================================
-- MENU ELEMENTS (Amatic SC font applied)
-- ===================================================================
Title.Parent = MainFrame
Title.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Title.BorderSizePixel = 0
Title.Size = UDim2.new(1, 0, 0, 46)
Title.FontFace = AmaticBold
Title.Text = "SENTRY"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 44
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 16)


Credits.Parent = MainFrame
Credits.BackgroundTransparency = 1
Credits.Position = UDim2.new(0, 0, 0, 46)
Credits.Size = UDim2.new(1, 0, 0, 22)
Credits.FontFace = AmaticFont
Credits.Text = "Coded by: Mrgrumeti"
Credits.TextColor3 = Color3.fromRGB(210, 210, 215)
Credits.TextSize = 26

-- Minimize Button
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Parent = MainFrame
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MinimizeBtn.BorderSizePixel = 0
MinimizeBtn.Position = UDim2.new(1, -38, 0, 6)
MinimizeBtn.Size = UDim2.new(0, 28, 0, 28)
MinimizeBtn.FontFace = AmaticBold
MinimizeBtn.Text = "−"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.TextSize = 22
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 8)

local isMinimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        MainFrame:TweenSize(UDim2.new(0, 540, 0, 50), "Out", "Quad", 0.3, true)
        MinimizeBtn.Text = "+"
        Container.Visible = false
        Credits.Visible = false
    else
        MainFrame:TweenSize(UDim2.new(0, 540, 0, 700), "Out", "Quad", 0.3, true)
        MinimizeBtn.Text = "−"
        Container.Visible = true
        Credits.Visible = true
    end
end)

Container.Parent = MainFrame
Container.BackgroundTransparency = 1
Container.Position = UDim2.new(0, 0, 0, 72)
Container.Size = UDim2.new(1, 0, 1, -72)
Container.CanvasSize = UDim2.new(0, 0, 0, 0) -- auto-calculated
Container.ScrollBarThickness = 6
Container.AutomaticCanvasSize = Enum.AutomaticSize.Y

-- UIListLayout replaces manual yOffset — handles positioning + auto-hides gaps
local ContainerLayout = Instance.new("UIListLayout")
ContainerLayout.Parent = Container
ContainerLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContainerLayout.Padding = UDim.new(0, 5)

local ContainerPadding = Instance.new("UIPadding")
ContainerPadding.Parent = Container
ContainerPadding.PaddingTop = UDim.new(0, 5)
ContainerPadding.PaddingBottom = UDim.new(0, 10)

-- ===================================================================
-- SEARCH BAR + ELEMENT REGISTRY
-- ===================================================================
local SearchElements = {} -- {name=string, frame=Frame, section=string}
local CurrentSection = ""
local LayoutCounter = 0

local function WrapInFrame(searchName, height)
    LayoutCounter = LayoutCounter + 1
    local wrapper = Instance.new("Frame")
    wrapper.Name = "Wrap_" .. searchName
    wrapper.Parent = Container
    wrapper.BackgroundTransparency = 1
    wrapper.BorderSizePixel = 0
    wrapper.Size = UDim2.new(1, 0, 0, height)
    wrapper.LayoutOrder = LayoutCounter
    wrapper.ClipsDescendants = false
    table.insert(SearchElements, {
        name = string.lower(searchName),
        frame = wrapper,
        section = string.lower(CurrentSection),
        isSection = false,
    })
    return wrapper
end

-- Search Box
local SearchWrapper = Instance.new("Frame")
SearchWrapper.Name = "SearchBarWrap"
SearchWrapper.Parent = Container
SearchWrapper.BackgroundTransparency = 1
SearchWrapper.BorderSizePixel = 0
SearchWrapper.Size = UDim2.new(1, 0, 0, 35)
SearchWrapper.LayoutOrder = 0

local SearchBox = Instance.new("TextBox")
SearchBox.Parent = SearchWrapper
SearchBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
SearchBox.BorderSizePixel = 0
SearchBox.Position = UDim2.new(0, 10, 0, 0)
SearchBox.Size = UDim2.new(1, -20, 0, 30)
SearchBox.FontFace = AmaticFont
SearchBox.PlaceholderText = "Search features..."
SearchBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
SearchBox.Text = ""
SearchBox.TextColor3 = Color3.fromRGB(235, 230, 220)
SearchBox.TextSize = 24
SearchBox.ClearTextOnFocus = false
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 8)



local function FilterFeatures(query)
    query = string.lower(query)
    local sectionVisible = {} -- track which sections have visible children

    -- First pass: check which features match
    for _, entry in ipairs(SearchElements) do
        if entry.isSection then
            -- sections handled in second pass
        else
            local match = query == "" or string.find(entry.name, query, 1, true) or string.find(entry.section, query, 1, true)
            entry.frame.Visible = match
            if match and entry.section ~= "" then
                sectionVisible[entry.section] = true
            end
        end
    end

    -- Second pass: show/hide section headers
    for _, entry in ipairs(SearchElements) do
        if entry.isSection then
            if query == "" then
                entry.frame.Visible = true
            else
                -- Show section if its name matches OR if any child in that section matches
                local nameMatch = string.find(entry.name, query, 1, true)
                entry.frame.Visible = nameMatch or (sectionVisible[entry.name] == true)
            end
        end
    end
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    FilterFeatures(SearchBox.Text)
end)

-- Focus/unfocus styling
SearchBox.Focused:Connect(function()
    SearchBox.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
    local s = SearchBox:FindFirstChildOfClass("UIStroke"); if s then s.Color = Color3.fromRGB(0, 150, 190) end
end)
SearchBox.FocusLost:Connect(function()
    SearchBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    local s = SearchBox:FindFirstChildOfClass("UIStroke"); if s then s.Color = Color3.fromRGB(45, 45, 55) end
end)

local function CreateToggle(name, configKey)
    local wrapper = WrapInFrame(name, 30)
    local Toggle = Instance.new("TextButton")
    Toggle.Parent = wrapper
    Toggle.BackgroundColor3 = Config[configKey] and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
    Toggle.BorderSizePixel = 0
    Toggle.Position = UDim2.new(0, 10, 0, 0)
    Toggle.Size = UDim2.new(1, -20, 0, 30)
    Toggle.FontFace = AmaticFont
    Toggle.Text = name .. ": " .. tostring(Config[configKey])
    Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    Toggle.TextSize = 24
    Instance.new("UICorner", Toggle).CornerRadius = UDim.new(0, 8)
    Toggle.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        Toggle.Text = name .. ": " .. tostring(Config[configKey])
        Toggle.BackgroundColor3 = Config[configKey] and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
        if configKey == "Fly" then
            if Config.Fly then
                if Config.StealthFly then Config.StealthFly = false; StopStealthFly() end
                if Config.SilverSurfer then Config.SilverSurfer = false; StopSilverSurfer() end
                StartFly()
            else StopFly() end
        elseif configKey == "Noclip" then ToggleNoclip()
        end
    end)
    return Toggle
end

local function CreateSlider(name, configKey, min, max)
    local wrapper = WrapInFrame(name, 38)
    local Label = Instance.new("TextLabel")
    Label.Parent = wrapper
    Label.BackgroundTransparency = 1
    Label.Position = UDim2.new(0, 10, 0, 0)
    Label.Size = UDim2.new(1, -20, 0, 20)
    Label.FontFace = AmaticFont
    Label.Text = name .. ": " .. Config[configKey]
    Label.TextColor3 = Color3.fromRGB(255, 255, 255)
    Label.TextSize = 24
    Label.TextXAlignment = Enum.TextXAlignment.Left
    local Slider = Instance.new("Frame")
    Slider.Parent = wrapper
    Slider.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Slider.BorderSizePixel = 0
    Slider.Position = UDim2.new(0, 10, 0, 24)
    Slider.Size = UDim2.new(1, -20, 0, 10)
    Instance.new("UICorner", Slider).CornerRadius = UDim.new(0, 5)
    local Fill = Instance.new("Frame")
    Fill.Parent = Slider
    Fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Fill.BorderSizePixel = 0
    Fill.Size = UDim2.new((Config[configKey] - min) / (max - min), 0, 1, 0)
    Instance.new("UICorner", Fill).CornerRadius = UDim.new(0, 5)
    local dragging = false
    local function update(input)
        local pos = math.clamp((input.Position.X - Slider.AbsolutePosition.X) / Slider.AbsoluteSize.X, 0, 1)
        Fill.Size = UDim2.new(pos, 0, 1, 0)
        Config[configKey] = math.floor(min + (max - min) * pos)
        Label.Text = name .. ": " .. Config[configKey]
    end
    Slider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; update(input) end
    end)
    Slider.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then update(input) end
    end)
end

local function CreateSection(name)
    CurrentSection = name
    LayoutCounter = LayoutCounter + 1
    local wrapper = Instance.new("Frame")
    wrapper.Name = "Section_" .. name
    wrapper.Parent = Container
    wrapper.BackgroundTransparency = 1
    wrapper.BorderSizePixel = 0
    wrapper.Size = UDim2.new(1, 0, 0, 28)
    wrapper.LayoutOrder = LayoutCounter
    local Section = Instance.new("TextLabel")
    Section.Parent = wrapper
    Section.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Section.BorderSizePixel = 0
    Section.Position = UDim2.new(0, 10, 0, 0)
    Section.Size = UDim2.new(1, -20, 0, 25)
    Section.FontFace = AmaticBold
    Section.Text = name
    Section.TextColor3 = Color3.fromRGB(255, 255, 255)
    Section.TextSize = 29
    Instance.new("UICorner", Section).CornerRadius = UDim.new(0, 6)
    table.insert(SearchElements, {name = string.lower(name), frame = wrapper, section = "", isSection = true})
end

-- Create Menu Sections
CreateSection("Microwave Hub's Aimbot")
CreateToggle("Microwave Hub's Aimbot", "Aimbot")
CreateToggle("Show FOV Circle", "AimbotShowFOV")
CreateSlider("Aimbot FOV", "AimbotFOV", 50, 400)
CreateSlider("Aim Smoothing", "AimbotSmoothing", 5, 100)

CreateSection("Sentry Aimbot (OG)")
CreateToggle("Sentry Aimbot", "OGAimbot")
CreateToggle("Show FOV Circle", "OGAimbotShowFOV")
CreateSlider("Aimbot FOV", "OGAimbotFOV", 50, 600)
CreateSlider("Aim Smoothing", "OGAimbotSmoothing", 10, 90)
CreateToggle("Dynamic Smoothing", "OGAimbotDynamicSmooth")
CreateSlider("Prediction", "OGAimbotPrediction", 0, 10)

-- Sentry Bone Cycle Button
local BoneOptions = {"Head", "UpperTorso", "HumanoidRootPart"}
local BoneIndex = 1
local BoneBtnWrap = WrapInFrame("Target Bone OG", 30)
local BoneBtn = Instance.new("TextButton")
BoneBtn.Parent = BoneBtnWrap
BoneBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
BoneBtn.BorderSizePixel = 0
BoneBtn.Position = UDim2.new(0, 10, 0, 0)
BoneBtn.Size = UDim2.new(1, -20, 0, 30)
BoneBtn.FontFace = AmaticFont
BoneBtn.Text = "Target Bone: " .. Config.OGAimbotBone
BoneBtn.TextColor3 = Color3.fromRGB(0, 220, 255)
BoneBtn.TextSize = 24
Instance.new("UICorner", BoneBtn).CornerRadius = UDim.new(0, 8)
BoneBtn.MouseButton1Click:Connect(function()
    BoneIndex = BoneIndex % #BoneOptions + 1
    Config.OGAimbotBone = BoneOptions[BoneIndex]
    BoneBtn.Text = "Target Bone: " .. Config.OGAimbotBone
end)

-- =================================================================
-- NEON HUB AIMBOT UI SECTION (purple/magenta accent)
-- =================================================================
CreateSection("Neon Hub's Aimbot")

-- Neon Aimbot Toggle
local NeonAimWrap = WrapInFrame("Neon Hub Aimbot", 30)
local NeonAimToggle = Instance.new("TextButton")
NeonAimToggle.Parent = NeonAimWrap
NeonAimToggle.BackgroundColor3 = Config.NeonAimbot and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
NeonAimToggle.BorderSizePixel = 0
NeonAimToggle.Position = UDim2.new(0, 10, 0, 0)
NeonAimToggle.Size = UDim2.new(1, -20, 0, 30)
NeonAimToggle.FontFace = AmaticFont
NeonAimToggle.Text = "Neon Hub Aimbot: " .. tostring(Config.NeonAimbot)
NeonAimToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
NeonAimToggle.TextSize = 24
Instance.new("UICorner", NeonAimToggle).CornerRadius = UDim.new(0, 8)
NeonAimToggle.MouseButton1Click:Connect(function()
    Config.NeonAimbot = not Config.NeonAimbot
    NeonAimToggle.Text = "Neon Hub Aimbot: " .. tostring(Config.NeonAimbot)
    NeonAimToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    NeonAimToggle.BackgroundColor3 = Config.NeonAimbot and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
end)

-- Neon Show FOV Toggle
local NeonFOVWrap = WrapInFrame("Neon Show FOV", 30)
local NeonFOVToggle = Instance.new("TextButton")
NeonFOVToggle.Parent = NeonFOVWrap
NeonFOVToggle.BackgroundColor3 = Config.NeonAimbotShowFOV and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
NeonFOVToggle.BorderSizePixel = 0
NeonFOVToggle.Position = UDim2.new(0, 10, 0, 0)
NeonFOVToggle.Size = UDim2.new(1, -20, 0, 30)
NeonFOVToggle.FontFace = AmaticFont
NeonFOVToggle.Text = "Show FOV Circle: " .. tostring(Config.NeonAimbotShowFOV)
NeonFOVToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
NeonFOVToggle.TextSize = 24
Instance.new("UICorner", NeonFOVToggle).CornerRadius = UDim.new(0, 8)
NeonFOVToggle.MouseButton1Click:Connect(function()
    Config.NeonAimbotShowFOV = not Config.NeonAimbotShowFOV
    NeonFOVToggle.Text = "Show FOV Circle: " .. tostring(Config.NeonAimbotShowFOV)
    NeonFOVToggle.BackgroundColor3 = Config.NeonAimbotShowFOV and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
end)

-- Neon FOV Slider
CreateSlider("Neon FOV", "NeonAimbotFOV", 30, 400)

-- Neon Smoothness Slider (0 = instant snap, 50 = very smooth)
CreateSlider("Neon Smoothness", "NeonAimbotSmoothing", 0, 50)

-- Neon Wall Check Toggle
local NeonWallWrap = WrapInFrame("Neon Wall Check", 30)
local NeonWallToggle = Instance.new("TextButton")
NeonWallToggle.Parent = NeonWallWrap
NeonWallToggle.BackgroundColor3 = Config.NeonAimbotWallCheck and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
NeonWallToggle.BorderSizePixel = 0
NeonWallToggle.Position = UDim2.new(0, 10, 0, 0)
NeonWallToggle.Size = UDim2.new(1, -20, 0, 30)
NeonWallToggle.FontFace = AmaticFont
NeonWallToggle.Text = "Neon Wall Check: " .. tostring(Config.NeonAimbotWallCheck)
NeonWallToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
NeonWallToggle.TextSize = 24
Instance.new("UICorner", NeonWallToggle).CornerRadius = UDim.new(0, 8)
NeonWallToggle.MouseButton1Click:Connect(function()
    Config.NeonAimbotWallCheck = not Config.NeonAimbotWallCheck
    NeonWallToggle.Text = "Neon Wall Check: " .. tostring(Config.NeonAimbotWallCheck)
    NeonWallToggle.BackgroundColor3 = Config.NeonAimbotWallCheck and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
end)

-- Neon Per-Team Filter Toggle
local NeonTeamWrap = WrapInFrame("Neon Team Filter", 30)
local NeonTeamToggle = Instance.new("TextButton")
NeonTeamToggle.Parent = NeonTeamWrap
NeonTeamToggle.BackgroundColor3 = Config.NeonAimbotTeamFilter and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
NeonTeamToggle.BorderSizePixel = 0
NeonTeamToggle.Position = UDim2.new(0, 10, 0, 0)
NeonTeamToggle.Size = UDim2.new(1, -20, 0, 30)
NeonTeamToggle.FontFace = AmaticFont
NeonTeamToggle.Text = "Neon Team Filter: " .. tostring(Config.NeonAimbotTeamFilter)
NeonTeamToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
NeonTeamToggle.TextSize = 24
Instance.new("UICorner", NeonTeamToggle).CornerRadius = UDim.new(0, 8)
NeonTeamToggle.MouseButton1Click:Connect(function()
    Config.NeonAimbotTeamFilter = not Config.NeonAimbotTeamFilter
    NeonTeamToggle.Text = "Neon Team Filter: " .. tostring(Config.NeonAimbotTeamFilter)
    NeonTeamToggle.BackgroundColor3 = Config.NeonAimbotTeamFilter and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
end)

-- Neon Bone Cycle Button (purple accent text)
local NeonBoneOptions = {"Head", "UpperTorso", "HumanoidRootPart"}
local NeonBoneIndex = 1
local NeonBoneWrap = WrapInFrame("Neon Target Bone", 30)
local NeonBoneBtn = Instance.new("TextButton")
NeonBoneBtn.Parent = NeonBoneWrap
NeonBoneBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
NeonBoneBtn.BorderSizePixel = 0
NeonBoneBtn.Position = UDim2.new(0, 10, 0, 0)
NeonBoneBtn.Size = UDim2.new(1, -20, 0, 30)
NeonBoneBtn.FontFace = AmaticFont
NeonBoneBtn.Text = "Neon Target Bone: " .. Config.NeonAimbotBone
NeonBoneBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
NeonBoneBtn.TextSize = 24
Instance.new("UICorner", NeonBoneBtn).CornerRadius = UDim.new(0, 8)
NeonBoneBtn.MouseButton1Click:Connect(function()
    NeonBoneIndex = NeonBoneIndex % #NeonBoneOptions + 1
    Config.NeonAimbotBone = NeonBoneOptions[NeonBoneIndex]
    NeonBoneBtn.Text = "Neon Target Bone: " .. Config.NeonAimbotBone
end)

CreateSection("Shared")
CreateToggle("Team Check", "TeamCheck")
CreateToggle("Visible Check", "VisibleCheck")

CreateToggle("ESP", "ESP")
CreateToggle("Corner Box", "ESPCornerBox")
CreateToggle("ESP Health", "ESPHealth")
CreateToggle("ESP Names", "ESPNames")
CreateToggle("ESP Distance", "ESPDistance")
CreateToggle("ESP Tracers", "ESPTracers")
CreateToggle("Head Dot", "ESPHeadDot")
CreateToggle("Tool Display", "ESPToolName")
CreateToggle("Movement Flags", "ESPFlags")
CreateToggle("Vis-Check Color", "ESPVisCheck")
CreateToggle("Offscreen Arrows", "ESPOffscreen")
CreateToggle("ESP Team Color", "ESPTeamColor")
CreateSection("Visuals")
CreateToggle("Crosshair", "Crosshair")
CreateToggle("Skeleton ESP", "ESPSkeleton")
CreateToggle("FPS Counter", "FPSCounter")
CreateToggle("Ping Counter", "PingCounter")

-- Charms Toggle (special — refreshes Highlight instances)
local CharmsWrap = WrapInFrame("Charms Team ESP", 30)
local CharmsToggle = Instance.new("TextButton")
CharmsToggle.Parent = CharmsWrap
CharmsToggle.BackgroundColor3 = Config.ESPCharms and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
CharmsToggle.BorderSizePixel = 0
CharmsToggle.Position = UDim2.new(0, 10, 0, 0)
CharmsToggle.Size = UDim2.new(1, -20, 0, 30)
CharmsToggle.FontFace = AmaticFont
CharmsToggle.Text = "Charms (Team ESP): " .. tostring(Config.ESPCharms)
CharmsToggle.TextColor3 = Config.ESPCharms and Color3.fromRGB(130, 200, 255) or Color3.fromRGB(255, 255, 255)
CharmsToggle.TextSize = 24
Instance.new("UICorner", CharmsToggle).CornerRadius = UDim.new(0, 8)
CharmsToggle.MouseButton1Click:Connect(function()
    Config.ESPCharms = not Config.ESPCharms
    CharmsToggle.Text = "Charms (Team ESP): " .. tostring(Config.ESPCharms)
    CharmsToggle.TextColor3 = Config.ESPCharms and Color3.fromRGB(130, 200, 255) or Color3.fromRGB(255, 255, 255)
    CharmsToggle.BackgroundColor3 = Config.ESPCharms and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
    RefreshAllCharms()
end)

-- Pink Charms Toggle (overrides team color with soft pink)
local PinkCharmsWrap = WrapInFrame("Pink Charms", 30)
local PinkCharmsToggle = Instance.new("TextButton")
PinkCharmsToggle.Parent = PinkCharmsWrap
PinkCharmsToggle.BackgroundColor3 = Config.PinkCharms and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
PinkCharmsToggle.BorderSizePixel = 0
PinkCharmsToggle.Position = UDim2.new(0, 10, 0, 0)
PinkCharmsToggle.Size = UDim2.new(1, -20, 0, 30)
PinkCharmsToggle.FontFace = AmaticFont
PinkCharmsToggle.Text = "Pink Charms: " .. tostring(Config.PinkCharms)
PinkCharmsToggle.TextColor3 = Config.PinkCharms and Color3.fromRGB(255, 140, 180) or Color3.fromRGB(255, 255, 255)
PinkCharmsToggle.TextSize = 24
Instance.new("UICorner", PinkCharmsToggle).CornerRadius = UDim.new(0, 8)
PinkCharmsToggle.MouseButton1Click:Connect(function()
    Config.PinkCharms = not Config.PinkCharms
    PinkCharmsToggle.Text = "Pink Charms: " .. tostring(Config.PinkCharms)
    PinkCharmsToggle.TextColor3 = Config.PinkCharms and Color3.fromRGB(255, 140, 180) or Color3.fromRGB(255, 255, 255)
    PinkCharmsToggle.BackgroundColor3 = Config.PinkCharms and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
    RefreshAllCharms()
end)

-- KO Feed Toggle
local KOWrap = WrapInFrame("KO Feed", 30)
local KOToggle = Instance.new("TextButton")
KOToggle.Parent = KOWrap
KOToggle.BackgroundColor3 = Config.KOFeed and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
KOToggle.BorderSizePixel = 0
KOToggle.Position = UDim2.new(0, 10, 0, 0)
KOToggle.Size = UDim2.new(1, -20, 0, 30)
KOToggle.FontFace = AmaticFont
KOToggle.Text = "KO Feed: " .. tostring(Config.KOFeed)
KOToggle.TextColor3 = Config.KOFeed and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 255, 255)
KOToggle.TextSize = 24
Instance.new("UICorner", KOToggle).CornerRadius = UDim.new(0, 8)
KOToggle.MouseButton1Click:Connect(function()
    Config.KOFeed = not Config.KOFeed
    KOToggle.Text = "KO Feed: " .. tostring(Config.KOFeed)
    KOToggle.TextColor3 = Config.KOFeed and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(255, 255, 255)
    KOToggle.BackgroundColor3 = Config.KOFeed and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
    if not Config.KOFeed then
        KOFrame.Visible = false
    end
end)

CreateSection("Player")
CreateToggle("Super Speed", "SuperSpeed")
CreateSlider("Speed Amount", "SpeedAmount", 16, 200)
CreateToggle("Super Jump", "SuperJump")
CreateSlider("Jump Amount", "JumpAmount", 50, 300)
CreateToggle("Infinite Jump", "InfiniteJump")

CreateSection("Movement")
CreateToggle("Fly", "Fly")
CreateSlider("Fly Speed", "FlySpeed", 10, 200)
CreateToggle("Noclip", "Noclip")

-- Stealth Fly Method Cycle Button (magenta)
local SFMethodWrap = WrapInFrame("Stealth Fly Method", 30)
local SFMethodBtn = Instance.new("TextButton")
SFMethodBtn.Parent = SFMethodWrap
SFMethodBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
SFMethodBtn.BorderSizePixel = 0
SFMethodBtn.Position = UDim2.new(0, 10, 0, 0)
SFMethodBtn.Size = UDim2.new(1, -20, 0, 30)
SFMethodBtn.FontFace = AmaticFont
SFMethodBtn.Text = "Fly Method: " .. StealthMethodNames[Config.StealthFlyMethod]
SFMethodBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SFMethodBtn.TextSize = 22
Instance.new("UICorner", SFMethodBtn).CornerRadius = UDim.new(0, 8)
SFMethodBtn.MouseButton1Click:Connect(function()
    -- Cycle method 1→2→3→1
    Config.StealthFlyMethod = (Config.StealthFlyMethod % 3) + 1
    SFMethodBtn.Text = "Fly Method: " .. StealthMethodNames[Config.StealthFlyMethod]
    -- If stealth fly is active, restart with new method
    if Config.StealthFly and StealthFlying then
        StopStealthFly()
        task.wait(0.1)
        StartStealthFly()
    end
end)

-- Stealth Fly toggle (magenta — anti-cheat evasion)
local StealthFlyWrap = WrapInFrame("Stealth Fly", 30)
local StealthFlyToggle = Instance.new("TextButton")
StealthFlyToggle.Parent = StealthFlyWrap
StealthFlyToggle.BackgroundColor3 = Config.StealthFly and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
StealthFlyToggle.BorderSizePixel = 0
StealthFlyToggle.Position = UDim2.new(0, 10, 0, 0)
StealthFlyToggle.Size = UDim2.new(1, -20, 0, 30)
StealthFlyToggle.FontFace = AmaticFont
StealthFlyToggle.Text = "Stealth Fly: " .. tostring(Config.StealthFly)
StealthFlyToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
StealthFlyToggle.TextSize = 24
Instance.new("UICorner", StealthFlyToggle).CornerRadius = UDim.new(0, 8)
StealthFlyToggle.MouseButton1Click:Connect(function()
    Config.StealthFly = not Config.StealthFly
    StealthFlyToggle.Text = "Stealth Fly: " .. tostring(Config.StealthFly)
    StealthFlyToggle.BackgroundColor3 = Config.StealthFly and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
    if Config.StealthFly then
        -- Kill normal fly if it's on
        if Config.Fly then
            Config.Fly = false
            StopFly()
        end
        if Config.SilverSurfer then
            Config.SilverSurfer = false
            StopSilverSurfer()
        end
        StartStealthFly()
    else
        StopStealthFly()
    end
end)

-- Stealth Fly Speed slider (magenta fill)
local SFSpeedWrap = WrapInFrame("Stealth Fly Speed", 38)
local SFLabel = Instance.new("TextLabel")
SFLabel.Parent = SFSpeedWrap
SFLabel.BackgroundTransparency = 1
SFLabel.Position = UDim2.new(0, 10, 0, 0)
SFLabel.Size = UDim2.new(1, -20, 0, 20)
SFLabel.FontFace = AmaticFont
SFLabel.Text = "Stealth Fly Speed: " .. Config.StealthFlySpeed
SFLabel.TextColor3 = Color3.fromRGB(0, 220, 255)
SFLabel.TextSize = 24
SFLabel.TextXAlignment = Enum.TextXAlignment.Left

local SFSlider = Instance.new("Frame")
SFSlider.Parent = SFSpeedWrap
SFSlider.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
SFSlider.BorderSizePixel = 0
SFSlider.Position = UDim2.new(0, 10, 0, 24)
SFSlider.Size = UDim2.new(1, -20, 0, 10)
Instance.new("UICorner", SFSlider).CornerRadius = UDim.new(0, 5)

local SFFill = Instance.new("Frame")
SFFill.Parent = SFSlider
SFFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SFFill.BorderSizePixel = 0
SFFill.Size = UDim2.new((Config.StealthFlySpeed - 10) / (200 - 10), 0, 1, 0)
Instance.new("UICorner", SFFill).CornerRadius = UDim.new(0, 5)

local sfDragging = false
local function sfUpdate(input)
    local pos = math.clamp((input.Position.X - SFSlider.AbsolutePosition.X) / SFSlider.AbsoluteSize.X, 0, 1)
    SFFill.Size = UDim2.new(pos, 0, 1, 0)
    Config.StealthFlySpeed = math.floor(10 + (200 - 10) * pos)
    SFLabel.Text = "Stealth Fly Speed: " .. Config.StealthFlySpeed
end
SFSlider.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then sfDragging = true; sfUpdate(i) end
end)
SFSlider.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then sfDragging = false end
end)
UserInputService.InputChanged:Connect(function(i)
    if sfDragging and i.UserInputType == Enum.UserInputType.MouseMovement then sfUpdate(i) end
end)

-- Register forward-ref so StartStealthFly can update slider when auto-setting speed
SFSliderUpdateFn = function()
    SFLabel.Text = "Stealth Fly Speed: " .. Config.StealthFlySpeed
    SFFill.Size = UDim2.new((Config.StealthFlySpeed - 10) / (200 - 10), 0, 1, 0)
end

-- Silver Surfer Toggle (cyan accent — matches Sentry style)
local SurferWrap = WrapInFrame("Silver Surfer", 30)
local SurferToggle = Instance.new("TextButton")
SurferToggle.Parent = SurferWrap
SurferToggle.BackgroundColor3 = Config.SilverSurfer and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
SurferToggle.BorderSizePixel = 0
SurferToggle.Position = UDim2.new(0, 10, 0, 0)
SurferToggle.Size = UDim2.new(1, -20, 0, 30)
SurferToggle.FontFace = AmaticFont
SurferToggle.Text = "Silver Surfer: " .. tostring(Config.SilverSurfer)
SurferToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
SurferToggle.TextSize = 24
Instance.new("UICorner", SurferToggle).CornerRadius = UDim.new(0, 8)
SurferToggle.MouseButton1Click:Connect(function()
    Config.SilverSurfer = not Config.SilverSurfer
    SurferToggle.Text = "Silver Surfer: " .. tostring(Config.SilverSurfer)
    SurferToggle.BackgroundColor3 = Config.SilverSurfer and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
    if Config.SilverSurfer then
        -- Kill other fly modes (mutual exclusion)
        if Config.Fly then
            Config.Fly = false
            StopFly()
        end
        if Config.StealthFly then
            Config.StealthFly = false
            StopStealthFly()
        end
        StartSilverSurfer()
    else
        StopSilverSurfer()
    end
end)

-- Silver Surfer Speed Mode Cycle (Slow / Medium / Fast)
local SurferModeWrap = WrapInFrame("Surfer Speed Mode", 30)
local SurferModeBtn = Instance.new("TextButton")
SurferModeBtn.Parent = SurferModeWrap
SurferModeBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
SurferModeBtn.BorderSizePixel = 0
SurferModeBtn.Position = UDim2.new(0, 10, 0, 0)
SurferModeBtn.Size = UDim2.new(1, -20, 0, 30)
SurferModeBtn.FontFace = AmaticFont
SurferModeBtn.Text = "Speed: " .. SurferModeNames[Config.SilverSurferMode] .. " (" .. SurferModeSpeeds[Config.SilverSurferMode] .. ")"
SurferModeBtn.TextColor3 = Color3.fromRGB(0, 220, 255)
SurferModeBtn.TextSize = 24
Instance.new("UICorner", SurferModeBtn).CornerRadius = UDim.new(0, 8)
SurferModeBtn.MouseButton1Click:Connect(function()
    Config.SilverSurferMode = (Config.SilverSurferMode % 3) + 1
    SurferModeBtn.Text = "Speed: " .. SurferModeNames[Config.SilverSurferMode] .. " (" .. SurferModeSpeeds[Config.SilverSurferMode] .. ")"
end)

CreateSection("Troll")

-- Click TP toggle (right at the top of Troll)
local ClickTPWrap = WrapInFrame("Click TP Teleport", 30)
local ClickTPToggle = Instance.new("TextButton")
ClickTPToggle.Parent = ClickTPWrap
ClickTPToggle.BackgroundColor3 = Config.ClickTP and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
ClickTPToggle.BorderSizePixel = 0
ClickTPToggle.Position = UDim2.new(0, 10, 0, 0)
ClickTPToggle.Size = UDim2.new(1, -20, 0, 30)
ClickTPToggle.FontFace = AmaticFont
ClickTPToggle.Text = "Click TP (Ctrl+Click): " .. tostring(Config.ClickTP)
ClickTPToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
ClickTPToggle.TextSize = 24
Instance.new("UICorner", ClickTPToggle).CornerRadius = UDim.new(0, 8)
ClickTPToggle.MouseButton1Click:Connect(function()
    Config.ClickTP = not Config.ClickTP
    ClickTPToggle.Text = "Click TP (Ctrl+Click): " .. tostring(Config.ClickTP)
    ClickTPToggle.BackgroundColor3 = Config.ClickTP and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
    if Config.ClickTP then
        StartClickTP()
    else
        StopClickTP()
    end
end)

-- ===================================================================
-- SELECTED PLAYER TELEPORT (Expandable Side Panel)
-- ===================================================================
local PlayerTPOpen = false
local PlayerTPButtons = {}

-- Flyout panel — parented to ScreenGui so it renders outside MainFrame's clip bounds
local PlayerTPPanel = Instance.new("Frame")
PlayerTPPanel.Name = "PlayerTPPanel"
PlayerTPPanel.Parent = ScreenGui
PlayerTPPanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
PlayerTPPanel.BorderSizePixel = 0
PlayerTPPanel.Size = UDim2.new(0, 0, 0, 400)
PlayerTPPanel.ClipsDescendants = true
PlayerTPPanel.Visible = false
PlayerTPPanel.ZIndex = 30
Instance.new("UICorner", PlayerTPPanel).CornerRadius = UDim.new(0, 14)

-- Subtle cyan left-edge accent line
local TPPanelAccent = Instance.new("Frame")
TPPanelAccent.Parent = PlayerTPPanel
TPPanelAccent.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
TPPanelAccent.BorderSizePixel = 0
TPPanelAccent.Position = UDim2.new(0, 0, 0, 12)
TPPanelAccent.Size = UDim2.new(0, 2, 1, -24)
TPPanelAccent.ZIndex = 31

-- Panel header
local TPPanelTitle = Instance.new("TextLabel")
TPPanelTitle.Parent = PlayerTPPanel
TPPanelTitle.BackgroundTransparency = 1
TPPanelTitle.Position = UDim2.new(0, 12, 0, 8)
TPPanelTitle.Size = UDim2.new(1, -20, 0, 32)
TPPanelTitle.FontFace = AmaticBold
TPPanelTitle.Text = "Players"
TPPanelTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
TPPanelTitle.TextSize = 30
TPPanelTitle.TextXAlignment = Enum.TextXAlignment.Left
TPPanelTitle.ZIndex = 31

-- Thin divider under header
local TPPanelDivider = Instance.new("Frame")
TPPanelDivider.Parent = PlayerTPPanel
TPPanelDivider.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
TPPanelDivider.BorderSizePixel = 0
TPPanelDivider.Position = UDim2.new(0, 10, 0, 42)
TPPanelDivider.Size = UDim2.new(1, -20, 0, 1)
TPPanelDivider.ZIndex = 31

-- Scrolling list for player names
local TPPlayerList = Instance.new("ScrollingFrame")
TPPlayerList.Parent = PlayerTPPanel
TPPlayerList.BackgroundTransparency = 1
TPPlayerList.Position = UDim2.new(0, 0, 0, 48)
TPPlayerList.Size = UDim2.new(1, 0, 1, -48)
TPPlayerList.CanvasSize = UDim2.new(0, 0, 0, 0)
TPPlayerList.ScrollBarThickness = 4
TPPlayerList.ScrollBarImageColor3 = Color3.fromRGB(180, 180, 180)
TPPlayerList.ZIndex = 31
TPPlayerList.BorderSizePixel = 0

local function TeleportToPlayer(targetPlayer)
    local localChar = GetCharacter(LocalPlayer)
    local localRoot = GetRootPart(localChar)
    local targetChar = GetCharacter(targetPlayer)
    local targetRoot = GetRootPart(targetChar)
    if localRoot and targetRoot then
        -- Place 5 studs in front of target, facing them
        local targetCF = targetRoot.CFrame
        localRoot.CFrame = targetCF * CFrame.new(0, 0, -5)
    end
end

local function RefreshPlayerTPList()
    for _, btn in pairs(PlayerTPButtons) do
        pcall(function() btn:Destroy() end)
    end
    PlayerTPButtons = {}

    local listY = 6
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local pBtn = Instance.new("TextButton")
            pBtn.Parent = TPPlayerList
            pBtn.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
            pBtn.BorderSizePixel = 0
            pBtn.Position = UDim2.new(0, 8, 0, listY)
            pBtn.Size = UDim2.new(1, -16, 0, 28)
            pBtn.FontFace = AmaticFont
            pBtn.Text = player.DisplayName
            pBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            pBtn.TextSize = 26
            pBtn.ZIndex = 32
            pBtn.AutoButtonColor = false
            Instance.new("UICorner", pBtn).CornerRadius = UDim.new(0, 6)

            -- Friend star check — async so it never blocks the list build
            local starLabel = nil
            task.spawn(function()
                local ok, result = pcall(function()
                    return LocalPlayer:IsFriendsWith(player.UserId)
                end)
                if ok and result and pBtn and pBtn.Parent then
                    starLabel = Instance.new("TextLabel")
                    starLabel.Parent = pBtn
                    starLabel.BackgroundTransparency = 1
                    starLabel.Position = UDim2.new(0, 4, 0, 0)
                    starLabel.Size = UDim2.new(0, 16, 1, 0)
                    starLabel.FontFace = AmaticBold
                    starLabel.Text = "\u{2605}"
                    starLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                    starLabel.TextSize = 16
                    starLabel.ZIndex = 33
                    starLabel.TextYAlignment = Enum.TextYAlignment.Center
                end
            end)

            -- Hover glow
            pBtn.MouseEnter:Connect(function()
                pBtn.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
                pBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
                if starLabel then starLabel.TextColor3 = Color3.fromRGB(220, 220, 220) end
            end)
            pBtn.MouseLeave:Connect(function()
                pBtn.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
                pBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                if starLabel then starLabel.TextColor3 = Color3.fromRGB(255, 255, 255) end
            end)

            -- Click flash + teleport
            pBtn.MouseButton1Click:Connect(function()
                pBtn.BackgroundColor3 = Color3.fromRGB(0, 220, 255)
                pBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
                TeleportToPlayer(player)
                task.delay(0.15, function()
                    if pBtn and pBtn.Parent then
                        pBtn.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
                        pBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    end
                end)
            end)

            table.insert(PlayerTPButtons, pBtn)
            listY = listY + 33
        end
    end

    TPPlayerList.CanvasSize = UDim2.new(0, 0, 0, listY + 5)
end

-- Position tracking: anchor panel to right edge of MainFrame each frame
local function UpdateTPPanelPosition()
    local mfPos = MainFrame.AbsolutePosition
    local mfSize = MainFrame.AbsoluteSize
    PlayerTPPanel.Position = UDim2.new(0, mfPos.X + mfSize.X + 6, 0, mfPos.Y + 60)
end

local tpPanelTracker = nil

-- The toggle button inside the Troll section
local SelectedTPWrap = WrapInFrame("Selected Player Teleport", 30)
local SelectedTPBtn = Instance.new("TextButton")
SelectedTPBtn.Parent = SelectedTPWrap
SelectedTPBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
SelectedTPBtn.BorderSizePixel = 0
SelectedTPBtn.Position = UDim2.new(0, 10, 0, 0)
SelectedTPBtn.Size = UDim2.new(1, -20, 0, 30)
SelectedTPBtn.FontFace = AmaticFont
SelectedTPBtn.Text = "Selected Player Teleport  \u{203A}"
SelectedTPBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SelectedTPBtn.TextSize = 24
SelectedTPBtn.ZIndex = 10
Instance.new("UICorner", SelectedTPBtn).CornerRadius = UDim.new(0, 8)

SelectedTPBtn.MouseButton1Click:Connect(function()
    PlayerTPOpen = not PlayerTPOpen
    if PlayerTPOpen then
        SelectedTPBtn.Text = "Selected Player Teleport  \u{2039}"
        SelectedTPBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        PlayerTPPanel.Visible = true
        RefreshPlayerTPList()
        UpdateTPPanelPosition()
        PlayerTPPanel:TweenSize(UDim2.new(0, 225, 0, 400), "Out", "Quad", 0.25, true)
        -- Start position tracking while open
        if tpPanelTracker then tpPanelTracker:Disconnect() end
        tpPanelTracker = RunService.RenderStepped:Connect(UpdateTPPanelPosition)
    else
        SelectedTPBtn.Text = "Selected Player Teleport  \u{203A}"
        SelectedTPBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        -- Stop position tracking
        if tpPanelTracker then tpPanelTracker:Disconnect(); tpPanelTracker = nil end
        PlayerTPPanel:TweenSize(UDim2.new(0, 0, 0, 400), "In", "Quad", 0.2, true, function()
            PlayerTPPanel.Visible = false
        end)
    end
end)

-- Auto-refresh player list when players join or leave (only while panel is open)
Players.PlayerAdded:Connect(function()
    if PlayerTPOpen then
        task.wait(1)
        RefreshPlayerTPList()
    end
end)
Players.PlayerRemoving:Connect(function()
    if PlayerTPOpen then
        task.wait(0.3)
        RefreshPlayerTPList()
    end
end)

-- Hide panel when menu is hidden via INSERT
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Config.MenuKey and PlayerTPOpen then
        PlayerTPOpen = false
        SelectedTPBtn.Text = "Selected Player Teleport  \u{203A}"
        SelectedTPBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        if tpPanelTracker then tpPanelTracker:Disconnect(); tpPanelTracker = nil end
        PlayerTPPanel.Visible = false
        PlayerTPPanel.Size = UDim2.new(0, 0, 0, 400)
    end
end)

-- ===================================================================
-- EJECTION (Meme Launcher — Sends YOU to the Moon)
-- ===================================================================
-- Spins your character on all axes at extreme angular velocity
-- while applying massive upward force. You become a screaming
-- spinning missile launched through the skybox. Pure comedy.
-- Auto-cleans after 3 seconds so you respawn normally.
-- ===================================================================

local EjectionActive = false

local function DoEjection()
    if EjectionActive then return end

    local myChar = GetCharacter(LocalPlayer)
    local myRoot = GetRootPart(myChar)
    local myHum = GetHumanoid(myChar)
    if not myRoot or not myHum then return end

    EjectionActive = true
    local cleanup = {}

    -- SPIN: all three axes, max torque — you become a physics tornado
    local bav = Instance.new("BodyAngularVelocity")
    bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bav.AngularVelocity = Vector3.new(9999, 9999, 9999)
    bav.P = 1250000
    bav.Parent = myRoot
    table.insert(cleanup, bav)

    -- LAUNCH: straight up at absurd velocity
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.new(0, 8000, 0)
    bv.P = 1250000
    bv.Parent = myRoot
    table.insert(cleanup, bv)

    -- Noclip so we don't bonk on ceilings
    local noclipConn = RunService.Stepped:Connect(function()
        local char = GetCharacter(LocalPlayer)
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end)

    -- Cleanup after 3 seconds — let physics settle, then respawn normally
    task.delay(3, function()
        if noclipConn then noclipConn:Disconnect() end
        for _, obj in pairs(cleanup) do
            pcall(function() obj:Destroy() end)
        end
        EjectionActive = false
    end)
end

-- Ejection button in the Troll section
local EjectionWrap = WrapInFrame("Ejection Launcher", 30)
local EjectionBtn = Instance.new("TextButton")
EjectionBtn.Parent = EjectionWrap
EjectionBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
EjectionBtn.BorderSizePixel = 0
EjectionBtn.Position = UDim2.new(0, 10, 0, 0)
EjectionBtn.Size = UDim2.new(1, -20, 0, 30)
EjectionBtn.FontFace = AmaticFont
EjectionBtn.Text = "Ejection"
EjectionBtn.TextColor3 = Color3.fromRGB(0, 220, 255)
EjectionBtn.TextSize = 24
EjectionBtn.ZIndex = 10
Instance.new("UICorner", EjectionBtn).CornerRadius = UDim.new(0, 8)

EjectionBtn.MouseButton1Click:Connect(function()
    if EjectionActive then return end
    EjectionBtn.BackgroundColor3 = Color3.fromRGB(0, 220, 255)
    EjectionBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    DoEjection()
    task.delay(3, function()
        if EjectionBtn and EjectionBtn.Parent then
            EjectionBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            EjectionBtn.TextColor3 = Color3.fromRGB(0, 220, 255)
        end
    end)
end)

-- Spinbot toggle
local SpinWrap = WrapInFrame("Spinbot", 30)
local SpinToggle = Instance.new("TextButton")
SpinToggle.Parent = SpinWrap
SpinToggle.BackgroundColor3 = Config.Spinbot and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
SpinToggle.BorderSizePixel = 0
SpinToggle.Position = UDim2.new(0, 10, 0, 0)
SpinToggle.Size = UDim2.new(1, -20, 0, 30)
SpinToggle.FontFace = AmaticFont
SpinToggle.Text = "Spinbot: " .. tostring(Config.Spinbot)
SpinToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
SpinToggle.TextSize = 24
Instance.new("UICorner", SpinToggle).CornerRadius = UDim.new(0, 8)
SpinToggle.MouseButton1Click:Connect(function()
    Config.Spinbot = not Config.Spinbot
    SpinToggle.Text = "Spinbot: " .. tostring(Config.Spinbot)
    SpinToggle.BackgroundColor3 = Config.Spinbot and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
    if Config.Spinbot then
        StartSpinbot()
    else
        StopSpinbot()
    end
end)

CreateSlider("Spin Speed", "SpinSpeed", 5, 500)

-- Slingshot toggle (Ctrl+Click to launch toward click point)
local SlingshotWrap = WrapInFrame("Slingshot Launch", 30)
local SlingshotToggle = Instance.new("TextButton")
SlingshotToggle.Parent = SlingshotWrap
SlingshotToggle.BackgroundColor3 = Config.Slingshot and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
SlingshotToggle.BorderSizePixel = 0
SlingshotToggle.Position = UDim2.new(0, 10, 0, 0)
SlingshotToggle.Size = UDim2.new(1, -20, 0, 30)
SlingshotToggle.FontFace = AmaticFont
SlingshotToggle.Text = "Slingshot (Ctrl+Click): " .. tostring(Config.Slingshot)
SlingshotToggle.TextColor3 = Color3.fromRGB(0, 220, 255)
SlingshotToggle.TextSize = 24
Instance.new("UICorner", SlingshotToggle).CornerRadius = UDim.new(0, 8)
SlingshotToggle.MouseButton1Click:Connect(function()
    Config.Slingshot = not Config.Slingshot
    SlingshotToggle.Text = "Slingshot (Ctrl+Click): " .. tostring(Config.Slingshot)
    SlingshotToggle.BackgroundColor3 = Config.Slingshot and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
    if Config.Slingshot then
        StartSlingshot()
    else
        StopSlingshot()
    end
end)

CreateSection("Premium")

-- Triggerbot toggle — white text
local TriggerWrap = WrapInFrame("Triggerbot", 30)
local TriggerToggle = Instance.new("TextButton")
TriggerToggle.Parent = TriggerWrap
TriggerToggle.BackgroundColor3 = Config.Triggerbot and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
TriggerToggle.BorderSizePixel = 0
TriggerToggle.Position = UDim2.new(0, 10, 0, 0)
TriggerToggle.Size = UDim2.new(1, -20, 0, 30)
TriggerToggle.FontFace = AmaticFont
TriggerToggle.Text = "Triggerbot: " .. tostring(Config.Triggerbot)
TriggerToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
TriggerToggle.TextSize = 24
Instance.new("UICorner", TriggerToggle).CornerRadius = UDim.new(0, 8)
TriggerToggle.MouseButton1Click:Connect(function()
    Config.Triggerbot = not Config.Triggerbot
    TriggerToggle.Text = "Triggerbot: " .. tostring(Config.Triggerbot)
    TriggerToggle.BackgroundColor3 = Config.Triggerbot and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
end)

CreateSlider("Trigger Delay", "TriggerbotDelay", 5, 30)


-- ===================================================================
-- ORBIT PLAYER (Expandable Side Panel — Troll, IIFE scoped)
-- ===================================================================
Config._OrbitConn = nil
Config._OrbitActive = false
;(function()
    local OrbitPanel = Instance.new("Frame")
    OrbitPanel.Name = "OrbitPanel"; OrbitPanel.Parent = ScreenGui
    OrbitPanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0); OrbitPanel.BorderSizePixel = 0
    OrbitPanel.Size = UDim2.new(0, 0, 0, 400); OrbitPanel.ClipsDescendants = true
    OrbitPanel.Visible = false; OrbitPanel.ZIndex = 30
    Instance.new("UICorner", OrbitPanel).CornerRadius = UDim.new(0, 14)
    do local a = Instance.new("Frame"); a.Parent = OrbitPanel; a.BackgroundColor3 = Color3.fromRGB(200, 200, 200); a.BorderSizePixel = 0; a.Position = UDim2.new(0, 0, 0, 12); a.Size = UDim2.new(0, 2, 1, -24); a.ZIndex = 31 end
    local OTitle = Instance.new("TextLabel"); OTitle.Parent = OrbitPanel; OTitle.BackgroundTransparency = 1
    OTitle.Position = UDim2.new(0, 12, 0, 8); OTitle.Size = UDim2.new(1, -20, 0, 32)
    OTitle.FontFace = AmaticBold; OTitle.Text = "Orbit"; OTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    OTitle.TextSize = 30; OTitle.TextXAlignment = Enum.TextXAlignment.Left; OTitle.ZIndex = 31
    do local d = Instance.new("Frame"); d.Parent = OrbitPanel; d.BackgroundColor3 = Color3.fromRGB(35,35,35); d.BorderSizePixel = 0; d.Position = UDim2.new(0,10,0,42); d.Size = UDim2.new(1,-20,0,1); d.ZIndex = 31 end
    local OList = Instance.new("ScrollingFrame"); OList.Parent = OrbitPanel; OList.BackgroundTransparency = 1
    OList.Position = UDim2.new(0,0,0,48); OList.Size = UDim2.new(1,0,1,-48)
    OList.CanvasSize = UDim2.new(0,0,0,0); OList.ScrollBarThickness = 4
    OList.ScrollBarImageColor3 = Color3.fromRGB(180,180,180); OList.ZIndex = 31; OList.BorderSizePixel = 0
    local orbitOpen, orbitTracker = false, nil

    local function StopOrbit()
        if Config._OrbitConn then Config._OrbitConn:Disconnect(); Config._OrbitConn = nil end
        Config._OrbitActive = false
        Config._OrbitTarget = nil
        local ch = LocalPlayer.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum.PlatformStand = false; hum.AutoRotate = true end) end
    end

    local function StartOrbit(target)
        StopOrbit()
        Config._OrbitTarget = target
        local tChar = target and target.Character
        local tRoot = tChar and (tChar:FindFirstChild("HumanoidRootPart") or tChar:FindFirstChild("Torso"))
        if not tRoot then return end
        local ch = LocalPlayer.Character
        local root = ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso"))
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        local height, radius = 8, 14
        root.CFrame = CFrame.new(tRoot.Position + Vector3.new(radius, height, 0), tRoot.Position + Vector3.new(0, height, 0))
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hum.PlatformStand = true; hum.AutoRotate = false
        Config._OrbitActive = true
        local offset = root.Position - tRoot.Position
        local angle = math.atan2(offset.X, offset.Z)
        Config._OrbitConn = RunService.RenderStepped:Connect(function(dt)
            if not Config._OrbitActive then StopOrbit(); return end
            local tc = target and target.Character
            local tr = tc and (tc:FindFirstChild("HumanoidRootPart") or tc:FindFirstChild("Torso"))
            if not tr or not root or not root.Parent then StopOrbit(); return end
            angle = angle + dt * 2.5
            local px = tr.Position.X + math.sin(angle) * radius
            local pz = tr.Position.Z + math.cos(angle) * radius
            local py = tr.Position.Y + height
            root.CFrame = CFrame.new(Vector3.new(px,py,pz), Vector3.new(tr.Position.X, py, tr.Position.Z))
            root.AssemblyLinearVelocity = Vector3.new(0,0,0)
            for _, p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
        end)
    end

    local function RefreshOList()
        for _, c in pairs(OList:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        local y = 6
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local b = Instance.new("TextButton"); b.Parent = OList
                b.BackgroundColor3 = Color3.fromRGB(12,12,12); b.BorderSizePixel = 0
                b.Position = UDim2.new(0,8,0,y); b.Size = UDim2.new(1,-16,0,28)
                b.FontFace = AmaticFont; b.Text = player.DisplayName
                b.TextColor3 = Color3.fromRGB(255,255,255); b.TextSize = 24
                b.ZIndex = 32; b.AutoButtonColor = false
                Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
                b.MouseEnter:Connect(function() b.BackgroundColor3 = Color3.fromRGB(35,35,35) end)
                b.MouseLeave:Connect(function() b.BackgroundColor3 = Color3.fromRGB(12,12,12) end)
                b.MouseButton1Click:Connect(function()
                    if Config._OrbitActive then StopOrbit(); b.Text = player.DisplayName
                    else StartOrbit(player); b.Text = "STOP " .. player.DisplayName end
                end)
                y = y + 33
            end
        end
        OList.CanvasSize = UDim2.new(0,0,0,y+5)
    end

    local function UpdateOPos()
        local p = MainFrame.AbsolutePosition; local s = MainFrame.AbsoluteSize
        OrbitPanel.Position = UDim2.new(0, p.X+s.X+6, 0, p.Y+120)
    end

    local OBtnWrap = WrapInFrame("Orbit Player", 30)
    local OBtn = Instance.new("TextButton"); OBtn.Parent = OBtnWrap
    OBtn.BackgroundColor3 = Color3.fromRGB(20,20,20); OBtn.BorderSizePixel = 0
    OBtn.Position = UDim2.new(0,10,0,0); OBtn.Size = UDim2.new(1,-20,0,30)
    OBtn.FontFace = AmaticFont; OBtn.Text = "Orbit Player  \u{203A}"
    OBtn.TextColor3 = Color3.fromRGB(255,255,255); OBtn.TextSize = 24
    OBtn.ZIndex = 10; Instance.new("UICorner", OBtn).CornerRadius = UDim.new(0, 8)
    OBtn.MouseButton1Click:Connect(function()
        orbitOpen = not orbitOpen
        if orbitOpen then
            OrbitPanel.Visible = true; OBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
            RefreshOList()
            OrbitPanel:TweenSize(UDim2.new(0,225,0,400), "Out", "Quad", 0.25, true)
            if not orbitTracker then orbitTracker = RunService.RenderStepped:Connect(UpdateOPos) end
        else
            OBtn.BackgroundColor3 = Color3.fromRGB(20,20,20)
            OrbitPanel:TweenSize(UDim2.new(0,0,0,400), "In", "Quad", 0.2, true, function() OrbitPanel.Visible = false end)
            if orbitTracker then orbitTracker:Disconnect(); orbitTracker = nil end
            StopOrbit()
        end
    end)

    -- Auto-refresh orbit list when players join or leave
    Players.PlayerAdded:Connect(function()
        if orbitOpen then task.wait(1); RefreshOList() end
    end)
    Players.PlayerRemoving:Connect(function(leavingPlayer)
        if Config._OrbitActive then
            -- Check if we were orbiting the person who left
            StopOrbit()
        end
        if orbitOpen then task.wait(0.3); RefreshOList() end
    end)
end)()

-- CONNECTIONS
-- ===================================================================

-- Toggle Menu (blocked until authenticated)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Config.MenuKey then
        Config.ShowMenu = not Config.ShowMenu
        MainFrame.Visible = Config.ShowMenu
    end

end)


-- Aimbot + ESP
RunService.RenderStepped:Connect(function()
    -- All three aimbots run every frame (each checks its own toggle)
    DoAimbot()
    DoOGAimbot()
    DoNeonAimbot()
    DoTriggerbot()
    -- ESP v2 (staggered, cached)
    ESP2_Tick()
    if Config._XH then Config._XH() end


    -- Skeleton ESP
    if Config.ESPSkeleton then
        for _, player in pairs(Players:GetPlayers()) do
            UpdateSkeleton(player)
        end
    else
        for _, player in pairs(Players:GetPlayers()) do
            if SkeletonObjects[player] then
                for _, bone in pairs(SkeletonObjects[player]) do
                    bone.bloom.Visible = false
                    bone.glow.Visible = false
                    bone.inner.Visible = false
                    bone.core.Visible = false
                end
            end
        end
    end
end)

-- Player Mods
RunService.Heartbeat:Connect(ApplyMods)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if Config.InfiniteJump then
        local humanoid = GetHumanoid(GetCharacter(LocalPlayer))
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Player Added/Removed
Players.PlayerAdded:Connect(function(player)
    task.wait(1)
    CreateESP2(player)
    CreateSkeleton(player)
    if Config.ESPCharms then ApplyCharm(player) end
    HookPlayerDeath(player)
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESP2(player)
    RemoveSkeleton(player)
    RemoveCharm(player)
    UnhookPlayerDeath(player)
end)

-- Initialize ESP + Skeleton + Charms + KO hooks for existing players
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESP2(player)
        CreateSkeleton(player)
        if Config.ESPCharms then ApplyCharm(player) end
        HookPlayerDeath(player)
    end
end

-- ===================================================================
-- INITIALIZATION
-- ===================================================================
print("╔════════════════════════════════════════╗")
print("║     SENTRY       ║")
print("║     Coded by: Mrgrumeti                ║")
print("║     + 3x Aimbot (OG/Micro/Neon Hub)    ║")
print("║     + Click TP + Spinbot + Slingshot    ║")
print("║     + Selected Player TP (Side Panel)   ║")
print("║     + Ejection (Meme Launcher)           ║")
print("║     + ESP + Charms + Fly | Rounded UI   ║")
print("║     + Silver Surfer (Cosmic Board Fly)   ║")
print("║     + Bypass Fly (Anti-Cheat Evasion)   ║")
print("║     + 3 Stealth Methods | Charms        ║")
print("║     + Neon Hub's Aim (CHEESE_BOY)       ║")
print("║     Press INSERT to toggle menu         ║")
print("╚════════════════════════════════════════╝")

if not DrawingSupported then
    warn("[Sentry] Drawing library not supported - ESP will not work")
end

local addonOk, addonErr = pcall(function()
Config.ChatCommands = false
local TweenService = game:GetService("TweenService")
local CmdNotifFrame = Instance.new("Frame")
CmdNotifFrame.Name = "Sentry_CmdNotifs"
CmdNotifFrame.Parent = ScreenGui
CmdNotifFrame.BackgroundTransparency = 1
CmdNotifFrame.Position = UDim2.new(1, -310, 1, -300)
CmdNotifFrame.Size = UDim2.new(0, 300, 0, 290)
CmdNotifFrame.ClipsDescendants = true
CmdNotifFrame.ZIndex = 50
local CmdLayout = Instance.new("UIListLayout")
CmdLayout.Parent = CmdNotifFrame
CmdLayout.SortOrder = Enum.SortOrder.LayoutOrder
CmdLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
CmdLayout.Padding = UDim.new(0, 3)
local _cmdN = 0
local function CmdNotify(text, color)
    color = color or Color3.fromRGB(0, 220, 255)
    _cmdN = _cmdN + 1
    local bg = Instance.new("Frame")
    bg.Parent = CmdNotifFrame
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0.2
    bg.BorderSizePixel = 0
    bg.Size = UDim2.new(1, 0, 0, 22)
    bg.LayoutOrder = _cmdN
    bg.ZIndex = 51
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
    local lb = Instance.new("TextLabel")
    lb.Parent = bg
    lb.BackgroundTransparency = 1
    lb.Position = UDim2.new(0, 8, 0, 0)
    lb.Size = UDim2.new(1, -16, 1, 0)
    lb.FontFace = AmaticFont
    lb.Text = text
    lb.TextColor3 = color
    lb.TextSize = 20
    lb.TextXAlignment = Enum.TextXAlignment.Left
    lb.TextTruncate = Enum.TextTruncate.AtEnd
    lb.ZIndex = 52
    task.delay(4.5, function()
        if bg and bg.Parent then
            local fi = TweenInfo.new(0.5, Enum.EasingStyle.Quad)
            TweenService:Create(bg, fi, {BackgroundTransparency = 1}):Play()
            TweenService:Create(lb, fi, {TextTransparency = 1}):Play()
            task.delay(0.6, function() if bg and bg.Parent then bg:Destroy() end end)
        end
    end)
end
local function KillAllFlyModes(except)
    if except ~= "Fly" and Config.Fly then Config.Fly = false; StopFly() end
    if except ~= "StealthFly" and Config.StealthFly then Config.StealthFly = false; StopStealthFly() end
    if except ~= "SilverSurfer" and Config.SilverSurfer then Config.SilverSurfer = false; StopSilverSurfer() end
end
local function ResolveToggle(cur, arg)
    if arg == "on" or arg == "1" then return true end
    if arg == "off" or arg == "0" then return false end
    return not cur
end
local function HandleCommand(message)
    if not Config.ChatCommands then return end
    if string.sub(message, 1, 1) ~= "/" then return end
    local parts = string.split(string.lower(message), " ")
    local cmd = parts[1]
    local argStr = parts[2]
    local argNum = tonumber(parts[2])
    if string.sub(cmd, 1, 3) == "/un" and #cmd > 3 then
        local s = "/" .. string.sub(cmd, 4)
        local vt = {["/esp"]=1,["/cornerbox"]=1,["/esphealth"]=1,["/espnames"]=1,["/espdist"]=1,["/tracers"]=1,["/headdot"]=1,["/toolname"]=1,["/espflags"]=1,["/espvischeck"]=1,["/offscreen"]=1,["/espteam"]=1,["/fly"]=1,["/noclip"]=1,["/stealth"]=1,["/surfer"]=1,["/aimbot"]=1,["/ogaim"]=1,["/neonaim"]=1,["/trigger"]=1,["/skeleton"]=1,["/charms"]=1,["/pinkcharms"]=1,["/kofeed"]=1,["/showfov"]=1,["/teamcheck"]=1,["/vischeck"]=1,["/superspeed"]=1,["/superjump"]=1,["/ijump"]=1,["/spin"]=1,["/clicktp"]=1,["/sling"]=1,["/fps"]=1,["/ping"]=1,["/cmds"]=1}
        if vt[s] then cmd = s; argStr = "off" end
    end
    local cy = Color3.fromRGB(0, 220, 255)
    local gn = Color3.fromRGB(80, 255, 80)
    local rd = Color3.fromRGB(255, 80, 80)
    local pk = Color3.fromRGB(255, 120, 180)
    local yl = Color3.fromRGB(255, 230, 80)
    local wt = Color3.fromRGB(255, 255, 255)
    if cmd == "/panic" or cmd == "/off" then Config.Fly = false; StopFly(); Config.ESP = false; Config.Crosshair = false; Config._OrbitActive = false; if Config._OrbitConn then Config._OrbitConn:Disconnect(); Config._OrbitConn = nil end; Config.StealthFly = false; StopStealthFly(); Config.SilverSurfer = false; StopSilverSurfer(); Config.Noclip = false; ToggleNoclip(); Config.Aimbot = false; Config.OGAimbot = false; Config.NeonAimbot = false; Config.Triggerbot = false; Config.ESPSkeleton = false; Config.ESPCharms = false; RefreshAllCharms(); Config.PinkCharms = false; Config.KOFeed = false; KOFrame.Visible = false; Config.SuperSpeed = false; Config.SuperJump = false; Config.InfiniteJump = false; Config.Spinbot = false; StopSpinbot(); Config.ClickTP = false; StopClickTP(); Config.Slingshot = false; StopSlingshot(); CmdNotify("PANIC — all OFF", rd); return
    elseif cmd == "/fly" then Config.Fly = ResolveToggle(Config.Fly, argStr); if Config.Fly then KillAllFlyModes("Fly"); StartFly() else StopFly() end; CmdNotify("Fly: "..tostring(Config.Fly), Config.Fly and gn or rd)
    elseif cmd == "/noclip" then Config.Noclip = ResolveToggle(Config.Noclip, argStr); ToggleNoclip(); CmdNotify("Noclip: "..tostring(Config.Noclip), Config.Noclip and gn or rd)
    elseif cmd == "/stealth" then Config.StealthFly = ResolveToggle(Config.StealthFly, argStr); if Config.StealthFly then KillAllFlyModes("StealthFly"); StartStealthFly() else StopStealthFly() end; CmdNotify("Stealth: "..tostring(Config.StealthFly), Config.StealthFly and gn or rd)
    elseif cmd == "/surfer" then Config.SilverSurfer = ResolveToggle(Config.SilverSurfer, argStr); if Config.SilverSurfer then KillAllFlyModes("SilverSurfer"); StartSilverSurfer() else StopSilverSurfer() end; CmdNotify("Surfer: "..tostring(Config.SilverSurfer), Config.SilverSurfer and gn or rd)
    elseif cmd == "/aimbot" then Config.Aimbot = ResolveToggle(Config.Aimbot, argStr); CmdNotify("Aimbot: "..tostring(Config.Aimbot), Config.Aimbot and gn or rd)
    elseif cmd == "/ogaim" then Config.OGAimbot = ResolveToggle(Config.OGAimbot, argStr); CmdNotify("OG: "..tostring(Config.OGAimbot), Config.OGAimbot and gn or rd)
    elseif cmd == "/neonaim" then Config.NeonAimbot = ResolveToggle(Config.NeonAimbot, argStr); CmdNotify("Neon: "..tostring(Config.NeonAimbot), Config.NeonAimbot and gn or rd)
    elseif cmd == "/trigger" then Config.Triggerbot = ResolveToggle(Config.Triggerbot, argStr); CmdNotify("Trigger: "..tostring(Config.Triggerbot), Config.Triggerbot and gn or rd)
    elseif cmd == "/skeleton" then Config.ESPSkeleton = ResolveToggle(Config.ESPSkeleton, argStr); CmdNotify("Skel: "..tostring(Config.ESPSkeleton), Config.ESPSkeleton and gn or rd)
    elseif cmd == "/charms" then Config.ESPCharms = ResolveToggle(Config.ESPCharms, argStr); RefreshAllCharms(); CmdNotify("Charms: "..tostring(Config.ESPCharms), Config.ESPCharms and gn or rd)
    elseif cmd == "/pinkcharms" then Config.PinkCharms = ResolveToggle(Config.PinkCharms, argStr); RefreshAllCharms(); CmdNotify("Pink: "..tostring(Config.PinkCharms), Config.PinkCharms and pk or rd)
    elseif cmd == "/kofeed" then Config.KOFeed = ResolveToggle(Config.KOFeed, argStr); if not Config.KOFeed then KOFrame.Visible = false end; CmdNotify("KO: "..tostring(Config.KOFeed), Config.KOFeed and gn or rd)
    elseif cmd == "/showfov" then local s = ResolveToggle(Config.AimbotShowFOV, argStr); Config.AimbotShowFOV = s; Config.OGAimbotShowFOV = s; Config.NeonAimbotShowFOV = s; CmdNotify("FOV: "..tostring(s), s and gn or rd)
    elseif cmd == "/teamcheck" then Config.TeamCheck = ResolveToggle(Config.TeamCheck, argStr); CmdNotify("Team: "..tostring(Config.TeamCheck), Config.TeamCheck and gn or rd)
    elseif cmd == "/vischeck" then Config.VisibleCheck = ResolveToggle(Config.VisibleCheck, argStr); CmdNotify("Vis: "..tostring(Config.VisibleCheck), Config.VisibleCheck and gn or rd)
    elseif cmd == "/esp" then Config.ESP = ResolveToggle(Config.ESP, argStr); CmdNotify("ESP: "..tostring(Config.ESP), Config.ESP and gn or rd)
    elseif cmd == "/cornerbox" then Config.ESPCornerBox = ResolveToggle(Config.ESPCornerBox, argStr); CmdNotify("CBox: "..tostring(Config.ESPCornerBox), Config.ESPCornerBox and gn or rd)
    elseif cmd == "/esphealth" then Config.ESPHealth = ResolveToggle(Config.ESPHealth, argStr); CmdNotify("HP: "..tostring(Config.ESPHealth), Config.ESPHealth and gn or rd)
    elseif cmd == "/espnames" then Config.ESPNames = ResolveToggle(Config.ESPNames, argStr); CmdNotify("Names: "..tostring(Config.ESPNames), Config.ESPNames and gn or rd)
    elseif cmd == "/espdist" then Config.ESPDistance = ResolveToggle(Config.ESPDistance, argStr); CmdNotify("Dist: "..tostring(Config.ESPDistance), Config.ESPDistance and gn or rd)
    elseif cmd == "/tracers" then Config.ESPTracers = ResolveToggle(Config.ESPTracers, argStr); CmdNotify("Trc: "..tostring(Config.ESPTracers), Config.ESPTracers and gn or rd)
    elseif cmd == "/headdot" then Config.ESPHeadDot = ResolveToggle(Config.ESPHeadDot, argStr); CmdNotify("HDot: "..tostring(Config.ESPHeadDot), Config.ESPHeadDot and gn or rd)
    elseif cmd == "/toolname" then Config.ESPToolName = ResolveToggle(Config.ESPToolName, argStr); CmdNotify("Tool: "..tostring(Config.ESPToolName), Config.ESPToolName and gn or rd)
    elseif cmd == "/espflags" then Config.ESPFlags = ResolveToggle(Config.ESPFlags, argStr); CmdNotify("Flags: "..tostring(Config.ESPFlags), Config.ESPFlags and gn or rd)
    elseif cmd == "/espvischeck" then Config.ESPVisCheck = ResolveToggle(Config.ESPVisCheck, argStr); CmdNotify("VisChk: "..tostring(Config.ESPVisCheck), Config.ESPVisCheck and gn or rd)
    elseif cmd == "/offscreen" then Config.ESPOffscreen = ResolveToggle(Config.ESPOffscreen, argStr); CmdNotify("OFS: "..tostring(Config.ESPOffscreen), Config.ESPOffscreen and gn or rd)
    elseif cmd == "/espteam" then Config.ESPTeamColor = ResolveToggle(Config.ESPTeamColor, argStr); CmdNotify("TClr: "..tostring(Config.ESPTeamColor), Config.ESPTeamColor and gn or rd)
    elseif cmd == "/espmaxdist" then if argNum then Config.ESPMaxDist = math.clamp(argNum, 100, 5000); CmdNotify("MaxD: "..Config.ESPMaxDist, cy) else CmdNotify("/espmaxdist [100-5000]", yl) end
    elseif cmd == "/superspeed" then Config.SuperSpeed = ResolveToggle(Config.SuperSpeed, argStr); CmdNotify("Speed: "..tostring(Config.SuperSpeed), Config.SuperSpeed and gn or rd)
    elseif cmd == "/superjump" then Config.SuperJump = ResolveToggle(Config.SuperJump, argStr); CmdNotify("Jump: "..tostring(Config.SuperJump), Config.SuperJump and gn or rd)
    elseif cmd == "/ijump" then Config.InfiniteJump = ResolveToggle(Config.InfiniteJump, argStr); CmdNotify("InfJmp: "..tostring(Config.InfiniteJump), Config.InfiniteJump and gn or rd)
    elseif cmd == "/spin" then Config.Spinbot = ResolveToggle(Config.Spinbot, argStr); if Config.Spinbot then StartSpinbot() else StopSpinbot() end; CmdNotify("Spin: "..tostring(Config.Spinbot), Config.Spinbot and gn or rd)
    elseif cmd == "/clicktp" then Config.ClickTP = ResolveToggle(Config.ClickTP, argStr); if Config.ClickTP then StartClickTP() else StopClickTP() end; CmdNotify("CTP: "..tostring(Config.ClickTP), Config.ClickTP and gn or rd)
    elseif cmd == "/sling" then Config.Slingshot = ResolveToggle(Config.Slingshot, argStr); if Config.Slingshot then StartSlingshot() else StopSlingshot() end; CmdNotify("Sling: "..tostring(Config.Slingshot), Config.Slingshot and gn or rd)
    elseif cmd == "/eject" then DoEjection(); CmdNotify("Ejected!", yl)
    elseif cmd == "/fps" then Config.FPSCounter = ResolveToggle(Config.FPSCounter, argStr); CmdNotify("FPS: "..tostring(Config.FPSCounter), Config.FPSCounter and gn or rd)
    elseif cmd == "/ping" then Config.PingCounter = ResolveToggle(Config.PingCounter, argStr); CmdNotify("Ping: "..tostring(Config.PingCounter), Config.PingCounter and gn or rd)
    elseif cmd == "/flyspeed" then if argNum then Config.FlySpeed = math.clamp(argNum, 10, 200); CmdNotify("FlySpd: "..Config.FlySpeed, cy) else CmdNotify("/flyspeed [10-200]", yl) end
    elseif cmd == "/stealthspeed" then if argNum then Config.StealthFlySpeed = math.clamp(argNum, 10, 200); if SFSliderUpdateFn then SFSliderUpdateFn() end; CmdNotify("SSpd: "..Config.StealthFlySpeed, cy) else CmdNotify("/stealthspeed [10-200]", yl) end
    elseif cmd == "/speedamt" then if argNum then Config.SpeedAmount = math.clamp(argNum, 16, 200); CmdNotify("Spd: "..Config.SpeedAmount, cy) else CmdNotify("/speedamt [16-200]", yl) end
    elseif cmd == "/jumpamt" then if argNum then Config.JumpAmount = math.clamp(argNum, 50, 300); CmdNotify("Jmp: "..Config.JumpAmount, cy) else CmdNotify("/jumpamt [50-300]", yl) end
    elseif cmd == "/fov" then if argNum then Config.AimbotFOV = math.clamp(argNum, 50, 400); CmdNotify("FOV: "..Config.AimbotFOV, cy) else CmdNotify("/fov [50-400]", yl) end
    elseif cmd == "/ogfov" then if argNum then Config.OGAimbotFOV = math.clamp(argNum, 50, 600); CmdNotify("OGFOV: "..Config.OGAimbotFOV, cy) else CmdNotify("/ogfov [50-600]", yl) end
    elseif cmd == "/neonfov" then if argNum then Config.NeonAimbotFOV = math.clamp(argNum, 50, 600); CmdNotify("NeFOV: "..Config.NeonAimbotFOV, cy) else CmdNotify("/neonfov [50-600]", yl) end
    elseif cmd == "/smooth" then if argNum then Config.AimbotSmoothing = math.clamp(argNum, 5, 100); CmdNotify("Smth: "..Config.AimbotSmoothing, cy) else CmdNotify("/smooth [5-100]", yl) end
    elseif cmd == "/ogsmooth" then if argNum then Config.OGAimbotSmoothing = math.clamp(argNum, 10, 90); CmdNotify("OGSmth: "..Config.OGAimbotSmoothing, cy) else CmdNotify("/ogsmooth [10-90]", yl) end
    elseif cmd == "/spinspeed" then if argNum then Config.SpinSpeed = math.clamp(argNum, 5, 500); CmdNotify("SpnSpd: "..Config.SpinSpeed, cy) else CmdNotify("/spinspeed [5-500]", yl) end
    elseif cmd == "/triggerdelay" then if argNum then Config.TriggerbotDelay = math.clamp(argNum, 5, 30); CmdNotify("TrgDly: "..Config.TriggerbotDelay, cy) else CmdNotify("/triggerdelay [5-30]", yl) end
    elseif cmd == "/bone" then local b = parts[2]; if b then local bm = {head="Head",torso="UpperTorso",root="HumanoidRootPart"}; local r = bm[b]; if r then Config.OGAimbotBone = r; Config.NeonAimbotBone = r; CmdNotify("Bone: "..r, cy) else CmdNotify("head/torso/root", yl) end else CmdNotify("/bone [h/t/r]", yl) end
    elseif cmd == "/method" then if argNum and argNum >= 1 and argNum <= 3 then Config.StealthFlyMethod = argNum; CmdNotify("Method: "..StealthMethodNames[argNum], cy); if Config.StealthFly and StealthFlying then StopStealthFly(); task.wait(0.1); StartStealthFly() end else CmdNotify("/method [1-3]", yl) end
    elseif cmd == "/surfermode" then if argNum and argNum >= 1 and argNum <= 3 then Config.SilverSurferMode = argNum; CmdNotify("Surfer: "..SurferModeNames[argNum], cy) else CmdNotify("/surfermode [1-3]", yl) end
    elseif cmd == "/cmds" then Config.ChatCommands = ResolveToggle(Config.ChatCommands, argStr); CmdNotify("Cmds: "..tostring(Config.ChatCommands), Config.ChatCommands and gn or rd)
    elseif cmd == "/menu" then Config.ShowMenu = not Config.ShowMenu; MainFrame.Visible = Config.ShowMenu; CmdNotify("Menu: "..tostring(Config.ShowMenu), Config.ShowMenu and gn or rd)
    elseif cmd == "/help" then CmdNotify("=== Sentry ===", wt); CmdNotify("/cmd | /cmd on | /cmd off | /uncmd", cy); CmdNotify("/panic — kill ALL", rd); CmdNotify("/fly /noclip /stealth /surfer", cy); CmdNotify("/esp /cornerbox /tracers /headdot", cy); CmdNotify("/toolname /espflags /espvischeck /offscreen", cy); CmdNotify("/skeleton /charms /espteam /espmaxdist", cy); CmdNotify("/aimbot /ogaim /neonaim /trigger", cy); CmdNotify("/superspeed /superjump /ijump", cy); CmdNotify("/spin /clicktp /sling /eject", cy); CmdNotify("/fps /ping /kofeed /menu /cmds", cy); CmdNotify("/help2 for values", yl)
    elseif cmd == "/help2" then CmdNotify("=== Values ===", wt); CmdNotify("/flyspeed /stealthspeed", cy); CmdNotify("/speedamt /jumpamt /fov /ogfov /neonfov", cy); CmdNotify("/smooth /ogsmooth /spinspeed /triggerdelay", cy); CmdNotify("/bone [head|torso|root] /method [1-3]", cy); CmdNotify("Ex: /fly on | /unfly | /panic", yl)
    end
end
LocalPlayer.Chatted:Connect(function(msg) HandleCommand(msg) end)
local CmdWrap = WrapInFrame("Chat Commands", 52)
local CmdToggle = Instance.new("TextButton")
CmdToggle.Parent = CmdWrap
CmdToggle.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
CmdToggle.BorderSizePixel = 0
CmdToggle.Position = UDim2.new(0, 10, 0, 0)
CmdToggle.Size = UDim2.new(1, -20, 0, 30)
CmdToggle.FontFace = AmaticBold
CmdToggle.Text = "Chat Commands: false"
CmdToggle.TextColor3 = Color3.fromRGB(0, 220, 255)
CmdToggle.TextSize = 24
Instance.new("UICorner", CmdToggle).CornerRadius = UDim.new(0, 8)
CmdToggle.MouseButton1Click:Connect(function()
    Config.ChatCommands = not Config.ChatCommands
    CmdToggle.Text = "Chat Commands: " .. tostring(Config.ChatCommands)
    CmdToggle.BackgroundColor3 = Config.ChatCommands and Color3.fromRGB(50, 50, 50) or Color3.fromRGB(20, 20, 20)
end)
local CmdDesc = Instance.new("TextLabel")
CmdDesc.Parent = CmdWrap
CmdDesc.BackgroundTransparency = 1
CmdDesc.Position = UDim2.new(0, 14, 0, 32)
CmdDesc.Size = UDim2.new(1, -28, 0, 18)
CmdDesc.FontFace = AmaticFont
CmdDesc.Text = "Type /help in chat — /panic kills everything"
CmdDesc.TextColor3 = Color3.fromRGB(0, 180, 210)
CmdDesc.TextSize = 20
CmdDesc.TextXAlignment = Enum.TextXAlignment.Left
warn("[Sentry] Loaded")
end)
if not addonOk then warn("[Sentry] Error: " .. tostring(addonErr)) end
