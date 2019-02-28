
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

local capi = {
    client       = client,
    tag          = tag,
    mouse        = mouse,
    screen       = screen,
    mousegrabber = mousegrabber,
}

local treetile = {
    focusnew         = true,
    name             = "treetile",
    new_location     = "right",
    new_ratio        = 0.5,
    new_split        = "vertical",
    rotate_on_remove = true
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

local function table_diff(table1, table2)
    local diff_list = {}
    for i, v in ipairs(table1) do
        if table2[i] ~= v then
            table.insert(diff_list, v)
        end
    end
    return diff_list
end

local function match(c)
    return function(node)
        return node.data.id == c
    end
end

local function cleanup(node)
    node.data.id = nil
end

-- }}}

-- {{{ bintree enhancement

function bintree:add_client(client, split)
    local left_id, right_id
    if treetile.new_location == "left" or treetile.new_location == "top" then
        left_id, right_id = client, self.data.id
    else
        left_id, right_id = self.data.id, client
    end

    self.data.split = split or treetile.new_split
    self.data.ratio = treetile.new_ratio

    self:set_new_left { id = left_id }
    self:set_new_right { id = right_id }

    -- Not allowed to hold a client now.
    self.data.id = nil
end

function bintree:remove_client(client)
    local node
    if self.right and self.right.data.id == client then
        self:remove_right(cleanup)
        node = self.left
    elseif self.left and self.left.data.id == client then
        self:remove_left(cleanup)
        node = self.right
    else
        assert(false)
    end

    node.parent = self.parent
    if self.parent then
        if self.parent.left == self then
            self.parent.left = node
        else
            self.parent.right = node
        end
    end

    return node
end

local function calculate_geometry(geometry, split, ratio)
    local vertical = split == "vertical"
    local x, y, width, height

    if vertical then
        x      = geometry.x + geometry.width * ratio
        width  = geometry.width * ratio
    else
        y      = geometry.y + geometry.height * ratio
        height = geometry.height * ratio
    end

    return {
        x      = geometry.x,
        y      = geometry.y,
        width  = width or geometry.width,
        height = height or geometry.height,
    }, {
        x      = x or geometry.x,
        y      = y or geometry.y,
        width  = width or geometry.width,
        height = height or geometry.height,
    }
end

function bintree:apply_geometry(geometry, gaps)
    assert((self.left and self.right and not self.data.id)
            or (not self.left and not self.right and self.data.id))

    if self.left and self.right then
        local g1, g2 = calculate_geometry(geometry, self.data.split, self.data.ratio)
        self.left:apply_geometry(g1, gaps)
        self.right:apply_geometry(g2, gaps)
        return
    else
        local c = self.data.id
        geometry.width  = geometry.width  - 2 * gaps - 2 * c.border_width
        geometry.height = geometry.height - 2 * gaps - 2 * c.border_width
        c:geometry(geometry)
    end
end

function bintree:rotate()
    if self.data.split == "vertical" then
        self.data.split = "horizontal"
    elseif self.data.split == "horizontal" then
        self.data.split = "vertical"
    end
end

function bintree:rotate_all()
    self:apply(function(node) node:rotate() end)
end

function bintree:show_detailed()
    self:apply_levels(function(node, level)
        if node.data.id then
            print(table.concat {
                string.rep(" ", 4 * level), "●     [",
                "x:", tostring(node.data.id.x),      " ",
                "y:", tostring(node.data.id.y),      " ",
                "w:", tostring(node.data.id.width),  " ",
                "h:", tostring(node.data.id.height), "]",
            })
        else
            print(table.concat {
                string.rep(" ", 4 * level), "●     [",
                tostring(node.data.ratio), "] [",
                tostring(node.data.split), "]",
            })
        end
    end)
end

-- }}}

