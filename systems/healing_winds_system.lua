-- healing_winds_system.lua
-- Manages the reactive "Healing Winds" passive.

local EventBus = require("modules.event_bus")
local EffectFactory = require("modules.effect_factory")
local CombatActions = require("modules.combat_actions")

local HealingWindsSystem = {}

-- Helper function to apply team-wide healing from Florges's passive.
local function apply_healing_winds(world)
    -- Heal player team if the list of living providers for HealingWinds is not empty.
    if #world.teamPassives.player.HealingWinds > 0 then
        for _, p in ipairs(world.players) do
            if p.hp > 0 and p.hp < p.maxHp then
                if CombatActions.applyDirectHeal(p, 5) then
                    EffectFactory.createDamagePopup(p, "5", false, {0.5, 1, 0.5, 1}) -- Green text for heal
                end
            end
        end
    end

    -- Heal enemy team if the list of living providers for HealingWinds is not empty.
    if #world.teamPassives.enemy.HealingWinds > 0 then
        for _, e in ipairs(world.enemies) do
            if e.hp > 0 and e.hp < e.maxHp then
                if CombatActions.applyDirectHeal(e, 5) then
                    EffectFactory.createDamagePopup(e, "5", false, {0.5, 1, 0.5, 1}) -- Green text for heal
                end
            end
        end
    end
end

EventBus:register("player_turn_ended", function(data)
    apply_healing_winds(data.world)
end)

EventBus:register("enemy_turn_ended", function(data)
    apply_healing_winds(data.world)
end)