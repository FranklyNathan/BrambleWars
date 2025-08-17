-- systems/enemy_turn_system.lua
-- Manages the sequence of enemy actions during their turn and controls camera focus.

local Pathfinding = require("modules.pathfinding")
local WorldQueries = require("modules.world_queries")
local Grid = require("modules.grid")
local EffectFactory = require("modules.effect_factory")
local Camera = require("modules.camera")

local EnemyTurnSystem = {}

-- State for the system's internal logic.
EnemyTurnSystem.state = {
    activeEnemyIndex = 1,
    phase = "picking_enemy", -- "picking_enemy", "panning_camera", "acting", "waiting_for_action"
    timer = 0
}

-- A static, non-moving entity for the camera to focus on to keep it stationary.
-- It needs a 'size' property so the camera system can calculate its center point.
local cameraAnchor = { x = 0, y = 0, size = 0 }

-- A very simple AI to find the closest player unit.
local function find_closest_player(enemy, world)
    local closestPlayer = nil
    local min_dist = math.huge
    for _, player in ipairs(world.players) do
        if player.hp > 0 then
            local dist = math.abs(enemy.tileX - player.tileX) + math.abs(enemy.tileY - player.tileY)
            if dist < min_dist then
                min_dist = dist
                closestPlayer = player
            end
        end
    end
    return closestPlayer
end

