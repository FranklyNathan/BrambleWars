-- attack_handler.lua
-- This module is responsible for dispatching player attacks.

local UnitAttacks = require("data.unit_attacks")
local EventBus = require("modules.event_bus")
local AttackBlueprints = require("data.attack_blueprints")
local CombatActions = require("modules.combat_actions")

local AttackHandler = {}

function AttackHandler.execute(square, attackName, world)
    local attackData = AttackBlueprints[attackName]
    local target = nil  -- Initialize target to nil

    -- Safety checks
    if not attackData then
        print("Error: Attack data not found for attack:", attackName)
        return false
    end

    if not UnitAttacks[attackName] then
        print("Error: Attack function not found for attack:", attackName)
        return false
    end

    -- Handle cycle targeting: Get the selected target and ensure it's valid
    if attackData.targeting_style == "cycle_target" then
        if not world.cycleTargeting.active or not world.cycleTargeting.targets[world.cycleTargeting.selectedIndex] then
            print("Error: No valid cycle target selected for attack:", attackName)
            return false
        end
        target = world.cycleTargeting.targets[world.cycleTargeting.selectedIndex]
    elseif attackData.targeting_style == "ground_aim" then
        -- For ground-aimed attacks, the target tile is already set in world.mapCursorTile.
        -- We do not pass a specific target.
    end    

    -- Check if the unit has enough Wisp. Basic attacks always have 0 cost.
    if attackData.wispCost > 0 and square.wisp < attackData.wispCost then
        print("Insufficient Wisp for attack:", attackName)
        return false -- Not enough Wisp, attack fails.
    end

    print("Executing attack:", attackName)
    print("Target:", target)
    print("Attacker:", square)

    -- Deduct the Wisp cost.
    if attackData.wispCost > 0 then
        if not AttackHandler.deductWispCost(square, attackData) then return false end
    end

    -- Execute the attack.
    local result = UnitAttacks[attackName](square, attackData.power, world, target) -- Target is only used by cycle-targeting
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