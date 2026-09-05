--!strict

local function assertVector3(vec3:Vector3, name:string)
    assert(typeof(vec3) == "Vector3",name.." agrument must be a valid Vector3 instance")
end
local function assertNumber(n:number, name:string)
    assert(typeof(n)=="number", name.." argument must be a valid number")
end


local config = require(script.config)
local DEFAULT_CAPACITY = config.Module.DEFAULT_CAPACITY
local EPSILON = config.Module.EPSILON

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

--[=[
    returns true if given position is in
    bounds of the box with given center and size
]=]
local function isInBounds(center:Vector3, pos:Vector3, nSize:number) : boolean
    local distX = pos.X - center.X
	local distY = pos.Y - center.Y
	local distZ = pos.Z - center.Z
	local halfSize = (nSize/2) + EPSILON

	return not(
    math.abs(distX) > halfSize
	or math.abs(distY) > halfSize
	or math.abs(distZ) > halfSize
    )
end

--[=[
    returns the direction which
    given position is in
]=]
local function getDirection(center:Vector3, pos:Vector3) : number
	return directionMap
	[(pos.X - center.X) >= 0 and 1 or -1]
	[(pos.Y - center.Y) >= 0 and 1 or -1]
	[(pos.Z - center.Z) >= 0 and 1 or -1]
end

--[=[
    creates a visualizer block
    at given position with given size
]=]
local function debugVis(pos, size)
	local p = Instance.new("Part", workspace)
	p.Anchored = true
	p.Position = pos
	p.Size = size
	p.CanCollide = false
	p.CastShadow = false
	p.CanQuery = false
    p.AudioCanCollide = false
    p.CanTouch = false
	p.Transparency = 0.9
    p.BrickColor = BrickColor.random()
    if config.Debug.DEBUG_ON then
        return p
    end
    return nil
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
    nodeMap:{[any]:OctreeInstance},
    parent:OctreeInstance,
    dir:number,
    descendantCount:number,

    bodyDiagonal:number,

    debugVisual:Part
},Octree))

--[=[
    creates a new octree
]=]
function Octree.new(pos:Vector3, size:number, parent:OctreeInstance?, dir:number?) : OctreeInstance
    assertVector3(pos, "pos")
    assertNumber(size, "size")

	local self = setmetatable({}, Octree)
	self.Pos = pos
	self.Size = Vector3.new(size,size,size)
	self.nSize = size
    self.capacity = DEFAULT_CAPACITY
    self.objectCount = 0
    self.objects = {}
    self.descendantCount = 0
	self.children = {}
	self.parent = parent
    self.dir = dir

    if not parent then
        self.nodeMap = {}
    else
        self.nodeMap = parent.nodeMap
    end

    --pre computation
    self.bodyDiagonal = (Vector3.new(size, size, size)).Magnitude/2
	
	self.debugVisual = debugVis(self.Pos, self.Size)
	
	return self
end

--[=[
    divides self into 8 smaller octrees
]=]
function Octree.divide(self:OctreeInstance)
	for i=1, 8 do
		local xdir = directions[i][1]
		local ydir = directions[i][2]
		local zdir = directions[i][3]
		local child = Octree.new(self.Pos + Vector3.new(xdir*self.nSize/4, ydir*self.nSize/4, zdir*self.nSize/4), self.nSize/2, self, i)
		self.children[i] = child
	end
end

--[=[
    FOR TESTING PURPOSES ONLY
]=]
function Octree._query(self:OctreeInstance, pos:Vector3, accumulatedDivisions:number)
    assertVector3(pos, "pos")
    assertNumber(accumulatedDivisions, "accumulatedDivisions")

	if not isInBounds(self.Pos, pos, self.nSize) then return end
	
	if #self.children == 0 then
		self:divide()
	end
	
	local dir = getDirection(self.Pos, pos)
	
	accumulatedDivisions += 1
	if accumulatedDivisions >= 4 then return end
	
	self.children[dir]:query(pos, accumulatedDivisions)
end

