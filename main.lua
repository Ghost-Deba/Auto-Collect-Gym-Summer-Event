-- Dex Collector with Working Server Teleport
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local DexCollector = {
    Running = false,
    Collected = 0,
    LastCollectionTime = 0,
    CollectionInterval = 120, -- 2 minutes
    CurrentGiftId = 1,
    MaxGiftId = 9,
    CurrentServerId = nil,
    RejoinAttempts = 0,
    MaxRejoinAttempts = 3
}

-- Function to safely get server list
function DexCollector:GetServerList()
    local success, result = pcall(function()
        return TeleportService:GetGameInstances(game.PlaceId)
    end)
    return success and result or {}
end

-- Improved server teleport function
function DexCollector:TeleportToGoodServer()
    local servers = self:GetServerList()
    
    -- Try to find the same server first
    if self.CurrentServerId then
        for _, server in ipairs(servers) do
            if tostring(server.id) == tostring(self.CurrentServerId) and #server.playing > 0 then
                print("Rejoining previous server...")
                return server.id
            end
        end
    end
    
    -- Find any server with players
    for _, server in ipairs(servers) do
        if #server.playing > 0 then
            print("Found server with players:", server.id)
            return server.id
        end
    end
    
    -- If no servers found, try default teleport
    warn("No servers with players found. Using default teleport...")
    return nil
end

-- New improved teleport function
function DexCollector:SafeTeleport(serverId)
    if not serverId then
        -- Normal teleport if no server ID
        TeleportService:Teleport(game.PlaceId)
        return
    end

    local success, errorMsg = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId)
    end)
    
    if not success then
        warn("Teleport failed:", errorMsg)
        -- Fallback to normal teleport
        TeleportService:Teleport(game.PlaceId)
    end
end

function DexCollector:StartCollection()
    self.Running = true
    self.Collected = 0
    
    while self.Running and task.wait(1) do
        -- Collect using remote
        self:CollectWithRemote()
        
        -- Collect physical items
        self:CollectPhysicalItems()
    end
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
                print("Collected all gifts! Preparing to rejoin...")
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

function DexCollector:CollectPhysicalItems()
    for _, part in ipairs(workspace:GetDescendants()) do
        if part.Name == "Collectable" and part:IsA("BasePart") then
            local character = Players.LocalPlayer.Character
            if character then
                local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
                if humanoidRootPart then
                    firetouchinterest(humanoidRootPart, part, 0)
                    firetouchinterest(humanoidRootPart, part, 1)
                    print("Collected physical Collectable")
                end
            end
        end
    end
end

function DexCollector:RejoinServer()
    if self.RejoinAttempts >= self.MaxRejoinAttempts then
        warn("Max rejoin attempts reached")
        return
    end
    
    self.RejoinAttempts = self.RejoinAttempts + 1
    
    local serverId = self:TeleportToGoodServer()
    if serverId then
        print("Attempting to rejoin server... (Attempt "..self.RejoinAttempts.."/"..self.MaxRejoinAttempts..")")
        self.CurrentServerId = serverId
        self:Stop()
        wait(5)
        self:Start()
    else
        warn("Failed to find server. Trying again in 30 seconds...")
        wait(30)
        self:RejoinServer()
    end
end

function DexCollector:Start()
    if self.Running then return end
    
    print("Starting collector...")
    
    -- First try to find a good server
    local serverId = self:TeleportToGoodServer()
    if serverId then
        self.CurrentServerId = serverId
        print("Found server. Teleporting...")
        self:Stop()
        wait(2)
        self:StartCollection()
    else
        warn("No servers found. Starting collection in current server.")
        self:StartCollection()
    end
end

function DexCollector:Stop()
    self.Running = false
    print("Collector stopped. Total collected:", self.Collected)
end

-- Start the collector
DexCollector:Start()
