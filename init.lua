--
-- Minetest advmarkers mod
--
-- © 2019 by luk3yx
--

advmarkers = {
    dated_death_markers = false
}

-- Get the mod storage
local storage = minetest.get_mod_storage()
local hud = {}
local use_sscsm = false
advmarkers.last_coords = {}

-- Convert positions to/from strings
local function pos_to_string(pos)
    if type(pos) == 'table' then
        pos = minetest.pos_to_string(vector.round(pos))
    end
    if type(pos) == 'string' then
        return pos
    end
end

local function string_to_pos(pos)
    if type(pos) == 'string' then
        pos = minetest.string_to_pos(pos)
    end
    if type(pos) == 'table' then
        return vector.round(pos)
    end
end

local get_player_by_name    = minetest.get_player_by_name
local get_connected_players = minetest.get_connected_players
if minetest.get_modpath('cloaking') then
    get_player_by_name      = cloaking.get_player_by_name
    get_connected_players   = cloaking.get_connected_players
end

-- Adds compatibility alias and coerces the first argument to a player object
local is_player = minetest.is_player
local function add_compat_function(func_name)
    local func = assert(advmarkers[func_name])
    local function wrapper(player, ...)
        if not is_player(player) then
            player = get_player_by_name(player)
            if not player then return end
        end
        return func(player, ...)
    end

    advmarkers[func_name] = wrapper
    advmarkers[func_name:gsub('waypoint', 'marker')] = wrapper
end

-- Set the HUD position
function advmarkers.set_hud_pos(player, pos, title)
    local name = player:get_player_name()
    pos = string_to_pos(pos)
    if not pos then return end
    if not title then
        title = pos.x .. ', ' .. pos.y .. ', ' .. pos.z
    end
    if hud[name] then
        player:hud_change(hud[name], 'name',      title)
        player:hud_change(hud[name], 'world_pos', pos)
    else
        hud[name] = player:hud_add({
            hud_elem_type = 'waypoint',
            name          = title,
            text          = 'm',
            number        = 0xbf360c,
            world_pos     = pos
        })
    end
    minetest.chat_send_player(name, 'Waypoint set to ' ..
        minetest.colorize('#bf360c', title))
    return true
end
add_compat_function('set_hud_pos')

-- Get and save player storage
local function get_storage(player)
    local raw = player:get_meta():get_string('advmarkers:waypoints') or ''
    local version = raw:sub(1, 1)
    if version == '0' then
        -- Player meta: 0{"Marker name": {"x": 1, "y": 2, "z": 3}}
        return minetest.parse_json(raw:sub(2))
    elseif version == '' then
        -- Mod storage: return {["marker-Marker name"] = "(1,2,3)"}
        local pname = player:get_player_name()
        local res = {}
        raw = minetest.deserialize(storage:get_string(pname))
        if raw then
            for name, pos in pairs(raw) do
                if name:sub(1, 7) == 'marker-' then
                    res[name:sub(8)] = string_to_pos(pos)
                end
            end
        end
        return res
    end
end

local function save_storage(player, markers)
    local name = player:get_player_name()
    local meta = player:get_meta()
    if next(markers) then
        meta:set_string('advmarkers:waypoints', '0' ..
            minetest.write_json(markers))
    else
        meta:set_string('advmarkers:waypoints', '')
    end
    storage:set_string(name, '')

    if use_sscsm and sscsm.has_sscsms_enabled(name) then
        sscsm.com_send(name, 'advmarkers:update', markers)
    end

    return true
end

-- Add a waypoint
function advmarkers.set_waypoint(player, pos, name)
    local data = get_storage(player)
    data[tostring(name)] = string_to_pos(pos)
    return save_storage(player, data)
end
add_compat_function('set_waypoint')

-- Delete a waypoint
function advmarkers.delete_waypoint(player, name)
    local data = get_storage(player)
    data[name] = nil
    return save_storage(player, data)
end
add_compat_function('delete_waypoint')

