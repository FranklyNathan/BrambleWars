-- enemy_turn_system.lua
-- Manages the AI logic for enemies during their turn.

local Pathfinding = require("modules.pathfinding")
local WorldQueries = require("modules.world_queries")
local AttackPatterns = require("modules.attack_patterns")
local AscensionSystem = require("systems/ascension_system")
local CombatFormulas = require("modules.combat_formulas")
local EntityFactory = require("data.entities")
local EnemyBlueprints = require("data.enemy_blueprints")
local WeaponBlueprints = require("weapon_blueprints")
local AttackBlueprints = require("data.attack_blueprints")
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

-- Helper to find the closest win tile to an enemy.
local function findClosestWinTile(enemy, world)
    if not world.winTiles or #world.winTiles == 0 then return nil end
    local closestTile, shortestDistSq = nil, math.huge
    for _, tile in ipairs(world.winTiles) do
        -- Check if the tile is already occupied by another enemy. If so, it's not a valid target for movement.
        local isOccupiedByEnemy = false
        for _, otherEnemy in ipairs(world.enemies) do
            if otherEnemy ~= enemy and otherEnemy.tileX == tile.x and otherEnemy.tileY == tile.y then
                isOccupiedByEnemy = true
                break
            end
        end

        if not isOccupiedByEnemy then
            local distSq = (tile.x - enemy.tileX)^2 + (tile.y - enemy.tileY)^2
            if distSq < shortestDistSq then
                shortestDistSq, closestTile = distSq, tile
            end
        end
    end
    return closestTile
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
                if WorldQueries.isTileWater(nextTileX, nextTileY, world) and not enemy.isFlying then
                    canPass = false -- Can't path through water unless flying.
                elseif WorldQueries.getObstacleAt(nextTileX, nextTileY, world) then
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

-- Helper to check if a value exists in a table.
local function table_contains(tbl, val)
    for _, value in ipairs(tbl) do
        if value == val then
            return true
        end
    end
    return false
end

-- Finds the best possible attack action against any player, prioritizing lethal hits.
local function findBestPlayerAttackAction(enemy, reachableTiles, world)
    local bestAction = nil
    local bestScore = -1 -- Kills will have a score > 1000

    -- Combine innate moves and moves granted by the equipped weapon.
    local all_moves = {}
    local move_exists = {} -- Use a set to track existing moves and prevent duplicates

    -- 1. Add moves from the enemy blueprint's innate list.
    local blueprint = EnemyBlueprints[enemy.enemyType]
    if blueprint and blueprint.attacks then
        for _, attackName in ipairs(blueprint.attacks) do
            if not move_exists[attackName] then
                table.insert(all_moves, attackName)
                move_exists[attackName] = true
            end
        end
    end

    -- 2. Add moves from the equipped weapon.
    if enemy.equippedWeapon and WeaponBlueprints[enemy.equippedWeapon] then
        local weapon = WeaponBlueprints[enemy.equippedWeapon]
        if weapon.grants_moves then
            for _, attackName in ipairs(weapon.grants_moves) do
                if not move_exists[attackName] then
                    table.insert(all_moves, attackName)
                    move_exists[attackName] = true
                end
            end
        end
    end

    -- Check every player unit to find the best possible target.
    for _, targetPlayer in ipairs(world.players) do
        if targetPlayer.hp > 0 then
            for _, attackName in ipairs(all_moves) do
                local attackData = AttackBlueprints[attackName]
                if attackData and enemy.wisp >= (attackData.wispCost or 0) then
                    -- Check if we can attack from the current position.
                    local currentTargets = WorldQueries.findValidTargetsForAttack(enemy, attackName, world)
                    if table_contains(currentTargets, targetPlayer) then
                        local damage = CombatFormulas.calculateFinalDamage(enemy, targetPlayer, attackData, false)
                        local hitChance = CombatFormulas.calculateHitChance(enemy, targetPlayer, attackData.Accuracy or 100)
                        local expectedDamage = damage * hitChance
                        local score = expectedDamage - (attackData.wispCost or 0) * 5

                        if damage >= targetPlayer.hp then
                            score = (1000 + expectedDamage) * hitChance -- Prioritize likely kills.
                        end

                        if score > bestScore then
                            bestScore = score
                            bestAction = { type = "attack_now", attackName = attackName, target = targetPlayer }
                        end
                    end

                    -- Check if we can move to a position to attack (only for cycle_target attacks).
                    if attackData.targeting_style == "cycle_target" then
                        local bestMovePosKey = findBestCycleTargetAttackPosition(enemy, targetPlayer, attackName, reachableTiles, world)
                        if bestMovePosKey then
                            local damage = CombatFormulas.calculateFinalDamage(enemy, targetPlayer, attackData, false)
                            local hitChance = CombatFormulas.calculateHitChance(enemy, targetPlayer, attackData.Accuracy or 100)
                            local expectedDamage = damage * hitChance
                            local score = (expectedDamage - (attackData.wispCost or 0) * 5) - 1 -- A small penalty for moving first.

                            if damage >= targetPlayer.hp then
                                score = ((1000 + expectedDamage) * hitChance) - 1
                            end

                            if score > bestScore then
                                bestScore = score
                                bestAction = { type = "move_and_attack", attackName = attackName, target = targetPlayer, destinationKey = bestMovePosKey }
                            end
                        end
                    end
                end
            end
        end
    end
    return bestAction
