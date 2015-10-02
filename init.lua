--[[
    Treesome: Binary Tree-based tiling layout for Awesome 3

    Github: https://github.com/RobSis/treesome
    License: GNU General Public License v2.0
--]]

local awful     = require("awful")
local beautiful = require("beautiful")
--local client = require("awful.client")
local Bintree   = require("treesome/bintree")
local os        = os
local math      = math
local ipairs    = ipairs
local pairs     = pairs
local table     = table
local tonumber  = tonumber
local tostring  = tostring
local type      = type
local capi =
{
    client = client,
    mouse = mouse
}

local treesome = {
    focusFirst = true,
    name       = "treesome",
    forceSplit = nil,
    trees = {}
}
    

-- Layout icon
beautiful.layout_treesome = os.getenv("HOME") .. "/.config/awesome/treesome/layout_icon.png"

-- Globals
--local trees = {}


-- get an unique identifier of a window
local function hash(client)
    return client.window
end

local function table_find(tbl, item)
    for key, value in pairs(tbl) do
        if value == item then return key end
    end
    return false
end

local function table_diff(table1, table2)
    local diffList = {}
    for i,v in ipairs(table1) do
        if table2[i] ~= v then
            table.insert(diffList, v)
        end
    end
    if #diffList == 0 then
        diffList = nil
    end
    return diffList
end

-- get ancestors of node with given data
function Bintree:trace(data, path, dir)
    if path then
        table.insert(path, {split=self.data, direction=dir})
    end

    if data == self.data then
        return path
    end

    if type(self.left) == "table" then
        if (self.left:trace(data, path, "left")) then
            return true
        end
    end

    if type(self.right) == "table" then
        if (self.right:trace(data, path, "right")) then
            return true
        end
    end

    if path then
        table.remove(path)
    end
end

-- remove all leaves with data that don't appear in given table
function Bintree:filterClients(node, clients)
    if node then
        if node.data and not table_find(clients, node.data) and
            node.data ~= "horizontal" and node.data ~= "vertical" then
            self:removeLeaf(node.data)
        end

        local output = nil
        if node.left then
            self:filterClients(node.left, clients)
        end

        if node.right then
            self:filterClients(node.right, clients)
        end
    end
end

local function setslave(client)
    if not treesome.trees[tostring(awful.tag.selected(capi.mouse.screen))] then
        awful.client.setslave(client)
    end
end

local function setmaster(client)
    if not treesome.trees[tostring(awful.tag.selected(capi.mouse.screen))] then
        awful.client.setmaster(client)
    end
end

function treesome.horizontal()
    treesome.forceSplit = "horizontal"
    debuginfo('Next split is'..treesome.forceSplit)
end

function treesome.vertical()
    treesome.forceSplit = "vertical"
    debuginfo('Next split is'..treesome.forceSplit)
end

