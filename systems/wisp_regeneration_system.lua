-- systems/wisp_regeneration_system.lua
-- This system regenerates 1 Wisp for all units of the active team at the end of their turn.

local EventBus = require("modules.event_bus")

local WispRegenerationSystem = {}

-- A generic function to regenerate Wisp for a given list of units.
local function regenerate_wisp_for_team(team_list)
    if not team_list then return end

    for _, unit in ipairs(team_list) do
        -- Only regenerate for living units that have a Wisp stat.
        if unit.hp > 0 and unit.wisp ~= nil then
            -- Increment wisp by 1, but do not exceed the maximum.
            unit.wisp = math.min(unit.finalMaxWisp, unit.wisp + 1)
        end
    end
end

-- Listen for the player's turn to end, then regenerate Wisp for all players.
EventBus:register("player_turn_ended", function(data)
    regenerate_wisp_for_team(data.world.players)
end)

-- Listen for the enemy's turn to end, then regenerate Wisp for all enemies.
EventBus:register("enemy_turn_ended", function(data)
    regenerate_wisp_for_team(data.world.enemies)
end)

return WispRegenerationSystem