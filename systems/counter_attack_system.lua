-- systems\counter_attack_system.lua
-- This system processes delayed counter-attacks to ensure they trigger after the initial attack animation.

local AttackPatterns = require("modules.attack_patterns")
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

            -- New: Re-validate range before executing the counter-attack.
            -- This handles cases where the defender was moved (e.g., by Careen) after the counter was queued.
            local basicAttackData = AttackBlueprints[counter.attackName]
            local pattern = basicAttackData and AttackPatterns[basicAttackData.patternType]
            local inRange = false
            if pattern and type(pattern) == "table" then
                local dx = attacker.tileX - defender.tileX
                local dy = attacker.tileY - defender.tileY
                for _, p_coord in ipairs(pattern) do
                    if p_coord.dx == dx and p_coord.dy == dy then
                        inRange = true
                        break
                    end
                end
            end
            if not inRange then
                -- The unit was pushed out of range. The counter-attack is cancelled.
                -- We must remove it from the pending list to prevent the game from locking.
                table.remove(world.pendingCounters, i)
                goto continue_counter_loop -- Skip to the next counter in the list.
            end

            -- Make the defender (counter-attacker) face the original attacker.
            local dx_face, dy_face = attacker.tileX - defender.tileX, attacker.tileY - defender.tileY
            if math.abs(dx_face) > math.abs(dy_face) then
                defender.lastDirection = (dx_face > 0) and "right" or "left"
            else
                defender.lastDirection = (dy_face > 0) and "down" or "up"
            end

            -- Add the lunge component for the visual effect.
            defender.components.lunge = { timer = 0.2, initialTimer = 0.2, direction = defender.lastDirection }

            -- The attack name is now passed in the counter object.
            if counter.attackName then
                -- Create a visual effect for the counter-attack. This will handle damage resolution.
                local targetType = (defender.type == "player") and "enemy" or "player"
                -- Mark this effect as a counter-attack so it doesn't trigger another counter.
                EffectFactory.addAttackEffect(world, {
                    attacker = defender,
                    attackName = counter.attackName,
                    x = attacker.x,
                    y = attacker.y,
                    width = attacker.size,
                    height = attacker.size,
                    color = {1, 0, 0, 1},
                    targetType = targetType,
                    specialProperties = {isCounterAttack = true}
                })
            end

            -- Remove the counter from the pending list.
            table.remove(world.pendingCounters, i)
            ::continue_counter_loop::
        end
    end
end

return CounterAttackSystem