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
    focusnew       = true,
    focusFirst     = false,
    name           = "treesome",
    direction      = "right"
}

    

local forceSplit = nil
local trees = {}

treesome.resize_jump_to_corner = true

-- Layout icon
beautiful.layout_treesome = os.getenv("HOME") .. "/.config/awesome/treesome/layout_icon.png"

-- Globals
--local trees = {}
--

local function hash(client)
    if client then
        return client.window
        --return client
    else
        return nil
    end
end

function Bintree:update_node_geo(parent_geo, geo_table)

    local left_node_geo = nil
    local right_node_geo = nil
    if type(self.data) == 'number' then 
        -- this node is a client
        -- if the sibling is a client, resize this client
        -- to the size of its parent space to fill the empty space

        if type(parent_geo) == "table" then
            geo_table[self.data] = parent_geo
        else
            debuginfo("udpate_geo errors")
        end

        return
    end

    if type(self.data) == 'table' then
        -- sibling is another table, need to update the all discents. 
        local now_geo = nil
        now_geo = awful.util.table.clone(self.data)
        self.data = awful.util.table.clone(parent_geo)

        --debuginfo('type left '..type(sib_data.left.data))
        --debuginfo('type left '..type(sib_data.right.data))
        --

        --if type(sib_data.left.data) == 'table' then
            ---- update_tables
            --slib_data.left:update_geo_table(parent_geo)
        --end
        if type(self.left.data) == 'number'  then
            left_node_geo = awful.util.table.clone(geo_table[self.left.data])
        end

        if type(self.left.data) == 'table' then
            left_node_geo = awful.util.table.clone(self.left.data)
        end

        if type(self.right.data) == 'number'  then
            right_node_geo = awful.util.table.clone(geo_table[self.right.data])
        end

        if type(self.right.data) == 'table' then
            right_node_geo = awful.util.table.clone(self.right.data)
        end
        

        -- {{{ vertical split 
        if math.abs(left_node_geo.x - right_node_geo.x) < 0.2 then
            -- split in vertical way
            if parent_geo.width > now_geo.width + 0.2 then
                left_node_geo.width = parent_geo.width 
                right_node_geo.width = parent_geo.width 

                local new_x = math.min(left_node_geo.x, parent_geo.x)

                left_node_geo.x = new_x
                right_node_geo.x = new_x
            end

            if parent_geo.height > now_geo.height + 0.2 then

                if treesome.direction == 'left' then 
                    left_node_geo, right_node_geo = right_node_geo, left_node_geo
                end

                local new_y = math.min(left_node_geo.y, parent_geo.y)

                r_l_ratio = left_node_geo.height / now_geo.height

                left_node_geo.height = parent_geo.height * r_l_ratio
                right_node_geo.height = parent_geo.height - left_node_geo.height
                
                left_node_geo.y = new_y
                right_node_geo.y = new_y + left_node_geo.height

            end
        end
        -- }}}

        -- {{{ horizontal split
        if math.abs(left_node_geo.y - right_node_geo.y) < 0.2 then
            --debuginfo("horizontal am in")
            -- split in horizontal way
            if parent_geo.height > now_geo.height + 0.2 then
                left_node_geo.height = parent_geo.height
                right_node_geo.height = parent_geo.height

                local new_y = math.min(parent_geo.y,  left_node_geo.y)

                left_node_geo.y = new_y
                right_node_geo.y = new_y
            end

            if parent_geo.width > now_geo.width + 0.2 then

                if treesome.direction == 'left' then 
                    left_node_geo, right_node_geo = right_node_geo, left_node_geo
                end

                local new_x = math.min(left_node_geo.x, parent_geo.x)

                r_l_ratio = left_node_geo.width / now_geo.width

                left_node_geo.width = parent_geo.width * r_l_ratio
                right_node_geo.width = parent_geo.width - left_node_geo.width
                
                left_node_geo.x = new_x
                right_node_geo.x = new_x + left_node_geo.width

            end

        end
        -- }}}
        

        if type(self.left.data) == 'number' then
            geo_table[self.left.data] = left_node_geo
        end 

        if type(self.right.data) == 'number' then
            geo_table[self.right.data] = right_node_geo
        end 


        if type(self.left.data) == 'table' then
           self.left:update_node_geo(left_node_geo, geo_table)
        end

        if type(self.right.data) == 'table' then
           self.right:update_node_geo(right_node_geo, geo_table)
        end


    end