-- Get a waypoint
function advmarkers.get_waypoint(player, name)
    return get_storage(player)[name]
end
add_compat_function('get_waypoint')

-- Rename a waypoint
function advmarkers.rename_waypoint(player, oldname, newname)
    oldname, newname = tostring(oldname), tostring(newname)
    local pos = advmarkers.get_waypoint(player, oldname)
    if not pos or not advmarkers.set_waypoint(player, pos, newname) then
        return
    end
    if oldname ~= newname then
        advmarkers.delete_waypoint(player, oldname)
    end
    return true
end
add_compat_function('rename_waypoint')

-- Get waypoint names
function advmarkers.get_waypoint_names(player, sorted)
    local data = get_storage(player)
    local res = {}
    for name, _ in pairs(data) do
        table.insert(res, name)
    end
    if sorted or sorted == nil then table.sort(res) end
    return res
end
add_compat_function('get_waypoint_names')

-- Display a waypoint
function advmarkers.display_waypoint(player, name)
    return advmarkers.set_hud_pos(player, advmarkers.get_waypoint(player, name),
        name)
end
add_compat_function('display_waypoint')

-- Export waypoints
function advmarkers.export(player, raw)
    local s = {}
    for name, pos in pairs(get_storage(player)) do
        s['marker-' .. name] = pos_to_string(pos)
    end

    if raw == 'M' then
        s = minetest.compress(minetest.serialize(s))
        s = 'M' .. minetest.encode_base64(s)
    elseif not raw then
        s = minetest.compress(minetest.write_json(s))
        s = 'J' .. minetest.encode_base64(s)
    end
    return s
end
add_compat_function('export')

-- Import waypoints - Note that this won't import strings made by older
--  versions of the CSM.
function advmarkers.import(player, s)
    if type(s) ~= 'table' then
        if s:sub(1, 1) ~= 'J' then return end
        s = minetest.decode_base64(s:sub(2))
        local success, msg = pcall(minetest.decompress, s)
        if not success then return end
        s = minetest.parse_json(msg)
        if type(s) ~= 'table' then return end
    end

    -- Parse the exported table
    local data = get_storage(player)
    for field, pos in pairs(s) do
        if type(field) == 'string' and type(pos) == 'string' and
                field:sub(1, 7) == 'marker-' then
            pos = string_to_pos(pos)
            if pos then
                -- Prevent collisions
                local name = field:sub(8)
                local c = 0
                while data[name] and not vector.equals(data[name], pos) and
                        c < 50 do
                    name = name .. '_'
                    c = c + 1
                end

                -- Sanity check
                if c < 50 then
                    data[name] = string_to_pos(pos)
                end
            end
        end
    end
    return save_storage(player, data)
end
add_compat_function('import')

-- Get the waypoints formspec
local formspec_list = {}
local selected_name = {}
function advmarkers.display_formspec(player)
    local pname = player:get_player_name()
    local formspec = 'size[5.25,8]' ..
                     'label[0,0;Waypoint list]' ..
                     'button_exit[0,7.5;1.3125,0.5;display;Display]' ..
                     'button[1.3125,7.5;1.3125,0.5;teleport;Teleport]' ..
                     'button[2.625,7.5;1.3125,0.5;rename;Rename]' ..
                     'button[3.9375,7.5;1.3125,0.5;delete;Delete]' ..
                     'textlist[0,0.75;5,6;marker;'

    -- Iterate over all the waypoints
    local selected = 1
    formspec_list[pname] = advmarkers.get_waypoint_names(player)

    for id, name in ipairs(formspec_list[pname]) do
        if id > 1 then formspec = formspec .. ',' end
        if not selected_name[pname] then selected_name[pname] = name end
        if name == selected_name[pname] then selected = id end
        formspec = formspec .. '##' .. minetest.formspec_escape(name)
    end

    -- Close the text list and display the selected waypoint position
    formspec = formspec .. ';' .. tostring(selected) .. ']'
    local pos = selected_name[pname] and
            advmarkers.get_waypoint(player, selected_name[pname])
    if pos then
        formspec = formspec .. 'label[0,6.75;Waypoint position: ' ..
            minetest.formspec_escape(tostring(pos.x) .. ', ' ..
            tostring(pos.y) .. ', ' .. tostring(pos.z)) .. ']'
    else
        -- Draw over the buttons
        formspec = formspec ..
            'button_exit[0,7.5;5.25,0.5;quit;Close dialog]' ..
            'label[0,6.75;No waypoints. Add one with "/add_wp".]'
    end

    -- Display the formspec
    return minetest.show_formspec(pname, 'advmarkers-ssm', formspec)
