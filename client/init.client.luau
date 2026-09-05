local objectSize = Vector3.new(.5,.5,.5)
local inactiveColor = BrickColor.Green()
local activeColor = BrickColor.Red()
local playerRadius = 10

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
    p.Size = objectSize
    p.CanCollide = false
    p.CastShadow = false
    p.BrickColor = inactiveColor
    p.Name = key

    allParts[key] = p
end

local indicatorPart = Instance.new("Part", workspace)
indicatorPart.Size = Vector3.new(2,2,2)
indicatorPart.Anchored = true
indicatorPart.CanCollide = false
indicatorPart.CastShadow = false

for i=1 ,20000 do
    insertRandom("sa"..i)
end

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local primary = char:WaitForChild("HumanoidRootPart")

local t = {}
local previous = {}
RunService.Heartbeat:Connect(function(deltaTime)
    for i,v in previous do
        v.BrickColor = inactiveColor
    end
    table.clear(previous)

    myoct:GetInRadius(primary.Position, playerRadius, t)
    
    for i,v in t do
        previous[v] = allParts[v]
        allParts[v].BrickColor = activeColor
    end
    table.clear(t)
end)