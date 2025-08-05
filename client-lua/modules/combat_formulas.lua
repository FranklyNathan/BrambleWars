-- combat_formulas.lua
-- Contains pure functions for calculating combat-related values.

local WorldQueries = require("modules.world_queries")
local PassiveBlueprints = require("data/passive_blueprints")
local CombatFormulas = {}

local typeEffectivenessTable = {
    marshborn = {
        cavernborn = 1.25,
        forestborn = 0.75,
        marshborn = 1,
    },
    cavernborn = {
        forestborn = 1.25,
        marshborn = 0.75,
        cavernborn = 1,
    },
    forestborn = {
        marshborn = 1.25,
        cavernborn = 0.75,
        forestborn = 1,
    },
}

-- Helper to calculate type effectiveness
function CombatFormulas.calculateTypeEffectiveness(attackType, defenderType)
    if not attackType or not defenderType then return 1 end
    return typeEffectivenessTable[attackType][defenderType] or 1
end

-- Helper to calculate the chance of a critical hit
function CombatFormulas.calculateCritChance(attacker, defender, moveCritChance)
    -- The final crit chance is the move's base chance, modified by the difference in Wit.
    -- A higher attacker Wit increases the chance, a higher defender Wit decreases it.
    local attackerWit = attacker.finalWitStat or 0
    local defenderWit = defender.finalWitStat or 0
    return (moveCritChance + (attackerWit - defenderWit)) / 100
end

-- Helper function to calculate hit chance
function CombatFormulas.calculateHitChance(attacker, defender, moveAccuracy)
    local attackerWit = attacker.finalWitStat or 0
    local defenderWit = defender.finalWitStat or 0
    return ((moveAccuracy / 100) + (attackerWit - defenderWit) / 100)
end

-- Helper to calculate base damage for physical and magical attacks
function CombatFormulas.calculateBaseDamage(attacker, defender, attackData, attackName, world)
    -- Check for Invincible status on the defender first. It blocks ALL incoming damage.
    if defender.statusEffects and defender.statusEffects.invincible then
        return 0 -- Immune to all damage.
    end

    -- Check for true damage, which bypasses all other calculations except invincibility.
    if attackData.deals_true_damage then
        return attackData.power or 0
    end

    -- New: Check for Oblivious passive
    local isObliviousCombat = false
    if world then
        isObliviousCombat = WorldQueries.hasPassive(attacker, "Oblivious", world) or WorldQueries.hasPassive(defender, "Oblivious", world)
    end

    local attackerWeaponBonuses = { attackStat = 0, magicStat = 0 }
    local defenderWeaponBonuses = { defenseStat = 0, resistanceStat = 0 }

    if isObliviousCombat then
        -- This local helper function calculates the total stat bonuses from a unit's equipped weapons.
        local function getWeaponStatBonuses(unit)
            local bonuses = { attackStat = 0, magicStat = 0, defenseStat = 0, resistanceStat = 0 }
            if unit.equippedWeapons then
                -- Lazily require WeaponBlueprints here to avoid potential top-level circular dependencies.
                local WeaponBlueprints = require("data.weapon_blueprints")
                for _, weaponName in ipairs(unit.equippedWeapons) do
                    local weapon = WeaponBlueprints[weaponName]
                    if weapon and weapon.stats then
                        for statName, bonus in pairs(weapon.stats) do
                            if bonuses[statName] ~= nil then
                                bonuses[statName] = bonuses[statName] + bonus
                            end
                        end
                    end
                end
            end
            return bonuses
        end

        attackerWeaponBonuses = getWeaponStatBonuses(attacker)
        defenderWeaponBonuses = getWeaponStatBonuses(defender)
    end

    print("--- Damage Calculation: " .. (attackName or "Unknown") .. " ---")
    print("Attacker: " .. (attacker.displayName or attacker.enemyType) .. ", Defender: " .. (defender.displayName or defender.enemyType or "Obstacle"))

    -- Determine the origin type for the attack. Prioritize the attack's own type, fall back to the attacker's type.
    local attackOriginType = attackData.originType or attacker.originType
    local statUsed = (attackData.useType == "physical") and ((attacker.finalAttackStat or 0) - attackerWeaponBonuses.attackStat) or ((attacker.finalMagicStat or 0) - attackerWeaponBonuses.magicStat)
    local power = attackData.power or 0
    local effectiveness = CombatFormulas.calculateTypeEffectiveness(attackOriginType, defender.originType)

    print(string.format("  Move Power: %d, Attacker Stat: %d", power, statUsed))
    print(string.format("  Type Effectiveness: x%.2f", effectiveness))

    -- Apply the type effectiveness to the attack power + attacker's stat.
    local adjustedPower = (power + (statUsed or 0)) * effectiveness
    print(string.format("  Adjusted Power ( (Power + Stat) * Effectiveness ): %.2f", adjustedPower))

    local rawDamage = 0
    local defenseStatUsed = 0
    local defenseStatName = ""
    -- Calculate damage dealt by a physical attack.
    if attackData.useType == "physical" then
        defenseStatUsed = (defender.finalDefenseStat or 0) - defenderWeaponBonuses.defenseStat
        defenseStatName = "Defense"
        rawDamage = math.max(0, adjustedPower - defenseStatUsed) -- Subtract defender's defense.
    elseif attackData.useType == "magical" then
        defenseStatUsed = (defender.finalResistanceStat or 0) - defenderWeaponBonuses.resistanceStat
        defenseStatName = "Resistance"
        rawDamage = math.max(0, adjustedPower - defenseStatUsed) -- Subtract defender's resistance.
    elseif attackData.useType == "utility" and power > 0 then
        -- Utility moves with power use physical stats by default.
        defenseStatUsed = (defender.finalDefenseStat or 0) - defenderWeaponBonuses.defenseStat
        defenseStatName = "Defense"
        rawDamage = math.max(0, adjustedPower - defenseStatUsed)
    end

    if defenseStatName ~= "" then
        print(string.format("  Defender %s: %d", defenseStatName, defenseStatUsed))
        print(string.format("  Raw Damage ( Adjusted Power - Defender Stat ): %.2f", rawDamage))
    end

    print("  Final Base Damage (un-floored): " .. rawDamage)
    print("--------------------------")
    -- Return the raw, un-floored damage. The final flooring happens at the call site (e.g., in applyDirectDamage or the UI).
    return rawDamage
