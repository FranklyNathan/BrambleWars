-- modules/rescue_handler.lua
-- Contains the logic for executing Rescue and Drop commands.

local Grid = require("modules.grid")
local EventBus = require("modules.event_bus")
local WorldQueries = require("modules.world_queries")

local RescueHandler = {}

-- Calculates the movement penalty for a rescuer.
-- The penalty is based on the ratio of the rescuer's base weight to the carried unit's weight.
-- The closer in weight they are, the higher the penalty.
-- X = Rescuer's Base Weight / Carried Unit's Weight
function RescueHandler.calculateMovementPenalty(rescuer, carriedUnit)
    -- We will use 'baseWeight' to ensure the calculation is always based on original stats,
    -- not the combined weight. We'll need to add this to our units later.
    if not rescuer or not carriedUnit or not rescuer.baseWeight or not carriedUnit.baseWeight or carriedUnit.baseWeight == 0 then
        return 0 -- No penalty if data is invalid or dividing by zero.
    end

    local ratio = rescuer.baseWeight / carriedUnit.baseWeight

    if ratio >= 4 then
        return 1 -- Light load, small penalty.
    elseif ratio >= 2 then -- This covers the range [2, 4)
        return 2 -- Medium load, medium penalty.
    else -- Less than 2
        return 3 -- Heavy load, large penalty.
    end
end

-- Executes the Rescue action.
-- The rescuer picks up the target unit.
function RescueHandler.rescue(rescuer, target, world)
    if not rescuer or not target then return false end
    if target.weight >= rescuer.weight then return false end -- Cannot rescue heavier units.

    -- 1. Store the carried unit and apply penalties.
    rescuer.carriedUnit = target
    rescuer.rescuePenalty = RescueHandler.calculateMovementPenalty(rescuer, target)
    rescuer.weight = rescuer.baseWeight + target.baseWeight -- Update current weight.

    -- 2. Animate the target moving to the rescuer's tile before disappearing.
    target.isCarried = true -- Flag to remember its state.

    -- Set the target's destination to the rescuer's tile. The movement_system will handle the movement.
    target.targetX = rescuer.x
    target.targetY = rescuer.y
    -- Give it a speed boost to make the animation quick and feel like a lunge.
    target.speedMultiplier = 4

    -- Add a component to handle the delayed deletion after the animation.
    -- A new system will need to process this component.
    target.components.being_rescued = { timer = 0.25 } -- A short duration for the animation.

    return true
end

-- Executes the Drop action.
-- The rescuer places the carried unit on an adjacent tile.
function RescueHandler.drop(rescuer, tileX, tileY, world)
    local carriedUnit = rescuer.carriedUnit
    if not carriedUnit then return false end

    -- 1. Restore the carried unit to the world.
    -- Set its starting visual position to the rescuer's position for the animation.
    carriedUnit.x, carriedUnit.y = rescuer.x, rescuer.y

    -- Set its final logical and visual target position to the drop tile.
    local destPixelX, destPixelY = Grid.toPixels(tileX, tileY)
    carriedUnit.tileX, carriedUnit.tileY = tileX, tileY
    carriedUnit.targetX, carriedUnit.targetY = destPixelX, destPixelY
    EventBus:dispatch("unit_tile_changed", { unit = carriedUnit, world = world })

    -- Give it a speed boost for the lunge effect.
    carriedUnit.speedMultiplier = 4

    carriedUnit.isCarried = false
    world:queue_add_entity(carriedUnit) -- Re-add the unit to the world.

    -- 2. Reset the rescuer's state.
    rescuer.carriedUnit = nil
    rescuer.rescuePenalty = 0
    rescuer.weight = rescuer.baseWeight

    return true
end

return RescueHandler