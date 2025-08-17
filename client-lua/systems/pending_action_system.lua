-- systems/pending_action_system.lua
-- This system checks for and triggers actions that are queued to run when the game state is idle,
-- such as level-ups that occur from out-of-turn actions (e.g., reaction kills).

local WorldQueries = require("modules.world_queries")

local PendingActionSystem = {}

function PendingActionSystem.update(dt, world)
    -- This system should only run when no other major actions are ongoing.
    if WorldQueries.isActionOngoing(world) then
        return
    end

    -- Check for pending level-ups.
    for _, entity in ipairs(world.all_entities) do
        if entity.components.pending_level_up then
            local LevelUpSystem = require("systems.level_up_system")
            entity.components.pending_level_up = nil -- Consume the flag
            LevelUpSystem.checkForLevelUp(entity, world)
            -- A level-up animation has started. Return to only process one per frame, preventing UI overlap.
            return
        end
    end
end

return PendingActionSystem