end

-- Finds the best obstacle to attack if it's blocking the path to the main objective.
local function findBestObstacleAttackAction(enemy, moveTarget, reachableTiles, world)
    local bestAction = nil
    local closestDistSq = math.huge

    -- Combine innate moves and moves granted by the equipped weapon.
    local all_moves = {}
    local move_exists = {} -- Use a set to track existing moves and prevent duplicates

    -- 1. Add moves from the enemy blueprint's innate list.
    local blueprint = EnemyBlueprints[enemy.enemyType]
    if blueprint and blueprint.attacks then
        for _, attackName in ipairs(blueprint.attacks) do
            if not move_exists[attackName] then
                table.insert(all_moves, attackName)
                move_exists[attackName] = true
            end
        end
    end

    -- 2. Add moves from the equipped weapon.
    if enemy.equippedWeapon and WeaponBlueprints[enemy.equippedWeapon] then
        local weapon = WeaponBlueprints[enemy.equippedWeapon]
        if weapon.grants_moves then
            for _, attackName in ipairs(weapon.grants_moves) do
                if not move_exists[attackName] then
                    table.insert(all_moves, attackName)
                    move_exists[attackName] = true
                end
            end
        end
    end

    -- Check every destructible obstacle on the map.
    for _, obstacle in ipairs(world.obstacles) do
        if obstacle.hp and obstacle.hp > 0 then
            for _, attackName in ipairs(all_moves) do
                local attackData = AttackBlueprints[attackName]
                -- Only consider damaging attacks.
                if attackData and enemy.wisp >= (attackData.wispCost or 0) and attackData.useType ~= "support" then
                    -- Can we move to a position to attack this obstacle?
                    if attackData.targeting_style == "cycle_target" then
                        local bestMovePosKey = findBestCycleTargetAttackPosition(enemy, obstacle, attackName, reachableTiles, world)
                        if bestMovePosKey then
                            -- It's a good idea to attack if the obstacle is "on the way" to the main goal.
                            local obsDistSq = (obstacle.tileX - enemy.tileX)^2 + (obstacle.tileY - enemy.tileY)^2
                            local targetDistSq = (moveTarget.tileX - enemy.tileX)^2 + (moveTarget.tileY - enemy.tileY)^2

                            if obsDistSq < targetDistSq and obsDistSq < closestDistSq then
                                closestDistSq = obsDistSq
                                bestAction = { type = "move_and_attack", attackName = attackName, target = obstacle, destinationKey = bestMovePosKey }
                            end
                        end
                    end
                end
            end
        end
    end
    return bestAction
end

