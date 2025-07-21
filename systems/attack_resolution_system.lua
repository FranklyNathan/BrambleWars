-- attack_resolution_system.lua
-- This system is responsible for resolving the damage, healing, and status effects

-- of all active attack effects in the world.

local CombatActions = require("modules.combat_actions")
local AttackBlueprints = require("data.attack_blueprints")
local CombatFormulas = require("modules.combat_formulas")
local StatusEffectManager = require("modules.status_effect_manager")
local CharacterBlueprints = require("data.character_blueprints")
local EnemyBlueprints = require("data.enemy_blueprints")
local AttackPatterns = require("modules.attack_patterns")
local EffectFactory = require("modules.effect_factory")


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
                            local attackData = AttackBlueprints[effect.attackName]
                            if attackData then
                                -- Centralized logic: Check for hit chance first.
                                local hitChance = CombatFormulas.calculateHitChance(effect.attacker.witStat, target.witStat, attackData.Accuracy or 100)
                                if love.math.random() < hitChance then
                                    -- The attack hits.
                                    local critChance = CombatFormulas.calculateCritChance(effect.attacker.witStat, target.witStat, attackData.CritChance or 0)
                                    local isCrit = (love.math.random() < critChance) or effect.critOverride
                                    local damage = CombatFormulas.calculateFinalDamage(effect.attacker, target, attackData, isCrit)
                                    local isCounter = effect.specialProperties and effect.specialProperties.isCounterAttack
                                    CombatActions.applyDirectDamage(world, target, damage, isCrit, effect.attacker, { createCombatDisplay = not isCounter, attackName = effect.attackName })

                                    -- Handle status effects on successful hit.
                                    if effect.statusEffect then
                                        local statusCopy = {
                                            type = effect.statusEffect.type,
                                            duration = effect.statusEffect.duration,
                                            force = effect.statusEffect.force,
                                            attacker = effect.attacker,
                                        }
                                        statusCopy.direction = effect.attacker.lastDirection
                                        if statusCopy.type == "careening" and not effect.statusEffect.useAttackerDirection then
                                            statusCopy.direction = StatusEffectManager.calculateCareeningDirection(target, effect.x, effect.y, effect.width, effect.height)
                                        end
                                        StatusEffectManager.applyStatusEffect(target, statusCopy, world)
                                    end

                                    -- New: Check for counter-attacks right after a successful hit.
                                    local isCounter = effect.specialProperties and effect.specialProperties.isCounterAttack
                                    if not isCounter and target.hp and target.hp > 0 and not target.statusEffects.stunned and not target.statusEffects.airborne then
                                        local defenderBlueprint = (target.type == "player") and CharacterBlueprints[target.playerType] or EnemyBlueprints[target.enemyType]
                                        if defenderBlueprint and defenderBlueprint.attacks and defenderBlueprint.attacks[1] then
                                            local basicAttackName = defenderBlueprint.attacks[1]
                                            local basicAttackData = AttackBlueprints[basicAttackName]
                                            if basicAttackData and basicAttackData.patternType then
                                                local pattern = AttackPatterns[basicAttackData.patternType]
                                                if pattern and type(pattern) == "table" then
                                                    local dx = effect.attacker.tileX - target.tileX
                                                    local dy = effect.attacker.tileY - target.tileY
                                                    local inCounterRange = false
                                                    for _, p_coord in ipairs(pattern) do
                                                        if p_coord.dx == dx and p_coord.dy == dy then
                                                            inCounterRange = true
                                                            break
                                                        end
                                                    end

                                                    if inCounterRange then
                                                        table.insert(world.pendingCounters, {
                                                            defender = target,
                                                            attacker = effect.attacker,
                                                            delay = 0.25
                                                        })
                                                    end
                                                end
                                            end
                                        end
                                    end
                                else
                                    -- The attack misses.
                                    EffectFactory.createDamagePopup(target, "Miss!", false, {0.8, 0.8, 0.8, 1})
                                end
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