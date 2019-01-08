--
-- Minetest advmarkers mod
--
-- The advmarkers CSM ported to a server-side mod
--

advmarkers = {}

-- Get the mod storage
local storage = minetest.get_mod_storage()
local hud = {}
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

-- Get player name or object
local get_player_by_name    = minetest.get_player_by_name
local get_connected_players = minetest.get_connected_players
if minetest.get_modpath('cloaking') then
    get_player_by_name      = cloaking.get_player_by_name
    get_connected_players   = cloaking.get_connected_players
end

local function get_player(player, t)
    local name
    if type(player) == 'string' then
        name = player
        if t ~= 0 then
            player = get_player_by_name(name)
        end
    else
        name = player:get_player_name()
    end
    if t == 0 then
        return name
    elseif t == 1 then
        return player
    end
    return name, player
end

-- Set the HUD position
function advmarkers.set_hud_pos(player, pos, title)
    local name, player = get_player(player)
    pos = string_to_pos(pos)
    if not player or not pos then return end
    if not title then
        title = pos.x .. ', ' .. pos.y .. ', ' .. pos.z
    end
    if hud[player] then
        player:hud_change(hud[player], 'name',      title)
        player:hud_change(hud[player], 'world_pos', pos)
    else
        hud[player] = player:hud_add({
            hud_elem_type = 'waypoint',
            name          = title,
            text          = 'm',
            number        = 0xbf360c,
            world_pos     = pos
        })
    end
    minetest.chat_send_player(name, 'Marker set to ' .. title)
    return true
end

-- Get and save player storage
local function get_storage(name)
    name = get_player(name, 0)
    return minetest.deserialize(storage:get_string(name)) or {}
end

local function save_storage(name, data)
    name = get_player(name, 0)
    if type(data) == 'table' then
        data = minetest.serialize(data)
    end
    if type(data) ~= 'string' then return end
    if #data > 0 then
        storage:set_string(name, data)
    else
        storage:set_string(name, '')
    end
    return true
end

-- Add a marker
function advmarkers.set_marker(player, pos, name)
    pos = pos_to_string(pos)
    if not pos then return end
    local data = get_storage(player)
    data['marker-' .. tostring(name)] = pos
    return save_storage(player, data)
end

-- Delete a marker
function advmarkers.delete_marker(player, name)
    local data = get_storage(player)
    data['marker-' .. tostring(name)] = nil
    return save_storage(player, data)
end

-- Get a marker
function advmarkers.get_marker(player, name)
    local data = get_storage(player)
    return string_to_pos(data['marker-' .. tostring(name)])
end

-- Rename a marker and re-interpret the position.
function advmarkers.rename_marker(player, oldname, newname)
    player = get_player(player, 0)
    oldname, newname = tostring(oldname), tostring(newname)
    local pos = advmarkers.get_marker(player, oldname)
    if not pos or not advmarkers.set_marker(player, pos, newname) then
        return
    end
    if oldname ~= newname then
        advmarkers.delete_marker(player, oldname)
    end
    return true
end

-- Display a marker
function advmarkers.display_marker(player, name)
    return advmarkers.set_hud_pos(player, advmarkers.get_marker(player, name),
        name)
end

-- Export markers
function advmarkers.export(player, raw)
    local s = get_storage(player)
    if raw == 'M' then
        s = minetest.compress(minetest.serialize(s))
        s = 'M' .. minetest.encode_base64(s)
    elseif not raw then
        s = minetest.compress(minetest.write_json(s))
        s = 'J' .. minetest.encode_base64(s)
    end
    return s
end

-- Import markers - Note that this won't import strings made by older versions
--  of the CSM.
function advmarkers.import(player, s)
    if type(s) ~= 'table' then
        if s:sub(1, 1) ~= 'J' then return end
        s = minetest.decode_base64(s:sub(2))
        local success, msg = pcall(minetest.decompress, s)
        if not success then return end
        s = minetest.parse_json(msg)
    end

    -- Iterate over markers to preserve existing ones and check for errors.
    if type(s) == 'table' then
        local data = get_storage(player)
        for name, pos in pairs(s) do
            if type(name) == 'string' and type(pos) == 'string' and
              name:sub(1, 7) == 'marker-' and minetest.string_to_pos(pos) and
              data[name] ~= pos then
                -- Prevent collisions
                local c = 0
                while data[name] and c < 50 do
                    name = name .. '_'
                    c = c + 1
                end

                -- Sanity check
                if c < 50 then
                    data[name] = pos
                end
            end
        end
        return save_storage(player, data)
    end
