-- systems/battle_info_system.lua
-- Calculates and updates the data for the battle forecast UI.

local EventBus = require("modules.event_bus")
local CombatFormulas = require("modules.combat_formulas")
local AttackBlueprints = require("data.attack_blueprints")
local CharacterBlueprints = require("data.character_blueprints")
local EnemyBlueprints = require("data.enemy_blueprints")
local WeaponBlueprints = require("data.weapon_blueprints")
local AttackPatterns = require("modules.attack_patterns")
local WorldQueries = require("modules.world_queries")

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

        -- If the target is a tile, not a unit, don't show the forecast.
        if target.isTileTarget then
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
            local playerDmg = CombatFormulas.calculateFinalDamage(attacker, target, attackData, false, attackName, world)

            -- Check for Unbound passive on the attacker for forecast.
            if attacker.wisp == 0 then
                local unbound_providers = world.teamPassives[attacker.type].Unbound
                if unbound_providers then
                    local attackerHasUnbound = false
                    for _, provider in ipairs(unbound_providers) do
                        if provider == attacker then
                            attackerHasUnbound = true
                            break
                        end
                    end
                    if attackerHasUnbound then
                        playerDmg = playerDmg * 1.5
                    end
                end
            end

            -- Check for special, conditional damage multipliers to ensure the forecast is accurate.
            local damageMultiplier = 1.0 -- Default multiplier

            if attackName == "impale" then
                local dx = target.tileX - attacker.tileX
                local dy = target.tileY - attacker.tileY
                local behindTileX, behindTileY = target.tileX + dx, target.tileY + dy
                local secondaryUnit = WorldQueries.getUnitAt(behindTileX, behindTileY, target, world)
                local behindObstacle = WorldQueries.getObstacleAt(behindTileX, behindTileY, world)

                if (secondaryUnit and secondaryUnit.type ~= attacker.type) or (behindObstacle and not behindObstacle.isTrap) then
                    damageMultiplier = 1.5
                end
            end
            menu.playerDamage = tostring(math.floor(playerDmg * damageMultiplier))
            local attackOriginType = attackData.originType or attacker.originType
            if CombatFormulas.calculateTypeEffectiveness(attackOriginType, target.originType) > 1 then
                menu.playerDamage = menu.playerDamage .. "!"
            end
            local playerHit = math.max(0, math.min(1, CombatFormulas.calculateHitChance(attacker, target, attackData.Accuracy or 100)))
            local playerCrit = math.max(0, math.min(1, CombatFormulas.calculateCritChance(attacker, target, attackData.CritChance or 0)))
            menu.playerHitChance = math.floor(playerHit * 100)
            menu.playerCritChance = math.floor(playerCrit * 100)

            -- Enemy's counter-attack forecast
            local all_defender_moves = WorldQueries.getUnitMoveList(target)

            local counterAttackName = all_defender_moves[1]

            if not counterAttackName then
                menu.enemyDamage, menu.enemyHitChance, menu.enemyCritChance = "--", "--", "--"
            else
                local counterAttackData = AttackBlueprints[counterAttackName]
                local pattern = counterAttackData and AttackPatterns[counterAttackData.patternType]
                local inCounterRange = false

                if pattern and type(pattern) == "table" then
                    -- For counter-attack calculations, we need to know where the defender will be *after*
                    -- the initial attack resolves, as some attacks move the defender.
                    local attackerFutureTileX, attackerFutureTileY = attacker.tileX, attacker.tileY
                    local defenderFutureTileX, defenderFutureTileY = target.tileX, target.tileY

                    if attackName == "shunt" then
                        -- Calculate where the shunt will push the defender.
                        local push_dx = target.tileX - attacker.tileX
                        local push_dy = target.tileY - attacker.tileY
                        local behindTileX, behindTileY = target.tileX + push_dx, target.tileY + push_dy
                        
                        -- The push only happens if the destination is not occupied.
                        if not WorldQueries.isTileOccupied(behindTileX, behindTileY, nil, world) then
                            defenderFutureTileX, defenderFutureTileY = behindTileX, behindTileY
                        end
                    elseif attackName == "slipstep" then
                        -- The attacker and defender swap positions.
                        attackerFutureTileX, attackerFutureTileY = target.tileX, target.tileY
                        defenderFutureTileX, defenderFutureTileY = attacker.tileX, attacker.tileY
                    end

                    local dx = attackerFutureTileX - defenderFutureTileX
                    local dy = attackerFutureTileY - defenderFutureTileY
                    for _, p_coord in ipairs(pattern) do
                        if p_coord.dx == dx and p_coord.dy == dy then
                            inCounterRange = true
                            break
                        end
                    end
                end

                if inCounterRange then
                    local enemyDmg = CombatFormulas.calculateFinalDamage(target, attacker, counterAttackData, false, counterAttackName, world)
                    menu.enemyDamage = tostring(math.floor(enemyDmg))
                    local counterAttackOriginType = counterAttackData.originType or target.originType
                    if CombatFormulas.calculateTypeEffectiveness(counterAttackOriginType, attacker.originType) > 1 then
                        menu.enemyDamage = menu.enemyDamage .. "!"
                    end
                    local enemyHit = math.max(0, math.min(1, CombatFormulas.calculateHitChance(target, attacker, counterAttackData.Accuracy or 100)))
                    local enemyCrit = math.max(0, math.min(1, CombatFormulas.calculateCritChance(target, attacker, counterAttackData.CritChance or 0)))
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