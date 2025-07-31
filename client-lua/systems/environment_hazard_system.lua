-- systems/environment_hazard_system.lua
-- Manages environmental hazards, like drowning in water.

local WorldQueries = require("modules.world_queries")
local EventBus = require("modules.event_bus")

local EnvironmentHazardSystem = {}

function EnvironmentHazardSystem.update(dt, world)
    -- Iterate through all units to check for hazards.
    for _, entity in ipairs(world.all_entities) do
        if (entity.type == "player" or entity.type == "enemy") and entity.hp > 0 then
            local isOnWater = WorldQueries.isTileWater(entity.tileX, entity.tileY, world)

            -- Manage the 'submerged' component for rendering.
            if isOnWater and (entity.canSwim or entity.isFlying) then
                -- Unit is safely in/over water, ensure it has the submerged component.
                if not entity.components.submerged then
                    entity.components.submerged = true
                end
            else
                -- Unit is not in water, ensure it does not have the submerged component.
                if entity.components.submerged then
                    entity.components.submerged = nil
                end
            end

            -- Check for drowning hazard (only if not already sinking).
            if isOnWater and not entity.components.sinking then
                if not entity.isFlying and not entity.canSwim then
                    -- This unit should drown.
                    entity.hp = 0
                    entity.components.sinking = { timer = 1.5, initialTimer = 1.5 }

                    -- Announce the death. The killer is the environment (nil).
                    EventBus:dispatch("unit_died", { victim = entity, killer = nil, world = world, reason = {type = "drown"} })
                end
            end
        end

        -- Update any existing sinking animations.
        if entity.components.sinking then
            local sinking = entity.components.sinking
            sinking.timer = math.max(0, sinking.timer - dt)
            if sinking.timer == 0 then
                -- Animation is over, mark the unit for deletion.
                entity.isMarkedForDeletion = true
                entity.components.sinking = nil -- Clean up component
            end
        end
    end
end

return EnvironmentHazardSystem