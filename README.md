# Luau Octree
strictly typed octree implementation for luau

## Simple Usage

```luau
--getting the module
local Octree = require(path.to.Octree)

--creating our octree
local myOctree = Octree.new(Vector3.zero, 100)

--our turret models
local turrets = workspace:WaitForChild("Turrets")

--adding turrets to the Octree
for _,turret in turrets:GetChildren() do
    myOctree:insert(turret, turret.PrimaryPart.Position)
end

--player references
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")


RunService.RenderStepped:Connect(function(dt)
    local hrpPos = hrp.Position

    --getting turrets in range
    local turretsInRange = {} -- our external table
    myOctree:GetInRadius(hrpPos, 15, turretsInRange)

    --making turrets look at player
    for _,turret in turretsInRange do
        turret:PivotTo(CFrame.lookAt(turret:GetPivot().Position, hrpPos))
    end
end)

--turrets will constantly look at player and you can have thousands of turrets without any fps drop
```