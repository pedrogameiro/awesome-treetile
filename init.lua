
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

-- Get an unique identifier of a window.
local function hash(client)
    return client and client.window
end

local function table_diff(table1, table2)
    local diff_list = {}
    for i,v in ipairs(table1) do
        if table2[i] ~= v then
            table.insert(diff_list, v)
        end
    end
    return diff_list
end

local function clip(v, min, max)
    return math.max(math.min(v, max), min)
end

local function apply_size_hints(c, width, height, useless_gap)
    local bw = c.border_width
    width, height = width - 2 * bw - useless_gap, height - 2 * bw - useless_gap
    width, height = c:apply_size_hints(math.max(1, width), math.max(1, height))
    return width + 2 * bw + useless_gap, height + 2 * bw + useless_gap
end

-- }}}

-- {{{ bintree enhancement

function bintree:update_nodes_geo(parent_geo, geo_table)
    if type(self.data) == 'number' then
        -- This sibling node is a client.
        -- Just need to resize this client to the size of its geometry of parent
        -- node (the empty work area left by the killed client together with
        -- original area occupied by this sibling client).

        assert(type(parent_geo) == 'table')
        geo_table[self.data] = gtable.clone(parent_geo)

        return
    end

    -- The sibling is another table, need to update the geometry of all descendants.
    assert(type(self.data) == 'table')

    local left_node_geo
    local right_node_geo

    local now_geo = gtable.clone(self.data)
    self.data = gtable.clone(parent_geo)

    if type(self.left.data) == 'number' then
        left_node_geo = gtable.clone(geo_table[self.left.data])
    elseif type(self.left.data) == 'table' then
        left_node_geo = gtable.clone(self.left.data)
    end

    if type(self.right.data) == 'number' then
        right_node_geo = gtable.clone(geo_table[self.right.data])
    elseif type(self.right.data) == 'table' then
        right_node_geo = gtable.clone(self.right.data)
    end

    -- Split vertically.
    if math.abs(left_node_geo.x - right_node_geo.x) < 0.2 then
        if math.abs(parent_geo.width - now_geo.width) > 0.2 then
            left_node_geo.width  = parent_geo.width
            right_node_geo.width = parent_geo.width
            left_node_geo.x      = parent_geo.x
            right_node_geo.x     = parent_geo.x
        end

        if math.abs(parent_geo.height - now_geo.height) > 0.2 then
            if treetile.direction == 'left' then
                left_node_geo, right_node_geo = right_node_geo, left_node_geo
            end

            left_node_geo.height  = parent_geo.height * (left_node_geo.height / now_geo.height)
            right_node_geo.height = parent_geo.height - left_node_geo.height
            left_node_geo.y       = parent_geo.y
            right_node_geo.y      = parent_geo.y + left_node_geo.height
        end
    end

    -- Split horizontally.
    if math.abs(left_node_geo.y - right_node_geo.y) < 0.2 then
        if math.abs(parent_geo.height - now_geo.height) > 0.2 then
            left_node_geo.height  = parent_geo.height
            right_node_geo.height = parent_geo.height
            left_node_geo.y       = parent_geo.y
            right_node_geo.y      = parent_geo.y
        end

        if math.abs(parent_geo.width - now_geo.width) > 0.2 then
            if treetile.direction == 'left' then
                left_node_geo, right_node_geo = right_node_geo, left_node_geo
            end

            left_node_geo.width  = parent_geo.width * (left_node_geo.width / now_geo.width)
            right_node_geo.width = parent_geo.width - left_node_geo.width
            left_node_geo.x      = parent_geo.x
            right_node_geo.x     = parent_geo.x + left_node_geo.width
        end
    end

    if type(self.left.data) == 'number' then
        geo_table[self.left.data].x      = left_node_geo.x
        geo_table[self.left.data].y      = left_node_geo.y
        geo_table[self.left.data].height = left_node_geo.height
        geo_table[self.left.data].width  = left_node_geo.width
    elseif type(self.left.data) == 'table' then
       self.left:update_nodes_geo(left_node_geo, geo_table)
    end

    if type(self.right.data) == 'number' then
        geo_table[self.right.data].x      = right_node_geo.x
        geo_table[self.right.data].y      = right_node_geo.y
        geo_table[self.right.data].height = right_node_geo.height
        geo_table[self.right.data].width  = right_node_geo.width
    elseif type(self.right.data) == 'table' then
       self.right:update_nodes_geo(right_node_geo, geo_table)
    end
end

function bintree:show_detailed(level, child)
    if not level then level = 0 end
    if not child then child = '' end
    if not self then return end

    if type(self.data) ~= "table" then
        print(table.concat {
            string.rep("  ", level),
            child, "Node[",
            tostring(self.data), "]",
        })
    else
        print(table.concat {
            string.rep("  ", level),
            child, "Node[",
            "x:", tostring(self.data.x),      " ",
            "y:", tostring(self.data.y),      " ",
            "w:", tostring(self.data.width),  " ",
            "h:", tostring(self.data.height), "]",
        })
    end

    bintree.show_detailed(self.left,  level + 1, "L_")
    bintree.show_detailed(self.right, level + 1, "R_")
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

function treetile.resize_client(inc)
    -- inc: percentage of change: 0.01, 0.99 with +/-
    local focus_c = capi.client.focus
    local g = focus_c:geometry()

    local t = (capi.screen[focus_c.screen].selected_tag
            or awful.tag.selected(capi.mouse.screen))

    local parent_node = trees[t].geo_t:get_parent(hash(focus_c))
    local parent_c = trees[t].t:get_parent(hash(focus_c))
    local sib_node = trees[t].geo_t:get_sibling(hash(focus_c))
    local sib_node_geo
    if type(sib_node.data) == "number" then
        sib_node_geo = trees[t].geo[sib_node.data]
    else
        sib_node_geo = sib_node.data
    end

    if not parent_node then return end
    local parent_geo = parent_node.data

    local min_x = 20.0
    local min_y = 20.0

    local new_geo = gtable.clone(g)
    local new_sib = {}
    local useless_gap = (t.gap or tonumber(beautiful.useless_gap) or 0) * 2.0

    if parent_c.data == "vertical" then
        local f =  math.ceil(clip(g.height * clip(math.abs(inc), 0.01, 0.99), 5, 30))
        if inc < 0 then f = -f end

        -- determine which is on the right side
        if g.y  > sib_node_geo.y  then
            new_geo.height = clip(g.height - f, min_y, parent_geo.height - min_y)
            new_geo.y      = parent_geo.y + parent_geo.height - new_geo.height

            new_sib.width  = parent_geo.width
            new_sib.height = parent_geo.height - new_geo.height - useless_gap
            new_sib.x      = parent_geo.x
            new_sib.y      = parent_geo.y
        else
            new_geo.height = clip(g.height + f, min_y, parent_geo.height - min_y)
            new_geo.y      = g.y

            new_sib.width  = parent_geo.width
            new_sib.height = parent_geo.height - new_geo.height - useless_gap
            new_sib.x      = new_geo.x
            new_sib.y      = new_geo.y + new_geo.height + useless_gap
        end
    end

    if parent_c.data == "horizontal" then
        local f =  math.ceil(clip(g.width * clip(math.abs(inc), 0.01, 0.99), 5, 30))
        if inc < 0 then f = -f end

        -- determine which is on the top side
        if g.x  > sib_node_geo.x  then
            new_geo.width  = clip(g.width - f, min_x, parent_geo.width - min_x)
            new_geo.x      = parent_geo.x + parent_geo.width - new_geo.width

            new_sib.height = parent_geo.height
            new_sib.width  = parent_geo.width - new_geo.width - useless_gap
            new_sib.y      = parent_geo.y
            new_sib.x      = parent_geo.x
        else
            new_geo.width  = clip(g.width + f, min_x, parent_geo.width - min_x)
            new_geo.x      = g.x

            new_sib.height = parent_geo.height
            new_sib.width  = parent_geo.width - new_geo.width - useless_gap
            new_sib.y      = parent_geo.y
            new_sib.x      = parent_geo.x + new_geo.width + useless_gap
        end
    end

    trees[t].geo[hash(focus_c)] = new_geo
    sib_node:update_nodes_geo(new_sib, trees[t].geo)

    for _, c in ipairs(trees[t].clients) do
        local geo = gtable.clone(trees[t].geo[hash(c)])
        c:geometry(geo)
    end
end

-- One or more clients are added. Put them in the tree.
local function client_added(p, t, l)
    local area  = p.workarea
    -- area.x      = area.x + t.gap / 2
    -- area.y      = area.y + t.gap / 2
    -- area.width  = area.width  - t.gap
    -- area.height = area.height - t.gap

    -- TODO: find a better to handle this
    local focus = treetile.focusnew
            and awful.client.focus.history.get(p.screen, 1)
            or capi.client.focus

    if focus and not focus.floating then
        trees[t].last_focus = focus
    else
        focus = trees[t].last_focus
    end

    local prev_client = nil
    for _, c in ipairs(p.clients) do
        if not trees[t].t or not trees[t].t:find(hash(c)) then
            local focus_node       = nil
            local focus_node_geo_t = nil
            local focus_node_geo   = nil
            local focus_id         = nil
            local next_split       = 0

            if not trees[t].t then
                -- Create a new bintree root.
                trees[t].t            = bintree.new(hash(c))
                trees[t].geo_t        = bintree.new(hash(c))
                trees[t].geo          = { }
                trees[t].geo[hash(c)] = gtable.clone(area)
                focus_node_geo        = nil
                focus_id              = hash(c)
            elseif trees[t].t and focus and hash(c) ~= hash(focus) and not l then
                -- Find the parent node for splitting.
                focus_node            = trees[t].t:find(hash(focus))
                focus_node_geo_t      = trees[t].geo_t:find(hash(focus))
                focus_node_geo        = focus:geometry()
                focus_id              = hash(focus)
            elseif prev_client then
                -- The layout was switched with more clients to order at once.
                focus_node            = trees[t].t:find(hash(prev_client))
                focus_node_geo_t      = trees[t].geo_t:find(hash(prev_client))
                focus_node_geo        = trees[t].geo[hash(prev_client)]
                focus_id              = hash(prev_client)
                next_split            = (next_split + 1) % 2
            end

            if focus_node then
                if not focus_node_geo then
                    focus_node.data = ({ "horizontal", "vertical" })[next_split + 1]
                elseif force_split then
                    focus_node.data = force_split
                elseif (focus_node_geo.width <= focus_node_geo.height) then
                    focus_node.data = "vertical"
                else
                    focus_node.data = "horizontal"
                end

                if treetile.direction == 'right' then
                    focus_node:set_new_left(focus_id)
                    focus_node_geo_t:set_new_left(focus_id)
                    focus_node:set_new_right(hash(c))
                    focus_node_geo_t:set_new_right(hash(c))
                else
                    focus_node:set_new_right(focus_id)
                    focus_node_geo_t:set_new_right(focus_id)
                    focus_node:set_new_left(hash(c))
                    focus_node_geo_t:set_new_left(hash(c))
                end

                local useless_gap = (t.gap or tonumber(beautiful.useless_gap) or 0) * 2.0
                local avail_geo = focus_node_geo or area
                local new_c = {}
                local old_focus_c = {}

                -- Put the geometry of parament node into table too.
                focus_node_geo_t.data = gtable.clone(avail_geo)

                if focus_node.data == "horizontal" then
                    new_c.width = math.floor((avail_geo.width - useless_gap) / 2.0 )
                    new_c.height = avail_geo.height
                    old_focus_c.width = math.floor((avail_geo.width - useless_gap) / 2.0 )
                    old_focus_c.height = avail_geo.height
                    old_focus_c.y = avail_geo.y
                    new_c.y = avail_geo.y

                    if treetile.direction == "right" then
                        new_c.x = avail_geo.x + new_c.width + useless_gap
                        old_focus_c.x = avail_geo.x
                    else
                        new_c.x = avail_geo.x
                        old_focus_c.x = avail_geo.x + new_c.width - useless_gap
                    end

                elseif focus_node.data == "vertical" then
                    new_c.height = math.floor((avail_geo.height - useless_gap) / 2.0 )
                    new_c.width = avail_geo.width
                    old_focus_c.height = math.floor((avail_geo.height - useless_gap) / 2.0 )
                    old_focus_c.width = avail_geo.width
                    old_focus_c.x = avail_geo.x
                    new_c.x = avail_geo.x

                    if  treetile.direction == "right" then
                        new_c.y = avail_geo.y + new_c.height + useless_gap
                        old_focus_c.y = avail_geo.y
                    else
                        new_c.y = avail_geo.y
                        old_focus_c.y =avail_geo.y + new_c.height - useless_gap
                    end

                end

                -- put geometry of clients into tables
                if focus_id then
                    trees[t].geo[focus_id] = old_focus_c
                    trees[t].geo[hash(c)] = new_c
                end
            end
        end

        prev_client = c
    end

    force_split = nil
end

-- Some client removed. Update the trees.
local function client_removed(p, t)
    if #p.clients <= 0 then
        trees[t] = nil
        return
    end

    local tokens = {}
    for i, c in ipairs(p.clients) do
        tokens[i] = hash(c)
    end

    for clid, _ in pairs(trees[t].geo) do
        if not gtable.hasitem(tokens, clid) then
            -- Update the size of clients left, fill the empty space left by the killed client.

            local sibling = trees[t].geo_t:get_sibling(clid)
            local parent = trees[t].geo_t:get_parent(clid)

            if sibling then
                sibling:update_nodes_geo(parent and parent.data, trees[t].geo)
            end

            local pos = gtable.hasitem(trees[t].geo, clid)
            table.remove(trees[t].geo, pos)
        end
    end

    local function predicate(node)
        return type(node.data) == "number" and not table_find(tokens, node.data)
    end

    trees[t].geo_t:remove_if(predicate)
    trees[t].t:remove_if(predicate)
end

-- Update the geometries of all clients.
local function update_clients(p, t)
    if #p.clients >= 1 then
        for _, c in ipairs(p.clients) do
            local geo = gtable.clone(trees[t].geo[hash(c)])
            -- geo.width, geo.height = apply_size_hints(c, geo.width, geo.height, t.gap)
            -- geo.width  = geo.width - 2 * c.border_width
            -- geo.height = geo.height - 2 * c.border_width
            c:geometry(geo)
        end
    end
end

function treetile.arrange(p)
    local t = (p.tag
            or capi.screen[p.screen].selected_tag
            or awful.tag.selected(capi.mouse.screen))

    -- Create a new root.
    if not trees[t] then
        trees[t] = {
            t = nil,
            geo_t = nil,
            geo = nil,
            last_focus = nil,
            clients = { },
        }
    end

    -- `t` is tree structure to record all the clients and the way of splitting.
    -- `geo_t` is the tree structure to record the geometry of all nodes/clients
    -- of the parent nodes (the over-all geometry of all siblings together).

    -- Rearange only on change.
    local update_needed
    local changed = (#trees[t].clients == #p.clients and 0)
            or (#p.clients > #trees[t].clients and 1 or -1)

    if trees[t].clients then
        local diff = table_diff(p.clients, trees[t].clients)
        if #diff == 2 then
            trees[t].t:swap_leaves(hash(diff[1]), hash(diff[2]))
            trees[t].geo_t:swap_leaves(hash(diff[1]), hash(diff[2]))
            trees[t].geo[hash(diff[1])], trees[t].geo[hash(diff[2])]
                = trees[t].geo[hash(diff[2])], trees[t].geo[hash(diff[1])]
            update_needed = true
        end
    end

    trees[t].clients = p.clients

    if changed < 0 then
        client_removed(p, t)
    elseif changed > 0 then
        client_added(p, t, layout_switch)
    end

    if changed ~= 0 or layout_switch or update_needed then
        update_clients(p, t)
    end

    if trees[t] and trees[t].t then
        print("\ntree:" .. t.name .. " (t)")
        trees[t].t:show_detailed()
    end
    if trees[t] and trees[t].geo_t then
        print("\ntree:" .. t.name .. " (geo_t)")
        trees[t].geo_t:show_detailed()
    end

    layout_switch = false
end

-- TODO
-- Not implimented yet, do not use it!
-- Resizing should only happen between the siblings?
local function mouse_resize_handler(c, _, _, _)
    local t = c.screen.selected_tag or awful.tag.selected(c.screen)
    local g = c:geometry()
    local cursor
    local corner_coords

    local parent_c = trees[t].t:get_parent(hash(c))

    local parent_node = trees[t].geo_t:get_parent(hash(c))
    local parent_geo

    local new_y = nil
    local new_x = nil

    local sib_node = trees[t].geo_t:get_sibling(hash(c))
    local sib_node_geo
    if type(sib_node.data) == "number" then
        sib_node_geo = trees[t].geo[sib_node.data]
    else
        sib_node_geo = sib_node.data
    end

    if parent_node then
        parent_geo = parent_node.data
    else
        return
    end

    if parent_c then
        if parent_c.data =='vertical' then
            cursor = "sb_v_double_arrow"
            new_y = math.max(g.y, sib_node_geo.y)
            new_x = g.x + g.width / 2
        end

        if parent_c.data =='horizontal' then
            cursor = "sb_h_double_arrow"
            new_x = math.max(g.x, sib_node_geo.x)
            new_y = g.y + g.height / 2
        end
    end

    corner_coords = { x = new_x, y = new_y }

    capi.mouse.coords(corner_coords)

    local prev_coords = {}
    capi.mousegrabber.run(function(m)
        for _, v in ipairs(m.buttons) do
            if v then
                prev_coords = { x = m.x, y = m.y }
                local fact_x = (m.x - corner_coords.x)
                local fact_y = (m.y - corner_coords.y)

                local new_geo = { }
                local new_sib = { }

                local min_x = 15.0
                local min_y = 15.0

                new_geo.x = g.x
                new_geo.y = g.y
                new_geo.width = g.width
                new_geo.height = g.height

                if parent_c.data =='vertical' then
                    if g.y > sib_node_geo.y then
                        new_geo.height = clip(g.height - fact_y, min_y, parent_geo.height - min_y)
                        new_geo.y= clip(m.y, sib_node_geo.y + min_y, parent_geo.y + parent_geo.height - min_y)

                        new_sib.x = parent_geo.x
                        new_sib.y = parent_geo.y
                        new_sib.width = parent_geo.width
                        new_sib.height = parent_geo.height - new_geo.height
                    else
                        new_geo.y = g.y
                        new_geo.height = clip(g.height + fact_y,  min_y, parent_geo.height - min_y)

                        new_sib.x = new_geo.x
                        new_sib.y = new_geo.y + new_geo.height
                        new_sib.width = parent_geo.width
                        new_sib.height = parent_geo.height - new_geo.height
                    end
                end

                if parent_c.data =='horizontal' then
                    if g.x  > sib_node_geo.x  then
                        new_geo.width = clip(g.width - fact_x, min_x, parent_geo.width - min_x)
                        new_geo.x = clip(m.x, sib_node_geo.x + min_x, parent_geo.x + parent_geo.width - min_x)

                        new_sib.y = parent_geo.y
                        new_sib.x = parent_geo.x
                        new_sib.height = parent_geo.height
                        new_sib.width = parent_geo.width - new_geo.width
                    else
                        new_geo.x = g.x
                        new_geo.width = clip(g.width + fact_x, min_x, parent_geo.width - min_x)

                        new_sib.y = parent_geo.y
                        new_sib.x = parent_geo.x + new_geo.width
                        new_sib.height = parent_geo.height
                        new_sib.width = parent_geo.width - new_geo.width
                    end
                end

                trees[t].geo[hash(c)] = new_geo

                if sib_node then
                    sib_node:update_nodes_geo(new_sib, trees[t].geo)
                end

                for _, cl in ipairs(trees[t].clients) do
                    local geo = trees[t].geo[hash(cl)]
                    if type(geo) == 'table' then
                        cl:geometry(geo)
                    else
                        debug.print_error("treetile: faulty geometry")
                    end
                end

                return true
            end
        end
        return prev_coords.x == m.x and prev_coords.y == m.y
    end, cursor)
end

function treetile.mouse_resize_handler(c, corner, x, y)
    mouse_resize_handler(c, corner,x,y)
end

-- }}}

return treetile
