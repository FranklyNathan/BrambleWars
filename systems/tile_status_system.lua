-- systems/tile_status_system.lua
-- Manages the lifecycle (e.g., duration) of tile status effects.

local EventBus = require("modules.event_bus")

local TileStatusSystem = {}

-- This function is called at the end of the enemy turn, which represents one full round.
local function on_turn_passed(data)
    local world = data.world
    if not world.tileStatuses then return end

    for posKey, status in pairs(world.tileStatuses) do
        -- Only process statuses that have a duration.
        if status.duration then
            status.duration = status.duration - 1
            if status.duration <= 0 then
                world.tileStatuses[posKey] = nil -- Remove the status effect.
            end
        end
    end
end

EventBus:register("enemy_turn_ended", on_turn_passed)

return TileStatusSystem