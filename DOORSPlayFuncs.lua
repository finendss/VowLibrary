local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local RemotesFolder = nil
local CurrentSpeed = 16
local CurrentClimbSpeed = 16
local CurrentFlightSpeed = 15

local function FindRemotes()
    if not RemotesFolder then
        RemotesFolder = ReplicatedStorage:FindFirstChild("EntityInfo") or 
                       ReplicatedStorage:FindFirstChild("Bricks") or 
                       ReplicatedStorage:FindFirstChild("RemotesFolder")
    end
    return RemotesFolder
end

local function SetMovementSpeed(speed)
    CurrentSpeed = speed
    if LocalPlayer.Character and not LocalPlayer.Character:GetAttribute("Climbing") then
        LocalPlayer.Character.Humanoid.WalkSpeed = speed
    end
end

local function SetClimbingSpeed(speed)
    CurrentClimbSpeed = speed
    if LocalPlayer.Character and LocalPlayer.Character:GetAttribute("Climbing") then
        LocalPlayer.Character.Humanoid.WalkSpeed = speed
    end
end

local function ResetMovementSpeed()
    CurrentSpeed = 16
    CurrentClimbSpeed = 16
    if LocalPlayer.Character then
        LocalPlayer.Character.Humanoid.WalkSpeed = 16
    end
end

local InfiniteJumpEnabled = false
local jumpCooldown = false

local function ToggleInfiniteJump(enabled)
    InfiniteJumpEnabled = enabled
end

if UserInputService.KeyboardEnabled then
    UserInputService.JumpRequest:Connect(function()
        if InfiniteJumpEnabled and not jumpCooldown and LocalPlayer.Character then
            jumpCooldown = true
            LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping, true)
            task.wait(0.1)
            jumpCooldown = false
        end
    end)
end

local OldAccel = nil

local function ToggleNoAcc(enabled)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    if enabled then
        OldAccel = LocalPlayer.Character.HumanoidRootPart.CustomPhysicalProperties
        LocalPlayer.Character.HumanoidRootPart.CustomPhysicalProperties = PhysicalProperties.new(100, 0.1, 0.1, 0.1, 0.1)
    else
        if OldAccel then
            LocalPlayer.Character.HumanoidRootPart.CustomPhysicalProperties = OldAccel
            OldAccel = nil
        end
    end
end

local NoClipEnabled = false

local function ToggleNoClip(enabled)
    NoClipEnabled = enabled
    if not enabled and LocalPlayer.Character then
        for _, v in pairs(LocalPlayer.Character:GetChildren()) do
            if v:IsA("BasePart") and v.Name ~= "CollisionClone" then
                v.CanCollide = true
            end
        end
        if LocalPlayer.Character:FindFirstChild("Collision") then
            LocalPlayer.Character.Collision.CanCollide = true
            if LocalPlayer.Character.Collision:FindFirstChild("CollisionCrouch") then
                LocalPlayer.Character.Collision.CollisionCrouch.CanCollide = true
            end
        end
    end
end

local function HandleNoClip()
    if NoClipEnabled and LocalPlayer.Character then
        for _, v in ipairs(LocalPlayer.Character:GetChildren()) do
            if v:IsA("BasePart") and v.Name ~= "CollisionClone" and v.CanCollide then
                v.CanCollide = false
            end
        end
        if LocalPlayer.Character:FindFirstChild("Collision") then
            LocalPlayer.Character.Collision.CanCollide = false
            if LocalPlayer.Character.Collision:FindFirstChild("CollisionCrouch") then
                LocalPlayer.Character.Collision.CollisionCrouch.CanCollide = false
            end
        end
    end
end

local FlightEnabled = false
local function ToggleFlight(enabled)
    FlightEnabled = enabled
    if not enabled then
        if LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart:FindFirstChild("FlightVelocity") then
            LocalPlayer.Character.HumanoidRootPart:FindFirstChild("FlightVelocity"):Destroy()
        end
    end
end

local function SetFlightSpeed(speed)
    CurrentFlightSpeed = speed
end

