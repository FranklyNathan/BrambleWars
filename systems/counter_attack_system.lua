-- systems\counter_attack_system.lua
-- This system handles counter-attacks when a unit is attacked by an enemy in range.

local EventBus = require("modules.event_bus")
local WorldQueries = require("modules.world_queries")
local AttackHandler = require("modules.attack_handler")
local AttackBlueprints = require("data.attack_blueprints")
local RangeLogic = require("modules.range_logic")

local CounterAttackSystem = {}

local function trigger_counter_attack(counter_attacker, attacker, world)
    -- Make the counter attacker face the attacker.
    local dx, dy = attacker.tileX - counter_attacker.tileX, attacker.tileY - counter_attacker.tileY
    if math.abs(dx) > math.abs(dy) then
        counter_attacker.lastDirection = (dx > 0) and "right" or "left"
    else
        counter_attacker.lastDirection = (dy > 0) and "down" or "up"
    end

    -- Execute the basic attack.
    local attackName = counter_attacker.playerType .. "_basic"
    AttackHandler.execute(counter_attacker, attackName, world)
end

EventBus:register("unit_attacked", function(data)
    local target = data.target
    local attacker = data.attacker
    local world = data.world

    -- Validate data
    if not target or not attacker or target.hp <= 0 then return end

    -- If the target (being attacked) is in range of their basic attack, counter attack.
    local attackName = target.playerType .. "_basic"
    local attackData = AttackBlueprints[attackName]
    if attackData and RangeLogic.isInRange(target, attacker, attackData) then
        trigger_counter_attack(target, attacker, world)
    end
end)

return CounterAttackSystem