end
add_compat_function('display_formspec')

-- Get waypoint position
function advmarkers.get_chatcommand_pos(player, pos)
    local pname = player:get_player_name()

    -- Validate the position
    if pos == 'h' or pos == 'here' then
        pos = player:get_pos()
    elseif pos == 't' or pos == 'there' then
        if not advmarkers.last_coords[pname] then
            return false, 'No-one has used ".coords" and you have not died!'
        end
        pos = advmarkers.last_coords[pname]
    else
        pos = string_to_pos(pos)
        if not pos then
            return false, 'Invalid position!'
        end
    end
    return pos
end
add_compat_function('get_chatcommand_pos')

local function register_chatcommand_alias(old, ...)
    local def = assert(minetest.registered_chatcommands[old])
    def.name = nil
    for i = 1, select('#', ...) do
        minetest.register_chatcommand(select(i, ...), table.copy(def))
    end
end

-- Open the waypoints GUI
minetest.register_chatcommand('mrkr', {
    params      = '',
    description = 'Open the advmarkers GUI',
    func = function(pname, param)
        if param == '' then
            advmarkers.display_formspec(pname)
        else
            local pos, err = advmarkers.get_chatcommand_pos(pname, param)
            if not pos then
                return false, err
            end
            if not advmarkers.set_hud_pos(pname, pos) then
                return false, 'Error setting the waypoint!'
            end
        end
    end
})

register_chatcommand_alias('mrkr', 'wp', 'wps', 'waypoint', 'waypoints')

-- Add a waypoint
minetest.register_chatcommand('add_mrkr', {
    params      = '<pos / "here" / "there"> <name>',
    description = 'Adds a waypoint.',
    func = function(pname, param)
        -- Get the parameters
        local s, e = param:find(' ')
        if not s or not e then
            return false, 'Invalid syntax! See /help add_mrkr for more info.'
        end
        local raw_pos = param:sub(1, s - 1)
        local name = param:sub(e + 1)

        -- Get the position
        local pos, err = advmarkers.get_chatcommand_pos(pname, raw_pos)
        if not pos then
            return false, err
        end

        -- Validate the name
        if not name or #name < 1 then
            return false, 'Invalid name!'
        end

        -- Set the waypoint
        return advmarkers.set_waypoint(pname, pos, name), 'Done!'
    end
})

register_chatcommand_alias('add_mrkr', 'add_wp', 'add_waypoint')

