-- systems/environment_hazard_system.lua
-- Manages environmental hazards, like drowning in water.

local WorldQueries = require("modules.world_queries")
local EventBus = require("modules.event_bus")
local RescueHandler = require("modules.rescue_handler")

local EnvironmentHazardSystem = {}

-- Helper function to change the player's turn state and notify other systems.
local function set_player_turn_state(newState, world)
    local oldState = world.ui.playerTurnState
    if oldState ~= newState then
        world.ui.playerTurnState = newState
        EventBus:dispatch("player_state_changed", { oldState = oldState, newState = newState, world = world })
    end
end

-- This function is now called only when a unit's tile position changes.
local function check_hazards_for_unit(unit, world)
    if (unit.type == "player" or unit.type == "enemy") and unit.hp > 0 then
        local isOnWater = WorldQueries.isTileWater(unit.tileX, unit.tileY, world)

        -- Manage the 'submerged' component for rendering.
        if isOnWater and (unit.canSwim or unit.isFlying) then
            if not unit.components.submerged then unit.components.submerged = true end
        else
            if unit.components.submerged then unit.components.submerged = nil end
        end

        -- Check for drowning hazard (only if not already sinking).
        if isOnWater and not unit.components.sinking then
            if not unit.isFlying and not unit.canSwim then

                -- Check if the drowning unit is carrying someone.
                if unit.carriedUnit then
                    if unit.carriedUnit.canSwim then
                        -- The carried unit can swim! Drop them here to save them.
                        -- This also resets the carrier's weight and rescue penalty.
                        RescueHandler.drop(unit, unit.tileX, unit.tileY, world)
                    end
                end
                
                unit.hp = 0
                unit.components.sinking = { timer = 1.5, initialTimer = 1.5 }
                EventBus:dispatch("unit_died", { victim = unit, killer = nil, world = world, reason = {type = "drown"} })
            end
        end
    end
end

-- Listen for the new event that signals a unit has landed on a new tile.
EventBus:register("unit_tile_changed", function(data)
    check_hazards_for_unit(data.unit, data.world)
end)

return EnvironmentHazardSystem