end

-- Helper to calculate final damage including base damage and critical hit multiplier
function CombatFormulas.calculateFinalDamage(attacker, defender, attackData, isCrit, attackName, world)
    local damage = CombatFormulas.calculateBaseDamage(attacker, defender, attackData, attackName, world)
    if isCrit then
        damage = damage * 2
    end

    -- Check for Desperate passive on the attacker.
    if world and world.teamPassives[attacker.type] and world.teamPassives[attacker.type].Desperate then
        local desperate_providers = world.teamPassives[attacker.type].Desperate
        local attackerHasDesperate = false
        for _, provider in ipairs(desperate_providers) do
            if provider == attacker then
                attackerHasDesperate = true
                break
            end
        end

        if attackerHasDesperate then
            local hp_ratio = attacker.hp / attacker.finalMaxHp
            local multiplier = 1 + (1 - hp_ratio)
            damage = damage * multiplier
        end
    end

    -- New: Check for Spiritburn weapon property
    if world and attacker.equippedWeapons and attacker.wisp > 0 then
        local WeaponBlueprints = require("data.weapon_blueprints")
        for _, weaponName in ipairs(attacker.equippedWeapons) do
            local weapon = WeaponBlueprints[weaponName]
            if weapon and weapon.spiritburn_bonus then
                -- The wisp deduction happens in attack_resolution_system.
                -- Here, we just apply the damage bonus.
                damage = damage * weapon.spiritburn_bonus
                break -- Apply bonus only once, even if both weapons have it.
            end
        end
    end

    -- New: Check for Harmony weapon property
    if world and attacker.equippedWeapons then
        local WeaponBlueprints = require("data.weapon_blueprints")
        local totalHarmonyBonus = 0
        for _, weaponName in ipairs(attacker.equippedWeapons) do
            local weapon = WeaponBlueprints[weaponName]
            if weapon and weapon.harmony_bonus_per_ally then
                totalHarmonyBonus = totalHarmonyBonus + weapon.harmony_bonus_per_ally
            end
        end

        if totalHarmonyBonus > 0 then
            local WorldQueries = require("modules.world_queries")
            local adjacentAllies = WorldQueries.countAdjacentAllies(attacker, world)
            if adjacentAllies > 0 then
                local harmonyMultiplier = 1 + (adjacentAllies * totalHarmonyBonus)
                damage = damage * harmonyMultiplier
            end
        end
    end

    -- New: Check for Last Stand passive
    if world and world.teamPassives[attacker.type] and world.teamPassives[attacker.type].LastStand then
        local last_stand_providers = world.teamPassives[attacker.type].LastStand
        local attackerHasLastStand = false
        for _, provider in ipairs(last_stand_providers) do
            if provider == attacker then
                attackerHasLastStand = true
                break
            end
        end

        if attackerHasLastStand then
            local onWinTile = false
            if world.winTiles then
                for _, winTile in ipairs(world.winTiles) do
                    if attacker.tileX == winTile.x and attacker.tileY == winTile.y then
                        onWinTile = true; break;
                    end
                end
            end
            if onWinTile then damage = damage * 2 end
        end
    end

    -- New: Check for Pristine passive on the DEFENDER.
    -- This is applied after all attacker bonuses.
    if world and WorldQueries.hasPassive(defender, "Pristine", world) then
        if defender.hp >= defender.finalMaxHp then
            damage = damage * 0.5
        end
    end

    return damage
