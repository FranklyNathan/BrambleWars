-- attack_handler.lua
-- This module is responsible for dispatching player attacks.

local UnitAttacks = require("data.unit_attacks")
local AttackBlueprints = require("data.attack_blueprints")
local CombatActions = require("modules.combat_actions")

local AttackHandler = {}

function AttackHandler.execute(square, attackName, world)
    local attackData = AttackBlueprints[attackName]

    if attackData and UnitAttacks[attackName] then
        -- Standard attack execution.
        local result = UnitAttacks[attackName](square, attackData.power, world)
        -- If the attack function returns a boolean, use it. Otherwise, assume it fired successfully.
        if type(result) == "boolean" then
            return result
        else
            return true
        end
    end
    return false -- Attack not found
end

return AttackHandler