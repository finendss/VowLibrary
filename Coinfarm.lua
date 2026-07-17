local MainScript = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/finendss/VowLibrary/refs/heads/main/AnimalHospitalCoinFarm-obfuscated.lua"))()
]]

game:GetService("Players").LocalPlayer.Idled:Connect(function()
    game:GetService("VirtualUser"):Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    wait(0.1)
    game:GetService("VirtualUser"):Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end)

local function AutoReconnect()
    while true do
        if game:IsLoaded() then
            loadstring(MainScript)()
            
            if queue_on_teleport then
                queue_on_teleport(MainScript)
            end
            
            local player = game.Players.LocalPlayer
            if player then
                player:WaitForChild("CharacterRemoving")
            end
            wait(1)
        else
            wait(1)
        end
    end
end

spawn(AutoReconnect)

loadstring(MainScript)()
if queue_on_teleport then
    queue_on_teleport(MainScript)
end
