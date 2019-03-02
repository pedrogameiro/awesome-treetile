
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
    assert(node.data and type(node.data) == "table")
    node.parent = self
    self.left = node
    return self.left
end

-- Set right node
function bintree:set_right(node)
    assert(node.data and type(node.data) == "table")
    node.parent = self
    self.right = node
    return self.right
end

-- Remove node
function bintree:remove(fn)
    if fn then fn(self) end

    if self.parent then
        if self.parent.left == self then
            self.parent.left = nil
        else
            self.parent.right = nil
        end
    end

    self.data   = nil
    self.parent = nil
    self.left   = nil
    self.right  = nil
end

function bintree:swap_children()
    self.left, self.right = self.right, self.left
end

-- Get node if predicate returns true
function bintree:find_if(predicate)
    if predicate(self) then return self end
    return self.left and self.left:find_if(predicate)
            or self.right and self.right:find_if(predicate)
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

-- Apply to each node (in-order tree traversal)
function bintree:apply(fn)
    if self.left then self.left:apply(fn) end
    fn(self)
    if self.right then self.right:apply(fn) end
end

-- Apply to each node, with levels (in-order tree traversal)
function bintree:apply_levels(fn, level)
    if not level then level = 0 end
    if self.left then self.left:apply_levels(fn, level + 1) end
    fn(self, level)
    if self.right then self.right:apply_levels(fn, level + 1) end
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
