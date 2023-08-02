--
-- Minetest advmarkers mod
--
-- © 2019 by luk3yx
--

advmarkers = {
    dated_death_markers = false,
}

local DEFAULT_COLOUR = 0xbf360c

-- Get the mod storage
local storage = minetest.get_mod_storage()
local hud = {}
advmarkers.last_coords = {}

local abs, type = math.abs, type
local vector_copy = vector.copy or vector.new

local round = math.round or function(n)
    return math.floor(n + 0.5)
end

-- Convert positions to/from strings
local function pos_to_string(pos)
    if type(pos) == 'table' then
        pos = minetest.pos_to_string(vector.round(pos))
    end
    if type(pos) == 'string' then
        return pos
    end
end

local function dir_ok(n)
    return type(n) == 'number' and abs(n) < 31000
end
local function string_to_pos(pos)
    if type(pos) == 'string' then
        pos = minetest.string_to_pos(pos)
    end
    if type(pos) == 'table' and dir_ok(pos.x) and dir_ok(pos.y) and
            dir_ok(pos.z) then
        -- Create a normal table so that adding additional keys (like "colour")
        -- is guaranteed to work correctly.
        return {x = round(pos.x), y = round(pos.y), z = round(pos.z)}
    end
end

local get_player_by_name    = minetest.get_player_by_name
local get_connected_players = minetest.get_connected_players
if minetest.get_modpath('cloaking') then
    get_player_by_name      = cloaking.get_player_by_name
    get_connected_players   = cloaking.get_connected_players
end

-- Set the HUD position
function advmarkers.set_hud_pos(player, pos, title, colour)
    local name = player:get_player_name()
    pos = string_to_pos(pos)
    if not pos then return end
    if not title then
        title = pos.x .. ', ' .. pos.y .. ', ' .. pos.z
    end
    colour = colour or DEFAULT_COLOUR
    if hud[name] then
        player:hud_change(hud[name], 'name', title)
        player:hud_change(hud[name], 'world_pos', pos)
        player:hud_change(hud[name], 'number', colour)
    else
        hud[name] = player:hud_add({
            hud_elem_type = 'waypoint',
            name          = title,
            text          = 'm',
            number        = colour,
            world_pos     = pos
        })
    end
    minetest.chat_send_player(name, 'Waypoint set to ' ..
        minetest.colorize(("#%06x"):format(colour), title))
    return true
end

function advmarkers.is_waypoint_shown(player, wp_name)
    local pname = player:get_player_name()
    local hud_elem = hud[pname] and player:hud_get(hud[pname])
    if hud_elem and hud_elem.name == wp_name then
        local pos = advmarkers.get_waypoint(player, wp_name)
        if pos then
            return vector.equals(hud_elem.world_pos, pos)
        end
    end
    return false
end

function advmarkers.clear_hud(player)
    local name = player:get_player_name()
    if hud[name] then
        player:hud_remove(hud[name])
        hud[name] = nil
        return true
    end
end

-- Get and save player storage
local storage_cache = {}
local function get_storage(player)
    local pname = player:get_player_name()
    if storage_cache[pname] then
        return storage_cache[pname]
    end

    local raw = player:get_meta():get_string('advmarkers:waypoints') or ''
    local version = raw:sub(1, 1)
    local res
    if version == '0' then
        -- Player meta: 0{"Marker name": {"x": 1, "y": 2, "z": 3}}
        res = minetest.parse_json(raw:sub(2))
    elseif version == '' then
        -- Mod storage: return {["marker-Marker name"] = "(1,2,3)"}
        res = {}
        raw = minetest.deserialize(storage:get_string(pname))
        if raw then
            for name, pos in pairs(raw) do
                if name:sub(1, 7) == 'marker-' then
                    res[name:sub(8)] = string_to_pos(pos)
                end
            end
        end
    end

    -- Cache the waypoint list
    res = res or {}
    storage_cache[pname] = res
    return res
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

    return true
end

-- Add a waypoint
function advmarkers.set_waypoint(player, pos, name, colour)
    pos = string_to_pos(pos)
    if not pos then
        return false, "Invalid position!"
    end

    name = tostring(name)
    if name == "" then
        return false, "No name specified!"
    end

    if #name > 100 then
        return false, "Waypoint name too long!"
    end

    local data = get_storage(player)

    local count = 0
    for _ in pairs(data) do count = count + 1 end
    if count >= 100 then
        return false, "You have too many waypoints!"
    end

    -- Add the colour (string_to_pos makes a copy of pos)
    pos.colour = colour ~= DEFAULT_COLOUR and colour or nil

    data[name] = pos
    return save_storage(player, data)
end

