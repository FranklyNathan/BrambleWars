-- healing_winds_system.lua
-- Manages the reactive "Healing Winds" passive.

local EventBus = require("modules.event_bus")
local EffectFactory = require("modules.effect_factory")
local CombatActions = require("modules.combat_actions")

local HealingWindsSystem = {}

-- Refactored to reduce code duplication. This helper now applies healing to any given list of units.
local function heal_team(team_list, world)
    if not team_list or #team_list == 0 then return end
    for _, unit in ipairs(team_list) do
        if unit.hp > 0 and unit.hp < unit.maxHp then
            if CombatActions.applyDirectHeal(unit, 5) then
                EffectFactory.createDamagePopup(world, unit, "5", false, {0.5, 1, 0.5, 1}) -- Green text for heal
            end
        end
    end
end

-- The main function that checks for the passive and triggers the healing.
local function apply_healing_winds(world)
    if #world.teamPassives.player.HealingWinds > 0 then
        heal_team(world.players, world)
    end
    if #world.teamPassives.enemy.HealingWinds > 0 then
        heal_team(world.enemies, world)
    end
end

EventBus:register("player_turn_ended", function(data)
    apply_healing_winds(data.world)
end)

EventBus:register("enemy_turn_ended", function(data)
    apply_healing_winds(data.world)
end)