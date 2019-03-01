
--[[

     Licensed under GNU General Public License v2
      * (c) 2019, Alphonse Mariyagnanaseelan



    treetile: Binary Tree-based tiling layout for Awesome v4

    URL:     https://github.com/alfunx/treetile
    Fork of: https://github.com/RobSis/treesome
             https://github.com/guotsuan/treetile



    Because the the split of space is depending on the parent node, which is
    current focused client.  Therefore it is necessary to set the correct
    focus option, "treetile.new_focus".

    If the new created client will automatically gain the focus, for exmaple
    in rc.lua with the settings:

    ...
    awful.rules.rules = {
        { rule = { },
          properties = { focus = awful.client.focus.filter,
    ...

    You need to set "treetile.new_focus = true"
    Otherwise, set "treetile.new_focus = false"

--]]

local awful        = require("awful")
local beautiful    = require("beautiful")
local debug        = require("gears.debug")
local gtable       = require("gears.table")
local naughty      = require("naughty")

local bintree      = require("treetile.bintree")
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
    name             = "treetile",
    new_focus        = true,
    new_ratio        = 0.5,
    new_split        = "vertical",
    new_vertical     = "right",
    new_horizontal   = "bottom",
    rotate_on_remove = false,
}

-- globals
local force_split  = nil
local force_update = false
local trees        = { }

-- TODO
-- layout icon
beautiful.layout_treetile = os.getenv("HOME") .. "/.config/awesome/treetile/layout_icon.png"

capi.tag.connect_signal("property::layout", function() force_update = true end)

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

-- Ugly but optimized.
local function full_diff(old, new)
    local added = {}
    local moved = {}
    local removed = {}
    for i, v in ipairs(old) do
        local new_index = gtable.hasitem(new, v)
        if new[i] ~= v  and new_index then
            table.insert(moved, v)
        elseif not new_index then
            table.insert(removed, v)
        end
    end
    for _, v in ipairs(new) do
        if not gtable.hasitem(old, v) then
            table.insert(added, v)
        end
    end
    return added, moved, removed
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
    self.data.split = split or treetile.new_split
    self.data.ratio = treetile.new_ratio

    local old_client = self.data.id
    self.data.id = nil

    if self.data.split == "vertical" and treetile.new_vertical == "left"
            or self.data.split == "horizontal" and treetile.new_vertical == "top" then
        self:set_new_right { id = old_client }
        return self:set_new_left { id = client }
    else
        self:set_new_left { id = old_client }
        return self:set_new_right { id = client }
    end

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
    if not self.data.split then return end
    self.data.split = self.data.split == "vertical" and "horizontal" or "vertical"
end

function bintree:rotate_all()
    if not self.data.split then return end
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

-- One or more clients are added. Put them in the tree.
local function add_clients(t, clients, focus)
    if #clients == 0 then return end

    local node = trees[t].root and (trees[t].root:find_if(match(focus))
            or trees[t].root:find_if(match(trees[t].last_focus)))

    for _, c in pairs(clients) do
        if node then
            local next_split
            if node.parent then
                if node.parent.data.split == "horizontal" then
                    next_split = "vertical"
                else
                    next_split = "horizontal"
                end
            end
            node = node:add_client(c, force_split or next_split)
        else
            trees[t].root = bintree.new { id = c }
            node = trees[t].root
        end
        focus = c
    end

    if focus and not focus.floating then
        trees[t].last_focus = focus
    end
    force_split = nil
end

-- Some client removed. Update the trees.
local function prune_clients(t, clients)
    if not trees[t].root then return end

    for _, c in ipairs(clients) do
        local node = trees[t].root:find_if(match(c))
        if node and node.parent then
            if node.parent.parent then
                local n = node.parent:remove_client(c)
                trees[t].last_focus = n.data.id
                if treetile.rotate_on_remove then
                    n.parent:rotate_all()
                end
            else
                trees[t].root = node.parent:remove_client(c)
                trees[t].last_focus = trees[t].root.data.id
            end
        else
            trees[t].root:remove(cleanup)
            trees[t].root = nil
            trees[t].last_focus = nil
            return
        end
    end
end

-- Update the geometries of all clients.
local function update_clients(t, geometry)
    trees[t].root:apply_geometry({
        x      = geometry.x + t.gap,
        y      = geometry.y + t.gap,
        width  = geometry.width,
        height = geometry.height,
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

    local added, moved, removed = full_diff(trees[t].clients, p.clients)
    print("added:", #added)
    print("moved:", #moved)
    print("removed:", #removed)

    if #p.clients == #trees[t].clients and #moved == 2 then
        local nodes = trees[t].root:find_if { match(moved[1]), match(moved[2]) }
        nodes[1].data.id, nodes[2].data.id = nodes[2].data.id, nodes[1].data.id
        force_update = true
    end

    if trees[t].root then
        prune_clients(t, removed)
    end

    if #added > 0 then
        -- TODO: find a better to handle this
        local focus = treetile.new_focus
                and awful.client.focus.history.get(p.screen, 1)
                or capi.client.focus

        if not focus or focus.floating then
            focus = trees[t].last_focus
        end

        add_clients(t, added, focus)
    end

    if trees[t].root and (#added + #moved + #removed > 0 or force_update) then
        update_clients(t, p.workarea)
    end

    if trees[t].root and #added + #moved + #removed > 0 then
        print("tree:", t.name)
        trees[t].root:show_detailed()
    end

    force_update = false
    trees[t].clients = p.clients
    trees[t].last_p = p
end

function treetile.resize_client(inc)
    -- inc: percentage of change: 0.01, 0.99 with +/-
    local c = capi.client.focus
    local t = (capi.screen[c.screen].selected_tag
            or awful.tag.selected(capi.mouse.screen))
    if not trees[t].root then return end

    local node = trees[t].root:find_if(match(c))
    if not node and node.parent then return end

    node.parent.data.ratio = math.min(math.max(node.parent.data.ratio + inc, 1), 0)
    update_clients(t, trees[t].last_p.workarea)
end

-- function treetile.mouse_resize_handler(c, corner, x, y)
--     local t = (capi.screen[c.screen].selected_tag
--             or awful.tag.selected(capi.mouse.screen))
--     if not trees[t].root then return end
--
--     local node = trees[t].root:find_if(match(c))
--     local cl = node.data.id
--     cl.x = x
--     cl.y = y
-- end

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

    local node = c and trees[t].root:find_if(match(c)).parent
    if node then
        node:rotate()
        update_clients(t, trees[t].last_p.workarea)
    end
end

function treetile.rotate_all(c)
    local t = c and c.screen.selected_tag
            or awful.screen.focused().selected_tag

    local node = c and trees[t].root:find_if(match(c)).parent
    if node then
        node:rotate_all()
        update_clients(t, trees[t].last_p.workarea)
    end
end

function treetile.swap(c)
    local t = c and c.screen.selected_tag
            or awful.screen.focused().selected_tag

    local node = c and trees[t].root:find_if(match(c)).parent
    if node then
        node:swap_children()
        update_clients(t, trees[t].last_p.workarea)
    end
end

function treetile.swap_all(c)
    local t = c and c.screen.selected_tag
            or awful.screen.focused().selected_tag

    local node = c and trees[t].root:find_if(match(c)).parent
    if node then
        node:apply(function(n)
            if not n.parent or n.parent.right == n then n:swap_children() end
        end)
        update_clients(t, trees[t].last_p.workarea)
    end
end

-- }}}

return treetile
