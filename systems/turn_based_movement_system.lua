-- turn_based_movement_system.lua
-- This system handles moving a unit along a predefined path, one tile at a time.

local Grid = require("modules.grid")
local WorldQueries = require("modules.world_queries")
local CharacterBlueprints = require("data.character_blueprints")
local WeaponBlueprints = require("data.weapon_blueprints")
local AttackBlueprints = require("data.attack_blueprints")
local CombatActions = require("modules.combat_actions")
local StatusEffectManager = require("modules.status_effect_manager")
local Assets = require("modules.assets")

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

                -- Check for traps on the tile the unit just landed on.
                if not entity.isFlying then -- Flying units are immune to ground traps.
                    local obstacle = WorldQueries.getObstacleAt(entity.tileX, entity.tileY, world)
                    if obstacle and obstacle.isTrap then
                        -- Apply trap effects based on its blueprint
                        if obstacle.trapDamage and obstacle.trapDamage > 0 then
                            CombatActions.applyDirectDamage(world, entity, obstacle.trapDamage, false, nil)
                        end
                        if obstacle.trapStatus then
                            local statusCopy = { type = obstacle.trapStatus.type, duration = obstacle.trapStatus.duration }
                            StatusEffectManager.applyStatusEffect(entity, statusCopy, world)
                        end
                        -- Destroy the trap
                        obstacle.isMarkedForDeletion = true
                        if Assets.sounds.attack_hit then
                            Assets.sounds.attack_hit:stop(); Assets.sounds.attack_hit:play()
                        end

                        -- If a unit triggers a trap, their turn ends immediately.
                        entity.hasActed = true

                        if entity.type == "player" then
                            world.ui.pathing.moveDestinationEffect = nil
                            -- The unit's turn is over. Return to the free roam state so the player
                            -- can select another unit or end their turn. This prevents the game from
                            -- getting stuck in the 'unit_moving' state.
                            world.ui.playerTurnState = "free_roam"
                        end
                        -- Stop all further movement for this unit by removing the component.
                        entity.components.movement_path = nil
                    end
                end

                -- Check if the movement path still exists after potential trap interaction.
                if entity.components.movement_path and #entity.components.movement_path > 0 then
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
                elseif entity.components.movement_path then -- Path exists but is now empty.
                    -- The path is now empty, which means movement is complete.
                    entity.components.movement_path = nil -- Clean up the component.

                    -- Clear the move destination effect now that the unit has arrived.
                    world.ui.pathing.moveDestinationEffect = nil

                    -- Only player units trigger state changes upon finishing a move.
                    if entity.type == "player" then -- Player finished moving
                        -- Movement is done, open the action menu.
                        world.ui.playerTurnState = "action_menu"

                        local menuOptions = {}
                        local all_moves = WorldQueries.getUnitMoveList(entity)
                        -- Populate menu with attacks from the combined list.
                        for _, attackName in ipairs(all_moves) do
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
                                elseif style == "cycle_valid_tiles" then
                                    -- Check if there are any valid tiles for this move.
                                    local tileType = attackData.valid_tile_type
                                    if world[tileType] then
                                        for _, tile in ipairs(world[tileType]) do
                                            if not WorldQueries.isTileOccupied(tile.x, tile.y, nil, world) then
                                                showAttack = true
                                                break -- Found one, that's enough to show the move.
                                            end
                                        end
                                    end
                                    end

                                    if showAttack then
                                        table.insert(menuOptions, {text = formatAttackName(attackName), key = attackName})
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

                            -- Check for win condition after the move is complete.
                            if world.winTiles and #world.winTiles > 0 then
                                for _, winTile in ipairs(world.winTiles) do
                                    if entity.tileX == winTile.x and entity.tileY == winTile.y then
                                        -- An enemy has reached a win tile!
                                        world.gameState = "game_over"
                                        return -- Stop processing further movement this frame.
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- This system runs on both turns, making it a good place to check for pending level-ups
    -- that might have been triggered during combat on the enemy's turn.
    -- We check this separately from movement to ensure it can happen even if no one is moving.
    for _, entity in ipairs(world.all_entities) do
        if entity.components.pending_level_up then
            -- We must wait for any other major actions (like the attack that granted the EXP) to finish.
            -- isActionOngoing checks for things like damage animations, projectiles, etc.
            -- The EXP bar animation itself does NOT block isActionOngoing.
            if not WorldQueries.isActionOngoing(world) then
                local LevelUpSystem = require("systems.level_up_system")
                entity.components.pending_level_up = nil -- Consume the flag
                LevelUpSystem.checkForLevelUp(entity, world)
                -- Only process one level up per frame to prevent UI overlap issues.
                return
            end
        end
    end
end

return TurnBasedMovementSystem