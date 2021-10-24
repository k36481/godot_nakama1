local world_control = {}

local nk = require("nakama")


-- Custom operation codes. Nakama specific codes are <= 0.
local OpCodes = {
    update_position = 1,
    update_input = 2,
    update_state = 3,
    update_jump = 4,
    do_spawn = 5,
    update_kill = 6,

    presence_leave = 7
}

local commands = {}

-- Updates the character color in the game state once the player's picked a character
commands[OpCodes.do_spawn] = function(data, state)
    local id = data.id
    local nm = data.nm
    
    -- if state.presences[id] == nil then
    --     state.presences[id] = id
    -- end

    -- if state.names[id] == nil then
    --     state.names[id] = nm
    -- end
end

-- Updates the position in the game state
commands[OpCodes.update_position] = function(data, state)
    local id = data.id
    local position = data.pos
    if state.positions[id] ~= nil then
        state.positions[id] = position
    end
end

commands[OpCodes.update_input] = function(data, state)
    local id = data.id
    local inp = data.inp
    if state.inputs[id] ~= nil then
        state.inputs[id] = inp
    end
end

commands[OpCodes.update_kill] = function(data, state)
    local id = data.id
    local kill = data.kill
    if state.kills[id] ~= nil then
        state.kills[id] = kill
    end
end

function world_control.match_init(context, params)
    local gamestate = {
        presences = {},
        inputs = {},
        positions = {},
        jumps = {},
        kills = {},
        names = {}
    }

    local tick_rate = 60
    local label = "game world"

    return gamestate, tick_rate, label
end

function world_control.match_join_attempt(context, dispatcher, tick, state, presence, metadata)
    if state.presences[presence.user_id] ~= nil then
        return state, false, "already logged in"
    end
    return state, true
end

function world_control.match_join(context, dispatcher, tick, state, presences)
    for _, presence in ipairs(presences) do
        state.presences[presence.user_id] = presence

        state.positions[presence.user_id] = {
            ["x"] = 0,
            ["y"] = 0
        }

        state.inputs[presence.user_id] = {
            ["dir"] = 0,
            ["inputs"] = {["q"] = 0, ["w"] = 0, ["e"] = 0, ["r"] = 0, ["space"] = 0}
        }

        state.kills[presence.user_id] = {
            ["kill"] = 0
        }
    end
    return state
end

function world_control.match_leave(context, dispatcher, tick, state, presences)
    local data = {}
    for _, presence in ipairs(presences) do
        state.presences[presence.user_id] = nil
        data[presence.user_id] = presence.user_id
    end
    dispatcher.broadcast_message(OpCodes.presence_leave, nk.json_encode(data))
    return state
end

function world_control.match_loop(context, dispatcher, tick, state, messages)
    for _, message in ipairs(messages) do
        local op_code = message.op_code
        local decoded = nk.json_decode(message.data)
        local command = commands[op_code]

        if command ~= nil then
            commands[op_code](decoded, state)
        end

        if op_code == OpCodes.do_spawn then
            decoded = nk.json_decode(message.data)
            decoded["presences"] = state.presences
            dispatcher.broadcast_message(OpCodes.do_spawn, nk.json_encode(decoded))

            local data = {["kills"] = state.kills }
            local encoded = nk.json_encode(state.kills)
            dispatcher.broadcast_message(OpCodes.update_kill, encoded)
        end

        if op_code == OpCodes.update_kill then
            local data = {["kills"] = state.kills }
            local encoded = nk.json_encode(state.kills)
            dispatcher.broadcast_message(OpCodes.update_kill, encoded)
        end

    end

    local data = {["pos"] = state.positions, ["inp"] = state.inputs }
    local encoded = nk.json_encode(data)
    dispatcher.broadcast_message(OpCodes.update_state, encoded)
    dispatcher.broadcast_message(OpCodes.update_input, encoded)

    return state
end

function world_control.match_terminate(context, dispatcher, tick, state, grace_seconds)
    return state
end 

return world_control
