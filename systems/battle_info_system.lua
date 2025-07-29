-- systems/battle_info_system.lua
-- Calculates and updates the data for the battle forecast UI.

local EventBus = require("modules.event_bus")
local CombatFormulas = require("modules.combat_formulas")
local AttackBlueprints = require("data.attack_blueprints")
local CharacterBlueprints = require("data.character_blueprints")
local EnemyBlueprints = require("data.enemy_blueprints")
local AttackPatterns = require("modules.attack_patterns")

local BattleInfoSystem = {}

-- This is the core logic. It's called by event handlers to update the forecast.
function BattleInfoSystem.refresh_forecast(world)
    local menu = world.ui.menus.battleInfo
    if not menu then return end

    -- Only show a forecast if the player is actively cycling targets.
    if world.ui.playerTurnState == "cycle_targeting" and world.ui.targeting.cycle.active then
        local attacker = world.ui.menus.action.unit
        local target = world.ui.targeting.cycle.targets[world.ui.targeting.cycle.selectedIndex]
        local attackName = world.ui.targeting.selectedAttackName
        local attackData = attackName and AttackBlueprints[attackName]

        if not (attacker and target and attackData) then
            menu.active = false
            return
        end

        -- If the target has no HP (i.e., it's an obstacle), don't show the forecast.
        if not target.hp then
            menu.active = false
            return
        end

        menu.active = true
        menu.attacker = attacker
        menu.target = target
        menu.targetName = target.displayName or target.enemyType

        -- Current Health
        menu.playerHP = math.floor(attacker.hp)
        menu.enemyHP = math.floor(target.hp)

        if attackData.useType == "support" then
            -- Healing forecast
            menu.playerActionLabel = "Heal:"
            local healAmount = CombatFormulas.calculateHealingAmount(attacker, attackData)
            menu.playerDamage = tostring(healAmount)
            menu.playerHitChance = "--"
            menu.playerCritChance = "--"
            menu.enemyDamage, menu.enemyHitChance, menu.enemyCritChance = "--", "--", "--"
        elseif attackData.useType == "utility" and (attackData.power or 0) == 0 then
            -- Non-damaging utility forecast
            menu.playerActionLabel = "Effect:"
            menu.playerDamage = "--"
            menu.playerHitChance = "--"
            menu.playerCritChance = "--"
            menu.enemyDamage, menu.enemyHitChance, menu.enemyCritChance = "--", "--", "--"
        else
            -- Damage forecast for physical, magical, and damaging utility
            menu.playerActionLabel = "Damage:"
            local playerDmg = CombatFormulas.calculateFinalDamage(attacker, target, attackData, false)
            menu.playerDamage = tostring(playerDmg)
            if CombatFormulas.calculateTypeEffectiveness(attackData.originType, target.originType) > 1 then
                menu.playerDamage = menu.playerDamage .. "!"
            end
            local playerHit = math.max(0, math.min(1, CombatFormulas.calculateHitChance(attacker.witStat, target.witStat, attackData.Accuracy or 100)))
            local playerCrit = math.max(0, math.min(1, CombatFormulas.calculateCritChance(attacker.witStat, target.witStat, attackData.CritChance or 0)))
            menu.playerHitChance = math.floor(playerHit * 100)
            menu.playerCritChance = math.floor(playerCrit * 100)

            -- Enemy's counter-attack forecast
            local defenderBlueprint = (target.type == "player") and CharacterBlueprints[target.playerType] or EnemyBlueprints[target.enemyType] -- target is the defender
            local counterAttackName = defenderBlueprint and defenderBlueprint.attacks and defenderBlueprint.attacks[1]

            if not counterAttackName then
                menu.enemyDamage, menu.enemyHitChance, menu.enemyCritChance = "--", "--", "--"
            else
                local counterAttackData = AttackBlueprints[counterAttackName]
                local pattern = counterAttackData and AttackPatterns[counterAttackData.patternType]
                local inCounterRange = false

                if pattern and type(pattern) == "table" then
                    local dx = attacker.tileX - target.tileX
                    local dy = attacker.tileY - target.tileY
                    for _, p_coord in ipairs(pattern) do
                        if p_coord.dx == dx and p_coord.dy == dy then
                            inCounterRange = true
                            break
                        end
                    end
                end

                if inCounterRange then
                    local enemyDmg = CombatFormulas.calculateFinalDamage(target, attacker, counterAttackData, false)
                    menu.enemyDamage = tostring(enemyDmg)
                    if CombatFormulas.calculateTypeEffectiveness(counterAttackData.originType, attacker.originType) > 1 then
                        menu.enemyDamage = menu.enemyDamage .. "!"
                    end
                    local enemyHit = math.max(0, math.min(1, CombatFormulas.calculateHitChance(target.witStat, attacker.witStat, counterAttackData.Accuracy or 100)))
                    local enemyCrit = math.max(0, math.min(1, CombatFormulas.calculateCritChance(target.witStat, attacker.witStat, counterAttackData.CritChance or 0)))
                    menu.enemyHitChance = math.floor(enemyHit * 100)
                    menu.enemyCritChance = math.floor(enemyCrit * 100)
                else
                    menu.enemyDamage, menu.enemyHitChance, menu.enemyCritChance = "--", "--", "--"
                end
            end
        end
    else
        menu.active = false
    end
end

-- Event handler for when the player's turn state changes.
-- This is crucial for showing/hiding the forecast when entering/leaving the targeting state.
local function on_player_state_changed(data)
    BattleInfoSystem.refresh_forecast(data.world)
end

-- Event handler for when the player cycles to a new target.
local function on_cycle_target_changed(data)
    BattleInfoSystem.refresh_forecast(data.world)
end

EventBus:register("player_state_changed", on_player_state_changed)
EventBus:register("cycle_target_changed", on_cycle_target_changed)

return BattleInfoSystem