end

-- Get the markers formspec
local formspec_list = {}
local selected_name = {}
function advmarkers.display_formspec(player)
    player = get_player(player, 0)
    if not get_player_by_name(player) then return end
    local formspec = 'size[5.25,8]' ..
                     'label[0,0;Marker list]' ..
                     'button_exit[0,7.5;1.3125,0.5;display;Display]' ..
                     'button[1.3125,7.5;1.3125,0.5;teleport;Teleport]' ..
                     'button[2.625,7.5;1.3125,0.5;rename;Rename]' ..
                     'button[3.9375,7.5;1.3125,0.5;delete;Delete]' ..
                     'textlist[0,0.75;5,6;marker;'

    -- Iterate over all the markers
    local id = 0
    local selected = 1
    formspec_list[player] = {}
    for name, pos in pairs(get_storage(player)) do
        if name:sub(1, 7) == 'marker-' then
            id = id + 1
            if id > 1 then
                formspec = formspec .. ','
            end
            name = name:sub(8)
            if not selected_name[player] then
                selected_name[player] = name
            end
            if name == selected_name[player] then
                selected = id
            end
            formspec_list[player][#formspec_list[player] + 1] = name
            formspec = formspec .. '##' .. minetest.formspec_escape(name)
        end
    end

    -- Close the text list and display the selected marker position
    formspec = formspec .. ';' .. tostring(selected) .. ']'
    if selected_name[player] then
        local pos = advmarkers.get_marker(player, selected_name[player])
        if pos then
            pos = minetest.formspec_escape(tostring(pos.x) .. ', ' ..
            tostring(pos.y) .. ', ' .. tostring(pos.z))
            pos = 'Marker position: ' .. pos
            formspec = formspec .. 'label[0,6.75;' .. pos .. ']'
        end
    else
        -- Draw over the buttons
        formspec = formspec .. 'button_exit[0,7.5;5.25,0.5;quit;Close dialog]' ..
            'label[0,6.75;No markers. Add one with "/add_mrkr".]'
    end

    -- Display the formspec
    return minetest.show_formspec(player, 'advmarkers-ssm', formspec)
end

-- Get marker position
function advmarkers.get_chatcommand_pos(player, pos)
    local pname = get_player(player, 0)

    -- Validate the position
    if pos == 'h' or pos == 'here' then
        pos = get_player(player, 1):get_pos()
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

-- Open the markers GUI
minetest.register_chatcommand('mrkr', {
    params      = '',
    description = 'Open the advmarkers GUI',
    func = function(pname, param)
        if #param:gsub(' ', '') > 0 then
            local pos, err = advmarkers.get_chatcommand_pos(pname, param)
            if not pos then
                return false, err
            end
            if not advmarkers.set_hud_pos(pname, pos) then
                return false, 'Error setting the marker!'
            end
        else
            advmarkers.display_formspec(pname)
        end
    end
})

-- Add a marker
minetest.register_chatcommand('add_mrkr', {
    params      = '<pos / "here" / "there"> <name>',
    description = 'Adds a marker.',
    func = function(pname, param)
        -- Get the parameters
        local s, e = param:find(' ')
        if not s or not e then
            return false, 'Invalid syntax! See /help add_mrkr for more info.'
        end
        local pos  = param:sub(1, s - 1)
        local name = param:sub(e + 1)

        -- Get the position
        local pos, err = advmarkers.get_chatcommand_pos(pname, pos)
        if not pos then
            return false, err
        end

        -- Validate the name
        if not name or #name < 1 then
            return false, 'Invalid name!'
        end

        -- Set the marker
        return advmarkers.set_marker(pname, pos, name), 'Done!'
    end
})

-- Set the HUD
minetest.register_on_player_receive_fields(function(player, formname, fields)
    local pname, player = get_player(player)
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
            if not advmarkers.display_marker(player, name) then
                minetest.chat_send_player(pname, 'Error displaying marker!')
            end
        elseif fields.rename then
            minetest.show_formspec(pname, 'advmarkers-ssm', 'size[6,3]' ..
                'label[0.35,0.2;Rename marker]' ..
                'field[0.3,1.3;6,1;new_name;New name;' ..
                minetest.formspec_escape(name) .. ']' ..
                'button[0,2;3,1;cancel;Cancel]' ..
                'button[3,2;3,1;rename_confirm;Rename]')
        elseif fields.rename_confirm then
            if fields.new_name and #fields.new_name > 0 then
                if advmarkers.rename_marker(pname, name, fields.new_name) then
                    selected_name[pname] = fields.new_name
                else
                    minetest.chat_send_player(pname, 'Error renaming marker!')
                end
                advmarkers.display_formspec(pname)
            else
                minetest.chat_send_player(pname,
                    'Please enter a new name for the marker.'
                )
            end
        elseif fields.teleport then
            minetest.show_formspec(pname, 'advmarkers-ssm', 'size[6,2.2]' ..
                'label[0.35,0.25;' .. minetest.formspec_escape(
                    'Teleport to a marker\n - ' .. name
                ) .. ']' ..
                'button[0,1.25;3,1;cancel;Cancel]' ..
                'button_exit[3,1.25;3,1;teleport_confirm;Teleport]')
        elseif fields.teleport_confirm then
            -- Teleport with /teleport
            local pos = advmarkers.get_marker(pname, name)
            if not pos then
                minetest.chat_send_player(pname, 'Error teleporting to marker!')
            elseif minetest.check_player_privs(pname, 'teleport') then
                player:set_pos(pos)
                minetest.chat_send_player(pname, 'Teleported to marker "' ..
                    name .. '".')
            else
                minetest.chat_send_player(pname, 'Insufficient privileges!')
            end
        elseif fields.delete then
            minetest.show_formspec(pname, 'advmarkers-ssm', 'size[6,2]' ..
                'label[0.35,0.25;Are you sure you want to delete this marker?]' ..
                'button[0,1;3,1;cancel;Cancel]' ..
                'button[3,1;3,1;delete_confirm;Delete]')
        elseif fields.delete_confirm then
            advmarkers.delete_marker(pname, name)
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
        minetest.chat_send_player(pname, 'Please select a marker.')
    end
    return true
end)

-- Auto-add markers on death.
minetest.register_on_dieplayer(function(player)
    local name = os.date('Death on %Y-%m-%d %H:%M:%S')
    local pos  = player:get_pos()
    advmarkers.last_coords[player] = pos
    advmarkers.set_marker(player, pos, name)
    minetest.chat_send_player(player:get_player_name(),
        'Added marker "' .. name .. '".')
end)

-- Allow string exporting
minetest.register_chatcommand('mrkr_export', {
    params      = '',
    description = 'Exports an advmarkers string containing all your markers.',
    func = function(name, param)
        local export
        if param == 'old' then
            export = advmarkers.export(name, 'M')
        else
            export = advmarkers.export(name)
        end
        minetest.show_formspec(name, 'advmarkers-ignore',
            'field[_;Your marker export string;' ..
            minetest.formspec_escape(export) .. ']')
    end
})

-- String importing
minetest.register_chatcommand('mrkr_import', {
    params      = '<advmarkers string>',
    description = 'Imports an advmarkers string. This will not overwrite ' ..
        'existing markers that have the same name.',
    func = function(name, param)
        if advmarkers.import(name, param) then
            return true, 'Markers imported!'
        else
            return false, 'Invalid advmarkers string!'
        end
    end
})

-- Chat channels .coords integration.
-- You do not need to have chat channels installed for this to work.
local function get_coords(msg, strict)
    local s = 'Current Position: %-?[0-9]+, %-?[0-9]+, %-?[0-9]+%.'
    if strict then
        s = '^' .. s
    end
    local s, e = msg:find(s)
    local pos = false
    if s and e then
        pos = string_to_pos(msg:sub(s + 18, e - 1))
    end
    return pos
end

-- Get global co-ords
table.insert(minetest.registered_on_chat_messages, 1, function(name, msg)
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
    local name = get_player(player, 0)
    hud[name]                       = nil
    formspec_list[name]             = nil
    selected_name[name]             = nil
    advmarkers.last_coords[name]    = nil
end)

-- Add '/mrkrthere'
minetest.register_chatcommand('mrkrthere', {
    params      = '',
    description = 'Alias for "/mrkr there".',
    func = function(name, param)
        return minetest.registered_chatcommands['mrkr'].func(name, 'there')
    end
})