-- Delete a waypoint
function advmarkers.delete_waypoint(player, name)
    local data = get_storage(player)
    data[name] = nil
    return save_storage(player, data)
end

-- Get a waypoint
function advmarkers.get_waypoint(player, name)
    local pos = get_storage(player)[name]
    return pos and vector_copy(pos), pos and pos.colour or DEFAULT_COLOUR
end

-- Rename a waypoint
function advmarkers.rename_waypoint(player, oldname, newname, colour)
    if oldname == newname and not colour then return true end

    local data = get_storage(player)
    if data[newname] and oldname ~= newname then return end
    local wp = data[oldname]
    if wp and colour then
        wp.colour = colour ~= DEFAULT_COLOUR and colour or nil
    end
    data[newname], data[oldname] = wp, nil
    return save_storage(player, data)
end

-- Get waypoint names
function advmarkers.get_waypoint_names(player, sorted)
    local data = get_storage(player)
    local res = {}
    for name in pairs(data) do
        res[#res + 1] = name
    end
    if sorted or sorted == nil then table.sort(res) end
    return res
end

-- Display a waypoint
function advmarkers.display_waypoint(player, name)
    local pos, colour = advmarkers.get_waypoint(player, name)
    return advmarkers.set_hud_pos(player, pos, name, colour)
end

-- Export waypoints
function advmarkers.export(player, raw)
    local s = {}
    for name, pos in pairs(get_storage(player)) do
        s['marker-' .. name] = pos_to_string(pos)
    end

    if not raw then
        s = minetest.compress(minetest.write_json(s))
        s = 'J' .. minetest.encode_base64(s)
    end
    return s
end

-- Import waypoints
function advmarkers.import(player, s)
    if type(s) ~= 'table' then
        if s:sub(1, 1) ~= 'J' then return end
        s = minetest.decode_base64(s:sub(2))
        local success, msg = pcall(minetest.decompress, s)
        if not success then return end
        s = minetest.parse_json(msg)
        if type(s) ~= 'table' then return end
    end

    local data = get_storage(player)

    -- Limit the total number of waypoints
    local count = 0
    for _ in pairs(data) do count = count + 1 end

    -- Parse the export table
    for field, pos in pairs(s) do
        if type(field) == 'string' and type(pos) == 'string' and
                field:sub(1, 7) == 'marker-' then
            pos = string_to_pos(pos)
            if pos and #field <= 107 then
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

                count = count + 1
                if count >= 100 then
                    break
                end
            end
        end
    end
    return save_storage(player, data)
end

-- Get waypoint position
function advmarkers.get_chatcommand_pos(player, pos)
    local pname = player:get_player_name()

    -- Validate the position
    if pos == 'h' or pos == 'here' then
        pos = player:get_pos()
    elseif pos == 't' or pos == 'there' then
        if not advmarkers.last_coords[pname] then
            return false, 'No "there" position found!'
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

-- Find co-ordinates sent in chat messages
local function get_coords(msg)
    if msg:byte(1) == 1 or #msg > 1000 then return end
    local pos = msg:match('%-?[0-9%.]+, *%-?[0-9%.]+, *%-?[0-9%.]+')
    if pos then
        return string_to_pos(pos)
    end
end

-- Get global co-ords
minetest.register_on_chat_message(function(_, msg)
    if msg:sub(1, 1) == '/' then return end
    local pos = get_coords(msg)
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
    storage_cache[name] = nil
    advmarkers.last_coords[name] = nil
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

-- Load other files
local modpath = minetest.get_modpath("advmarkers")
dofile(modpath .. "/chatcommands.lua")
dofile(modpath .. "/gui.lua")

-- Backwards compatibility
for _, func_name in ipairs({"set_hud_pos", "set_waypoint", "delete_waypoint",
    "get_waypoint", "rename_waypoint", "get_waypoint_names", "display_waypoint",
    "export", "import", "display_formspec", "get_chatcommand_pos"}) do
    local func = assert(advmarkers[func_name])
    local function wrapper(player, ...)
        if type(player) == "string" then
            minetest.log("warning", "[advmarkers] Calling advmarkers." ..
                func_name .. "() with a player name is deprecated.")
            player = get_player_by_name(player)
            if not player then return end
        end
        return func(player, ...)
    end

    if func_name:find("waypoint", 1, true) then
        local old_name = func_name:gsub('waypoint', 'marker')
        advmarkers[old_name] = function(...)
            minetest.log("warning", "[advmarkers] advmarkers." .. old_name ..
                "() is deprecated, use advmarkers." .. func_name ..
                "() instead.")
            return wrapper(...)
        end
    end

    advmarkers[func_name] = wrapper
end
