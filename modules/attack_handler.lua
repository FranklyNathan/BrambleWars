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

    -- Check for and deduct the Wisp cost.
    if not AttackHandler.deductWispCost(square, attackData) then
        return false -- Not enough Wisp, attack fails.
    end

    local attackInstanceId = nextAttackInstanceId
    nextAttackInstanceId = nextAttackInstanceId + 1

    -- Set the selected attack name for the duration of this execution, so attack implementations can reference it.
    world.ui.targeting.selectedAttackName = attackName
    -- Execute the attack. The attack function now only needs the attacker and the world state.
    local result = UnitAttacks[attackName](square, world, attackInstanceId)

    -- If the attack was Ascension, add the visual animation component.
    -- This is done here to ensure it happens after the core logic in UnitAttacks.
    if attackName == "ascension" then
        square.lastDirection = "up" -- Ensure the sprite faces up for the animation.
        square.components.ascending_animation = {
            timer = 0.4, -- Duration of the upward animation in seconds
            initialTimer = 0.4,
            speed = 900 -- Speed in pixels per second
        }
    end
    -- Clean up the state.
    world.ui.targeting.selectedAttackName = nil
    -- If the attack function returns a boolean, use it. Otherwise, assume it fired successfully.
    if type(result) == "boolean" then
        return result
    else
        return true -- Attack succeeded.
    end
end

function AttackHandler.deductWispCost(attacker, attackData)
    if not attacker or not attackData then return false end

    local cost = attackData.wispCost or 0
    if attacker.wisp >= cost then
        attacker.wisp = attacker.wisp - cost
        return true -- Enough wisp, deduct cost
    else
        return false -- Not enough wisp
    end
end
return AttackHandler