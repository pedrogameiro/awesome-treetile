
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
    assert(not self.left)
    self.left = bintree.new(data, self)
    return self.left
end

-- New right node
function bintree:set_new_right(data)
    assert(data and type(data) == "table")
    assert(not self.right)
    self.right = bintree.new(data, self)
    return self.right
end

-- Set left node
function bintree:set_left(node)
    assert(node and node.data and type(node.data) == "table")
    assert(not self.left)
    node.parent = self
    self.left = node
    return self.left
end

-- Set right node
function bintree:set_right(node)
    assert(node and node.data and type(node.data) == "table")
    assert(not self.right)
    node.parent = self
    self.right = node
    return self.right
end

-- Get sibling node
function bintree:get_sibling()
    if not self.parent then return nil end
    if self.parent.left == self then
        return self.parent.right
    elseif self.parent.right == self then
        return self.parent.left
    else
        assert(false)
        return nil
    end
end

-- Get rightmost leaf node
function bintree:get_rightmost()
    return self.right and self.right:get_rightmost() or self
end

-- Get leftmost leaf node
function bintree:get_leftmost()
    return self.left and self.left:get_leftmost() or self
end

-- Remove node (with cleanup function)
function bintree:remove(fn)
    if fn then fn(self.data) end

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
