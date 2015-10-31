--[[
    Treesome: Binary Tree-based tiling layout for Awesome 3

    Github: https://github.com/RobSis/treesome
    License: GNU General Public License v2.0

    Because the the split of space is depending on the parent node, 
    Therefore it is import to the the parent node right,
    the properities of client, focus, or fuction, awful.client.setlave, 
    will affect the splitting. Please make sure all these things work together.
--]]

local awful        = require("awful")
local beautiful    = require("beautiful")
local Bintree      = require("treesome/bintree")
local os           = os
local math         = math
local ipairs       = ipairs
local pairs        = pairs
local table        = table
local tonumber     = tonumber
local tostring     = tostring
local type         = type
local capi         = {
    client         = client,
    mouse          = mouse,
    screen         = screen,
    mousegrabber   = mousegrabber
}

local treesome     = {
    focusFirst     = false,
    name           = "treesome",
    direction      = "left"
}

    

local forceSplit = nil
local trees = {}

treesome.resize_jump_to_corner = true

-- Layout icon
beautiful.layout_treesome = os.getenv("HOME") .. "/.config/awesome/treesome/layout_icon.png"

-- Globals
--local trees = {}


-- get an unique identifier of a window
local function hash(client)
    if client then
        --return client.window
        return client
    else
        return nil
    end
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
    if not trees[tostring(awful.tag.selected(capi.mouse.screen))] then
        awful.client.setslave(client)
    end
end

local function setmaster(client)
    if not trees[tostring(awful.tag.selected(capi.mouse.screen))] then
        awful.client.setmaster(client)
    end
end

function treesome.horizontal()
    forceSplit = "horizontal"
    debuginfo('Next split is left right (|) split')
end

function treesome.vertical()
    forceSplit = "vertical"
    debuginfo('Next split is upper bottom (-)split')
end

