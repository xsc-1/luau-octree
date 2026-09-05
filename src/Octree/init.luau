--!strict
local DEFAULT_CAPACITY = 4

local directions = {
	[1] = {-1, 1, 1},
	[2] = {1, 1, 1},
	[3] = {1, -1, 1},
	[4] = {-1, -1, 1},
	[5] = {-1, 1, -1},
	[6] = {1, 1, -1},
	[7] = {1, -1, -1},
	[8] = {-1, -1, -1},
}

local directionMap = {
	[1] = {
		[1] = {
			[1] = 2,
			[-1] = 6
		},
		[-1] = {
			[1] = 3,
			[-1] = 7
		}
	},
	[-1] = {
		[1] = {
			[1] = 1,
			[-1] = 5
		},
		[-1] = {
			[1] = 4,
			[-1] = 8
		}
	},
}
local function isClose(m:Vector3, n:Vector3, epsilon) : boolean
    return (m - n).Magnitude < epsilon
end

local function isInBounds(center:Vector3, pos:Vector3, nSize:number) : boolean
    local distX = pos.X - center.X
	local distY = pos.Y - center.Y
	local distZ = pos.Z - center.Z
	
	return not(
    math.abs(distX) > nSize/2
	or math.abs(distY) > nSize/2
	or math.abs(distZ) > nSize/2
    )
end

local function sign(n:number) : number
	if n >= 0 then return 1 else return -1 end
end

local function getDirection(center:Vector3, pos:Vector3) : number
	return directionMap
	[(pos.X - center.X) >= 0 and 1 or -1]
	[(pos.Y - center.Y) >= 0 and 1 or -1]
	[(pos.Z - center.Z) >= 0 and 1 or -1]
end

local function debugVis(pos, size)
	local p = Instance.new("Part", workspace)
	p.Anchored = true
	p.Position = pos
	p.Size = size
	p.CanCollide = false
	p.CastShadow = false
	p.CanQuery = false
	p.Transparency = 0.9
	--p.Color = Color3.new(1, 0, 0)
    p.BrickColor = BrickColor.random()
end



local Octree = {}
Octree.__index = Octree

export type OctreeInstance = typeof(setmetatable({}::{
	Pos:Vector3,
	Size:Vector3,
	nSize:number,
    capacity:number,
    objects:{[any]:Vector3},
    objectCount:number,
	children:{[number]:OctreeInstance},
    parent:OctreeInstance,

    bodyDiagonal:number
},Octree))

function Octree.new(pos:Vector3, size:number, parent:OctreeInstance) : OctreeInstance
	local self = setmetatable({}, Octree)
	self.Pos = pos
	self.Size = Vector3.new(size,size,size)
	self.nSize = size
    self.capacity = DEFAULT_CAPACITY
    self.objectCount = 0
    self.objects = {}
	self.children = {}
	self.parent = parent

    --pre computation
    self.bodyDiagonal = (Vector3.new(size, size, size)).Magnitude/2
	
	debugVis(self.Pos, self.Size)
	
	return self
end

function Octree.divide(self:OctreeInstance)
	for i=1, 8 do
		local xdir = directions[i][1]
		local ydir = directions[i][2]
		local zdir = directions[i][3]
		local child = Octree.new(self.Pos + Vector3.new(xdir*self.nSize/4, ydir*self.nSize/4, zdir*self.nSize/4), self.nSize/2, self)
		self.children[i] = child
	end
end

function Octree._query(self:OctreeInstance, pos:Vector3, accumulatedDivisions:number)
	if not isInBounds(self.Pos, pos, self.nSize) then return end
	
	if #self.children == 0 then
		self:divide()
	end
	
	local dir = getDirection(self.Pos, pos)
	
	accumulatedDivisions += 1
	if accumulatedDivisions >= 4 then return end
	
	self.children[dir]:query(pos, accumulatedDivisions)
end

function Octree.insert(self:OctreeInstance, object:any, pos:Vector3)
    if not isInBounds(self.Pos, pos, self.nSize) then return end

    if #self.children > 0 then
        local dir = getDirection(self.Pos, pos)
        self.children[dir]:insert(object, pos)
        return
    end

    if self.objectCount == self.capacity then
        self:divide()
        for earlierObject, objPos in self.objects do
            local dir = getDirection(self.Pos, objPos)
            self.children[dir]:insert(earlierObject, objPos)
        end
        table.clear(self.objects)
        self.objectCount = 0
        local dir = getDirection(self.Pos, pos)
        self.children[dir]:insert(object, pos)
    else
        self.objects[object] = pos
        self.objectCount += 1
    end
end

function Octree.GetInRadius(self:OctreeInstance, pos:Vector3, radius:number, targetTable:{any}) : {any}
    local dist = (self.Pos - pos).Magnitude
    if dist > self.bodyDiagonal + radius then return end

    if #self.children > 0 then
        for _, child in self.children do
            child:GetInRadius(pos, radius, targetTable)
        end
    else
        for obj,p in self.objects do
            if (p - pos).Magnitude > radius then continue end
            table.insert(targetTable, obj)
        end
    end
end

function Octree.GetInRegion(self:OctreeInstance, pos:Vector3, size:Vector3, targetTable:{any})
    local distX = math.abs(self.Pos.X - pos.X)
    local distY = math.abs(self.Pos.Y - pos.Y)
    local distZ = math.abs(self.Pos.Z - pos.Z)

    if distX > (self.Size.X + size.X)/2
    or distY > (self.Size.Y + size.Y)/2
    or distZ > (self.Size.Z + size.Z)/2
    then return end

    if #self.children > 0 then
        for _,child in self.children do
            child:GetInRegion(pos, size, targetTable)
        end
    else
        for obj, p in self.objects do
            if math.abs(p.X - pos.X) < size.X/2
            and math.abs(p.Y - pos.Y) < size.Y/2
            and math.abs(p.Z - pos.Z) < size.Z/2 then continue end
            table.insert(targetTable, obj)
        end
    end

    return targetTable
end

return Octree