local function do_treesome(p)
    local area = p.workarea
    local n = #p.clients

    local tag = tostring(awful.tag.selected(capi.mouse.screen))
    if not treesome.trees[tag] then
        treesome.trees[tag] = {
            t = nil,
            lastFocus = nil,
            clients = nil,
            n = 0
        }
    end

    if treesome.trees[tag] ~= nil then
        focus = capi.client.focus

        if focus ~= nil then
            if awful.client.floating.get(focus) then
                focus = nil
            else
                treesome.trees[tag].lastFocus = focus
            end
        end
    end

    -- rearange only on change
    local changed = 0
    local layoutSwitch = false

    if treesome.trees[tag].n ~= n then
        if math.abs(n - treesome.trees[tag].n) > 1 then
            layoutSwitch = true
        end
        if not treesome.trees[tag].n or n > treesome.trees[tag].n then
            changed = 1
        else
            changed = -1
        end
        treesome.trees[tag].n = n
    else
        if treesome.trees[tag].clients then
            local diff = table_diff(p.clients, treesome.trees[tag].clients)
            if diff and #diff == 2 then
                treesome.trees[tag].t:swapLeaves(hash(diff[1]), hash(diff[2]))
            end
        end
    end
    treesome.trees[tag].clients = p.clients

    -- some client removed. remove (from) tree
    if changed < 0 then
        if n > 0 then
            local tokens = {}
            for i, c in ipairs(p.clients) do
                tokens[i] = hash(c)
            end

            treesome.trees[tag].t:filterClients(treesome.trees[tag].t, tokens)
        else
            treesome.trees[tag] = nil
        end
    end

    -- some client added. put it in the tree as a sibling of focus
    local prevClient = nil
    local nextSplit = 0
    if changed > 0 then
        for i, c in ipairs(p.clients) do
            if not treesome.trees[tag].t or not treesome.trees[tag].t:find(hash(c)) then
                if focus == nil then
                    focus = treesome.trees[tag].lastFocus
                end

                local focusNode = nil
                local focusGeometry = nil
                local focusId = nil
                if treesome.trees[tag].t and focus and hash(c) ~= hash(focus) and not layoutSwitch then
                    -- split focused window
                    focusNode = treesome.trees[tag].t:find(hash(focus))
                    focusGeometry = focus:geometry()
                    focusId = hash(focus)
                else
                    -- the layout was switched with more clients to order at once
                    if prevClient then
                        focusNode = treesome.trees[tag].t:find(hash(prevClient))
                        nextSplit = (nextSplit + 1) % 2
                        focusId = hash(prevClient)
                        focusGeometry = prevClient:geometry()

                    else
                        if not treesome.trees[tag].t then
                            -- create as root
                            treesome.trees[tag].t = Bintree.new(hash(c))
                            focusId = hash(c)
                            focusGeometry = {
                                width = 0,
                                height = 0
                            }
                        end
                    end
                end

                if focusNode then
                    if focusGeometry == nil then
                        local splits = {"horizontal", "vertical"}
                        focusNode.data = splits[nextSplit + 1]
                    else
                        if (treesome.forceSplit ~= nil) then

                            focusNode.data = treesome.forceSplit
                        else
                            if (focusGeometry.width <= focusGeometry.height) then
                                focusNode.data = "vertical"
                            else
                                focusNode.data = "horizontal"
                            end
                        end
                    end

                    if treesome.focusFirst then
                        focusNode:addLeft(Bintree.new(focusId))
                        focusNode:addRight(Bintree.new(hash(c)))
                    else
                        focusNode:addLeft(Bintree.new(hash(c)))
                        focusNode:addRight(Bintree.new(focusId))
                    end
                end
            end
            prevClient = c
        end
        treesome.forceSplit = nil
    end

    -- Useless gap.
    local useless_gap = tonumber(beautiful.useless_gap_width)
    if useless_gap == nil then
        useless_gap = 0
    end

    -- draw it
    if n >= 1 then
        for i, c in ipairs(p.clients) do
            local geometry = {
                width = area.width - ( useless_gap * 2.0 ),
                height = area.height - ( useless_gap * 2.0 ),
                x = area.x + useless_gap,
                y = area.y + useless_gap
            }

            local clientNode = treesome.trees[tag].t:find(hash(c))
            local path = {}

            treesome.trees[tag].t:trace(hash(c), path)
            for i, v in ipairs(path) do
                if i < #path then
                    split = v.split
                    -- is the client left of right from this node
                    direction = path[i + 1].direction

                    if split == "horizontal" then
                        geometry.width = ( geometry.width - useless_gap ) / 2.0

                        if direction == "right" then
                            geometry.x = geometry.x + geometry.width + useless_gap
                        end
                    elseif split == "vertical" then
                        geometry.height = ( geometry.height - useless_gap ) / 2.0

                        if direction == "right" then
                            geometry.y = geometry.y + geometry.height + useless_gap
                        end
                    end
                end
            end

            local sibling = treesome.trees[tag].t:getSibling(hash(c))

            --c:geometry(geometry)
            p.geometries[c] = geometry
        end
    end
end

--local function fmax(p, fs)
    ---- Fullscreen?
    --local area
    --if fs then
        --area = p.geometry
    --else
        --area = p.workarea
    --end

    --for k, c in pairs(p.clients) do
        --local g = {
            --x = area.x,
            --y = area.y,
            --width = area.width,
            --height = area.height
        --}
        --p.geometries[c] = g
    --end
--end

function treesome.arrange(p)

    return do_treesome(p)
end

treesome.name = "treesome"


--local function debuginfo( message )
    --if type(message) == "table" then
        --for k,v in pairs(message) do 
            --naughty.notify({ text = "key: "..k.." value: "..tostring(message), timeout = 10 })
        --end
    --else 
        --nid = naughty.notify({ text = message, timeout = 10 })
    --end
--end

return treesome