function EnemyTurnSystem.update(dt, world)
    if world.turn ~= "enemy" then return end

    -- If any action is ongoing (animations, projectiles, etc.), wait for it to resolve.
    if WorldQueries.isActionOngoing(world) then return end

    -- Find the next enemy that has not yet acted.
    local actingEnemy = nil
    for _, enemy in ipairs(world.enemies) do
        if enemy.hp > 0 and not enemy.hasActed then
            -- Check if the unit is stunned at the start of its turn.
            if enemy.statusEffects and enemy.statusEffects.stunned then
                -- If stunned, their turn is skipped. Mark them as having acted.
                -- The loop will then continue to the next available enemy.
                enemy.hasActed = true
            else
                -- This is the enemy that will act.
                actingEnemy = enemy
                break
            end
        end
    end

    if actingEnemy then
        -- This block handles post-move logic. If a unit has no movement path,
        -- it could be at the start of its turn, or it could have just finished moving.
        if not actingEnemy.components.movement_path then
            if actingEnemy.components.ai and actingEnemy.components.ai.pending_attack then
                -- Execute the pending attack.
                local pending = actingEnemy.components.ai.pending_attack
                world.ui.targeting.cycle.active = true
                world.ui.targeting.cycle.targets = {pending.target}
                world.ui.targeting.cycle.selectedIndex = 1
                world.ui.targeting.selectedAttackName = pending.name
                UnitAttacks[pending.name](actingEnemy, world)
                actingEnemy.components.ai.pending_attack = nil
                world.ui.targeting.cycle.active = false
                world.ui.targeting.selectedAttackName= nil
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

        -- Get pathfinding data for the current enemy.
        local pathData = world.enemyPathfindingCache[actingEnemy]
        if not pathData then
            local reachable, came, cost = Pathfinding.calculateReachableTiles(actingEnemy, world)
            pathData = { reachableTiles = reachable, came_from = came, cost_so_far = cost }
            world.enemyPathfindingCache[actingEnemy] = pathData
        end
        local reachableTiles = pathData.reachableTiles
        local came_from = pathData.came_from
        local cost_so_far = pathData.cost_so_far

        -- AI Decision Making Logic

        -- Priority 1: Winning Move. If a win tile is reachable, move to it.
        if world.winTiles and #world.winTiles > 0 then
            for _, winTile in ipairs(world.winTiles) do
                local winTileKey = winTile.x .. "," .. winTile.y
                if reachableTiles[winTileKey] and reachableTiles[winTileKey].landable then
                    local startKey = actingEnemy.tileX .. "," .. actingEnemy.tileY
                    local path = Pathfinding.reconstructPath(came_from, cost_so_far, nil, startKey, winTileKey)
                    if path and #path > 0 then
                        actingEnemy.components.movement_path = path
                        actingEnemy.components.action_in_progress = true -- Set flag to prevent re-evaluation
                        return
                    end
                end
            end
        end

        -- Priority 2: Lethal Attack. Find the best attack against any player, prioritizing kills.
        local bestPlayerAttack = findBestPlayerAttackAction(actingEnemy, reachableTiles, world)
        if bestPlayerAttack then
            if bestPlayerAttack.type == "attack_now" then
                world.ui.targeting.cycle.active = true
                world.ui.targeting.cycle.targets = {bestPlayerAttack.target}
                world.ui.targeting.cycle.selectedIndex = 1
                world.ui.targeting.selectedAttackName = bestPlayerAttack.attackName
                UnitAttacks[bestPlayerAttack.attackName](actingEnemy, world)
                world.ui.targeting.cycle.active = false
                world.ui.targeting.selectedAttackName = nil
                actingEnemy.components.action_in_progress = true
            elseif bestPlayerAttack.type == "move_and_attack" then
                local startKey = actingEnemy.tileX .. "," .. actingEnemy.tileY
                local path = Pathfinding.reconstructPath(came_from, cost_so_far, nil, startKey, bestPlayerAttack.destinationKey)
                if path and #path > 0 then
                    actingEnemy.components.movement_path = path
                    actingEnemy.components.ai.pending_attack = { name = bestPlayerAttack.attackName, target = bestPlayerAttack.target }
                else
                    actingEnemy.components.action_in_progress = true
                end
            end
            return
        end

        -- Priority 3, 4, 5, 6: No player attack is possible. Decide where to move or what to attack.
        local moveTarget = nil
        if world.winTiles and #world.winTiles > 0 then
            -- Priority 3: Move towards the closest win tile.
            local closestWinTile = findClosestWinTile(actingEnemy, world)
            if closestWinTile then
                moveTarget = { tileX = closestWinTile.x, tileY = closestWinTile.y }
            end
        end

        if not moveTarget then
            -- Priority 6 (Fallback): No win tiles, or they are all occupied. Move towards the closest player.
            moveTarget = findClosestPlayer(actingEnemy, world)
        end

        -- Priority 4: Attack Obstacle. If a move target exists, check for obstacles to attack on the way.
        if moveTarget then
            local bestObstacleAttack = findBestObstacleAttackAction(actingEnemy, moveTarget, reachableTiles, world)
            if bestObstacleAttack then
                -- This will always be a "move_and_attack" action.
                local startKey = actingEnemy.tileX .. "," .. actingEnemy.tileY
                local path = Pathfinding.reconstructPath(came_from, cost_so_far, nil, startKey, bestObstacleAttack.destinationKey)
                if path and #path > 0 then
                    actingEnemy.components.movement_path = path
                    actingEnemy.components.ai.pending_attack = { name = bestObstacleAttack.attackName, target = bestObstacleAttack.target }
                    return -- Action decided, exit.
                end
            end

            -- Priority 5: Move Only. If no attack was possible, just move towards the target.
            local moveDestinationKey = findBestMoveOnlyTile(actingEnemy, moveTarget, reachableTiles, world)
            if moveDestinationKey then
                local startKey = actingEnemy.tileX .. "," .. actingEnemy.tileY
                local path = Pathfinding.reconstructPath(came_from, cost_so_far, nil, startKey, moveDestinationKey)
                if path and #path > 0 then
                    actingEnemy.components.movement_path = path
                    actingEnemy.components.action_in_progress = true -- Set flag to prevent re-evaluation
                    return
                end
            end
        end

        -- No action possible, end turn.
        actingEnemy.components.action_in_progress = true
    else
        -- No more enemies to act. Time for reinforcements.
        if world.reinforcementTiles and #world.reinforcementTiles > 0 then
            -- 1. Calculate reinforcement level based on turn count.
            -- Level increases by 1 every 3 turns (1-3 -> L1, 4-6 -> L2, etc.)
            local reinforcementLevel = 1 + math.floor((world.turnCount - 1) / 3)
            reinforcementLevel = math.min(reinforcementLevel, 50) -- Cap at max level

            -- 2. Get a list of all possible enemy types from the blueprints.
            local enemyTypes = {}
            for typeName, _ in pairs(EnemyBlueprints) do
                table.insert(enemyTypes, typeName)
            end

            if #enemyTypes > 0 then
                -- 3. Iterate through reinforcement tiles and spawn enemies.
                for _, tile in ipairs(world.reinforcementTiles) do
                    if not WorldQueries.isTileOccupied(tile.x, tile.y, nil, world) then
                        -- Each unoccupied reinforcement tile has a 50% chance to spawn an enemy.
                        if love.math.random() < 0.5 then
                            local randomEnemyType = enemyTypes[love.math.random(1, #enemyTypes)]
                            local newEnemy = EntityFactory.createSquare(tile.x, tile.y, "enemy", randomEnemyType, { level = reinforcementLevel })
                            world:queue_add_entity(newEnemy)
                        end
                    end
                end
            end
        end
        -- Before ending the turn, resolve any pending ascensions.
        AscensionSystem.descend_units(world)

        -- No more enemies to act, which means the enemy turn is over.
        world.ui.turnShouldEnd = true
    end
end

return EnemyTurnSystem