-- {{{ implementation

-- function treetile.resize_client(inc)
--     -- inc: percentage of change: 0.01, 0.99 with +/-
--     local focus_c = capi.client.focus
--     local g = focus_c:geometry()
--
--     local t = (capi.screen[focus_c.screen].selected_tag
--             or awful.tag.selected(capi.mouse.screen))
--
--     local parent_c = trees[t].root:get_parent_if(match(focus_c))
--     local sib_node = parent_c:get_sibling_if(match(focus_c))
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
--     if parent_c.data.split == "vertical" then
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
--     if parent_c.data.split == "horizontal" then
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
        if not gtable.hasitem(trees[t].clients, c) then
            if not trees[t].root then
                trees[t].root = bintree.new { id = c }
            elseif focus then
                local node = trees[t].root:find_if(match(focus))
                local next_split
                if node.parent and node.parent.data.split == "vertical" then
                    next_split = "horizontal"
                else
                    next_split = "vertical"
                end
                node:add_client(c, force_split or next_split)
                focus = c
            end
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
            local node = trees[t].root:find_if(match(c))
            if node and node.parent then
                local root
                if node.parent.parent then
                    root = node.parent:remove_client(c).parent
                else
                    trees[t].root = node.parent:remove_client(c)
                    root = trees[t].root
                end
                if treetile.rotate_on_remove then
                    root:rotate_all()
                end
            else
                assert(not trees[t].root.left and not trees[t].root.right)
                trees[t].root:remove(cleanup)
                trees[t].root = nil
            end
        end
    end
end

-- Update the geometries of all clients.
local function update_clients(p, t)
    trees[t].root:apply_geometry({
        x      = p.workarea.x + t.gap,
        y      = p.workarea.y + t.gap,
        width  = p.workarea.width,
        height = p.workarea.height,
    }, t.gap)
end

function treetile.arrange(p)
    print()
    local t = (p.tag
            or capi.screen[p.screen].selected_tag
            or awful.tag.selected(capi.mouse.screen))

    -- Create a new root.
    if not trees[t] then
        trees[t] = {
            root = nil,
            last_focus = nil,
            clients = { },
        }
    end

    -- Rearange only on change.
    local changed = (#trees[t].clients == #p.clients and 0)
            or (#p.clients > #trees[t].clients and 1 or -1)

    local update_needed
    local diff = table_diff(p.clients, trees[t].clients)
    print("diff:", #diff)
    for _, c in pairs(diff) do print(tostring(c)) end
    if #p.clients == #trees[t].clients and #diff == 2 then
        local nodes = trees[t].root:find_if { match(diff[1]), match(diff[2]) }
        nodes[1].data.id, nodes[2].data.id = nodes[2].data.id, nodes[1].data.id
        update_needed = true
    end

    if changed < 0 then
        client_removed(p, t)
    elseif changed > 0 then
        client_added(p, t)
    end

    if (changed ~= 0 or layout_switch or update_needed) and trees[t].root then
        update_clients(p, t)
    end
    layout_switch = false

    print("changed:", changed)
    if changed ~= 0 and trees[t] and trees[t].root then
        print("tree:", t.name)
        trees[t].root:show_detailed()
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
--     local parent_c = trees[t].root:get_parent_if(match(c))
--     local parent_geo
--
--     local new_y = nil
--     local new_x = nil
--
--     local sib_node = parent_c:get_sibling_if(match(c))
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
--         if parent_c.data.split == "vertical" then
--             cursor = "sb_v_double_arrow"
--             new_y = math.max(g.y, sib_node_geo.y)
--             new_x = g.x + g.width / 2
--         end
--
--         if parent_c.data.split == "horizontal" then
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
--                 if parent_c.data.split == "vertical" then
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
--                 if parent_c.data.split == "horizontal" then
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

-- {{{ public functions

function treetile.horizontal()
    force_split = "horizontal"
    debug_info('Next split is horizontal.')
end

function treetile.vertical()
    force_split = "vertical"
    debug_info('Next split is vertical.')
end

function treetile.rotate(c)
    local t = c and c.screen.selected_tag
            or awful.screen.focused().selected_tag

    local node = c and trees[t].root:find_if(match(c))
            or trees[t].root
    node:rotate()
end

function treetile.rotate_all(c)
    local t = c and c.screen.selected_tag
            or awful.screen.focused().selected_tag

    local node = c and trees[t].root:find_if(match(c))
            or trees[t].root
    node:rotate_all()
end

-- }}}

return treetile
