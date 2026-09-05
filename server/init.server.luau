local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Octree = require(ReplicatedStorage.Shared.Octree)

local myoct = Octree.new(Vector3.new(0, 50, 0), 100)

local function getRandomVector3(n)
    return Vector3.new(math.random(-n,n), math.random(-n,n), math.random(-n,n))
end

local allParts = {} :: {[string]:Part}
local function insertRandom(key)
    local pos = getRandomVector3(30) + Vector3.new(20, 50, 20)

    myoct:insert(key, pos)

    local p = Instance.new("Part", workspace)
    p.Position = pos
    p.Anchored = true
    p.Size = Vector3.one
    p.CanCollide = false
    p.CastShadow = false
    p.Color = Color3.new(0, 1, 0)

    allParts[key] = p
end

for i=1 ,1000 do
    insertRandom("sa"..i)
end


local player = Players.PlayerAdded:Wait()
local char = player.Character or player.CharacterAdded:Wait()
RunService.Heartbeat:Connect(function(deltaTime)
    for i,v in allParts do
        v.BrickColor = BrickColor.Green()
    end

    local tab = {}
    myoct:GetInRadius(char.PrimaryPart.Position, 20, tab)

    for i,v in tab do
        allParts[v].BrickColor = BrickColor.Red()
    end
end)