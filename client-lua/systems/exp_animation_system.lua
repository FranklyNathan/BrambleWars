-- systems/exp_animation_system.lua
-- This system handles the visual animation of the EXP bar filling up.

local ExpAnimationSystem = {}

function ExpAnimationSystem.update(dt, world)
    local anim = world.ui.expGainAnimation
    if not anim.active or not anim.unit then return end

    -- Only process the "filling" state. The level-up system will handle
    -- what happens after the bar is full.
    if anim.state == "filling" then
        anim.animationTimer = anim.animationTimer + dt
        local progress = math.min(1, anim.animationTimer / anim.animationDuration)

        -- Linearly interpolate the displayed EXP value for a smooth fill.
        anim.expCurrentDisplay = anim.expStart + (anim.expGained * progress)

        if progress >= 1 then
            -- The bar has finished filling. Set the state to "finished" so other
            -- systems (like the level-up system) know they can proceed.
            anim.state = "finished"
        end
    end
end

return ExpAnimationSystem