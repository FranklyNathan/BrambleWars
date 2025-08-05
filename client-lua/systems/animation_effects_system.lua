-- systems/animation_effects_system.lua
-- This system manages the logic for timed visual effects on entities,
-- such as sinking, reviving, and ascending. It handles the state transitions
-- that occur when these animations complete.

local WorldQueries = require("modules.world_queries")
local EventBus = require("modules.event_bus")
local Grid = require("modules.grid")
local InputHelpers = require("modules.input_helpers")

local AnimationEffectsSystem = {}

-- Helper function to set the player's turn state.
local function set_player_turn_state(newState, world)
    local oldState = world.ui.playerTurnState
    if oldState ~= newState then
        world.ui.playerTurnState = newState
        EventBus:dispatch("player_state_changed", { oldState = oldState, newState = newState, world = world })
    end
end

function AnimationEffectsSystem.update(dt, world)
    for _, entity in ipairs(world.all_entities) do
        -- Sinking effect (for Burrow, part 1)
        if entity.components.sinking then
            local sinking = entity.components.sinking
            sinking.timer = math.max(0, sinking.timer - dt)

            if sinking.timer == 0 then
                local source = sinking.source
                entity.components.sinking = nil -- Remove component now

                if source == "burrow" then
                    entity.components.burrowed = true -- Mark as hidden underground. The renderer will need to handle this.
    
                    -- Find all molehills on the map to teleport to.
                    local molehills = {}
                    for _, obstacle in ipairs(world.obstacles) do
                        if obstacle.objectType == "molehill" and obstacle.hp > 0 then
                            table.insert(molehills, obstacle)
                        end
                    end
    
                    if #molehills > 0 then
                        -- Transition to the molehill selection state.
                        if not world.ui.targeting.molehill_select then world.ui.targeting.molehill_select = {} end
                        local molehillSelect = world.ui.targeting.molehill_select
                        
                        molehillSelect.active = true
                        molehillSelect.targets = {}
                        for _, mh in ipairs(molehills) do
                            table.insert(molehillSelect.targets, {tileX = mh.tileX, tileY = mh.tileY})
                        end
                        molehillSelect.selectedIndex = 1
                        
                        -- Set the state and snap the cursor to the first target.
                        InputHelpers.set_player_turn_state("burrow_teleport_selecting", world)
                        local firstTarget = molehillSelect.targets[1]
                        world.ui.mapCursorTile.x = firstTarget.tileX
                        world.ui.mapCursorTile.y = firstTarget.tileY
                        EventBus:dispatch("cursor_moved", { tileX = firstTarget.tileX, tileY = firstTarget.tileY, world = world })
                    else
                        -- Failsafe: If no molehills exist (shouldn't happen), end the action.
                        entity.components.burrowed = nil
                        entity.components.action_in_progress = false
                    end
                elseif source == "drown" then
                    -- The unit has finished sinking from drowning. Mark for deletion.
                    entity.isMarkedForDeletion = true
                end
            end
        end

        -- Reviving effect (for Necromantia and Burrow part 2)
        if entity.components.reviving then
            local reviving = entity.components.reviving
            reviving.timer = math.max(0, reviving.timer - dt)

            if reviving.timer == 0 then
                local source = reviving.source -- Check where the revival came from.
                entity.components.reviving = nil

                if source == "burrow" then
                    -- Burrow's revival refreshes the turn with adjusted movement.
                    entity.hasActed = false
                    entity.components.action_in_progress = false
                    
                    local totalMovement = entity.movement
                    local totalMovementUsed = entity.components.total_movement_used_this_turn or 0
                    entity.components.movement_override = { amount = totalMovement - totalMovementUsed }
                    
                    InputHelpers.set_player_turn_state("free_roam", world)
                else
                    -- For other sources like Necromancy, the unit is simply revived
                    -- and can act on its next turn. The death_system already set its HP.
                    entity.hasActed = false
                end
            end
        end
    end
end

return AnimationEffectsSystem