local function HandleFlight()
    if FlightEnabled and LocalPlayer.Character then
        if not LocalPlayer.Character.HumanoidRootPart:FindFirstChild("FlightVelocity") then
            local Velocity = Instance.new("BodyVelocity", LocalPlayer.Character.HumanoidRootPart)
            Velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            Velocity.Velocity = Vector3.zero
            Velocity.Name = "FlightVelocity"
            Velocity.P = math.huge
        end
        local moveDir = LocalPlayer.Character.Humanoid.MoveDirection
        local flatLook = Camera.CFrame.LookVector * Vector3.new(1, 0, 1)
        if flatLook.Magnitude < 0.001 then
            flatLook = Camera.CFrame.UpVector * Vector3.new(1, 0, 1) * math.sign(-Camera.CFrame.LookVector.Y)
        end
        local flatCam = CFrame.lookAt(Vector3.zero, flatLook)
        local localInput = flatCam:VectorToObjectSpace(moveDir)
        LocalPlayer.Character.HumanoidRootPart:FindFirstChild("FlightVelocity").Velocity = Camera.CFrame:VectorToWorldSpace(localInput) * CurrentFlightSpeed
    end
end

local GodmodeEnabled = false

local function ToggleGodmode(enabled)
    GodmodeEnabled = enabled
    if not FindRemotes() then return end
    if enabled then
        if RemotesFolder.Name ~= "RemotesFolder" then
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Collision") then
                LocalPlayer.Character.Collision.Position -= Vector3.new(0, 4, 0)
            end
        end
        if RemotesFolder.Name == "RemotesFolder" then
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("CollisionPart") then
                LocalPlayer.Character:PivotTo(LocalPlayer.Character.CollisionPart.CFrame * CFrame.new(0, -2, 0))
            end
        end
    else
        if RemotesFolder.Name == "RemotesFolder" and LocalPlayer.Character then
            LocalPlayer.Character.Humanoid.HipHeight = 2.4
            LocalPlayer.Character.Collision.Size = Vector3.new(5.5, 3, 3)
            LocalPlayer.Character.LowerTorso.Root.C1 = CFrame.new(Vector3.new(0, 0, 0))
            LocalPlayer.Character.Collision.CollisionCrouch.Size = Vector3.new(5.5, 3, 3)
            if LocalPlayer.Character:FindFirstChild("CollisionPart") then
                LocalPlayer.Character:PivotTo(LocalPlayer.Character.CollisionPart.CFrame * CFrame.new(0, 2, 0))
            end
        end
        if RemotesFolder.Name ~= "RemotesFolder" then
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Collision") then
                LocalPlayer.Character.Collision.Position = LocalPlayer.Character.HumanoidRootPart.Position
            end
        end
    end
end

local function HandleGodmode()
    if GodmodeEnabled and FindRemotes() then
        if RemotesFolder.Name == "RemotesFolder" and LocalPlayer.Character then
            if LocalPlayer.Character.LowerTorso.Root.C1 ~= CFrame.new(0, -2.3, 0) then
                LocalPlayer.Character.LowerTorso.Root.C1 = CFrame.new(0, -2.3, 0)
            end
            if LocalPlayer.Character.Humanoid.HipHeight ~= 0.22 then
                LocalPlayer.Character.Humanoid.HipHeight = 0.22
            end
            if LocalPlayer.Character.Collision.Size ~= Vector3.new(1, 1, 4) then
                LocalPlayer.Character.Collision.Size = Vector3.new(1, 1, 4)
            end
            if LocalPlayer.Character.Collision.CollisionCrouch.Size ~= Vector3.new(1, 1, 4) then
                LocalPlayer.Character.Collision.CollisionCrouch.Size = Vector3.new(1, 1, 4)
            end
        end
    end
end

local SpeedBypassEnabled = false
local SpeedBypassMethod = 1
local CollisionClone = nil

local function CreateCollisionClone()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("CollisionPart") then
        CollisionClone = LocalPlayer.Character.CollisionPart:Clone()
        CollisionClone.Parent = LocalPlayer.Character
        CollisionClone.Name = "CollisionClone"
        CollisionClone.RootPriority = 127
        CollisionClone.Anchored = false
        CollisionClone.CanCollide = false
        if CollisionClone:FindFirstChild("CollisionCrouch") then
            CollisionClone:FindFirstChild("CollisionCrouch"):Destroy()
        end
    end
end