-- A simple AI action: move towards the closest player and attack if possible.
local function perform_ai_action(enemy, world)
    -- First, calculate all possible moves. This is needed for both winning and moving towards a player.
    local reachableTiles, cameFrom, costSoFar = Pathfinding.calculateReachableTiles(enemy, world)

    -- 1. HIGHEST PRIORITY: Check if a winning move is possible.
    -- If an enemy can reach a win tile, it should always take that opportunity.
    if world.winTiles and #world.winTiles > 0 then
        for _, winTile in ipairs(world.winTiles) do
            local winPosKey = winTile.x .. "," .. winTile.y
            if reachableTiles[winPosKey] and reachableTiles[winPosKey].landable then
                print(string.format("[AI DEBUG] %s prioritizing winning move to (%d,%d)!", enemy.enemyType, winTile.x, winTile.y))
                local startPosKey = enemy.tileX .. "," .. enemy.tileY
                local pathInPixels = Pathfinding.reconstructPath(cameFrom, costSoFar, nil, startPosKey, winPosKey)
                if #pathInPixels > 0 then
                    enemy.components.movement_path = pathInPixels
                else
                    enemy.hasActed = true -- Should not happen, but a failsafe.
                end
                return -- Winning move chosen, exit.
            end
        end
    end

    -- 2. If no winning move is possible, check for an attack from the current position.
    -- This is more robust than the old logic, which only considered attacking the closest player.
    local available_attacks = WorldQueries.getUnitMoveList(enemy)
    for _, attackName in ipairs(available_attacks) do
        local validTargets = WorldQueries.findValidTargetsForAttack(enemy, attackName, world)
        if #validTargets > 0 then
            -- Found a valid attack. Execute it against the first available target.
            local targetToAttack = validTargets[1]

            -- Make the enemy face its target and trigger the lunge animation.
            -- This was missing, causing enemies to attack without turning or animating.
            enemy.lastDirection = Grid.getDirection(enemy.tileX, enemy.tileY, targetToAttack.tileX, targetToAttack.tileY)
            enemy.components.lunge = { timer = 0.2, initialTimer = 0.2, direction = enemy.lastDirection }

            enemy.components.action_in_progress = true
            local targetType = (enemy.type == "player") and "enemy" or "player"
            EffectFactory.addAttackEffect(world, {
                attacker = enemy,
                attackName = attackName,
                x = targetToAttack.x, y = targetToAttack.y,
                width = targetToAttack.size, height = targetToAttack.size,
                targetType = targetType
            })
            return -- Action chosen, exit.
        end
    end

    -- 2. If no attack was possible, find the closest player and move towards them.
    local target = find_closest_player(enemy, world)
    if not target then
        -- No players left on the map.
        enemy.hasActed = true
        return
    end

    -- Capture the 'cameFrom' table which is needed to reconstruct the path.
    -- We now capture 'costSoFar' as it's required by the updated reconstructPath function.
    local reachableTiles, cameFrom, costSoFar = Pathfinding.calculateReachableTiles(enemy, world)

    -- DEBUG: Print the number of reachable tiles found.
    local reachableTileCount = 0
    for _ in pairs(reachableTiles) do reachableTileCount = reachableTileCount + 1 end
    print(string.format("[AI DEBUG] %s at (%d,%d) found %d reachable tiles.", enemy.enemyType, enemy.tileX, enemy.tileY, reachableTileCount))


    local best_move_tile = nil
    local min_dist_to_target = math.huge

    for posKey, data in pairs(reachableTiles) do
        if data.landable then
            local tileX = tonumber(string.match(posKey, "(-?%d+)"))
            local tileY = tonumber(string.match(posKey, ",(-?%d+)"))

            -- Check if the tile is a water hazard for units that can't swim or fly.
            -- This prevents the AI from pathing into tiles that would cause them to drown.
            local isWater = WorldQueries.isTileWater(tileX, tileY, world)
            local canTraverseWater = enemy.isFlying or enemy.canSwim

            if not (isWater and not canTraverseWater) then
                local dist = math.abs(tileX - target.tileX) + math.abs(tileY - target.tileY)
                if dist < min_dist_to_target then
                    min_dist_to_target = dist
                    best_move_tile = {x = tileX, y = tileY}
                end
            end
        end
    end

    if best_move_tile then
        -- DEBUG: Print the chosen destination.
        print(string.format("[AI DEBUG] %s is moving to (%d,%d) to get closer to %s.", enemy.enemyType, best_move_tile.x, best_move_tile.y, target.displayName))

        -- Reconstruct the path from the start to the best destination tile.
        local startPosKey = enemy.tileX .. "," .. enemy.tileY
        local goalPosKey = best_move_tile.x .. "," .. best_move_tile.y
        -- Call reconstructPath with the correct arguments. The AI has no cursor path, so we pass 'nil'.
        -- The Pathfinding.reconstructPath function returns a path in PIXEL coordinates.
        local pathInPixels = Pathfinding.reconstructPath(cameFrom, costSoFar, nil, startPosKey, goalPosKey)

        -- The old code was converting these pixel coordinates a second time, leading to massive values.
        -- By removing the conversion loop, we use the correct pixel coordinates directly.

        -- DEBUG: Print the length of the generated path.
        print(string.format("[AI DEBUG] Path reconstructed with %d steps.", #pathInPixels))

        -- Assign the path to the enemy. The TurnBasedMovementSystem will handle the rest,
        -- including setting hasActed = true when the movement is complete.
        if #pathInPixels > 0 then
            enemy.components.movement_path = pathInPixels
        else
            enemy.hasActed = true -- No path found, end turn.
        end
    else
        -- DEBUG: Print that no valid move was found.
        print(string.format("[AI DEBUG] %s could not find a valid move tile from its reachable set.", enemy.enemyType))
        enemy.hasActed = true -- No valid move, end turn.
    end
end

function EnemyTurnSystem.update(dt, world)
    if world.turn ~= "enemy" then
        -- This needs to be reset at the start of the player's turn so the enemy turn can run correctly next time.
        EnemyTurnSystem.state.activeEnemyIndex = 1
        EnemyTurnSystem.state.phase = "picking_enemy"
        world.ui.cameraFocusEntity = nil -- Ensure focus is cleared when turn ends.
        return
    end

    -- If a level-up animation is playing (e.g., from a player's counter-attack kill),
    -- pause the entire enemy turn state machine. This prevents other enemies from
    -- moving or acting while the player is focused on the level-up sequence.
    if world.ui.levelUpAnimation and world.ui.levelUpAnimation.active then
        return
    end

    local state = EnemyTurnSystem.state

    if state.phase == "picking_enemy" then
        while state.activeEnemyIndex <= #world.enemies and (world.enemies[state.activeEnemyIndex].hp <= 0 or world.enemies[state.activeEnemyIndex].hasActed) do
            state.activeEnemyIndex = state.activeEnemyIndex + 1
        end

        -- After finding the next valid enemy, decide if we need to move the camera.
        if state.activeEnemyIndex > #world.enemies then
            -- No more enemies to move. End the turn if no actions are ongoing.
            if not WorldQueries.isActionOngoing(world) then world.ui.turnShouldEnd = true end
        else
            local currentEnemy = world.enemies[state.activeEnemyIndex]
            local targetPlayer = find_closest_player(currentEnemy, world)

            -- Determine if a camera pan is necessary. Pan if the current actor or its
            -- intended target are not visible. This keeps the action on-screen.
            local isTargetVisible = not targetPlayer or Camera.isEntityVisible(targetPlayer)
            local needsPan = not Camera.isEntityVisible(currentEnemy) or not isTargetVisible

            if needsPan then
                -- An important unit is off-screen. Set focus and pan the camera.
                world.ui.cameraFocusEntity = currentEnemy
                state.phase = "panning_camera"
                state.timer = 0.5 -- Time for camera to pan.
            else
                -- Everything is visible. Skip the pan and act immediately.
                state.phase = "acting"
            end
        end
    elseif state.phase == "panning_camera" then
        state.timer = state.timer - dt
        if state.timer <= 0 then
            state.phase = "acting"
            -- After the pan, make the camera focus on a static anchor point at the
            -- enemy's current location. This keeps the camera stationary without it
            -- snapping back to a default position.
            local currentEnemy = world.enemies[state.activeEnemyIndex]
            cameraAnchor.x, cameraAnchor.y = currentEnemy.x, currentEnemy.y
            -- This was the missing piece. The anchor must also have the same size as the
            -- enemy to ensure the camera's calculated center point doesn't change.
            cameraAnchor.size = currentEnemy.size
            world.ui.cameraFocusEntity = cameraAnchor
        end
    elseif state.phase == "acting" then
        perform_ai_action(world.enemies[state.activeEnemyIndex], world)
        state.phase = "waiting_for_action"
    elseif state.phase == "waiting_for_action" then
        local currentEnemy = world.enemies[state.activeEnemyIndex]
        -- The action is over when there are no global actions (like attacks or animations)
        -- AND the current enemy is no longer moving (its movement_path is nil).
        -- This prevents the camera from jumping to the next enemy before the current one finishes its move.
        if not WorldQueries.isActionOngoing(world) and not (currentEnemy and currentEnemy.components.movement_path) then
            state.activeEnemyIndex = state.activeEnemyIndex + 1
            state.phase = "picking_enemy"
        end
    end
end

return EnemyTurnSystem