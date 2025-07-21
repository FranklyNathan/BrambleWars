-- enemy_turn_system.lua
-- Manages the AI logic for enemies during their turn.

local Pathfinding = require("modules.pathfinding")
local WorldQueries = require("modules.world_queries")
local AttackPatterns = require("modules.attack_patterns")
local UnitAttacks = require("data.unit_attacks")
local Grid = require("modules.grid")

local EnemyTurnSystem = {}

-- Helper to find the closest player to an enemy.
local function findClosestPlayer(enemy, world)
    local closestPlayer, shortestDistSq = nil, math.huge
    for _, player in ipairs(world.players) do
        if player.hp > 0 then
            local distSq = (player.tileX - enemy.tileX)^2 + (player.tileY - enemy.tileY)^2
            if distSq < shortestDistSq then
                shortestDistSq, closestPlayer = distSq, player
            end
        end
    end
    return closestPlayer
end

-- Finds the best tile in a unit's range from which to attack a target using a directional pattern.
local function findBestAttackPosition(enemy, target, patternFunc, reachableTiles, world)
    if not patternFunc then return nil end
    
    local bestPosKey, closestDistSq = nil, math.huge
    -- Create a temporary enemy object to test positions without modifying the real one.
    -- It needs both tile and pixel coordinates for the pattern functions to work correctly.
    local tempEnemy = { tileX = 0, tileY = 0, x = 0, y = 0, size = enemy.size, lastDirection = "down" }
    
    for posKey, _ in pairs(reachableTiles) do
        local tileX = tonumber(string.match(posKey, "(-?%d+)"))
        local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
        tempEnemy.tileX, tempEnemy.tileY = tileX, tileY
        tempEnemy.x, tempEnemy.y = Grid.toPixels(tileX, tileY)
        
        -- Make the temporary unit face the target from its potential new spot.
        local dx, dy = target.tileX - tempEnemy.tileX, target.tileY - tempEnemy.tileY
        if math.abs(dx) > math.abs(dy) then tempEnemy.lastDirection = (dx > 0) and "right" or "left"
        else tempEnemy.lastDirection = (dy > 0) and "down" or "up" end
        
        -- Check if the target is in the attack pattern from this new position.
        if WorldQueries.isTargetInPattern(tempEnemy, patternFunc, {target}, world) then
            -- This is a valid attack spot. Is it the best one so far (closest to target)?
            local distSq = (tileX - target.tileX)^2 + (tileY - target.tileY)^2
            if distSq < closestDistSq then
                closestDistSq = distSq
                bestPosKey = posKey
            end
        end
    end
    return bestPosKey -- Return the best spot found, or nil.
end

-- Finds the best tile in a unit's range from which to use a cycle_target attack on a target.
local function findBestCycleTargetAttackPosition(enemy, target, attackName, reachableTiles, world)
    local bestPosKey, closestDistSq = nil, math.huge
    -- Create a temporary copy of the enemy to test positions without modifying the real one.
    local tempEnemy = {}
    for k, v in pairs(enemy) do tempEnemy[k] = v end
    
    for posKey, data in pairs(reachableTiles) do
        if data.landable then
            local tileX = tonumber(string.match(posKey, "(-?%d+)"))
            local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
            tempEnemy.tileX, tempEnemy.tileY = tileX, tileY
            
            local validTargets = WorldQueries.findValidTargetsForAttack(tempEnemy, attackName, world)
            for _, validTarget in ipairs(validTargets) do
                if validTarget == target then
                    -- This is a valid attack spot. Is it the best one so far (closest to target)?
                    local distSq = (tileX - target.tileX)^2 + (tileY - target.tileY)^2
                    if distSq < closestDistSq then
                        closestDistSq = distSq
                        bestPosKey = posKey
                    end
                    break -- Found a valid spot for this tile, no need to check other targets from this same tile.
                end
            end
        end
    end
    return bestPosKey
end

-- Finds the reachable tile that is closest to the target.
-- This is a simple greedy approach and is used as a fallback.
local function findClosestReachableTileByDistance(enemy, target, reachableTiles)
    local closestKey, closestDistSq = nil, math.huge
    for posKey, data in pairs(reachableTiles) do
        if data.landable and posKey ~= (enemy.tileX .. "," .. enemy.tileY) then
            local tileX = tonumber(string.match(posKey, "(-?%d+)"))
            local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
            local distSq = (tileX - target.tileX)^2 + (tileY - target.tileY)^2
            if distSq < closestDistSq then 
                closestDistSq, closestKey = distSq, posKey 
            end
        end
    end
    return closestKey
