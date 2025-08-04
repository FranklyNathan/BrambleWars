-- animation_system.lua
-- This system updates all animated sprites in the game.

local AnimationSystem = {}

function AnimationSystem.update(dt, world)
    for _, entity in ipairs(world.all_entities) do
        -- Check if the entity has an animation component
        if entity.components.animation then
            local animComponent = entity.components.animation

            -- Initialize previous position if it doesn't exist.
            if not animComponent.prevX then
                animComponent.prevX = entity.x
                animComponent.prevY = entity.y
            end

            -- 1. Set the correct animation based on the entity's direction.
            -- This works for both player and AI, since both use 'lastDirection'.
            if entity.lastDirection and animComponent.animations[entity.lastDirection] then
                animComponent.current = entity.lastDirection
            end

            local currentAnim = animComponent.animations[animComponent.current]
            if not currentAnim then return end -- Safety check

            -- 2. Pause or resume the animation based on whether the entity's position has changed.
            -- This is more robust than checking against targetX/Y, as it catches all forms
            -- of movement (grid-based, dashes, knockbacks, etc.).
            local isMoving = (entity.x ~= animComponent.prevX) or (entity.y ~= animComponent.prevY)
            -- A unit should also animate if it's airborne, even if its logical position isn't changing.
            local isAirborne = entity.statusEffects and entity.statusEffects.airborne
            local shouldBePaused = not isMoving and not entity.isFlying and not isAirborne

            if shouldBePaused then
                -- If the entity should be still but is animating, pause it.
                if currentAnim.status == "playing" then
                    currentAnim:pauseAtStart()
                end
            else
                -- If the entity should be animating but is paused, resume it.
                if currentAnim.status == "paused" then
                    currentAnim:resume()
                end
            end

            -- 3. Update the animation frame based on delta time.
            currentAnim:update(dt)

            -- 4. Store the current position for the next frame's check.
            animComponent.prevX = entity.x
            animComponent.prevY = entity.y
        end
    end
end

return AnimationSystem