-- attack_resolution_system.lua
-- This system is responsible for resolving the damage, healing, and status effects

-- of all active attack effects in the world.

local CombatActions = require("modules.combat_actions")
local AttackBlueprints = require("data.attack_blueprints")
local StatSystem = require("systems.stat_system")
local CombatFormulas = require("modules.combat_formulas")
local StatusEffectManager = require("modules.status_effect_manager")
local CharacterBlueprints = require("data.character_blueprints")
local EnemyBlueprints = require("data.enemy_blueprints")
local AttackPatterns = require("modules.attack_patterns")
local WorldQueries = require("modules.world_queries")
local EffectFactory = require("modules.effect_factory")
local WeaponBlueprints = require("data.weapon_blueprints")
local Grid = require("modules.grid")
local Assets = require("modules.assets")


local AttackResolutionSystem = {}

function AttackResolutionSystem.update(dt, world)
    -- Create a copy of the current effects to process for this frame.
    -- This prevents newly created effects (like from Thunderguard) from being processed in the same frame,
    -- which could cause state-management bugs where the game thinks an action is over prematurely.
    local effectsToProcess = {}
    for _, effect in ipairs(world.attackEffects) do
        -- Only process effects that haven't been applied yet.
        if not effect.effectApplied then
            table.insert(effectsToProcess, effect)
        end
    end

    local processed_spiritburn_instances = {} -- Track for this frame to prevent multiple wisp deductions.

    for _, effect in ipairs(effectsToProcess) do
        -- Process the effect on the frame it becomes active
        if effect.initialDelay <= 0 and not effect.effectApplied then
            local attackData = AttackBlueprints[effect.attackName]

            -- Check if the attack applies a status effect to the tile itself.
            if attackData and attackData.appliesTileStatus then
                local tileX, tileY = Grid.toTile(effect.x, effect.y)
                local statusInfo = attackData.appliesTileStatus
                local posKey = tileX .. "," .. tileY

                -- The logic for where a status can be applied is now handled by the status application function itself.
                if statusInfo.type == "aflame" then
                    StatusEffectManager.igniteTileAndSpread(tileX, tileY, world, statusInfo.duration)
                elseif statusInfo.type == "frozen" and WorldQueries.isTileWater_Base(tileX, tileY, world) then
                    -- 'frozen' can only be applied to water tiles.
                    world.tileStatuses[posKey] = { type = statusInfo.type, duration = statusInfo.duration }
                end
            end

            local targets = {}
            -- Build a list of potential targets for this effect.
            if effect.targetType == "enemy" then
                -- Player is attacking. Default targets are enemies and obstacles.
                for _, unit in ipairs(world.enemies) do table.insert(targets, unit) end
                -- Neutrals can also be targeted by player attacks.
                for _, unit in ipairs(world.neutrals) do table.insert(targets, unit) end

                for _, obstacle in ipairs(world.obstacles) do
                    if obstacle.hp and obstacle.hp > 0 then
                        table.insert(targets, obstacle)
                    end
                end
                -- If the attacker is treacherous, they can also target their allies.
                if WorldQueries.hasTreacherous(effect.attacker, world) then
                    for _, unit in ipairs(world.players) do table.insert(targets, unit) end
                end
            elseif effect.targetType == "player" then
                -- Enemy is attacking. Default targets are players and obstacles.
                for _, unit in ipairs(world.players) do table.insert(targets, unit) end
                for _, obstacle in ipairs(world.obstacles) do
                    if obstacle.hp and obstacle.hp > 0 then
                        table.insert(targets, obstacle)
                    end
                end
                -- If the attacker is treacherous, they can also target their allies.
                if WorldQueries.hasTreacherous(effect.attacker, world) then
                    for _, unit in ipairs(world.enemies) do table.insert(targets, unit) end
                end
            elseif effect.targetType == "all" then
                -- For effects targeting everyone, use the master list.
                for _, unit in ipairs(world.all_entities) do table.insert(targets, unit) end
            end

            for _, target in ipairs(targets) do
                -- Only process entities that can be targeted by combat actions (i.e., have health)
                if target.hp then
                    -- Use target.width/height for obstacles, fallback to target.size for units.
                    local targetWidth = target.width or target.size
                    local targetHeight = target.height or target.size
                    -- AABB collision check between the effect rectangle and the target's square.
                    local collision = target.x < effect.x + effect.width and target.x + targetWidth > effect.x and
                                      target.y < effect.y + effect.height and target.y + targetHeight > effect.y

                    if collision then
                        -- New: Special check for Combustive. A unit cannot damage itself with its own explosion.
                        -- This prevents Necromantia-revived units from instantly dying to their own on-death effect.
                        if effect.attackName == "combustive_explosion" and effect.attacker == target then
                            goto continue_target_loop -- Skip to the next target in the list.
                        end

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
                                local hitChance = CombatFormulas.calculateHitChance(effect.attacker, target, attackData.Accuracy or 100)
                                if love.math.random() < hitChance then
                                    -- The attack hits.
                                    if Assets.sounds.attack_hit then
                                        Assets.sounds.attack_hit:stop()
                                        Assets.sounds.attack_hit:play()
                                    end

                                    -- Make the target face the attacker, unless the attack stuns.
                                    local willBeStunned = effect.statusEffect and effect.statusEffect.type == "stunned"
                                    if not willBeStunned then
                                        -- The Grid.getDirection function calculates the direction from the first point to the second.
                                        target.lastDirection = Grid.getDirection(target.tileX, target.tileY, effect.attacker.tileX, effect.attacker.tileY)
                                    end

                                    local critChance = CombatFormulas.calculateCritChance(effect.attacker, target, attackData.CritChance or 0)
                                    local isCrit = (love.math.random() < critChance) or effect.critOverride
                                    local damage = CombatFormulas.calculateFinalDamage(effect.attacker, target, attackData, isCrit, effect.attackName, world)

                                    -- New: Handle Spiritburn weapon property (Wisp deduction)
                                    -- This happens *after* damage is calculated, so the formula sees the wisp.
                                    local attacker = effect.attacker
                                    if attacker.equippedWeapons and attacker.wisp > 0 then
                                        for _, weaponName in ipairs(attacker.equippedWeapons) do
                                            local weapon = WeaponBlueprints[weaponName]
                                            if weapon and weapon.spiritburn_bonus then
                                                local instanceId = effect.specialProperties.attackInstanceId
                                                if not processed_spiritburn_instances[instanceId] then
                                                    attacker.wisp = attacker.wisp - 1
                                                    EffectFactory.createDamagePopup(world, attacker, "-1 Wisp", false, {0.7, 0.2, 0.9, 1}) -- Purple text
                                                    processed_spiritburn_instances[instanceId] = true
                                                end
                                                break -- Only deduct wisp once per attack, even if both weapons have Spiritburn.
                                            end
                                        end
                                    end

                                    -- Check for Unbound passive on the attacker.
                                    if effect.attacker.wisp == 0 then
                                        local unbound_providers = world.teamPassives[effect.attacker.type].Unbound
                                        if unbound_providers then
                                            local attackerHasUnbound = false
                                            for _, provider in ipairs(unbound_providers) do
                                                if provider == effect.attacker then
                                                    attackerHasUnbound = true
                                                    break
                                                end
                                            end
                                            if attackerHasUnbound then
                                                damage = damage * 1.5
                                            end
                                        end
                                    end

                                    -- Apply damage multipliers from special properties (e.g., Impale).
                                    if effect.specialProperties and effect.specialProperties.damageMultiplier then
                                        damage = damage * effect.specialProperties.damageMultiplier
                                    end

                                    -- Handle Lifesteal property
                                    local lifestealPercent = WorldQueries.getUnitLifestealPercent(effect.attacker, world)
                                    if lifestealPercent > 0 then
                                        local healAmount = math.floor(damage * lifestealPercent)
                                        if healAmount > 0 then
                                            CombatActions.applyDirectHeal(effect.attacker, healAmount)
                                            EffectFactory.createDamagePopup(world, effect.attacker, "+" .. healAmount, false, {0.5, 1, 0.5, 1}) -- Green text
                                        end
                                    end

                                    -- Check for Treacherous passive on the attacker.
                                    if WorldQueries.hasTreacherous(effect.attacker, world) then
                                        -- If the attacker has the passive and the target is an ALLY.
                                        if target.type == effect.attacker.type then
                                            -- Apply permanent stat boosts
                                            effect.attacker.attackStat = effect.attacker.attackStat + 1
                                            effect.attacker.witStat = effect.attacker.witStat + 1
                                            StatSystem.recalculate_for_unit(effect.attacker)
                                            EffectFactory.createDamagePopup(world, effect.attacker, "+1 Atk/Wit", false, {1, 0.5, 0.2, 1}) -- Orange text
                                            -- Stun the ally
                                            StatusEffectManager.applyStatusEffect(target, {type = "stunned", duration = 1}, world)
                                        end
                                    end

                                    -- Check for Soulsnatcher passive on the attacker.
                                    local soulsnatcher_providers = world.teamPassives[effect.attacker.type].Soulsnatcher
                                    if soulsnatcher_providers and #soulsnatcher_providers > 0 then
                                        local attackerHasSoulsnatcher = false
                                        for _, provider in ipairs(soulsnatcher_providers) do
                                            if provider == effect.attacker then
                                                attackerHasSoulsnatcher = true
                                                break
                                            end
                                        end

                                        -- If the attacker has the passive and the target is an enemy with Wisp.
                                        if attackerHasSoulsnatcher and target.type ~= effect.attacker.type and target.wisp and target.wisp > 0 then
                                            target.wisp = target.wisp - 1
                                            effect.attacker.wisp = math.min(effect.attacker.finalMaxWisp, effect.attacker.wisp + 1)
                                            EffectFactory.createDamagePopup(world, target, "-1 Wisp", false, {0.7, 0.2, 0.9, 1}) -- Purple text
                                        end
                                    end

                                    -- Grant experience for the hit or kill.
                                    if effect.attacker.type == "player" and target.type == "enemy" then
                                        local isKill = (target.hp - damage <= 0)
                                        local expGained = CombatFormulas.calculateExpGain(effect.attacker, target, isKill)

                                        -- If the kill was from a reaction, flag the attacker so their turn isn't consumed by a level-up/promotion.
                                        if isKill and effect.specialProperties and effect.specialProperties.isAetherfallAttack then
                                            effect.attacker.components.level_up_from_reaction = true
                                        end

                                        CombatActions.grantExp(effect.attacker, expGained, world)
                                    end

                                    local isCounter = effect.specialProperties and effect.specialProperties.isCounterAttack
                                    CombatActions.applyDirectDamage(world, target, damage, isCrit, effect.attacker, { createPopup = not isCounter })

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
                                    local isAetherfall = effect.specialProperties and effect.specialProperties.isAetherfallAttack
                                    -- A unit cannot counter-attack if it is stunned, already airborne, or if the incoming attack is the one that *causes* it to become airborne.
                                    if not isCounter and not isAetherfall and target.hp and target.hp > 0 and not target.statusEffects.stunned and not target.statusEffects.airborne and not (effect.statusEffect and effect.statusEffect.type == "airborne") then
                                        local defender_moves = WorldQueries.getUnitMoveList(target)
                                        if #defender_moves > 0 then
                                            local basicAttackName = defender_moves[1] -- The first move is always the basic attack.
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
                                                            attackName = basicAttackName,
                                                            delay = 0.25
                                                        })
                                                    end
                                                end
                                            end
                                        end
                                    end
                                else
                                    -- The attack misses.
                                    if Assets.sounds.attack_miss then
                                        Assets.sounds.attack_miss:stop()
                                        Assets.sounds.attack_miss:play()
                                    end
                                    EffectFactory.createDamagePopup(world, target, "Miss!", false, {0.8, 0.8, 0.8, 1})
                                end
                            end
                        end
                    end
                end
            end
            ::continue_target_loop::

            effect.effectApplied = true -- Mark as processed
        end
    end
end

return AttackResolutionSystem