local function ToggleSpeedBypass(enabled)
    SpeedBypassEnabled = enabled
end

local function SetSpeedBypassMethod(method)
    SpeedBypassMethod = method
end

local Params = RaycastParams.new()
Params.FilterType = Enum.RaycastFilterType.Exclude
local Direction = Vector3.new(0, -100, 0)

local function HandleSpeedBypass()
    if not FindRemotes() then return end
    if SpeedBypassMethod == 1 then
        if SpeedBypassEnabled then
            if CollisionClone then
                CollisionClone.Massless = true
            end
            if RemotesFolder:FindFirstChild("Crouch") then
                RemotesFolder.Crouch:FireServer(true, true)
            end
        end
    elseif SpeedBypassMethod == 2 then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if LocalPlayer:GetAttribute("Alive") and hrp and CollisionClone and CollisionClone.Parent then
            Params.FilterDescendantsInstances = {char, CollisionClone}
            if not workspace:Raycast(hrp.Position, Direction, Params) or not SpeedBypassEnabled then
                CollisionClone.Massless = true
            else
                local cp = char:FindFirstChild("CollisionPart")
                if cp and (cp.Anchored or Passed) then
                    CollisionClone.Massless = true
                    repeat task.wait() until not cp.Anchored or not cp.Parent
                    if CollisionClone and CollisionClone.Parent then
                        CollisionClone.Massless = true
                        task.wait(0.5)
                        if CollisionClone and CollisionClone.Parent then
                            CollisionClone.Massless = false
                        end
                    end
                else
                    if LocalPlayer:GetAttribute("Alive") then CollisionClone.Massless = true end
                    task.wait(0.209)
                    if LocalPlayer:GetAttribute("Alive") and CollisionClone and CollisionClone.Parent then
                        CollisionClone.Massless = false
                    end
                end
            end
        end
    end
end

local AntiCheatManiEnabled = false
local AntiCheatManiMethod = 1

local function ToggleAntiCheatMani(enabled)
    AntiCheatManiEnabled = enabled
    if not enabled then
        if LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart:FindFirstChild("VelocityMani") then
            LocalPlayer.Character.HumanoidRootPart:FindFirstChild("VelocityMani"):Destroy()
        end
        if NoClipEnabled then
            ToggleNoClip(false)
        end
    end
end

local function SetAntiCheatManiMethod(method)
    AntiCheatManiMethod = method
end

local function HandleAntiCheatMani()
    if AntiCheatManiEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        if AntiCheatManiMethod == 1 then
            if not NoClipEnabled then
                ToggleNoClip(true)
            end
            local BodyVelocity = LocalPlayer.Character.HumanoidRootPart:FindFirstChild("VelocityMani") or Instance.new("BodyVelocity", LocalPlayer.Character.HumanoidRootPart)
            local LookingVector = LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector * 2
            BodyVelocity.Velocity = Vector3.new(LookingVector.X, LookingVector.Y, LookingVector.Z)
            BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            BodyVelocity.Name = "VelocityMani"
        else
            local currentPivot = LocalPlayer.Character:GetPivot()
            LocalPlayer.Character:PivotTo(currentPivot * CFrame.new(0, 0, 10000))
        end
    end
end

local LadderBypassEnabled = false

local function ToggleLadderBypass(enabled)
    LadderBypassEnabled = enabled
    if not enabled then
        if FindRemotes() and RemotesFolder:FindFirstChild("ClimbLadder") then
            RemotesFolder.ClimbLadder:FireServer()
        end
    end
end

local function ToggleEnableJump(enabled)
    if LocalPlayer.Character then
        LocalPlayer.Character:SetAttribute("CanJump", enabled)
    end
end

local function ToggleEnableSlide(enabled)
    if LocalPlayer.Character then
        LocalPlayer.Character:SetAttribute("Sliding", enabled)
    end
end

local FastClosetExitEnabled = false

local function ToggleFastClosetExit(enabled)
    FastClosetExitEnabled = enabled
end

local function HandleFastClosetExit()
    if FastClosetExitEnabled then
        if LocalPlayer.Character:GetAttribute("Hiding") and LocalPlayer.Character.Humanoid.MoveDirection.Magnitude > 0.45 then
            if FindRemotes() and RemotesFolder:FindFirstChild("CamLock") then
                RemotesFolder.CamLock:FireServer()
            end
        end
    end