--[=[
    inserts an object to the octree
]=]
function Octree.insert<T>(self:OctreeInstance, object:T, pos:Vector3) : boolean
    assertVector3(pos, "pos")

    if not isInBounds(self.Pos, pos, self.nSize) then return false end

    self.descendantCount += 1
    if #self.children > 0 then
        local dir = getDirection(self.Pos, pos)
        self.children[dir]:insert(object, pos)
        return true
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
        self.nodeMap[object] = self
    end

    return true
end

--[=[
    returns a table containing all
    objects that stands in the
    given sphere
]=]
function Octree.GetInRadius(self:OctreeInstance, pos:Vector3, radius:number, targetTable:{any}) : {any}
    assertVector3(pos, "pos")
    assertNumber(radius, "radius")

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

--[=[
    returns a table containing all
    objects that stands in the given region (box)
]=]
function Octree.GetInRegion(self:OctreeInstance, pos:Vector3, size:Vector3, targetTable:{any}) : {any}
    assertNumber(typeof(targetTable)=="table","target table must be a table")
    assertVector3(size, "size")
    assertVector3(pos, "pos")

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


--[=[
    returns the nearest object
    to the given position
]=]
function Octree.GetNearest(self:OctreeInstance, pos:Vector3, bestObj:any, bestDist:number) : (any, number)
    assertVector3(pos, "pos")

    bestDist = bestDist or math.huge

    if (self.Pos-pos).Magnitude > bestDist + self.bodyDiagonal then
        return bestObj, bestDist
    end

    if #self.children > 0 then
        local bestDir = getDirection(self.Pos, pos)
        for i=0, 7 do
            local currentDir = ((i + bestDir-1)%8 )+ 1

            bestObj, bestDist = self.children[currentDir]:GetNearest(pos, bestObj, bestDist)
        end
    else
        for obj, objpos in self.objects do
            local dist = (pos-objpos).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestObj = obj
            end
        end
    end
    return bestObj, bestDist
end


--[=[
    removes an object;
    if all childrens of an octree
    becomes empty after this process,
    empty octrees get removed
]=]
function Octree.Remove<A>(self:OctreeInstance, object:A)
    local node = self.nodeMap[object]
    if node then
        node.objects[object] = nil
        node.objectCount -= 1
        node.descendantCount -= 1
        self.nodeMap[object] = nil

        local current = node.parent
        while current do
            current.descendantCount -= 1
            
            if current.descendantCount == 0 and node.parent.objectCount == 0 and #current.children > 0 then
                current:DestroyChildren()
            end

            current = current.parent
        end
    end
end

--[=[
    updates position of the given
    object, calls Remove
]=]
function Octree.Update<A>(self:OctreeInstance, object:A, newPos:Vector3)
    assertVector3(newPos, "newPos")
    self:Remove(object)
    local success = self:insert(object, newPos)
    if not success then
        warn("position of the object located at ("..tostring(newPos)..") couldnt updated, its out of bounds")
    end
end

--[=[
    returns descendant count
]=]
function Octree.GetDescendantCount(self:OctreeInstance)
    return self.descendantCount
end

--[=[
    returns object count
]=]
function Octree.GetObjectCount(self:OctreeInstance)
    return self.objectCount
end

--[=[
    returns true if the given
    object exists in the octree instance
    across all nodes
]=]
function Octree.Contains(self:OctreeInstance, object:any)
    return self.nodeMap[object] ~= nil
end

--[=[
    destroys all childrens of
    an octree
]=]
function Octree.DestroyChildren(self:OctreeInstance)
    if #self.children > 0 then
        for i,child in self.children do
            child:Destroy()
        end
        table.clear(self.children)
    end
end


--[=[
    destroys an octree,
    also destroys visualizer parts
    if exist
]=]
function Octree.Destroy(self:OctreeInstance)
    self:DestroyChildren()

    if self.parent == nil then
        table.clear(self.nodeMap)
    end
    if self.debugVisual then
        self.debugVisual:Destroy()
    end
    table.clear(self.objects)
    table.clear(self)
    setmetatable(self, nil)
end

return Octree