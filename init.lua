
--[[

     Licensed under GNU General Public License v2
      * (c) 2019, Alphonse Mariyagnanaseelan



    treetile: Binary Tree-based tiling layout for Awesome v4

    URL:     https://github.com/alfunx/treetile
    Fork of: https://github.com/RobSis/treesome
             https://github.com/guotsuan/treetile



    Because the the split of space is depending on the parent node, which is
    current focused client.  Therefore it is necessary to set the correct
    focus option, "treetile.focusnew".

    If the new created client will automatically gain the focus, for exmaple
    in rc.lua with the settings:

    ...
    awful.rules.rules = {
        { rule = { },
          properties = { focus = awful.client.focus.filter,
    ...

    You need to set "treetile.focusnew = true"
    Otherwise, set "treetile.focusnew = false"

--]]

local awful        = require("awful")
local beautiful    = require("beautiful")
local debug        = require("gears.debug")
local gtable       = require("gears.table")
local naughty      = require("naughty")

local bintree      = require("treetile/bintree")
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
    tag            = tag,
    mouse          = mouse,
    screen         = screen,
    mousegrabber   = mousegrabber
}

local treetile     = {
    focusnew       = true,
    name           = "treetile",
    direction      = "right",
}

-- globals
local force_split   = nil
local layout_switch = false
local trees         = { }

-- TODO
-- layout icon
beautiful.layout_treetile = os.getenv("HOME") .. "/.config/awesome/treetile/layout_icon.png"

capi.tag.connect_signal("property::layout", function() layout_switch = true end)

-- {{{ helpers

local function debug_info(message)
    if type(message) == "table" then
        for k,v in pairs(message) do
            naughty.notify { text = table.concat {"key: ",k," value: ",tostring(v)} }
        end
    else
        naughty.notify { text = tostring(message) }
    end
end

local function table_find(tbl, item)
    for key, value in pairs(tbl) do
        if value == item then return key end
    end
    return false
end

local function table_diff(table1, table2)
    local diff_list = {}
    for i, v in ipairs(table1) do
        if table2[i] ~= v then
            table.insert(diff_list, v)
        end
    end
    return diff_list
end

local function match_hash(c)
    return function(node)
        return node.data.id == c
    end
end

local function cleanup(node)
    node.data.id = nil
end

local function apply_geometry(t)
    return function(node)
        if not node.data.id then return end
        local c = node.data.id
        local g = {
            x      = node.data.geometry.x,
            y      = node.data.geometry.y,
            width  = node.data.geometry.width  - 2 * t.gap - 2 * c.border_width,
            height = node.data.geometry.height - 2 * t.gap - 2 * c.border_width,
        }
        c:geometry(g)
    end
end

-- }}}

-- {{{ bintree enhancement

function bintree:add_client(client, split, location)
    local vertical
    if split == nil then
        vertical = self.data.geometry.width > self.data.geometry.height
    else
        vertical = split == "vertical"
    end

    -- local new_on_left = location == "left" or location == "top"
    -- local left_id     = not new_on_left and self.data.id or client
    -- local right_id    =     new_on_left and self.data.id or client

    local left_id, right_id
    if location == "left" or location == "top" then
        left_id, right_id = client, self.data.id
    else
        left_id, right_id = self.data.id, client
    end

    if vertical then
        self.data.direction = "vertical"
        self:set_new_left {
            id = left_id,
            geometry = {
                x      = self.data.geometry.x,
                y      = self.data.geometry.y,
                width  = self.data.geometry.width / 2,
                height = self.data.geometry.height,
            },
        }
        self:set_new_right {
            id = right_id,
            geometry = {
                x      = self.data.geometry.x + self.data.geometry.width / 2,
                y      = self.data.geometry.y,
                width  = self.data.geometry.width / 2,
                height = self.data.geometry.height,
            },
        }
    else
        self.data.direction = "horizontal"
        self:set_new_left {
            id = left_id,
            geometry = {
                x      = self.data.geometry.x,
                y      = self.data.geometry.y,
                width  = self.data.geometry.width,
                height = self.data.geometry.height / 2,
            },
        }
        self:set_new_right {
            id = right_id,
            geometry = {
                x      = self.data.geometry.x,
                y      = self.data.geometry.y + self.data.geometry.height / 2,
                width  = self.data.geometry.width,
                height = self.data.geometry.height / 2,
            },
        }
    end

    -- Not allowed to hold a client now.
    self.data.id = nil
end

function bintree:move_up_to(node)
    node.data.id, self.data.id = self.data.id, nil
    node.direction = self.direction

    if not self.left then
        if node.left then
            if node.left.left then node.left:remove_left(cleanup) end
            if node.left.right then node.left:remove_right(cleanup) end
            node:remove_left(cleanup)
        end
    end

    if not self.right then
        if node.right then
            if node.right.left then node.right:remove_left(cleanup) end
            if node.right.right then node.right:remove_right(cleanup) end
            node:remove_right(cleanup)
        end
    end

    if self.left then
        self.left:move_up_to(node.left)
    end

    if self.right then
        self.right:move_up_to(node.right)
    end
end

function bintree:remove_client(client)
    if self.right and self.right.data.id == client then
        self.left:move_up_to(self)
    elseif self.left and self.left.data.id == client then
        self.right:move_up_to(self)
    else
        assert(false)
    end
end

function bintree:show_detailed(level)
    if not level then level = 0 end

    if self.left then
        bintree.show_detailed(self.left, level + 1)
    end

    if self then
        print(table.concat {
            string.rep(" ", 4 * level), "●     [",
            tostring(self.data.id or " "), "] [",
            tostring(self.data.direction or " "), "] [",
            "x:", tostring(self.data.geometry.x),      " ",
            "y:", tostring(self.data.geometry.y),      " ",
            "w:", tostring(self.data.geometry.width),  " ",
            "h:", tostring(self.data.geometry.height), "]",
        })
    end

    if self.right then
        bintree.show_detailed(self.right, level + 1)
    end
end

-- }}}

-- {{{ public functions

function treetile.horizontal()
    force_split = "horizontal"
    debug_info('Next split is horizontal.')
end

function treetile.vertical()
    force_split = "vertical"
    debug_info('Next split is vertical.')
end

-- function treetile.resize_client(inc)
--     -- inc: percentage of change: 0.01, 0.99 with +/-
--     local focus_c = capi.client.focus
--     local g = focus_c:geometry()
--
--     local t = (capi.screen[focus_c.screen].selected_tag
--             or awful.tag.selected(capi.mouse.screen))
--
--     local parent_c = trees[t].t:get_parent_if(match_hash(focus_c))
--     local sib_node = parent_c:get_sibling_if(match_hash(focus_c))
--     local sib_node_geo
--     if type(sib_node.data.id) == "number" then
--         sib_node_geo = trees[t].geo[sib_node.data.id]
--     else
--         sib_node_geo = sib_node.data.geometry
--     end
--
--     if not parent_c then return end
--     local parent_geo = parent_c.data.geometry
--
--     local min_x = 20.0
--     local min_y = 20.0
--
--     local new_geo = gtable.clone(g)
--     local new_sib = {}
--     local useless_gap = (t.gap or tonumber(beautiful.useless_gap) or 0) * 2.0
--
--     if parent_c.data.direction == "vertical" then
--         local f =  math.ceil(clip(g.height * clip(math.abs(inc), 0.01, 0.99), 5, 30))
--         if inc < 0 then f = -f end
--
--         -- determine which is on the right side
--         if g.y  > sib_node_geo.y  then
--             new_geo.height = clip(g.height - f, min_y, parent_geo.height - min_y)
--             new_geo.y      = parent_geo.y + parent_geo.height - new_geo.height
--
--             new_sib.width  = parent_geo.width
--             new_sib.height = parent_geo.height - new_geo.height - useless_gap
--             new_sib.x      = parent_geo.x
--             new_sib.y      = parent_geo.y
--         else
--             new_geo.height = clip(g.height + f, min_y, parent_geo.height - min_y)
--             new_geo.y      = g.y
--
--             new_sib.width  = parent_geo.width
--             new_sib.height = parent_geo.height - new_geo.height - useless_gap
--             new_sib.x      = new_geo.x
--             new_sib.y      = new_geo.y + new_geo.height + useless_gap
--         end
--     end
--
--     if parent_c.data.direction == "horizontal" then
--         local f =  math.ceil(clip(g.width * clip(math.abs(inc), 0.01, 0.99), 5, 30))
--         if inc < 0 then f = -f end
--
--         -- determine which is on the top side
--         if g.x  > sib_node_geo.x  then
--             new_geo.width  = clip(g.width - f, min_x, parent_geo.width - min_x)
--             new_geo.x      = parent_geo.x + parent_geo.width - new_geo.width
--
--             new_sib.height = parent_geo.height
--             new_sib.width  = parent_geo.width - new_geo.width - useless_gap
--             new_sib.y      = parent_geo.y
--             new_sib.x      = parent_geo.x
--         else
--             new_geo.width  = clip(g.width + f, min_x, parent_geo.width - min_x)
--             new_geo.x      = g.x
--
--             new_sib.height = parent_geo.height
--             new_sib.width  = parent_geo.width - new_geo.width - useless_gap
--             new_sib.y      = parent_geo.y
--             new_sib.x      = parent_geo.x + new_geo.width + useless_gap
--         end
--     end
--
--     trees[t].geo[hash(focus_c)] = new_geo
--     sib_node:update_nodes_geo(new_sib, trees[t].geo)
--
--     for _, c in ipairs(trees[t].clients) do
--         local geo = gtable.clone(trees[t].geo[hash(c)])
--         c:geometry(geo)
--     end
-- end

-- One or more clients are added. Put them in the tree.
local function client_added(p, t)
    -- TODO: find a better to handle this
    local focus = treetile.focusnew
            and awful.client.focus.history.get(p.screen, 1)
            or capi.client.focus

    if focus and not focus.floating then
        trees[t].last_focus = focus
    else
        focus = trees[t].last_focus
    end

    for _, c in pairs(p.clients) do
        if gtable.hasitem(trees[t].clients, c) then
            -- Do nothing.
        elseif not trees[t].t then
            -- Create a new bintree root.
            trees[t].t = bintree.new {
                id = c,
                geometry = {
                    x      = p.workarea.x + t.gap,
                    y      = p.workarea.y + t.gap,
                    width  = p.workarea.width,
                    height = p.workarea.height,
                },
            }
        elseif focus then
            trees[t].t:find_if(match_hash(focus))
                    :add_client(c, force_split)
            focus = c
        end
    end

    force_split = nil
end

-- Some client removed. Update the trees.
local function client_removed(p, t)
    local p_clients = { }
    for _, c in ipairs(p.clients) do p_clients[c] = true end
    for _, c in ipairs(trees[t].clients) do
        if not p_clients[c] then
            local node = trees[t].t:find_if(match_hash(c))
            if node and node.parent then
                node.parent:remove_client(c)
            else
                print(" >>> ROOT")
                assert(not trees[t].t.left and not trees[t].t.right)
                trees[t].t:remove(cleanup)
                trees[t].t = nil
            end
        end
    end
end

-- Update the geometries of all clients.
local function update_clients(t)
    if not trees[t].t then return end
    trees[t].t:apply(apply_geometry(t))
end

function treetile.arrange(p)
    print()
    local t = (p.tag
            or capi.screen[p.screen].selected_tag
            or awful.tag.selected(capi.mouse.screen))

    -- Create a new root.
    if not trees[t] then
        trees[t] = {
            t = nil,
            last_focus = nil,
            clients = { },
        }
    end

    -- Rearange only on change.
    local changed = (#trees[t].clients == #p.clients and 0)
            or (#p.clients > #trees[t].clients and 1 or -1)

    local diff = table_diff(p.clients, trees[t].clients)
    print("diff:", #diff)
    for _, c in pairs(diff) do print(tostring(c)) end
    if #p.clients == #trees[t].clients and #diff == 2 then
        local nodes = trees[t].t:find_if { match_hash(diff[1]), match_hash(diff[2]) }
        nodes[1].data.id, nodes[2].data.id = nodes[2].data.id, nodes[1].data.id
        nodes[1]:apply(apply_geometry(t))
        nodes[2]:apply(apply_geometry(t))
    end

    if changed < 0 then
        client_removed(p, t)
    elseif changed > 0 then
        client_added(p, t)
    end

    if changed ~= 0 or layout_switch then
        update_clients(t)
    end
    layout_switch = false

    print("changed:", changed)
    if changed ~= 0 and trees[t] and trees[t].t then
        print("tree:", t.name)
        trees[t].t:show_detailed()
    end

    trees[t].clients = p.clients
end

-- -- TODO
-- -- Not implimented yet, do not use it!
-- -- Resizing should only happen between the siblings?
-- local function mouse_resize_handler(c, _, _, _)
--     local t = c.screen.selected_tag or awful.tag.selected(c.screen)
--     local g = c:geometry()
--     local cursor
--     local corner_coords
--
--     local parent_c = trees[t].t:get_parent_if(match_hash(c))
--     local parent_geo
--
--     local new_y = nil
--     local new_x = nil
--
--     local sib_node = parent_c:get_sibling_if(match_hash(c))
--     local sib_node_geo
--     if type(sib_node.data.id) == "number" then
--         sib_node_geo = trees[t].geo[sib_node.data.id]
--     else
--         sib_node_geo = sib_node.data.geometry
--     end
--
--     if parent_c then
--         parent_geo = parent_c.data.geometry
--     else
--         return
--     end
--
--     if parent_c then
--         if parent_c.data.direction == "vertical" then
--             cursor = "sb_v_double_arrow"
--             new_y = math.max(g.y, sib_node_geo.y)
--             new_x = g.x + g.width / 2
--         end
--
--         if parent_c.data.direction == "horizontal" then
--             cursor = "sb_h_double_arrow"
--             new_x = math.max(g.x, sib_node_geo.x)
--             new_y = g.y + g.height / 2
--         end
--     end
--
--     corner_coords = { x = new_x, y = new_y }
--
--     capi.mouse.coords(corner_coords)
--
--     local prev_coords = {}
--     capi.mousegrabber.run(function(m)
--         for _, v in ipairs(m.buttons) do
--             if v then
--                 prev_coords = { x = m.x, y = m.y }
--                 local fact_x = (m.x - corner_coords.x)
--                 local fact_y = (m.y - corner_coords.y)
--
--                 local new_geo = { }
--                 local new_sib = { }
--
--                 local min_x = 15.0
--                 local min_y = 15.0
--
--                 new_geo.x = g.x
--                 new_geo.y = g.y
--                 new_geo.width = g.width
--                 new_geo.height = g.height
--
--                 if parent_c.data.direction == "vertical" then
--                     if g.y > sib_node_geo.y then
--                         new_geo.height = clip(g.height - fact_y, min_y, parent_geo.height - min_y)
--                         new_geo.y= clip(m.y, sib_node_geo.y + min_y, parent_geo.y + parent_geo.height - min_y)
--
--                         new_sib.x = parent_geo.x
--                         new_sib.y = parent_geo.y
--                         new_sib.width = parent_geo.width
--                         new_sib.height = parent_geo.height - new_geo.height
--                     else
--                         new_geo.y = g.y
--                         new_geo.height = clip(g.height + fact_y,  min_y, parent_geo.height - min_y)
--
--                         new_sib.x = new_geo.x
--                         new_sib.y = new_geo.y + new_geo.height
--                         new_sib.width = parent_geo.width
--                         new_sib.height = parent_geo.height - new_geo.height
--                     end
--                 end
--
--                 if parent_c.data.direction == "horizontal" then
--                     if g.x  > sib_node_geo.x  then
--                         new_geo.width = clip(g.width - fact_x, min_x, parent_geo.width - min_x)
--                         new_geo.x = clip(m.x, sib_node_geo.x + min_x, parent_geo.x + parent_geo.width - min_x)
--
--                         new_sib.y = parent_geo.y
--                         new_sib.x = parent_geo.x
--                         new_sib.height = parent_geo.height
--                         new_sib.width = parent_geo.width - new_geo.width
--                     else
--                         new_geo.x = g.x
--                         new_geo.width = clip(g.width + fact_x, min_x, parent_geo.width - min_x)
--
--                         new_sib.y = parent_geo.y
--                         new_sib.x = parent_geo.x + new_geo.width
--                         new_sib.height = parent_geo.height
--                         new_sib.width = parent_geo.width - new_geo.width
--                     end
--                 end
--
--                 trees[t].geo[hash(c)] = new_geo
--
--                 if sib_node then
--                     sib_node:update_nodes_geo(new_sib, trees[t].geo)
--                 end
--
--                 for _, cl in ipairs(trees[t].clients) do
--                     local geo = trees[t].geo[hash(cl)]
--                     if type(geo) == 'table' then
--                         cl:geometry(geo)
--                     else
--                         debug.print_error("treetile: faulty geometry")
--                     end
--                 end
--
--                 return true
--             end
--         end
--         return prev_coords.x == m.x and prev_coords.y == m.y
--     end, cursor)
-- end
--
-- function treetile.mouse_resize_handler(c, corner, x, y)
--     mouse_resize_handler(c, corner,x,y)
-- end

-- }}}

return treetile
