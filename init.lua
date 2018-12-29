--
-- Minetest advmarkers CSM
--
-- Needs the https://github.com/Billy-S/kingdoms_game/tree/master/mods/marker
--  mod to be able to display HUD elements
--

advmarkers = {}

-- Get the mod storage
local storage = minetest.get_mod_storage()

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

-- Set the HUD position
-- TODO: Make this entirely client-side or allow the command to be changed.
function advmarkers.set_hud_pos(pos)
    pos = string_to_pos(pos)
    if not pos then return end
    minetest.run_server_chatcommand('mrkr', tostring(pos.x) .. ' ' ..
        tostring(pos.y) .. ' ' .. tostring(pos.z))
    return true
end

-- Add a marker
function advmarkers.set_marker(pos, name)
    pos = pos_to_string(pos)
    if not pos then return end
    storage:set_string('marker-' .. tostring(name), pos)
    return true
end

-- Delete a marker
function advmarkers.delete_marker(name)
    storage:set_string('marker-' .. tostring(name), '')
end

-- Get a marker
function advmarkers.get_marker(name)
    return string_to_pos(storage:get_string('marker-' .. tostring(name)))
end

-- Display a marker
function advmarkers.display_marker(name)
    return advmarkers.set_hud_pos(advmarkers.get_marker(name))
end

-- Get the markers formspec
local formspec_list = {}
local selected_name = false
function advmarkers.display_formspec()
    local formspec = 'size[5.25,8]' ..
                     'label[0,0;Marker list]' ..
                     'button_exit[0,7.5;2.625,0.5;display;Display]' ..
                     'button[2.625,7.5;2.625,0.5;delete;Delete]' ..
                     'textlist[0,0.75;5,6;marker;'

    -- Iterate over all the markers
    local id = 0
    local selected = 1
    formspec_list = {}
    for name, pos in pairs(storage:to_table().fields) do
        if name:sub(1, 7) == 'marker-' then
            id = id + 1
            if id > 1 then
                formspec = formspec .. ','
            end
            name = name:sub(8)
            if not selected_name then
                selected_name = name
            end
            if name == selected_name then
                selected = id
            end
            name = minetest.formspec_escape(name)
            if name:sub(1, 1) == '#' then
                name = '#' .. name
            end
            formspec_list[#formspec_list + 1] = name
            formspec = formspec .. name
        end
    end

    -- Close the text list and display the selected marker position
    formspec = formspec .. ';' .. tostring(selected) .. ']'
    if selected_name then
        local pos = advmarkers.get_marker(selected_name)
        if pos then
            pos = minetest.formspec_escape(tostring(pos.x) .. ', ' ..
            tostring(pos.y) .. ', ' .. tostring(pos.z))
            pos = 'Marker position: ' .. pos
            formspec = formspec .. 'label[0,6.75;' .. pos .. ']'
        end
    else
        -- Draw over the buttons
        formspec = formspec .. 'button_exit[0,7.5;5.25,0.5;quit;Close dialog]' ..
            'label[0,6.75;No markers. Add one with ".add_mrkr".]'
    end

    -- Display the formspec
    return minetest.show_formspec('advmarkers-csm', formspec)
end

-- Open the markers GUI
minetest.register_chatcommand('mrkr', {
    params      = '',
    description = 'Open the advmarkers GUI',
    func = advmarkers.display_formspec
})

-- Add a marker
minetest.register_chatcommand('add_mrkr', {
    params      = '<pos / "here"> <name>',
    description = 'Adds a marker.',
    func = function(param)
        local s, e = param:find(' ')
        local pos  = param:sub(1, s - 1)
        local name = param:sub(e + 1)

        -- Validate the position
        if pos == 'here' then
            pos = minetest.localplayer:get_pos()
        else
            pos = string_to_pos(pos)
            if not pos then
                return false, 'Invalid position!'
            end
        end

        -- Validate the name
        if not name or #name < 1 then
            return false, 'Invalid name!'
        end

        -- Set the marker
        return advmarkers.set_marker(pos, name), 'Done!'
    end
})

-- Set the HUD
minetest.register_on_formspec_input(function(formname, fields)
    if formname ~= 'advmarkers-csm' then return end
    local name = false
    if fields.marker then
        local event = minetest.explode_textlist_event(fields.marker)
        if event.index then
            name = formspec_list[event.index]
        end
    else
        name = selected_name
    end

    if name then
        if fields.display then
            if not advmarkers.display_marker(name) then
                minetest.display_chat_message('Error displaying marker!')
            end
        elseif fields.delete then
            minetest.show_formspec('advmarkers-csm', 'size[6,2]' ..
                'label[0.35,0.25;Are you sure you want to delete this marker?]' ..
                'button[0,1;3,1;cancel;Cancel]' ..
                'button[3,1;3,1;delete_confirm;Delete]')
        elseif fields.delete_confirm then
            advmarkers.delete_marker(name)
            selected_name = false
            advmarkers.display_formspec()
        elseif fields.cancel then
            advmarkers.display_formspec()
        elseif name ~= selected_name then
            selected_name = name
            advmarkers.display_formspec()
        end
    elseif fields.display or fields.delete then
        minetest.display_chat_message('Please select a marker.')
    end
    return true
end)

-- Add a marker on death
minetest.register_on_death(function()
    if minetest.localplayer then
        local name = os.date('Death on %Y-%m-%d %H:%M:%S')
        advmarkers.set_marker(minetest.localplayer:get_pos(), name)
        minetest.display_chat_message('Added marker "' .. name .. '".')
    end
end)