end

local FakeReviveEnabled = false

local function ToggleFakeRevive(enabled)
    FakeReviveEnabled = enabled
end

local function HandleFakeRevive()
    if FakeReviveEnabled then
        local Char = LocalPlayer.Character
        if Char and Char.Humanoid.Health == 0 then
            Char.Humanoid.Health = 100
            Char.HumanoidRootPart.Anchored = true
            Camera.CameraType = "Custom"
            LocalPlayer:SetAttribute("Alive", true)
            if not Char:GetAttribute("FakeRevived") then
                Char:SetAttribute("FakeRevived", true)
            end
        end
        if Char and Char:GetAttribute("FakeRevived") then
            Char.Humanoid.BreakJointsOnDeath = false
            Char.Humanoid.RequiresNeck = false
            Char.Humanoid.PlatformStand = false
            if Char.Humanoid.Health <= 0 then
                Char.Humanoid.Health = 0.1
            end
            Char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
            Char.Humanoid.Sit = false
            if Char:FindFirstChild("HumanoidRootPart") then
                Char.HumanoidRootPart.Anchored = false
            end
            if Char:FindFirstChild("CollisionPart") and Char.CollisionPart.Anchored ~= false then
                Char.CollisionPart.Anchored = false
            end
            if LocalPlayer.PlayerGui and LocalPlayer.PlayerGui.MainUI and 
               LocalPlayer.PlayerGui.MainUI.Initiator and 
               LocalPlayer.PlayerGui.MainUI.Initiator:FindFirstChild("Death") then
                LocalPlayer.PlayerGui.MainUI.Initiator.Death:Destroy()
            end
            game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)
            Char.Humanoid.AutomaticScalingEnabled = true
            Char:SetAttribute("Stunned", false)
        end
    end
end

local function ProcessPlayerFunctions()
    if not LocalPlayer:GetAttribute("Alive") then
        if CollisionClone then
            CollisionClone = nil
        end
        return
    end
    
    if LocalPlayer.Character then
        if not LocalPlayer.Character:GetAttribute("Climbing") then
            if LocalPlayer.Character.Humanoid.WalkSpeed ~= CurrentSpeed then
                LocalPlayer.Character.Humanoid.WalkSpeed = CurrentSpeed
            end
        else
            if LocalPlayer.Character.Humanoid.WalkSpeed ~= CurrentClimbSpeed then
                LocalPlayer.Character.Humanoid.WalkSpeed = CurrentClimbSpeed
            end
        end
    end
    
    HandleFlight()
    HandleNoClip()
    HandleGodmode()
    HandleSpeedBypass()
    HandleAntiCheatMani()
    HandleFakeRevive()
    HandleFastClosetExit()
    
    if LadderBypassEnabled and LocalPlayer.Character and LocalPlayer.Character:GetAttribute("Climbing") then
        LocalPlayer.Character:SetAttribute("Climbing", false)
    end
end

local PlayerFuncs = {
    SetMovementSpeed = SetMovementSpeed,
    SetClimbingSpeed = SetClimbingSpeed,
    ResetMovementSpeed = ResetMovementSpeed,
    ToggleInfiniteJump = ToggleInfiniteJump,
    ToggleNoAcc = ToggleNoAcc,
    ToggleNoClip = ToggleNoClip,
    ToggleFlight = ToggleFlight,
    SetFlightSpeed = SetFlightSpeed,
    ToggleGodmode = ToggleGodmode,
    ToggleSpeedBypass = ToggleSpeedBypass,
    SetSpeedBypassMethod = SetSpeedBypassMethod,
    ToggleAntiCheatMani = ToggleAntiCheatMani,
    SetAntiCheatManiMethod = SetAntiCheatManiMethod,
    ToggleLadderBypass = ToggleLadderBypass,
    ToggleEnableJump = ToggleEnableJump,
    ToggleEnableSlide = ToggleEnableSlide,
    ToggleFastClosetExit = ToggleFastClosetExit,
    ToggleFakeRevive = ToggleFakeRevive,
    Process = ProcessPlayerFunctions,
    CreateCollisionClone = CreateCollisionClone,
}

return PlayerFuncs
