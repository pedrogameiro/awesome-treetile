
--[[

     Licensed under GNU General Public License v2
      * (c) 2019, Alphonse Mariyagnanaseelan



    Class representing a binary tree.

--]]

local table        = table
local tostring     = tostring

local bintree = {}
bintree.__index = bintree

function bintree.new(data, parent, left, right)
    assert(data and type(data) == "table" or data == nil)
    return setmetatable({
        data = data or { },
        parent = parent,
        left = left,
        right = right,
    }, bintree)
end

-- New left node
function bintree:set_new_left(data)
    assert(data and type(data) == "table")
    self.left = bintree.new(data, self)
    return self.left
end

-- New right node
function bintree:set_new_right(data)
    assert(data and type(data) == "table")
    self.right = bintree.new(data, self)
    return self.right
end

-- Set left node
function bintree:set_left(node)
    node.parent = self
    self.left = node
    return self.left
end

-- Set right node
function bintree:set_right(node)
    node.parent = self
    self.right = node
    return self.right
end

-- Remove self
function bintree:remove(fn)
    if fn then fn(self) end
    self.data   = nil
    self.parent = nil
    self.left   = nil
    self.right  = nil
end

-- Remove left node
function bintree:remove_left(fn)
    if fn then fn(self.left) end
    self.left.data   = nil
    self.left.parent = nil
    self.left.left   = nil
    self.left.right  = nil
    self.left = nil
end

-- Remove right node
function bintree:remove_right(fn)
    if fn then fn(self.right) end
    self.right.data   = nil
    self.right.parent = nil
    self.right.left   = nil
    self.right.right  = nil
    self.right = nil
end

local function get_predicate(data)
    return function(node)
        return node.data == data
    end
end

-- Get node if predicate returns true
function bintree:find_if(predicate)
    if type(predicate) == "function" then
        if predicate(self) then return self end
        return self.left and self.left:find_if(predicate)
            or self.right and self.right:find_if(predicate)
    end

    local nodes = { }
    for _, f in pairs(predicate) do
        table.insert(nodes, (self:find_if(f)))
    end
    return nodes
end

-- -- Get node for matching data
-- function bintree:find(data)
--     return self:find_if(get_predicate(data))
-- end

-- Remove leaf node if predicate returns true
-- (Removes a node, parent is replaced by sibling.)
function bintree:remove_if(predicate)
    if self.left and predicate(self.left) then
        self.left.parent = nil
        local new_self = {
            data = self.right.data,
            left = self.right.left,
            right = self.right.right,
        }
        self.data = new_self.data
        self.left = new_self.left
        self.right = new_self.right
        return self
    end

    if self.right and predicate(self.right) then
        self.right.parent = nil
        local new_self = {
            data = self.left.data,
            left = self.left.left,
            right = self.left.right,
        }
        self.data = new_self.data
        self.left = new_self.left
        self.right = new_self.right
        return self
    end

    if self.left then
        local output = self.left:remove_if(predicate)
        if output then return output end
    end

    if self.right then
        local output = self.right:remove_if(predicate)
        if output then return output end
    end
end

-- -- Remove leaf node for matching data
-- function bintree:remove(data)
--     return self:remove_if(get_predicate(data))
-- end

-- Get sibling of node where predicate returns true
function bintree:get_sibling_if(predicate)
    if predicate(self) then return nil end

    if self.left then
        if predicate(self.left) then return self.right end
        local output = self.left:get_sibling_if(predicate)
        if output then return output end
    end

    if self.right then
        if predicate(self.right) then return self.left end
        local output = self.right:get_sibling_if(predicate)
        if output then return output end
    end
end

-- -- Get sibling of node for matching data
-- function bintree:get_sibling(data)
--     return self:get_sibling_if(get_predicate(data))
-- end

-- -- Get parent of node where predicate returns true
-- function bintree:get_parent_if(predicate)
--     if predicate(self) then return nil end
--
--     if self.left then
--         if predicate(self.left) then return self end
--         local output = self.left:get_parent_if(predicate)
--         if output then return output end
--     end
--
--     if self.right then
--         if predicate(self.right) then return self end
--         local output = self.right:get_parent_if(predicate)
--         if output then return output end
--     end
-- end

-- -- Get parent of node for matching data
-- function bintree:get_parent(data)
--     return self:get_parent_if(get_predicate(data))
-- end

-- Swap two nodes where predicate returns true
function bintree:swap_leaves_if(predicate1, predicate2)
    local leaf1 = self:find_if(predicate1)
    local leaf2 = self:find_if(predicate2)

    if not (leaf1 and leaf2) then return end
    leaf1.data, leaf2.data = leaf2.data, leaf1.data
end

-- Swap two nodes for matching data
function bintree:swap_leaves(data1, data2)
    local leaf1 = self:find_if(get_predicate(data1))
    local leaf2 = self:find_if(get_predicate(data2))

    if not (leaf1 and leaf2) then return end
    leaf1.data, leaf2.data = leaf2.data, leaf1.data
end

-- Apply to each node (in-order tree traversal)
function bintree:apply(fn)
    if self.left then self.left:apply(fn) end
    fn(self)
    if self.right then self.right:apply(fn) end
end

-- Apply to each node, with levels (in-order tree traversal)
function bintree:apply_levels(fn, level)
    if not level then level = 0 end
    if self.left then self.left:apply(fn, level + 1) end
    fn(self, level)
    if self.right then self.right:apply(fn, level + 1) end
end

-- Print tree
function bintree:show()
    self:apply_levels(function(node, level)
        print(table.concat {
            string.rep("  ", level), "Node[", tostring(node.data), "]",
        })
    end)
end

return bintree
