--
-- Minetest advmarkers mod
--
-- © 2023 by luk3yx
--

-- luacheck: ignore 432/player 43/ctx

local S = minetest.get_translator("advmarkers")
local gui = flow.widgets

local function cancel(_, ctx)
    ctx.form.mrkr_name = nil
    ctx.edit = nil
    ctx.edit_err = nil
    ctx.new_waypoint = nil
    ctx.err_msg = nil
    ctx.last_coords = nil
    ctx.form.x, ctx.form.y, ctx.form.z = nil, nil, nil
    ctx.form.pos_dropdown = nil
    ctx.form.wp_colour = nil
    return true
end

local colours = {0xbf360c, 0xff2222, 0xffa500, 0xffff00, 0x22ff22, 0x0000ff,
    0x00ffff, 0x000000, 0xffffff}
local colour_names = {
    S("Default"), S("Red"), S("Orange"), S("Yellow"), S("Green"), S("Blue"),
    S("Cyan"), S("Black"), S("White"),
}

local function hex(colour)
    return ("#%06xaa"):format(colour)
end

local function colour_picker(ctx)
    return gui.VBox{
        spacing = 0,
        gui.Label{label = S("Colour:")},
        gui.HBox{
            gui.Dropdown{
                name = "wp_colour", index_event = true, expand = true,
                items = colour_names,
            },
            gui.Box{
                w = 0.8, h = 0.8, color = hex(
                    colours[ctx.form.wp_colour] or colours[1]
                )
            },
        },
    }
end