end

-- A more intelligent way to find a tile to move to when no attack is possible.
-- It performs a Breadth-First Search (BFS) starting from the target player, and the
-- first tile it finds that is in the enemy's reachable set is the optimal one.
-- This ensures the enemy is always moving along a valid path towards the target,
-- preventing it from getting stuck in loops.
local function findBestMoveOnlyTile(enemy, target, reachableTiles, world)
    -- If there's nowhere to move, don't bother.
    if not next(reachableTiles) then return nil end

    local frontier = {{tileX = target.tileX, tileY = target.tileY}}
    local visited = {[target.tileX .. "," .. target.tileY] = true}
    local head = 1

    while head <= #frontier do
        local current = frontier[head]
        head = head + 1

        local currentKey = current.tileX .. "," .. current.tileY
        -- Check if the current tile in our search is one the enemy can actually land on this turn.
        if reachableTiles[currentKey] and reachableTiles[currentKey].landable and currentKey ~= (enemy.tileX .. "," .. enemy.tileY) then
            -- Success! We found a reachable tile that is on a valid path from the target.
            return currentKey
        end

        local neighbors = {{dx=0,dy=-1},{dx=0,dy=1},{dx=-1,dy=0},{dx=1,dy=0}}
        for _, move in ipairs(neighbors) do
            local nextTileX, nextTileY = current.tileX + move.dx, current.tileY + move.dy
            local nextKey = nextTileX .. "," .. nextTileY

            if not visited[nextKey] and
               nextTileX >= 0 and nextTileX < world.map.width and
               nextTileY >= 0 and nextTileY < world.map.height then
                
                -- The path for the BFS should not go through obstacles or opponents. It CAN go through allies.
                local canPass = true
                if WorldQueries.isTileAnObstacle(nextTileX, nextTileY, world) then
                    canPass = false -- Can't path through obstacles.
                else
                    local occupyingUnit = WorldQueries.getUnitAt(nextTileX, nextTileY, enemy, world)
                    if occupyingUnit and occupyingUnit.type ~= enemy.type then
                        canPass = false -- Can't path through opponents.
                    end
                end

                if canPass then
                    visited[nextKey] = true
                    table.insert(frontier, {tileX = nextTileX, tileY = nextTileY})
                end
            end
        end
    end

    -- Fallback: If the target is completely unreachable (e.g., walled off), revert to the simple "closest distance" approach.
    return findClosestReachableTileByDistance(enemy, target, reachableTiles)
end