end

-- Calculates the amount of HP restored by a healing move.
-- Formula: (User's Magic Stat) + (Healing Move Power)
function CombatFormulas.calculateHealingAmount(attacker, attackData)
    if not attacker or not attackData then return 0 end
    local magicStat = attacker.finalMagicStat or 0
    local movePower = attackData.power or 0
    local healing = magicStat + movePower
    return math.floor(healing)
end

-- Calculates the amount of EXP a unit gains from combat.
-- Formula: 20 + (Enemy Level - Player Level) * (expReward / modifier)
-- The modifier is 100 for a hit, and 10 for a kill.
function CombatFormulas.calculateExpGain(attacker, defender, isKill, world)
    -- Only players gain EXP from fighting enemies.
    if attacker.type ~= "player" or defender.type ~= "enemy" then
        return 0
    end

    -- Failsafe if defender has no expReward defined.
    if not defender.expReward then return 0 end

    print("--- EXP Calculation ---")
    -- Make the print statement safer by providing fallbacks, preventing crashes for converted units.
    print("Attacker: " .. (attacker.displayName or attacker.enemyType or "Unknown") .. ", Defender: " .. (defender.displayName or defender.enemyType or "Unknown"))

    local baseExp = 30
    local levelDifference = defender.level - attacker.level
    local rewardDivisor = isKill and 10 or 100

    local expGained = (baseExp + levelDifference) * (defender.expReward / rewardDivisor)
    print(string.format("  Base EXP: %d, Level Diff: %d, Kill: %s, Reward Divisor: %d", baseExp, levelDifference, tostring(isKill), rewardDivisor))
    print(string.format("  Initial EXP Gained (un-multiplied): %.2f", expGained))

    -- New: Check for Fast Learner passive
    if world and WorldQueries.hasPassive(attacker, "FastLearner", world) then
        local passiveData = PassiveBlueprints.FastLearner
        if passiveData and passiveData.exp_multiplier then
            expGained = expGained * passiveData.exp_multiplier
            print(string.format("  Fast Learner passive found! Applying x%.2f multiplier.", passiveData.exp_multiplier))
        end
    end

    -- EXP gain should not be negative. If the player is a much higher level,
    -- they get a minimum amount of EXP (e.g., 1).
    local finalExp = math.max(1, math.floor(expGained))
    print(string.format("  Final EXP Gained (floored): %d", finalExp))
    print("-----------------------")
    return finalExp
end

return CombatFormulas