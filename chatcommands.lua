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
            advmarkers.display_formspec(minetest.get_player_by_name(pname))
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
        local ok, msg = advmarkers.set_waypoint(pname, pos, name)
        return ok, ok and 'Done!' or msg
    end
})

register_chatcommand_alias('add_mrkr', 'add_wp', 'add_waypoint')

-- Allow string exporting
minetest.register_chatcommand('mrkr_export', {
    params      = '',
    description = 'Exports an advmarkers string containing all your waypoints.',
    func = function(name)
        minetest.show_formspec(name, 'advmarkers:ignore',
            'field[_;Your waypoint export string;' ..
            minetest.formspec_escape(advmarkers.export(name)) .. ']')
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
        if not player or not advmarkers.clear_hud(player) then
            return false, 'No waypoint is currently being displayed!'
        end
        return true, 'Hidden the currently displayed waypoint.'
    end,
})

register_chatcommand_alias('clrmrkr', 'clear_marker', 'clrwp',
    'clear_waypoint')
