-- systems/action_finalization_system.lua
-- This system checks when a unit's action (attack, move, etc.) is fully complete,
-- including any reactions like counter-attacks, and then sets their 'hasActed' state.

local EventBus = require("modules.event_bus")
local WorldQueries = require("modules.world_queries")
local LevelUpSystem = require("systems.level_up_system")
local ActionFinalizationSystem = {}

function ActionFinalizationSystem.update(dt, world)
    -- Use the centralized query to determine if any action is ongoing.
    local isActionOngoing = WorldQueries.isActionOngoing(world)

    -- If the action state is idle, we can finalize any pending actions.
    if not isActionOngoing then
        for _, entity in ipairs(world.all_entities) do
            -- Find units that have an action in progress and are not currently moving.
            if entity.components.action_in_progress and not entity.components.movement_path then
                local leveledUp = false
                -- A unit can only level up if it is still alive after its action.
                if entity.type == "player" and entity.hp > 0 then
                    -- The check now takes the world as an argument and returns a boolean.
                    -- It will trigger the LevelUpDisplaySystem if a level up occurs.
                    leveledUp = LevelUpSystem.checkForLevelUp(entity, world)
                end

                if not leveledUp then
                    -- No level up occurred. Finalize the action immediately.
                    entity.hasActed = true
                    entity.components.action_in_progress = nil -- Clean up the flag.
                    -- Fire an event specifically for this unit so other systems can react.
                    EventBus:dispatch("action_finalized", { unit = entity, world = world })
                else
                    -- A level up animation has started. The LevelUpDisplaySystem
                    -- is now in control and will set hasActed when it's finished.
                    -- We just need to clear the action_in_progress flag so this system
                    -- doesn't try to process the unit again.
                    entity.components.action_in_progress = nil
                end
            end
        end
    end
end

return ActionFinalizationSystem