function EnemyTurnSystem.update(dt, world)
    if world.turn ~= "enemy" then return end

    -- print("--- EnemyTurnSystem Frame ---")
    -- If any action is ongoing (animations, projectiles, etc.), wait for it to resolve.
    if WorldQueries.isActionOngoing(world) then return end

    -- Find the next enemy that has not yet acted.
    local actingEnemy = nil
    for _, enemy in ipairs(world.enemies) do
        if not enemy.hasActed and enemy.hp > 0 then
            actingEnemy = enemy
            break
        end
    end

    if actingEnemy then
        -- This block handles post-move logic. If a unit has no movement path,
        -- it could be at the start of its turn, or it could have just finished moving.
        if not actingEnemy.components.movement_path then
            if actingEnemy.components.ai and actingEnemy.components.ai.pending_attack then
                -- Execute the pending attack.
                local pending = actingEnemy.components.ai.pending_attack
                world.cycleTargeting.active = true
                world.cycleTargeting.targets = {pending.target}
                world.cycleTargeting.selectedIndex = 1
                world.selectedAttackName = pending.name
                UnitAttacks[pending.name](actingEnemy, world)
                actingEnemy.components.ai.pending_attack = nil
                world.cycleTargeting.active = false
                world.selectedAttackName = nil
                actingEnemy.components.action_in_progress = true
                return
            elseif actingEnemy.components.action_in_progress then
                -- The unit just finished a move-only action. Its turn is over.
                -- The action_finalization_system will set hasActed. We just need to stop here
                -- to prevent the AI from running again this frame.
                return
            end
        else
            return -- Has a movement path, so it's currently moving. Do nothing.
        end

        local targetPlayer = findClosestPlayer(actingEnemy, world)
        if not targetPlayer then actingEnemy.hasActed = true; return end

        -- 1. Find the best possible action (attack and position)
        local bestAction = nil
        local bestScore = -1

        -- Get pathfinding data from the cache, or calculate and store it if not present.
        -- This prevents recalculating movement range from a new position mid-turn.
        local pathData = world.enemyPathfindingCache[actingEnemy]
        if not pathData then
            local reachable, came, cost = Pathfinding.calculateReachableTiles(actingEnemy, world)
            pathData = { reachableTiles = reachable, came_from = came, cost_so_far = cost }
            world.enemyPathfindingCache[actingEnemy] = pathData
        end

        local reachableTiles = pathData.reachableTiles
        local came_from = pathData.came_from
        local cost_so_far = pathData.cost_so_far

        local movementRange = WorldQueries.getUnitMovement(actingEnemy)
        if movementRange == 0 then reachableTiles = {} end

        local blueprint = EnemyBlueprints[actingEnemy.enemyType]
        if not blueprint or not blueprint.attacks then actingEnemy.hasActed = true; return end

        for _, attackName in ipairs(blueprint.attacks) do
            local attackData = AttackBlueprints[attackName]
            if attackData and actingEnemy.wisp >= (attackData.wispCost or 0) then
                -- A simple scoring heuristic: power minus a penalty for wisp cost.
                local score = (attackData.power or 0) - (attackData.wispCost or 0) * 5

                -- Check if we can attack from the current position.
                local currentTargets = WorldQueries.findValidTargetsForAttack(actingEnemy, attackName, world)
                local canAttackNow = false
                for _, t in ipairs(currentTargets) do if t == targetPlayer then canAttackNow = true; break end end

                if canAttackNow then
                    if score > bestScore then
                        bestScore = score
                        bestAction = {
                            type = "attack_now",
                            attackName = attackName,
                            attackData = attackData
                        }
                    end
                end

                -- Check if we can move to a position to attack.
                -- For now, this AI logic only considers moving for cycle_target attacks.
                if attackData.targeting_style == "cycle_target" then
                    local bestMovePosKey = findBestCycleTargetAttackPosition(actingEnemy, targetPlayer, attackName, reachableTiles, world)
                    if bestMovePosKey then
                        -- A move-then-attack action is slightly less preferable than an attack-now action.
                        local moveAttackScore = score - 1
                        if moveAttackScore > bestScore then
                            bestScore = moveAttackScore
                            bestAction = {
                                type = "move_and_attack",
                                attackName = attackName,
                                attackData = attackData,
                                destinationKey = bestMovePosKey
                            }
                        end
                    end
                end
            end
        end

        -- 2. Execute the chosen action
        if bestAction then -- An optimal action was found
            if bestAction.type == "attack_now" then
                -- Attack from the current position.
                world.cycleTargeting.active = true
                world.cycleTargeting.targets = {targetPlayer}
                world.cycleTargeting.selectedIndex = 1
                world.selectedAttackName = bestAction.attackName
                UnitAttacks[bestAction.attackName](actingEnemy, world)

                world.cycleTargeting.active = false
                world.selectedAttackName = nil
                actingEnemy.components.action_in_progress = true
                return

            elseif bestAction.type == "move_and_attack" then
                -- Move to the best attack position, and set a pending attack.
                local startKey = actingEnemy.tileX .. "," .. actingEnemy.tileY
                local path = Pathfinding.reconstructPath(came_from, cost_so_far, nil, startKey, bestAction.destinationKey)
                if path and #path > 0 then
                    actingEnemy.components.movement_path = path
                    -- Set the pending attack that will be executed after the move is complete.
                    actingEnemy.components.ai.pending_attack = {
                        name = bestAction.attackName,
                        target = targetPlayer
                    }
                else
                    -- Pathfinding failed for some reason, end turn.
                    actingEnemy.components.action_in_progress = true
                end
                return
            end
        else -- No attack is possible, so just move closer to the target.
            local moveDestinationKey = findBestMoveOnlyTile(actingEnemy, targetPlayer, reachableTiles, world)
            if moveDestinationKey then
                local startKey = actingEnemy.tileX .. "," .. actingEnemy.tileY
                local path = Pathfinding.reconstructPath(came_from, cost_so_far, nil, startKey, moveDestinationKey)
                if path and #path > 0 then
                    actingEnemy.components.movement_path = path
                    return -- Let the movement system take over.
                end
            end
            -- If no move is possible, end the turn.
            actingEnemy.components.action_in_progress = true
        end
    else
        -- No more enemies to act, which means the enemy turn is over.
        world.turnShouldEnd = true
    end
end

return EnemyTurnSystem