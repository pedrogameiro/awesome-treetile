
--[[

     Licensed under GNU General Public License v2
      * (c) 2019, Alphonse Mariyagnanaseelan



    Class representing a binary tree.

--]]

local table        = table
local tostring     = tostring

local bintree = {}
bintree.__index = bintree

function bintree.new(data, left, right)
    return setmetatable({
        data = data,
        left = left,
        right = right,
    }, bintree)
end

-- New left node (forwards to constructor)
function bintree:set_new_left(...)
    self.left = bintree.new(...)
    return self.left
end

-- New right node (forwards to constructor)
function bintree:set_new_right(...)
    self.right = bintree.new(...)
    return self.right
end

-- Set left node
function bintree:set_left(node)
    self.left = node
    return self.left
end

-- Set right node
function bintree:set_right(node)
    self.right = node
    return self.right
end

local function get_predicate(data)
    return function(node)
        return node.data == data
    end
end

-- Get node if predicate returns true
function bintree:find_if(predicate)
    if predicate(self) then return self end
    return self.left and self.left:find_if(predicate)
        or self.right and self.right:find_if(predicate)
end

-- Get node for matching data
function bintree:find(data)
    return self:find_if(get_predicate(data))
end

-- Remove leaf node if predicate returns true
-- (Removes a node, parent is replaced by sibling.)
function bintree:remove_if(predicate)
    if self.left and predicate(self.left) then
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

-- Remove leaf node for matching data
function bintree:remove(data)
    return self:remove_if(get_predicate(data))
end

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

-- Get sibling of node for matching data
function bintree:get_sibling(data)
    return self:get_sibling_if(get_predicate(data))
end

-- Get parent of node where predicate returns true
function bintree:get_parent_if(predicate)
    if predicate(self) then return nil end

    if self.left then
        if predicate(self.left) then return self end
        local output = self.left:get_parent_if(predicate)
        if output then return output end
    end

    if self.right then
        if predicate(self.right) then return self end
        local output = self.right:get_parent_if(predicate)
        if output then return output end
    end
end

-- Get parent of node for matching data
function bintree:get_parent(data)
    return self:get_parent_if(get_predicate(data))
end

-- Swap two nodes where predicate returns true
function bintree:swap_leaves_if(predicate1, predicate2)
    local leaf1 = self:find_if(predicate1)
    local leaf2 = self:find_if(predicate2)

    if not (leaf1 and leaf2) then return end
    leaf1.data, leaf2.data = leaf2.data, leaf1.data
end

-- Swap two nodes for matching data
function bintree:swap_leaves(data1, data2)
    local leaf1 = self:find(data1)
    local leaf2 = self:find(data2)

    if not (leaf1 and leaf2) then return end
    leaf1.data, leaf2.data = leaf2.data, leaf1.data
end

-- Print tree
function bintree:show(level)
    if not level then level = 0 end
    if not self then return end

    print(table.concat {
        string.rep(" ", level), "Node[", tostring(self.data), "]",
    })

    bintree.show(self.left, level + 1)
    bintree.show(self.right, level + 1)
end

return bintree