end

-- get an unique identifier of a window

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
            type(node.data) == 'number' then
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

    local tag = tostring(p.tag or awful.tag.selected(p.screen))
    -- t is tree structure to record the clients
    -- geo is the tree structure to record the geometries of clients
    --
    if not trees[tag] then
        trees[tag] = {
            t = nil,
            lastFocus = nil,
            clients = nil,
            geo_tree = nil,
            geo = nil,
            n = 0
        }
    end

    if trees[tag] ~= nil then
        --focus=awful.client.focus.history.previous()
        --focus = capi.client.focus
        -- get the latest focused client
        if treesome.focusnew then
            focus = awful.client.focus.history.get(p.screen,1)
        else
            focus = capi.client.focus
        end
        
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

            for clid, geo in pairs(trees[tag].geo) do
                if awful.util.table.hasitem(tokens, clid) == nil then
                    -- update the size of clients left, fill the empty space left by the 
                    -- destroyed clients

                    local sib_node = trees[tag].geo_tree:getSibling(clid)
                    local parent = trees[tag].geo_tree:getParent(clid)
                    local parent_geo = nil
                    
                    if parent then
                        parent_geo = parent.data
                    end
                    --print 'test parent---'
                    --Bintree.show2(trees[tag].geo_tree:getParent(clid))

                    --debuginfo('test p geo '..tostring(trees[tag].geo_tree:getParent(ccl
                    --debuginfo('test p '..tostring(trees[tag].t:getParent(hash(ccl))))

                    if sib_node ~= nil then 
                        sib_node:update_node_geo(parent_geo, trees[tag].geo)
                    end
                    --
                    --parent = trees[tag].geo_tree:getParent(hash(c))
                    --if type(parent) == 'table' then 
                        --debuginfo(parent.data)
                    --else
                        --debuginfo("no parent")
                    --end
                    --trees[tag].geo_tree:update_geo(sibling)
                    local pos = awful.util.table.hasitem(trees[tag].geo, clid)
                    table.remove(trees[tag].geo, pos)
                end
            end

            trees[tag].geo_tree:filterClients(trees[tag].geo_tree, tokens)
            trees[tag].t:filterClients(trees[tag].t, tokens)

            --awful.client.jumpto(trees[tag].lastFocus)
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
                local focusNode_geo_tree = nil
                local focusId = nil
                --local focusCl = nil

                if trees[tag].t and focus and hash(c) ~= hash(focus)  and not layoutSwitch then
                    -- split focused window
                    -- find the focused client
                    focusNode = trees[tag].t:find(hash(focus))
                    focusNode_geo_tree = trees[tag].geo_tree:find(hash(focus))
                    focusGeometry = focus:geometry()
                    focusId = hash(focus)
                    --focusCl = focus
                else
                    -- the layout was switched with more clients to order at once
                    if prevClient then
                        focusNode = trees[tag].t:find(hash(prevClient))
                        focusNode_geo_tree = trees[tag].geo_tree:find(hash(prevClient))
                        nextSplit = (nextSplit + 1) % 2
                        focusId = hash(prevClient)
                        --focusCl = prevClient
                        --focusGeometry = prevClient:geometry()

                    else
                        if not trees[tag].t then
                            -- create as root
                            trees[tag].t = Bintree.new(hash(c))
                            focusId = hash(c)
                            --focusCl = c
                            focusGeometry = {
                                width = 0,
                                height = 0
                            }
                            trees[tag].geo_tree = Bintree.new(hash(c))
                            trees[tag].geo = {}
                            trees[tag].geo[hash(c)] = area
                            --focusNode = trees[tag].t
                            --focusNode_geo_tree = trees[tag].geo_tree
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
                        focusNode_geo_tree:addLeft(Bintree.new(focusId))
                        focusNode:addRight(Bintree.new(hash(c)))
                        focusNode_geo_tree:addRight(Bintree.new(hash(c)))
                    else
                        focusNode:addLeft(Bintree.new(hash(c)))
                        focusNode_geo_tree:addLeft(Bintree.new(hash(c)))
                        focusNode:addRight(Bintree.new(focusId))
                        focusNode_geo_tree:addRight(Bintree.new(focusId))
                    end

                    -- Useless gap.
                    local useless_gap = tonumber(beautiful.useless_gap_width)
                    if useless_gap == nil then
                        useless_gap = 0
                    end

                    local avail_geo =nil

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

                    focusNode_geo_tree.data = awful.util.table.clone(avail_geo)
                    --debuginfo('parent node geo '..tostring(focusNode_geo_tree))
                    --debuginfo('parent node '..tostring(focusNode))
                    --Bintree.show2(trees[tag].geo_tree)
                    --print('-----')


                    if focusNode.data == "horizontal" then
                        new_c.width = math.floor((avail_geo.width - useless_gap) / 2.0 )
                        new_c.height =avail_geo.height
                        old_focus_c.width = math.floor((avail_geo.width - useless_gap) / 2.0 )
                        old_focus_c.height =avail_geo.height
                        old_focus_c.y = avail_geo.y
                        new_c.y = avail_geo.y


                        if treesome.direction == "right" then
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

                        if  treesome.direction == "right" then
                            new_c.y = avail_geo.y + new_c.height
                            old_focus_c.y = avail_geo.y
                        else
                            new_c.y = avail_geo.y 
                            old_focus_c.y =avail_geo.y + new_c.height
                        end

                    end
                    -- put the geometry of parament node into table too
                    

                    -- put geometry of clients into tables
                    if focusId then
                        trees[tag].geo[focusId] = old_focus_c
                        trees[tag].geo[hash(c)] = new_c
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

                local geo = nil
                geo = trees[tag].geo[hash(c)]
                if type(geo) == 'table' then 
                    c:geometry(geo)
                else
                    debuginfo("wrong geometry")
                end


                --debuginfo(tostring(trees[tag].geo.x).." "..
                --p.geometries[c] = geo
                --local sibling = trees[tag].t:getSibling(hash(c))

                --c:geometry(geo)
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


local function mouse_resize_handler(c, corner, x, y)
    local orientation = orientation or "tile"
    local wa = capi.screen[c.screen].workarea
    local mwfact = awful.tag.getmwfact()
    local cursor
    local g = c:geometry()
    local offset = 0
    local corner_coords
    local coordinates_delta = {x=0,y=0}
    
    cursor = "cross"
    --if g.height+15 > wa.height then
        --offset = g.height * .5
        --cursor = "sb_h_double_arrow"
    --elseif not (g.y+g.height+15 > wa.y+wa.height) then
        --offset = g.height
    --end
    --debuginfo(tostring(x)..' '..tostring(y))
    debuginfo(tostring(wa.x)..' '..tostring(wa.y))

    local pos_now = capi.mouse.coords()

    if  (pos_now.x - g.x ) > g.width * 0.5 then
        new_y = pos_now.y
        new_x = g.x + g.width
    end

    --if (x - g.x ) < g.width * 0.5 and ( y - g.y) < g.height * 0.5 then
    cursor = "sb_v_double_arrow"
    corner_coords = { x = new_x, y = new_y }   
    --end
    --corner_coords = { x = wa.x + wa.width * mwfact, y = g.y + offset }   
    
    
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


                                      mwfact = fact_x
                                      wfact = wfact_y

                                      --awful.tag.setmwfact(math.min(math.max(mwfact, 0.01), 0.99), awful.tag.selected(c.screen))
                                      --awful.client.setwfact(math.min(math.max(wfact,0.01), 0.99), c)
                                      return true
                                  end
                              end
                              return prev_coords.x == _mouse.x and prev_coords.y == _mouse.y
                          end, cursor)
end



function treesome.mouse_resize_handler(c, corner, x, y)
    mouse_resize_handler(c, corner,x,y)
end

treesome.name = "treesome"

return treesome