local function do_treesome(p)
    local old_clients = nil
    local area = p.workarea
    local n = #p.clients

    local tag = tostring(awful.tag.selected(capi.mouse.screen))
    if not trees[tag] then
        trees[tag] = {
            t = nil,
            lastFocus = nil,
            clients = nil,
            geo = nil,
            n = 0
        }
    end

    if trees[tag] ~= nil then
        focus = capi.client.focus

        if focus ~= nil then
            if awful.client.floating.get(focus) then
                focus = nil
            else
                trees[tag].lastFocus = focus
            end
        end
    end

    -- rearange only on change
    local changed = 0
    local layoutSwitch = false
    local update = false

    if trees[tag].n ~= n then
        if math.abs(n - trees[tag].n) > 1 then
            layoutSwitch = true
        end
        if not trees[tag].n or n > trees[tag].n then
            changed = 1
        else
            changed = -1
        end
        trees[tag].n = n
    else
        if trees[tag].clients then
            local diff = table_diff(p.clients, trees[tag].clients)
            if diff and #diff == 2 then
                trees[tag].t:swapLeaves(hash(diff[1]), hash(diff[2]))
                trees[tag].geo[diff[1]], trees[tag].geo[diff[2]] = trees[tag].geo[diff[2]], trees[tag].geo[diff[1]] 
                update=true
            end
        end
    end

    trees[tag].clients = p.clients

    -- some client removed. remove (from) tree
    if changed < 0 then
        if n > 0 then
            local tokens = {}
            for i, c in ipairs(p.clients) do
                tokens[i] = hash(c)
            end

            for c, geo in pairs(trees[tag].geo) do
                if awful.util.table.hasitem(p.clients, c) == nil then
                    local sibling = trees[tag].t:getSibling(hash(c))
                    if sibling ~= nil then 
                        for _, sib_client in pairs(sibling) do 
                            sib_geo = trees[tag].geo[sib_client]

                            local new_geo = {}
                            if math.abs(geo.x - sib_geo.x) < 1  then 
                                new_geo.x = sib_geo.x
                                new_geo.y = math.min(geo.y, sib_geo.y)
                                new_geo.height = sib_geo.height + geo.height
                                new_geo.width = sib_geo.width
                            end

                            if math.abs(geo.y - sib_geo.y) < 1  then 
                                new_geo.y = sib_geo.y
                                new_geo.x = math.min(geo.x, sib_geo.x)
                                new_geo.width = sib_geo.width + geo.width
                                new_geo.height = sib_geo.height
                            end

                            trees[tag].geo[sib_client] = new_geo
                        end
                        local pos = awful.util.table.hasitem(trees[tag].geo, c)
                        table.remove(trees[tag].geo, pos)
                    end
                end
            end
            --local sibling = trees[tag].t:getSibling(hash(c))
            trees[tag].t:filterClients(trees[tag].t, tokens)
        else
            trees[tag] = nil
        end
    end


    -- some client added. put it in the tree as a sibling of focus
    local prevClient = nil
    local nextSplit = 0
    if changed > 0 then
        for i, c in ipairs(p.clients) do
            if not trees[tag].t or not trees[tag].t:find(hash(c)) then
                if focus == nil then
                    focus = trees[tag].lastFocus
                end

                local focusNode = nil
                local focusGeometry = nil
                local focusId = nil
                local focusCl = nil

                if trees[tag].t and focus and hash(c) ~= hash(focus)  and not layoutSwitch then
                    -- split focused window
                    --debuginfo('is switch')
                    focusNode = trees[tag].t:find(hash(focus))
                    focusGeometry = focus:geometry()
                    focusId = hash(focus)
                    focusCl = focus
                else
                    -- the layout was switched with more clients to order at once
                    if prevClient then
                        focusNode = trees[tag].t:find(hash(prevClient))
                        nextSplit = (nextSplit + 1) % 2
                        focusId = hash(prevClient)
                        focusCl = prevClient
                        --focusGeometry = prevClient:geometry()

                    else
                        if not trees[tag].t then
                            -- create as root
                            trees[tag].t = Bintree.new(hash(c))
                            focusId = hash(c)
                            focusCl = c
                            focusGeometry = {
                                width = 0,
                                height = 0
                            }
                            trees[tag].geo = {}
                            trees[tag].geo[c] = area
                        end
                    end
                end

                if focusNode then
                    if focusGeometry == nil then
                        local splits = {"horizontal", "vertical"}
                        focusNode.data = splits[nextSplit + 1]
                    else
                        if (forceSplit ~= nil) then

                            focusNode.data = forceSplit
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

                    -- Useless gap.
                    local useless_gap = tonumber(beautiful.useless_gap_width)
                    if useless_gap == nil then
                        useless_gap = 0
                    end

                    local avail_geo 

                    if focusGeometry then 
                        if focusGeometry.height == 0 and focusGeometry.width == 0 then
                            avail_geo = area
                        else
                            avail_geo = focusGeometry
                        end
                    else
                        avail_geo = area
                    end

                    local new_c = {}
                    local old_focus_c = {}

                    if focusNode.data == "horizontal" then
                        new_c.width = math.floor((avail_geo.width - useless_gap) / 2.0 )
                        new_c.height =avail_geo.height
                        old_focus_c.width = math.floor((avail_geo.width - useless_gap) / 2.0 )
                        old_focus_c.height =avail_geo.height
                        old_focus_c.y = avail_geo.y
                        new_c.y = avail_geo.y


                        if direction == treesome.direction then
                            new_c.x = avail_geo.x + new_c.width
                            old_focus_c.x = avail_geo.x
                        else
                            new_c.x = avail_geo.x
                            old_focus_c.x = avail_geo.x + new_c.width
                        end


                    elseif focusNode.data == "vertical" then
                        new_c.height = math.floor((avail_geo.height - useless_gap) / 2.0 )
                        new_c.width = avail_geo.width
                        old_focus_c.height = math.floor((avail_geo.height - useless_gap) / 2.0 )
                        old_focus_c.width = avail_geo.width
                        old_focus_c.x = avail_geo.x
                        new_c.x = avail_geo.x

                        if direction == treesome.direction then
                            new_c.y = avail_geo.y + new_c.height
                            old_focus_c.y = avail_geo.y
                        else
                            new_c.y = avail_geo.y 
                            old_focus_c.y =avail_geo.x + new_c.height
                        end

                    end

                    -- put geometry of clients into tables
                    if focusId then
                        trees[tag].geo[focusCl] = old_focus_c
                        trees[tag].geo[c] = new_c
                    end


                end
            end
            prevClient = c
        end
        forceSplit = nil
    end


    -- draw it
    if changed ~= 0 or layoutSwitch or update then
        if n >= 1 then
            for i, c in ipairs(p.clients) do

                local clientNode = trees[tag].t:find(hash(c))
                local path = {}
                local geo = nil

                geo = trees[tag].geo[c]
                --debuginfo(tostring(trees[tag].geo.x).." "..
                --p.geometries[c] = geo
                --local sibling = trees[tag].t:getSibling(hash(c))

                c:geometry(geo)
            end
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


local function mouse_resize_handler(c, corner, x, y, orientation)
    local orientation = orientation or "tile"
    local wa = capi.screen[c.screen].workarea
    local mwfact = awful.tag.getmwfact()
    local cursor
    local g = c:geometry()
    local offset = 0
    local corner_coords
    local coordinates_delta = {x=0,y=0}

    if orientation == "tile" then
        cursor = "cross"
        if g.height+15 > wa.height then
            offset = g.height * .5
            cursor = "sb_h_double_arrow"
        elseif not (g.y+g.height+15 > wa.y+wa.height) then
            offset = g.height
        end
        corner_coords = { x = wa.x + wa.width * mwfact, y = g.y + offset }
    elseif orientation == "left" then
        cursor = "cross"
        if g.height+15 >= wa.height then
            offset = g.height * .5
            cursor = "sb_h_double_arrow"
        elseif not (g.y+g.height+15 > wa.y+wa.height) then
            offset = g.height
        end
        corner_coords = { x = wa.x + wa.width * (1 - mwfact), y = g.y + offset }
    elseif orientation == "bottom" then
        cursor = "cross"
        if g.width+15 >= wa.width then
            offset = g.width * .5
            cursor = "sb_v_double_arrow"
        elseif not (g.x+g.width+15 > wa.x+wa.width) then
            offset = g.width
        end
        corner_coords = { y = wa.y + wa.height * mwfact, x = g.x + offset}
    else
        cursor = "cross"
        if g.width+15 >= wa.width then
            offset = g.width * .5
            cursor = "sb_v_double_arrow"
        elseif not (g.x+g.width+15 > wa.x+wa.width) then
            offset = g.width
        end
        corner_coords = { y = wa.y + wa.height * (1 - mwfact), x= g.x + offset }
    end
    if treesome.resize_jump_to_corner then
        capi.mouse.coords(corner_coords)
    else
        local mouse_coords = capi.mouse.coords()
        coordinates_delta = {
          x = corner_coords.x - mouse_coords.x,
          y = corner_coords.y - mouse_coords.y,
        }
    end

    local prev_coords = {}
    capi.mousegrabber.run(function (_mouse)
                              _mouse.x = _mouse.x + coordinates_delta.x
                              _mouse.y = _mouse.y + coordinates_delta.y
                              for k, v in ipairs(_mouse.buttons) do
                                  if v then
                                      prev_coords = { x =_mouse.x, y = _mouse.y }
                                      local fact_x = (_mouse.x - wa.x) / wa.width
                                      local fact_y = (_mouse.y - wa.y) / wa.height
                                      local mwfact

                                      local g = c:geometry()


                                      -- we have to make sure we're not on the last visible client where we have to use different settings.
                                      local wfact
                                      local wfact_x, wfact_y
                                      if (g.y+g.height+15) > (wa.y+wa.height) then
                                          wfact_y = (g.y + g.height - _mouse.y) / wa.height
                                      else
                                          wfact_y = (_mouse.y - g.y) / wa.height
                                      end

                                      if (g.x+g.width+15) > (wa.x+wa.width) then
                                          wfact_x = (g.x + g.width - _mouse.x) / wa.width
                                      else
                                          wfact_x = (_mouse.x - g.x) / wa.width
                                      end


                                      if orientation == "tile" then
                                          mwfact = fact_x
                                          wfact = wfact_y
                                      elseif orientation == "left" then
                                          mwfact = 1 - fact_x
                                          wfact = wfact_y
                                      elseif orientation == "bottom" then
                                          mwfact = fact_y
                                          wfact = wfact_x
                                      else
                                          mwfact = 1 - fact_y
                                          wfact = wfact_x
                                      end

                                      awful.tag.setmwfact(math.min(math.max(mwfact, 0.01), 0.99), awful.tag.selected(c.screen))
                                      awful.client.setwfact(math.min(math.max(wfact,0.01), 0.99), c)
                                      return true
                                  end
                              end
                              return prev_coords.x == _mouse.x and prev_coords.y == _mouse.y
                          end, cursor)
end



function treesome.mouse_resize_handler (c, corner, x, y)
    mouse_resize_handler(c, corner,x,y,'tile')
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
