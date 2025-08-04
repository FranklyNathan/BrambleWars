-- movement_system.lua
-- Handles updating entity positions based on their target coordinates.
-- Also manages the creation of afterimage effects during movement.

local CharacterBlueprints = require("data.character_blueprints")

local MovementSystem = {}

function MovementSystem.update(dt, world)
    for _, entity in ipairs(world.all_entities) do
        -- Only process entities that can move and have a target
        if entity.speed and entity.targetX and ((entity.x ~= entity.targetX) or (entity.y ~= entity.targetY)) then
            local oldX, oldY = entity.x, entity.y
            local wasMoving = true

            -- Use the final calculated speed from the StatSystem
            local moveAmount = ((entity.finalSpeed or entity.speed) * (entity.speedMultiplier or 1)) * dt
            local epsilon = 3

            -- Prioritize horizontal movement, then vertical, to prevent diagonal interpolation.
            if entity.x ~= entity.targetX then
                if entity.x < entity.targetX then
                    entity.x = math.min(entity.targetX, entity.x + moveAmount)
                else -- entity.x > entity.targetX
                    entity.x = math.max(entity.targetX, entity.x - moveAmount)
                end
            elseif entity.y ~= entity.targetY then
                if entity.y < entity.targetY then
                    entity.y = math.min(entity.targetY, entity.y + moveAmount)
                else -- entity.y > entity.targetY
                    entity.y = math.max(entity.targetY, entity.y - moveAmount)
                end
            end

            -- Create afterimage for players during movement
            if entity.type == "player" then
                if not entity.components.afterimage then
                    entity.components.afterimage = { timer = 0, interval = 0.05 }
                end
                local afterimage = entity.components.afterimage
                afterimage.timer = afterimage.timer + dt
                if afterimage.timer >= afterimage.interval then
                    afterimage.timer = afterimage.timer - afterimage.interval
                    -- Use the character's dominant color for the afterimage streak.
                    local blueprint = CharacterBlueprints[entity.playerType]
                    local streakColor = (blueprint and blueprint.dominantColor) or entity.color

                    -- Get sprite dimensions if available for the streak, otherwise use the logical size.
                    local streakWidth, streakHeight = entity.size, entity.size
                    local currentFrame, spriteSheet = nil, nil
                    if entity.components.animation then
                        local animComponent = entity.components.animation
                        local currentAnim = animComponent.animations[animComponent.current]
                        if currentAnim then
                            -- This gets the actual pixel dimensions of the current animation frame.
                            streakWidth, streakHeight = currentAnim:getDimensions()
                            -- Get the current frame (Quad) and the spritesheet Image
                            currentFrame = currentAnim.frames[currentAnim.position]
                            spriteSheet = animComponent.spriteSheet
                        end
                    end

                    table.insert(world.afterimageEffects, {
                        x = oldX, y = oldY, size = entity.size, -- Keep logical size for positioning
                        width = streakWidth, height = streakHeight, -- Store actual sprite dimensions
                        frame = currentFrame, -- The Quad for the specific frame
                        spriteSheet = spriteSheet, -- The Image for the spritesheet
                        color = streakColor, playerType = entity.playerType, lifetime = 0.2, initialLifetime = 0.2, direction = entity.lastDirection
                    })
                end
            end

            local isStillMoving = (entity.x ~= entity.targetX) or (entity.y ~= entity.targetY)
            if wasMoving and not isStillMoving then
                entity.speedMultiplier = 1 -- Reset speed multiplier once movement is complete
            end
        end
    end
end

return MovementSystem