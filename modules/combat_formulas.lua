-- combat_formulas.lua
-- Contains pure functions for calculating combat-related values.

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
function CombatFormulas.calculateCritChance(attackerWit, defenderWit, moveCritChance)
    -- The final crit chance is the move's base chance, modified by the difference in Wit.
    -- A higher attacker Wit increases the chance, a higher defender Wit decreases it.
    return (moveCritChance + (attackerWit - defenderWit)) / 100
end

-- Helper function to calculate hit chance
function CombatFormulas.calculateHitChance(attackerWit, defenderWit, moveAccuracy)
    return ((moveAccuracy / 100) + (attackerWit - defenderWit) / 100)
end

-- Helper to calculate base damage for physical and magical attacks
function CombatFormulas.calculateBaseDamage(attacker, defender, attackData)
    local statUsed = (attackData.useType == "physical") and attacker.attackStat or attacker.magicStat
    local power = attackData.power or 0
    local effectiveness = CombatFormulas.calculateTypeEffectiveness(attackData.originType, defender.originType)

    -- Apply the type effectiveness to the attack power + attacker's stat.
    local adjustedPower = (power + statUsed) * effectiveness

    local rawDamage = 0
    local defenseStatUsed = 0
    -- Calculate damage dealt by a physical attack.
    if attackData.useType == "physical" then
        defenseStatUsed = defender.defenseStat
        rawDamage = math.max(0, adjustedPower - defenseStatUsed) -- Subtract defender's defense.
    -- Calculate damage dealt by a magic attack.
    elseif attackData.useType == "magic" then
        defenseStatUsed = defender.resistanceStat
        rawDamage = math.max(0, adjustedPower - defenseStatUsed) -- Subtract defender's resistance.
    end

    -- Base damage should always be a whole number.
    return math.floor(rawDamage)
end

-- Helper to calculate final damage including base damage and critical hit multiplier
function CombatFormulas.calculateFinalDamage(attacker, defender, attackData, isCrit)
    local damage = CombatFormulas.calculateBaseDamage(attacker, defender, attackData)
    if isCrit then
        damage = damage * 2
    end
    return math.floor(damage)
end


return CombatFormulas