-- Set the HUD
minetest.register_on_player_receive_fields(function(player, formname, fields)
    local pname = player:get_player_name()
    if formname == 'advmarkers-ignore' then
        return true
    elseif formname ~= 'advmarkers-ssm' then
        return
    end
    local name = false
    if fields.marker then
        local event = minetest.explode_textlist_event(fields.marker)
        if event.index then
            name = formspec_list[pname][event.index]
        end
    else
        name = selected_name[pname]
    end

    if name then
        if fields.display then
            if not advmarkers.display_waypoint(player, name) then
                minetest.chat_send_player(pname, 'Error displaying waypoint!')
            end
        elseif fields.rename then
            minetest.show_formspec(pname, 'advmarkers-ssm', 'size[6,3]' ..
                'label[0.35,0.2;Rename waypoint]' ..
                'field[0.3,1.3;6,1;new_name;New name;' ..
                minetest.formspec_escape(name) .. ']' ..
                'button[0,2;3,1;cancel;Cancel]' ..
                'button[3,2;3,1;rename_confirm;Rename]')
        elseif fields.rename_confirm then
            if fields.new_name and #fields.new_name > 0 then
                if advmarkers.rename_waypoint(pname, name, fields.new_name) then
                    selected_name[pname] = fields.new_name
                else
                    minetest.chat_send_player(pname, 'Error renaming waypoint!')
                end
                advmarkers.display_formspec(pname)
            else
                minetest.chat_send_player(pname,
                    'Please enter a new name for the waypoint.'
                )
            end
        elseif fields.teleport then
            minetest.show_formspec(pname, 'advmarkers-ssm', 'size[6,2.2]' ..
                'label[0.35,0.25;' .. minetest.formspec_escape(
                    'Teleport to a waypoint\n - ' .. name
                ) .. ']' ..
                'button[0,1.25;3,1;cancel;Cancel]' ..
                'button_exit[3,1.25;3,1;teleport_confirm;Teleport]')
        elseif fields.teleport_confirm then
            -- Teleport with /teleport
            local pos = advmarkers.get_waypoint(pname, name)
            if not pos then
                minetest.chat_send_player(pname,
                    'Error teleporting to waypoint!')
            elseif minetest.check_player_privs(pname, 'teleport') then
                player:set_pos(pos)
                minetest.chat_send_player(pname, 'Teleported to waypoint "' ..
                    name .. '".')
            else
                minetest.chat_send_player(pname, 'Insufficient privileges!')
            end
        elseif fields.delete then
            minetest.show_formspec(pname, 'advmarkers-ssm', 'size[6,2]' ..
                'label[0.35,0.25;Are you sure you want to delete this ' ..
                    'waypoint?]' ..
                'button[0,1;3,1;cancel;Cancel]' ..
                'button[3,1;3,1;delete_confirm;Delete]')
        elseif fields.delete_confirm then
            advmarkers.delete_waypoint(pname, name)
            selected_name[pname] = nil
            advmarkers.display_formspec(pname)
        elseif fields.cancel then
            advmarkers.display_formspec(pname)
        elseif name ~= selected_name[pname] then
            selected_name[pname] = name
            if not fields.quit then
                advmarkers.display_formspec(pname)
            end
        end
    elseif fields.display or fields.delete then
        minetest.chat_send_player(pname, 'Please select a waypoint.')
    end
    return true
end)

-- Auto-add waypoints on death.
minetest.register_on_dieplayer(function(player)
    local name
    if advmarkers.dated_death_markers then
        name = os.date('Death on %Y-%m-%d %H:%M:%S')
    else
        name = 'Death waypoint'
    end
    local pos  = player:get_pos()
    advmarkers.last_coords[player] = pos
    advmarkers.set_waypoint(player, pos, name)
    minetest.chat_send_player(player:get_player_name(),
        'Added waypoint "' .. name .. '".')
end)

-- Allow string exporting
minetest.register_chatcommand('mrkr_export', {
    params      = '',
    description = 'Exports an advmarkers string containing all your waypoints.',
    func = function(name, param)
        local export
        if param == 'old' then
            export = advmarkers.export(name, 'M')
        else
            export = advmarkers.export(name)
        end
        minetest.show_formspec(name, 'advmarkers-ignore',
            'field[_;Your waypoint export string;' ..
            minetest.formspec_escape(export) .. ']')
    end
})

register_chatcommand_alias('mrkr_export', 'wp_export', 'waypoint_export')

-- String importing
minetest.register_chatcommand('mrkr_import', {
    params      = '<advmarkers string>',
    description = 'Imports an advmarkers string. This will not overwrite ' ..
        'existing waypoints that have the same name.',
    func = function(name, param)
        if advmarkers.import(name, param) then
            return true, 'Waypoints imported!'
        else
            return false, 'Invalid advmarkers string!'
        end
    end
})

