-- attack_handler.lua
-- This module is responsible for dispatching player attacks.

local UnitAttacks = require("data.unit_attacks")
local AttackBlueprints = require("data.attack_blueprints")

local AttackHandler = {}

local nextAttackInstanceId = 1

function AttackHandler.execute(square, attackName, world)
    local attackData = AttackBlueprints[attackName]

    -- Safety checks
    if not attackData then
        return false
    end

    if not UnitAttacks[attackName] then
        return false
    end

    -- Handle cycle targeting: Get the selected target and ensure it's valid
    if attackData.targeting_style == "cycle_target" then
        if not world.ui.targeting.cycle.active or not world.ui.targeting.cycle.targets[world.ui.targeting.cycle.selectedIndex] then
            return false
        end
    elseif attackData.targeting_style == "ground_aim" then
        -- For ground-aimed attacks, the target tile is already set in world.ui.mapCursorTile.
        -- We do not pass a specific target.
    end

    -- Check for Wisp cost BEFORE executing, but do not deduct yet.
    local cost = attackData.wispCost or 0
    if square.wisp < cost then
        -- TODO: Add a sound effect for "not enough mana"
        return false
    end

    local attackInstanceId = nextAttackInstanceId
    nextAttackInstanceId = nextAttackInstanceId + 1

    -- Set the selected attack name for the duration of this execution, so attack implementations can reference it.
    world.ui.targeting.selectedAttackName = attackName
    -- Execute the attack. The attack function now only needs the attacker and the world state.
    local result = UnitAttacks[attackName](square, world, attackInstanceId)

    -- If the attack was successful, NOW we deduct the wisp cost.
    if result then
        square.wisp = square.wisp - cost
    end

    -- If the attack was Ascension, add the visual animation component.
    -- This is done here to ensure it happens after the core logic in UnitAttacks.
    if attackName == "ascension" and result then
        square.lastDirection = "up" -- Ensure the sprite faces up for the animation.
        square.components.ascending_animation = {
            timer = 0.4, -- Duration of the upward animation in seconds
            initialTimer = 0.4,
            speed = 900 -- Speed in pixels per second
        }
    end
    -- If the attack function returns a boolean, use it. Otherwise, assume it fired successfully.
    if type(result) == "boolean" then
        return result
    else
        return true -- Attack succeeded.
    end
end

return AttackHandler