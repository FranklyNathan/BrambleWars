-- grapple_hook_system.lua
-- Manages the movement and state of grappling hook projectiles.
local Grid = require("modules.grid")
local EventBus = require("modules.event_bus")
local WorldQueries = require("modules.world_queries")

local GrappleHookSystem = {}

function GrappleHookSystem.update(dt, world)
    -- Loop through active grapple hooks. This is much more efficient than scanning all_entities.
    for i = #world.grapple_hooks, 1, -1 do
        local entity = world.grapple_hooks[i]
        -- A central system will handle removing entities marked for deletion from all lists.
        -- We just need to stop processing them here.
        if not entity.isMarkedForDeletion then
            local hook = entity.components.grapple_hook

            if hook.state == "firing" then
                -- 1. Move the hook forward
                local moveAmount = hook.speed * dt
                if hook.direction == "up" then entity.y = entity.y - moveAmount
                elseif hook.direction == "down" then entity.y = entity.y + moveAmount
                elseif hook.direction == "left" then entity.x = entity.x - moveAmount
                elseif hook.direction == "right" then entity.x = entity.x + moveAmount end

                -- 2. Update distance traveled
                hook.distanceTraveled = hook.distanceTraveled + moveAmount

                -- 3. Check for collision using efficient, tile-based logic
                local currentTileX, currentTileY = Grid.toTile(entity.x, entity.y)
                local hitTarget = nil

                -- Check for map boundary collision first
                if currentTileX < 0 or currentTileX >= world.map.width or
                   currentTileY < 0 or currentTileY >= world.map.height then
                    entity.isMarkedForDeletion = true
                else
                    -- Check for collision with any obstacle on the current tile.
                    for _, obstacle in ipairs(world.obstacles) do
                        local obsStartX, obsStartY = obstacle.tileX, obstacle.tileY
                        local obsEndX, obsEndY = Grid.toTile(obstacle.x + obstacle.width - 1, obstacle.y + obstacle.height - 1)
                        if currentTileX >= obsStartX and currentTileX <= obsEndX and currentTileY >= obsStartY and currentTileY <= obsEndY then
                            hitTarget = obstacle
                            break
                        end
                    end

                    -- If no obstacle was hit, check for collision with units.
                    if not hitTarget then
                        local potentialTargets = {}
                        for _, p in ipairs(world.players) do table.insert(potentialTargets, p) end
                        for _, e in ipairs(world.enemies) do table.insert(potentialTargets, e) end

                        for _, unit in ipairs(potentialTargets) do
                            if unit.hp > 0 and unit ~= hook.attacker and unit.tileX == currentTileX and unit.tileY == currentTileY then
                                hitTarget = unit
                                break
                            end
                        end
                    end
                end

                -- 4. Handle collision if a target was hit
                if hitTarget then
                    hook.state = "hit"
                    hook.target = hitTarget
                    EventBus:dispatch("grapple_hook_hit", { hookEntity = entity, world = world, target = hitTarget })
                -- 5. If no collision, check if max distance is reached
                elseif not entity.isMarkedForDeletion and hook.distanceTraveled >= hook.maxDistance then
                    -- For now, just remove the hook if it misses
                    entity.isMarkedForDeletion = true
                end
            end
        end
    end
end

-- Event handler for grapple hook hits
EventBus:register("grapple_hook_hit", function(data)
    local hookEntity = data.hookEntity
    local world = data.world
    local hook = hookEntity.components.grapple_hook
    local attacker = hook.attacker
    local target = hook.target

    if not attacker or not target then
        hookEntity.isMarkedForDeletion = true
        return
    end

    -- 1. Get weights
    local attackerWeight = attacker.weight or 1
    local targetWeight = target.weight or 1

    -- 2. Compare weights and determine movement
    local pullAttacker = false
    local pullTarget = false
    local pullBoth = false

if target.isObstacle then
        -- If the target is any kind of obstacle, the attacker is always pulled.
        pullAttacker = true
    else
        -- Standard unit-vs-unit logic
        if targetWeight == "Permanent" then
            pullAttacker = true
        elseif attackerWeight < targetWeight then
            pullAttacker = true
        elseif attackerWeight > targetWeight then
            pullTarget = true
        else -- attackerWeight == targetWeight
            pullBoth = true
        end
    end

    -- 3. Calculate destinations and initiate movement
    local step = Config.SQUARE_SIZE
    local pullSpeed = 4 -- Speed multiplier for the pull

    if pullAttacker then
        -- Attacker is pulled to the tile adjacent to the target
        local destX, destY = target.x, target.y
        if hook.direction == "up" then destY = destY + step
        elseif hook.direction == "down" then destY = destY - step
        elseif hook.direction == "left" then destX = destX + step
        elseif hook.direction == "right" then destX = destX - step
        end
        attacker.targetX, attacker.targetY = destX, destY
        attacker.speedMultiplier = pullSpeed
        -- Update the logical tile position immediately.
        attacker.tileX, attacker.tileY = Grid.toTile(destX, destY)
    elseif pullTarget then
        -- Target is pulled to the tile adjacent to the attacker
        local destX, destY = attacker.x, attacker.y
        if hook.direction == "up" then destY = attacker.y - step
        elseif hook.direction == "down" then destY = attacker.y + step
        elseif hook.direction == "left" then destX = attacker.x - step
        elseif hook.direction == "right" then destX = attacker.x + step
        end
        target.targetX, target.targetY = destX, destY
        target.speedMultiplier = pullSpeed
        -- Update the logical tile position immediately.
        target.tileX, target.tileY = Grid.toTile(destX, destY)
    elseif pullBoth then
        -- Both are pulled towards each other, meeting in the middle.
        local moveTiles = math.floor((hook.distanceTraveled / Config.SQUARE_SIZE) / 2)
        local movePixels = moveTiles * Config.SQUARE_SIZE

        -- Set destinations for both attacker and target
        attacker.targetX, attacker.targetY = Grid.getDestination(attacker.x, attacker.y, hook.direction, movePixels)
        target.targetX, target.targetY = Grid.getDestination(target.x, target.y, hook.direction, -movePixels)
        attacker.speedMultiplier, target.speedMultiplier = pullSpeed, pullSpeed
        -- Update the logical tile positions immediately.
        attacker.tileX, attacker.tileY = Grid.toTile(attacker.targetX, attacker.targetY)
        target.tileX, target.tileY = Grid.toTile(target.targetX, target.targetY)
    end

    -- 4. Mark the hook for deletion
    hookEntity.isMarkedForDeletion = true
end)

return GrappleHookSystem