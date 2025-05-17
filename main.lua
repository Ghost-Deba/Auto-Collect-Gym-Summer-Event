-- Dex Collector with Mobile ON/OFF Button
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local DexCollector = {
    Running = false,
    Collected = 0,
    LastCollectionTime = 0,
    CollectionInterval = 120, -- 2 minutes
    CurrentGiftId = 1,
    MaxGiftId = 9,
    CurrentServerId = nil,
    UI = nil
}

-- Create the ON/OFF button
function DexCollector:CreateButton()
    if self.UI then self.UI:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "DexCollectorUI"
    ScreenGui.Parent = CoreGui
    ScreenGui.ResetOnSpawn = false
    
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Name = "ToggleButton"
    ToggleButton.Size = UDim2.new(0, 120, 0, 50)
    ToggleButton.Position = UDim2.new(0.5, -60, 0, 20)
    ToggleButton.AnchorPoint = Vector2.new(0.5, 0)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.Text = "START"
    ToggleButton.Font = Enum.Font.SourceSansBold
    ToggleButton.TextSize = 18
    ToggleButton.Parent = ScreenGui
    
    -- Make button draggable
    local dragging
    local dragInput
    local dragStart
    local startPos
    
    local function update(input)
        local delta = input.Position - dragStart
        ToggleButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    
    ToggleButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = ToggleButton.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    ToggleButton.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
    
    -- Toggle functionality
    ToggleButton.MouseButton1Click:Connect(function()
        if self.Running then
            self:Stop()
            ToggleButton.Text = "START"
            ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        else
            self:Start()
            ToggleButton.Text = "STOP"
            ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        end
    end)
    
    -- Touch support for mobile
    ToggleButton.TouchTap:Connect(function()
        if self.Running then
            self:Stop()
            ToggleButton.Text = "START"
            ToggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        else
            self:Start()
            ToggleButton.Text = "STOP"
            ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        end
    end)
    
    self.UI = ScreenGui
end

function DexCollector:FindGoodServer()
    local gameId = game.PlaceId
    local servers = TeleportService:GetGameInstances(gameId)
    
    for _, server in ipairs(servers) do
        if #server.playing > 0 then
            return server.id
        end
    end
    
    return nil
end

function DexCollector:CollectWithRemote()
    local now = os.time()
    
    if now - self.LastCollectionTime >= self.CollectionInterval then
        local args = { self.CurrentGiftId }
        
        local success, err = pcall(function()
            ReplicatedStorage:WaitForChild("common"):WaitForChild("packages"):WaitForChild("_Index"):WaitForChild("sleitnick_knit@1.5.1"):WaitForChild("knit"):WaitForChild("Services"):WaitForChild("LimitedTimeEventService"):WaitForChild("RE"):WaitForChild("GetGift"):FireServer(unpack(args))
        end)
        
        if success then
            print("Collected gift ID:", self.CurrentGiftId)
            self.Collected = self.Collected + 1
            self.LastCollectionTime = now
            
            if self.CurrentGiftId == self.MaxGiftId then
                print("Collected all gifts! Preparing to rejoin server...")
                self:RejoinServer()
            end
            
            self.CurrentGiftId = (self.CurrentGiftId % self.MaxGiftId) + 1
        else
            warn("Failed to collect gift:", err)
        end
    else
        local remainingTime = self.CollectionInterval - (now - self.LastCollectionTime)
        print("Waiting", remainingTime, "seconds before next collection")
    end
end

function DexCollector:RejoinServer()
    local serverInfo = game:GetService("TeleportService"):GetPlayerPlaceInstanceAsync(game.PlaceId, game.JobId)
    if serverInfo then
        print("Rejoining server...")
        wait(5)
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverInfo.id)
    else
        warn("Couldn't get server info. Finding new server...")
        self:FindAndJoinServer()
    end
end

function DexCollector:FindAndJoinServer()
    local serverId = self:FindGoodServer()
    if serverId then
        print("Found server with players. Teleporting...")
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId)
    else
        warn("No servers with players found. Trying again in 30 seconds...")
        wait(30)
        self:FindAndJoinServer()
    end
end

function DexCollector:Start()
    if self.Running then return end
    
    self.Running = true
    self.Collected = 0
    
    print("Looking for a server with players...")
    local goodServerId = self:FindGoodServer()
    
    if goodServerId then
        print("Found server with players. Teleporting...")
        self.CurrentServerId = goodServerId
        TeleportService:TeleportToPlaceInstance(game.PlaceId, goodServerId)
    else
        warn("No servers with players found. Continuing in current server.")
    end
    
    while self.Running and wait(1) do
        self:CollectWithRemote()
        
        for _, part in ipairs(workspace:GetDescendants()) do
            if part.Name == "Collectable" and part:IsA("BasePart") then
                local humanoidRootPart = Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if humanoidRootPart then
                    firetouchinterest(humanoidRootPart, part, 0)
                    firetouchinterest(humanoidRootPart, part, 1)
                    print("Collected physical Collectable")
                end
            end
        end
    end
end

function DexCollector:Stop()
    self.Running = false
    print("Collector stopped. Total collected:", self.Collected)
end

-- Initialize the button
DexCollector:CreateButton()

-- For mobile touch support
if UserInputService.TouchEnabled then
    DexCollector.UI.ToggleButton.Size = UDim2.new(0, 150, 0, 60)
    DexCollector.UI.ToggleButton.TextSize = 22
end
