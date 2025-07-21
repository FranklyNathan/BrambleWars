-- systems/action_finalization_system.lua
-- This system checks when a unit's action (attack, move, etc.) is fully complete,
-- including any reactions like counter-attacks, and then sets their 'hasActed' state.

local ActionFinalizationSystem = {}
local EventBus = require("modules.event_bus")
local WorldQueries = require("modules.world_queries")

function ActionFinalizationSystem.update(dt, world)
    -- Use the centralized query to determine if any action is ongoing.
    local isActionOngoing = WorldQueries.isActionOngoing(world)

    local anyActionFinalized = false

    -- If the action state is idle, we can finalize any pending actions.
    if not isActionOngoing then
        for _, entity in ipairs(world.all_entities) do
            -- Find units that have an action in progress and are not currently moving.
            if entity.components.action_in_progress and not entity.components.movement_path then
                -- The action is fully resolved. Finalize it.
                anyActionFinalized = true
                entity.hasActed = true
                entity.components.action_in_progress = nil -- Clean up the component.
            end
        end
    end

    if anyActionFinalized then
        EventBus:dispatch("action_finalized", { world = world })
    end
end

return ActionFinalizationSystem