local waypoints_gui = flow.make_gui(function(player, ctx)
    if ctx.new_waypoint then
        ctx.last_coords = ctx.last_coords or
            advmarkers.last_coords[player:get_player_name()]
        local last_coords = ctx.last_coords
        return gui.VBox{
            min_w = 7, min_h = 9,
            gui.Label{label = S("New waypoint")},
            gui.Field{
                name = "mrkr_search",
                label = S("Waypoint name:"),
            },
            gui.VBox{
                spacing = 0,
                gui.Label{label = S("Position:")},
                gui.Dropdown{
                    name = "pos_dropdown",
                    index_event = true,
                    items = {S("Current position"), S("Custom"),
                        last_coords and S("@1, @2, @3", last_coords.x,
                            last_coords.y, last_coords.z) or nil},
                }
            },
            ctx.form.pos_dropdown == 2 and gui.HBox{
                gui.Field{name = "x", label = S("X:"), w = 1, expand = true},
                gui.Field{name = "y", label = S("Y:"), w = 1, expand = true},
                gui.Field{name = "z", label = S("Z:"), w = 1, expand = true},
            } or gui.Nil{},
            colour_picker(ctx),
            gui.Textarea{
                default = ctx.err_msg or "", w = 5, h = 1, expand = true,
                visible = ctx.err_msg ~= nil
            },
            gui.HBox{
                gui.Button{
                    label = S("Cancel"), w = 1, expand = true,
                    on_event = cancel,
                },
                gui.Button{
                    label = S("Create"), w = 1, expand = true,
                    on_event = function(player, ctx)
                        local wp_name = ctx.form.mrkr_search
                        if advmarkers.get_waypoint(player, wp_name) then
                            ctx.err_msg = S("A waypoint with that name " ..
                                "already exists!")
                            return true
                        end

                        local pos
                        if ctx.form.pos_dropdown == 1 then
                            pos = player:get_pos()
                        elseif ctx.form.pos_dropdown == 2 then
                            pos = {
                                x = tonumber(ctx.form.x),
                                y = tonumber(ctx.form.y),
                                z = tonumber(ctx.form.z),
                            }
                        elseif ctx.form.pos_dropdown == 3 then
                            pos = last_coords
                        end

                        local ok, err = advmarkers.set_waypoint(player, pos,
                            wp_name, colours[ctx.form.wp_colour])

                        if ok then
                            ctx.selected_wp = wp_name
                            ctx.wp_pos, ctx.wp_colour = advmarkers.get_waypoint(
                                player, wp_name
                            )
                            cancel(player, ctx)
                        else
                            ctx.err_msg = err
                        end
                        return true
                    end,
                },
            },
        }
    elseif ctx.delete then
        return gui.VBox{
            min_w = 6,
            gui.Label{label = S("Are you sure?")},
            gui.HBox{
                gui.Button{
                    label = S("Cancel"), w = 1, expand = true,
                    on_event = function(_, ctx)
                        ctx.delete = nil
                        return true
                    end,
                },
                gui.Style{selectors = {"delete_wp"}, props = {bgcolor = "red"}},
                gui.Button{
                    label = S("Delete"), w = 1, expand = true,
                    name = "delete_wp",
                    on_event = function(player, ctx)
                        advmarkers.delete_waypoint(player, ctx.selected_wp)
                        ctx.delete = nil
                        ctx.selected_wp = nil
                        ctx.wp_pos = nil
                        ctx.wp_colour = nil
                        return cancel(player, ctx)
                    end,
                },
            },
        }
    elseif ctx.edit then
        return gui.VBox{
            min_w = 7, min_h = 9,
            gui.Label{label = S("Edit waypoint")},
            gui.Field{
                name = "mrkr_name", w = 5,
                label = S("Waypoint name:"),
                default = ctx.selected_wp,
            },
            colour_picker(ctx),
            gui.Label{
                label = S("Another waypoint has that name!"),
                visible = ctx.edit_err or false,
            },
            gui.Spacer{},
            gui.Button{
                label = S("Delete waypoint"),
                on_event = function(_, ctx)
                    ctx.delete = true
                    return true
                end,
            },
            gui.HBox{
                gui.Button{
                    label = S("Cancel"), w = 1, expand = true, on_event = cancel
                },
                gui.Button{
                    label = S("Save"), w = 1, expand = true,
                    on_event = function(player, ctx)
                        local colour = colours[ctx.form.wp_colour]
                        if advmarkers.rename_waypoint(player, ctx.selected_wp,
                                ctx.form.mrkr_name, colour) then
                            ctx.selected_wp = ctx.form.mrkr_name
                            ctx.wp_colour = colour
                            return cancel(player, ctx)
                        end
                        ctx.edit_err = true
                        return true
                    end,
                },
            },
        }
    end

    local vbox = {name = "waypoints", h = 5.8}
    local search = (ctx.form.mrkr_search or ""):lower()
    for i, wp_name in ipairs(advmarkers.get_waypoint_names(player)) do
        if search == "" or wp_name:lower():find(search, 1, true) then
            local pos, colour = advmarkers.get_waypoint(player, wp_name)

            -- Select the shown waypoint by default
            if not ctx.selected_wp and
                    advmarkers.is_waypoint_shown(player, wp_name) then
                ctx.selected_wp = wp_name
                ctx.wp_pos = pos
                ctx.wp_colour = colour
            end

            local selected = ctx.selected_wp == wp_name
            vbox[#vbox + 1] = gui.Stack{
                bgcolor = selected and hex(colour) or "#5e5c64",
                gui.Label{
                    label = (selected or colour == colours[1])
                        and wp_name or minetest.colorize(hex(colour), wp_name),
                    w = 5, padding = 0.2
                },
                gui.ImageButton{
                    name = "wp_" .. i,
                    drawborder = false, w = 0, h = 0,
                    on_event = function(_, ctx)
                        ctx.selected_wp = wp_name
                        ctx.wp_pos = pos
                        ctx.wp_colour = colour
                        return true
                    end,
                },
                gui.Tooltip{
                    gui_element_name = "wp_" .. i,
                    tooltip_text = S("Position: @1, @2, @3", pos.x, pos.y,
                        pos.z)
                }
            }
        end
    end

    if #vbox == 0 then
        vbox[1] = gui.Label{label = S("No waypoints found!")}
        if search ~= "" then
            vbox[2] = gui.Button{
                label = S("Clear search query"),
                on_event = function(_, ctx)
                    ctx.form.mrkr_search = ""
                    return true
                end
            }
        end
    end

    local actions
    if ctx.wp_pos then
        local wp_shown = ctx.selected_wp and
            advmarkers.is_waypoint_shown(player, ctx.selected_wp)
        actions = {
            wp_shown and gui.Button{
                label = S("Hide"), w = 1, expand = true,
                on_event = function(player)
                    advmarkers.clear_hud(player)
                    return true
                end,
            } or gui.Button{
                label = S("Show"), w = 1, expand = true,
                on_event = function(player, ctx)
                    advmarkers.display_waypoint(player, ctx.selected_wp)
                    return true
                end,
            },
            gui.Button{
                label = S("Edit"), w = 1, expand = true,
                on_event = function(_, ctx)
                    ctx.form.wp_colour = table.indexof(colours, ctx.wp_colour)
                    ctx.edit = true
                    return true
                end,
            },
            minetest.check_player_privs(player, "teleport") and gui.ButtonExit{
                label = S("Teleport"), w = 1, expand = true,
                on_event = function(player, ctx)
                    local pname = player:get_player_name()
                    if minetest.check_player_privs(pname, "teleport") then
                        player:set_pos(ctx.wp_pos)
                        minetest.chat_send_player(pname,
                            'Teleported to waypoint "' .. ctx.selected_wp ..
                            '".')
                    end
                end,
            } or gui.Nil{},
        }
    else
        actions = {
            gui.ButtonExit{
                label = S("Close dialog"), expand = true
            }
        }
    end

    return gui.VBox{
        min_w = 7,
        gui.Label{label = S("Waypoint list")},
        gui.HBox{
            gui.Field{name = "mrkr_search", expand = true},
            gui.Button{label = S("Search")},
            gui.Button{
                name = "new_waypoint", label = S("+"), w = 0.8,
                on_event = function()
                    ctx.new_waypoint = true
                    return true
                end,
            },
            gui.Tooltip{
                gui_element_name = "new_waypoint",
                tooltip_text = S("Add new waypoint")
            },
        },
        gui.ScrollableVBox(vbox),
        gui.Label{
            w = 5,
            label = ctx.wp_pos and S("Waypoint position: @1, @2, @3",
                ctx.wp_pos.x, ctx.wp_pos.y, ctx.wp_pos.z) or
                S("No waypoint selected")
        },
        gui.HBox(actions)
    }
end)

function advmarkers.display_formspec(player)
    waypoints_gui:show(player)
end

if minetest.global_exists("sway") then
    local pagename = "advmarkers"
    sway.register_page(pagename .. ":waypoints", {
        title = S("Waypoints"),
        get = function(_, player, _)
            return sway.Form{
                waypoints_gui:embed{
                    player = player,
                    name = pagename,
                }
            }
        end
    })
end
