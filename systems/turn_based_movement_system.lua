-- turn_based_movement_system.lua
-- This system handles moving a unit along a predefined path, one tile at a time.

local Grid = require("modules.grid")
local WorldQueries = require("modules.world_queries")
local CharacterBlueprints = require("data.character_blueprints")
local RangeCalculator = require("modules.range_calculator")
local AttackBlueprints = require("data.attack_blueprints")

local TurnBasedMovementSystem = {}

-- Helper to format attack names into Title Case (e.g., "invigoration" -> "Invigoration").
local function formatAttackName(name)
    local s = name:gsub("_", " ")
    s = s:gsub("^%l", string.upper)
    s = s:gsub(" (%l)", function(c) return " " .. c:upper() end)
    return s
end

function TurnBasedMovementSystem.update(dt, world)
    -- Update the visual effect for the move destination tile.
    if world.ui.pathing.moveDestinationEffect then
        local effect = world.ui.pathing.moveDestinationEffect
        if effect.state == "descending" then
            effect.timer = math.max(0, effect.timer - dt)
            if effect.timer == 0 then
                effect.state = "glowing"
            end
        end
    end

    -- This system moves any entity that has a movement path.
    for _, entity in ipairs(world.all_entities) do
        -- The check for entity.components is no longer needed, as world.lua now guarantees it exists.
        if entity.components.movement_path then
            -- Check if the unit is close enough to its current target tile.
            -- Using a small epsilon to handle floating-point inaccuracies from dt-based movement.
            local epsilon = 1
            if math.abs(entity.x - entity.targetX) < epsilon and math.abs(entity.y - entity.targetY) < epsilon then
                -- Snap to the target position to prevent error accumulation.
                entity.x, entity.y = entity.targetX, entity.targetY
                -- Update the logical tile position to match.
                entity.tileX, entity.tileY = Grid.toTile(entity.x, entity.y)

                if #entity.components.movement_path > 0 then
                    -- It has arrived. Get the next step from the path.
                    local nextStep = table.remove(entity.components.movement_path, 1)

                    -- Update the entity's facing direction for the upcoming move
                    -- by comparing the next step's coords to the entity's current position.
                    -- This must be done *before* setting the new target.
                    if nextStep.x > entity.x then entity.lastDirection = "right"
                    elseif nextStep.x < entity.x then entity.lastDirection = "left"
                    elseif nextStep.y > entity.y then entity.lastDirection = "down"
                    elseif nextStep.y < entity.y then entity.lastDirection = "up" end

                    -- Set the next tile as the new target.
                    entity.targetX = nextStep.x
                    entity.targetY = nextStep.y
                else
                    -- The path is now empty, which means movement is complete.
                    entity.components.movement_path = nil -- Clean up the component.

                    -- Clear the move destination effect now that the unit has arrived.
                    world.ui.pathing.moveDestinationEffect = nil

                    -- Only player units trigger state changes upon finishing a move.
                    if entity.type == "player" then -- Player finished moving
                        -- Movement is done, open the action menu.
                        world.ui.playerTurnState = "action_menu"

                        local blueprint = CharacterBlueprints[entity.playerType]
                        local menuOptions = {}
                        -- Populate with attacks from the blueprint's attack list.
                        if blueprint and blueprint.attacks then
                            for _, attackName in ipairs(blueprint.attacks) do
                                -- Only show attacks that are actually usable from the current position.
                                local attackData = AttackBlueprints[attackName]
                                if attackData then
                                    local style = attackData.targeting_style
                                    local showAttack = false

                                    -- Attacks that don't need a pre-existing target can always be shown in the menu.
                                    if style == "ground_aim" or style == "no_target" then
                                        showAttack = true
                                    -- For directional, cycle, and auto-hit attacks, check if any valid targets exist from the current position.
                                    elseif style == "directional_aim" or style == "auto_hit_all" or style == "cycle_target" then
                                        if #WorldQueries.findValidTargetsForAttack(entity, attackName, world) > 0 then
                                            showAttack = true
                                        end
                                    end

                                    if showAttack then
                                        table.insert(menuOptions, {text = formatAttackName(attackName), key = attackName})
                                    end
                                end
                            end
                        end

                        -- If the unit is carrying someone, add a "Drop" option.
                        if entity.carriedUnit then
                            table.insert(menuOptions, {text = "Drop", key = "drop"})
                        else
                            -- If not carrying, check if they can rescue someone.
                            local rescuableUnits = WorldQueries.findRescuableUnits(entity, world)
                            if #rescuableUnits > 0 then
                                table.insert(menuOptions, {text = "Rescue", key = "rescue"})
                            end
                        end

                        -- Check if the unit can shove an ally.
                        local shoveTargets = WorldQueries.findShoveTargets(entity, world)
                        if #shoveTargets > 0 then
                            table.insert(menuOptions, {text = "Shove", key = "shove"})
                        end

                        -- Check if the unit can take a carried unit from an ally.
                        local takeTargets = WorldQueries.findTakeTargets(entity, world)
                        if #takeTargets > 0 then
                            table.insert(menuOptions, {text = "Take", key = "take"})
                        end

                        table.insert(menuOptions, {text = "Wait", key = "wait"})

                        world.ui.menus.action.active = true
                        world.ui.menus.action.unit = entity
                        world.ui.menus.action.options = menuOptions
                        world.ui.menus.action.selectedIndex = 1
                    elseif entity.type == "enemy" then
                        -- If an enemy finishes moving, decide what to do.
                        if entity.components.ai and entity.components.ai.pending_attack then
                            -- The enemy has a pending attack. Let the enemy_turn_system handle it.
                            entity.components.action_in_progress = true
                        else
                            -- The enemy just finished a move-only action. Their turn is over.
                            entity.hasActed = true
                        end
                    end
                end
            end
        end
    end
end

return TurnBasedMovementSystem