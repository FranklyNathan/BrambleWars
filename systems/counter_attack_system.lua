-- systems\counter_attack_system.lua
-- This system processes delayed counter-attacks to ensure they trigger after the initial attack animation.

local CharacterBlueprints = require("data.character_blueprints")
local EnemyBlueprints = require("data.enemy_blueprints")
local AttackBlueprints = require("data.attack_blueprints")
local EffectFactory = require("modules.effect_factory")

local CounterAttackSystem = {}

function CounterAttackSystem.update(dt, world)
    for i = #world.pendingCounters, 1, -1 do
        local counter = world.pendingCounters[i]
        counter.delay = counter.delay - dt

        -- Only execute the counter if the delay has passed, the defender is still alive,
        -- and the defender is not still animating taking damage.
        if counter.delay <= 0 and counter.defender.hp > 0 and not (counter.defender.components and counter.defender.components.pending_damage) then
            local defender = counter.defender
            local attacker = counter.attacker

            -- Make the defender (counter-attacker) face the original attacker.
            local dx_face, dy_face = attacker.tileX - defender.tileX, attacker.tileY - defender.tileY
            if math.abs(dx_face) > math.abs(dy_face) then
                defender.lastDirection = (dx_face > 0) and "right" or "left"
            else
                defender.lastDirection = (dy_face > 0) and "down" or "up"
            end

            -- Add the lunge component for the visual effect.
            defender.components.lunge = { timer = 0.2, initialTimer = 0.2, direction = defender.lastDirection }

            -- Get the defender's basic attack.
            local defenderBlueprint = (defender.type == "player") and CharacterBlueprints[defender.playerType] or EnemyBlueprints[defender.enemyType]
            local basicAttackName = defenderBlueprint and defenderBlueprint.attacks and defenderBlueprint.attacks[1]

            if basicAttackName then
                -- Create a visual effect for the counter-attack. This will handle damage resolution.
                local targetType = (defender.type == "player") and "enemy" or "player"
                -- Mark this effect as a counter-attack so it doesn't trigger another counter.
                EffectFactory.addAttackEffect(defender, basicAttackName, attacker.x, attacker.y, attacker.size, attacker.size, {1, 0, 0, 1}, 0, false, targetType, nil, nil, {isCounterAttack = true})
            end

            -- Remove the counter from the pending list.
            table.remove(world.pendingCounters, i)
        end
    end
end

return CounterAttackSystem