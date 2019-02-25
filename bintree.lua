
--[[

     Licensed under GNU General Public License v2
      * (c) 2019, Alphonse Mariyagnanaseelan



    Class representing a binary tree.

--]]

local table        = table
local tostring     = tostring
local type         = type

local bintree = {}
bintree.__index = bintree

function bintree.new(data, left, right)
    return setmetatable({
        data = data,
        left = left,
        right = right,
    }, bintree)
end

function bintree:set_new_left(...)
    self.left = bintree.new(...)
    return self.left
end

function bintree:set_new_right(...)
    self.right = bintree.new(...)
    return self.right
end

function bintree:set_left(node)
    self.left = node
    return self.left
end

function bintree:set_right(node)
    self.right = node
    return self.right
end

function bintree:find(data)
    if data == self.data then return self end

    return self.left and self.left:find(data)
        or self.right and self.right:find(data)
end

-- remove leaf and replace parent by sibling
function bintree:remove_leaf(data)
    if data == self.data then
        self.data = nil
        self.left = nil
        self.right = nil
        return true
    end

    if self.left then
        if self.left.data == data then
            local new_self = {
                data = self.right.data,
                left = self.right.left,
                right = self.right.right
            }
            self.data = new_self.data
            self.left = new_self.left
            self.right = new_self.right
            return true
        else
            local output = self.left:remove_leaf(data)
            if output then return output end
        end
    end

    if self.right then
        if self.right.data == data then
            local new_self = {
                data = self.left.data,
                left = self.left.left,
                right = self.left.right
            }
            self.data = new_self.data
            self.left = new_self.left
            self.right = new_self.right
            return true
        else
            local output = self.right:remove_leaf(data)
            if output then return output end
        end
    end
end

function bintree:get_sibling(data)
    if data == self.data then return nil end

    if self.left then
        if self.left.data == data then
            return self.right
        end

        local output = self.left:get_sibling(data)
        if output then return output end
    end

    if self.right then
        if self.right.data == data then
            return self.left
        end

        local output = self.right:get_sibling(data)
        if output then return output end
    end
end

function bintree:get_parent(data)
    if self.left then
        if self.left.data == data then
            return self
        end

        local output = self.left:get_parent(data)
        if output then return output end
    end

    if self.right then
        if self.right.data == data then
            return self
        end

        local output = self.right:get_parent(data)
        if output then return output end
    end
end

function bintree:swap_leaves(data1, data2)
    local leaf1 = self:find(data1)
    local leaf2 = self:find(data2)

    if not (leaf1 and leaf2) then return end
    leaf1.data, leaf2.data = leaf2.data, leaf1.data
end

function bintree.show(node, level)
    if not level then level = 0 end
    if not node then return end

    print(table.concat {
        string.rep(" ", level), "Node[", tostring(node.data), "]",
    })

    bintree.show(node.left, level + 1)
    bintree.show(node.right, level + 1)
end

function bintree.show2(node, level, child)
    if not level then level = 0 end
    if not child then child = '' end
    if not node then return end

    if type(node.data) == "number" then
        print(table.concat {
            string.rep(" ", level),
            child, "Node[",
            node.data, "]",
        })
    else
        print(table.concat {
            string.rep(" ", level),
            child, "Node[",
            "x:", tostring(node.data.x), " ",
            "y:", tostring(node.data.y), " ",
            "w:", tostring(node.data.width), " ",
            "h:", tostring(node.data.height), "]",
        })
    end

    bintree.show2(node.left, level + 1, "L_")
    bintree.show2(node.right, level + 1, "R_")
end

return bintree
