-- attack_resolution_system.lua
-- This system is responsible for resolving the damage, healing, and status effects

-- of all active attack effects in the world.

local CombatActions = require("modules.combat_actions")
local CombatFormulas = require("modules.combat_formulas")
local StatusEffectManager = require("modules.status_effect_manager")

local AttackResolutionSystem = {}

function AttackResolutionSystem.update(dt, world)
    for _, effect in ipairs(world.attackEffects) do
        -- Process the effect on the frame it becomes active
        if effect.initialDelay <= 0 and not effect.effectApplied then
            local targets = {}
            if effect.targetType == "enemy" then
                targets = world.enemies
            elseif effect.targetType == "player" then
                targets = world.players
            elseif effect.targetType == "all" then
                targets = world.all_entities
            end

            for _, target in ipairs(targets) do
                -- Only process entities that can be targeted by combat actions (i.e., have health)
                if target.hp then
                    -- AABB collision check between the effect rectangle and the target's square.
                    local collision = target.x < effect.x + effect.width and
                                      target.x + target.size > effect.x and
                                      target.y < effect.y + effect.height and
                                      target.y + target.size > effect.y

                    if collision then
                        if effect.isHeal then
                            CombatActions.applyDirectHeal(target, effect.power)
                            -- Handle special properties on successful heal.
                            if effect.specialProperties and effect.specialProperties.cleansesPoison and target.statusEffects then
                                target.statusEffects.poison = nil
                            end
                        else -- It's a damage effect
                            local damage, isCrit = CombatFormulas.calculateFinalDamage(effect.attacker, target, effect.power, effect.critChanceOverride)
                            CombatActions.applyDirectDamage(target, damage, isCrit, effect.attacker)

                            -- Handle status effects on successful hit.
                            if effect.statusEffect then                            
                                local statusCopy = { -- Create a copy to avoid modifying the original effect data
                                    type = effect.statusEffect.type,
                                    duration = effect.statusEffect.duration,
                                    force = effect.statusEffect.force,
                                    attacker = effect.attacker,
                                    -- Direction is calculated below
                                }
                                 -- Default direction is the attacker's facing. This is correct for most status effects and directional pushes.
                                statusCopy.direction = effect.attacker.lastDirection

                                -- For "explosive" careening effects, calculate the direction based on the effect's center.
                                if statusCopy.type == "careening" and not effect.statusEffect.useAttackerDirection then
                                    statusCopy.direction = StatusEffectManager.calculateCareeningDirection(target, effect.x, effect.y, effect.width, effect.height)
                                end
                                StatusEffectManager.applyStatusEffect(target, statusCopy, world) -- Call StatusEffectManager directly
                            end
                        end
                    end
                end
            end

            effect.effectApplied = true -- Mark as processed
        end
    end
end

return AttackResolutionSystem