-- systems/rescue_animation_system.lua
-- This system handles the visual effect of a unit being rescued,
-- deleting the unit after its "lunge" animation is complete.

local RescueAnimationSystem = {}

function RescueAnimationSystem.update(dt, world)
    -- Iterate backwards in case we modify the list, though we aren't here.
    for i = #world.all_entities, 1, -1 do
        local entity = world.all_entities[i]
        if entity.components.being_rescued then
            local rescueComp = entity.components.being_rescued
            rescueComp.timer = rescueComp.timer - dt

            if rescueComp.timer <= 0 then
                -- Animation time is up. Mark the unit for deletion.
                entity.isMarkedForDeletion = true
                entity.components.being_rescued = nil -- Clean up component
            end
        end
    end
end

return RescueAnimationSystem