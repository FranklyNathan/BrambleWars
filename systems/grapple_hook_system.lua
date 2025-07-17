-- grapple_hook_system.lua
-- Manages the movement and state of grappling hook projectiles.
local Grid = require("modules.grid")
local EventBus = require("modules.event_bus")
local WorldQueries = require("modules.world_queries")

local GrappleHookSystem = {}

function GrappleHookSystem.update(dt, world)
    -- Loop through all entities to find active grapple hooks
    for i = #world.all_entities, 1, -1 do
        local entity = world.all_entities[i]
        if entity.type == "grapple_hook" and entity.components.grapple_hook then
            local hook = entity.components.grapple_hook

            if hook.state == "firing" then
                -- 1. Move the hook forward
                local moveAmount = hook.speed * dt
                if hook.direction == "up" then
                    entity.y = entity.y - moveAmount
                elseif hook.direction == "down" then
                    entity.y = entity.y + moveAmount
                elseif hook.direction == "left" then
                    entity.x = entity.x - moveAmount
                elseif hook.direction == "right" then
                    entity.x = entity.x + moveAmount
                end

                -- 2. Update distance traveled
                hook.distanceTraveled = hook.distanceTraveled + moveAmount

                -- 3. Check for collision with units
                local potentialTargets = {}
                for _, p in ipairs(world.players) do table.insert(potentialTargets, p) end
                for _, e in ipairs(world.enemies) do table.insert(potentialTargets, e) end

                for _, target in ipairs(potentialTargets) do
                    -- The hook can't hit its own attacker or dead units.
                    if target ~= hook.attacker and target.hp > 0 then
                        -- Simple AABB collision check
                        if entity.x < target.x + target.size and entity.x + entity.size > target.x and
                           entity.y < target.y + target.size and entity.y + entity.size > target.y then
                            -- Collision detected!
                            hook.state = "hit"
                            hook.target = target -- Store what was hit
                            EventBus:dispatch("grapple_hook_hit", { hookEntity = entity, world = world, target = target})
                            break -- Stop checking other units
                        end
                    end
                end

                -- 4. Check for collision with obstacles (if still firing)
                if hook.state == "firing" then
                    for _, obstacle in ipairs(world.obstacles) do
                        if entity.x < obstacle.x + obstacle.width and entity.x + entity.size > obstacle.x and
                           entity.y < obstacle.y + obstacle.height and entity.y + entity.size > obstacle.y then
                            hook.state = "hit"
                            EventBus:dispatch("grapple_hook_hit", { hookEntity = entity, world = world, target = obstacle})
                            hook.target = obstacle
                            break
                        end
                    end
                end

                -- 5. If no collision, check if max distance is reached
                if hook.state == "firing" and hook.distanceTraveled >= hook.maxDistance then
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