register_chatcommand_alias('mrkr_import', 'wp_import', 'waypoint_import')

-- Chat channels .coords integration.
-- You do not need to have chat channels installed for this to work.
local function get_coords(msg, strict)
    local str = 'Current Position: %-?[0-9]+, %-?[0-9]+, %-?[0-9]+%.'
    if strict then
        str = '^' .. str
    end
    local s, e = msg:find(str)
    local pos = false
    if s and e then
        pos = string_to_pos(msg:sub(s + 18, e - 1))
    end
    return pos
end

-- Get global co-ords
table.insert(minetest.registered_on_chat_messages, 1, function(_, msg)
    if msg:sub(1, 1) == '/' then return end
    local pos = get_coords(msg, true)
    if pos then
        advmarkers.last_coords = {}
        for _, player in ipairs(get_connected_players()) do
            advmarkers.last_coords[player:get_player_name()] = pos
        end
    end
end)

-- Override chat_send_player to get PMed co-ords etc
local old_chat_send_player = minetest.chat_send_player
function minetest.chat_send_player(name, msg, ...)
    if type(name) == 'string' and type(msg) == 'string' and
      get_player_by_name(name) then
        local pos = get_coords(msg)
        if pos then
            advmarkers.last_coords[name] = pos
        end
    end
    return old_chat_send_player(name, msg, ...)
end

-- Clean up variables if a player leaves
minetest.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    hud[name] = nil
    formspec_list[name] = nil
    selected_name[name] = nil
    advmarkers.last_coords[name] = nil
end)

-- Add '/mrkrthere'
minetest.register_chatcommand('mrkrthere', {
    params      = '',
    description = 'Alias for "/mrkr there".',
    func = function(name, _)
        return minetest.registered_chatcommands['mrkr'].func(name, 'there')
    end
})

minetest.register_chatcommand('clrmrkr', {
    params = '',
    description = 'Hides the displayed waypoint.',
    func = function(name, _)
        local player = minetest.get_player_by_name(name)
        if not hud[name] or not player then
            return false, 'No waypoint is currently being displayed!'
        end
        player:hud_remove(hud[name])
        hud[name] = nil
        return true, 'Hidden the currently displayed waypoint.'
    end,
})

register_chatcommand_alias('clrmrkr', 'clear_marker', 'clrwp',
    'clear_waypoint')

-- SSCSM support
if not minetest.global_exists('sscsm') or not sscsm.register then
    return
end

if not sscsm.register_on_com_receive then
    minetest.log('warning', '[advmarkers] The SSCSM mod is outdated!')
    return
end

use_sscsm = true
sscsm.register({
    name = 'advmarkers',
    file = minetest.get_modpath('advmarkers') .. '/sscsm.lua',
})

-- SSCSM communication
-- TODO: Make this use a table (or multiple channels).
sscsm.register_on_com_receive('advmarkers:cmd', function(name, param)
    if type(param) ~= 'string' then
        return
    end

    local cmd = param:sub(1, 1)
    if cmd == 'D' then
        -- D: Delete
        advmarkers.delete_waypoint(name, param:sub(2))
    elseif cmd == 'S' then
        -- S: Set
        local s, e = param:find(' ', nil, true)
        if s and e then
            local pos = string_to_pos(param:sub(2, s - 1))
            if pos then
                advmarkers.set_waypoint(name, pos, param:sub(e + 1))
            end
        end
    elseif cmd == '0' then
        -- 0: Display
        if not advmarkers.display_waypoint(name, param:sub(2)) then
            minetest.chat_send_player(name, 'Error displaying waypoint!')
        end
    end
end)

-- Send waypoint list once SSCSMs are loaded.
sscsm.register_on_sscsms_loaded(function(name)
    local player = minetest.get_player_by_name(name)
    sscsm.com_send(name, 'advmarkers:update', get_storage(player))
end)
