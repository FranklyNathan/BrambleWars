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
    
    for posKey, _ in pairs(reachableTiles) do
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
    return bestPosKey
end

-- Finds the reachable tile that is closest to the target.
-- This is a simple greedy approach and is used as a fallback.
local function findClosestReachableTileByDistance(enemy, target, reachableTiles)
    local closestKey, closestDistSq = nil, math.huge
    for posKey, _ in pairs(reachableTiles) do
        if posKey ~= (enemy.tileX .. "," .. enemy.tileY) then
            local tileX = tonumber(string.match(posKey, "(-?%d+)"))
            local tileY = tonumber(string.match(posKey, ",(-?%d+)"))
            local distSq = (tileX - target.tileX)^2 + (tileY - target.tileY)^2
            if distSq < closestDistSq then closestDistSq, closestKey = distSq, posKey end
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
        -- Check if the current tile in our search is one the enemy can actually move to this turn.
        if reachableTiles[currentKey] and currentKey ~= (enemy.tileX .. "," .. enemy.tileY) then
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
                
                -- The path for the BFS should not go through tiles occupied by other units.
                if not WorldQueries.isTileOccupied(nextTileX, nextTileY, enemy, world) then
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

    -- If any unit is currently moving or an attack is resolving, wait.
    for _, entity in ipairs(world.all_entities) do if entity.components.movement_path then return end end
    if #world.attackEffects > 0 then
        return
    end

    -- Find the next enemy that has not yet acted.
    local actingEnemy = nil
    for _, enemy in ipairs(world.enemies) do
        if not enemy.hasActed and enemy.hp > 0 then
            actingEnemy = enemy
            break
        end
    end

    if actingEnemy then
        local targetPlayer = findClosestPlayer(actingEnemy, world)
        if not targetPlayer then actingEnemy.hasActed = true; return end

        -- 1. Decide which attack to use (for now, always the first one).
        local blueprint = EnemyBlueprints[actingEnemy.enemyType]
        local attackName = blueprint and blueprint.attacks and blueprint.attacks[1]
        if not attackName then actingEnemy.hasActed = true; return end
        local attackData = AttackBlueprints[attackName]
        if not attackData then actingEnemy.hasActed = true; return end

        -- 2. Determine if an attack is possible and from where.
        local canAttackNow = false
        local bestAttackPosKey = nil
        local reachableTiles, came_from = Pathfinding.calculateReachableTiles(actingEnemy, world)

        -- If the enemy has no movement, it cannot move to attack.
        local movementRange = WorldQueries.getUnitMovement(actingEnemy)
        if movementRange == 0 then reachableTiles = {} end

        if attackData.targeting_style == "cycle_target" then
            -- Check if we can attack from the current position.
            local currentTargets = WorldQueries.findValidTargetsForAttack(actingEnemy, attackName, world)
            for _, t in ipairs(currentTargets) do if t == targetPlayer then canAttackNow = true; break end end

            -- If not, find a better position.
            if not canAttackNow then
                bestAttackPosKey = findBestCycleTargetAttackPosition(actingEnemy, targetPlayer, attackName, reachableTiles, world)
            end

        elseif attackData.targeting_style == "directional_aim" then
            local patternFunc = AttackPatterns[attackName]
            if patternFunc and WorldQueries.isTargetInPattern(actingEnemy, patternFunc, {targetPlayer}, world) then
                canAttackNow = true
            else
                bestAttackPosKey = findBestAttackPosition(actingEnemy, targetPlayer, patternFunc, reachableTiles, world)
            end
        elseif attackData.targeting_style == "auto_hit_all" then
            -- For auto-hit attacks, just check if any valid targets exist from the current spot.
            local currentTargets = WorldQueries.findValidTargetsForAttack(actingEnemy, attackName, world)
            if #currentTargets > 0 then
                canAttackNow = true
            end
        end

        -- 3. Execute the chosen action.
        if canAttackNow then
            -- Attack from current position.
            if attackData.targeting_style == "cycle_target" then
                -- The AI needs to "select" its target for the attack function to work.
                world.cycleTargeting.active = true
                world.cycleTargeting.targets = {targetPlayer}
                world.cycleTargeting.selectedIndex = 1
            end
            UnitAttacks[attackName](actingEnemy, attackData.power, world)
            world.cycleTargeting.active = false -- Clean up
            actingEnemy.hasActed = true
            return

        elseif bestAttackPosKey then
            -- Move to the best attack position. The AI will attack on its next update after moving.
            local startKey = actingEnemy.tileX .. "," .. actingEnemy.tileY
            local path = Pathfinding.reconstructPath(came_from, startKey, bestAttackPosKey)
            if path and #path > 0 then actingEnemy.components.movement_path = path; return end

        else
            -- Cannot attack, so just move closer. This consumes the turn.
            local moveOnlyDestinationKey = findBestMoveOnlyTile(actingEnemy, targetPlayer, reachableTiles, world)
            if moveOnlyDestinationKey then
                local startKey = actingEnemy.tileX .. "," .. actingEnemy.tileY
                local path = Pathfinding.reconstructPath(came_from, startKey, moveOnlyDestinationKey)
                if path and #path > 0 then 
                     -- Before assigning the path, double-check if the destination tile is still reachable and landable.
                     if reachableTiles[moveOnlyDestinationKey] and reachableTiles[moveOnlyDestinationKey].landable then actingEnemy.components.movement_path = path end
                end
            end
        end

        -- After moving (or failing to), the enemy's turn is over.
        actingEnemy.hasActed = true
    else
        -- No more enemies to act, which means the enemy turn is over.
        world.turnShouldEnd = true
    end
end

return EnemyTurnSystem