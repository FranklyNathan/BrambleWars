-- combat_formulas.lua
-- Contains pure functions for calculating combat-related values.

local CombatFormulas = {}

function CombatFormulas.calculateFinalDamage(attacker, target, power, bonusCritChance)
    -- 1. Calculate crit multiplier
    local critMultiplier = 1
    local isCrit = false
    bonusCritChance = bonusCritChance or 0
    local effectiveCritChance = Config.BASE_CRIT_CHANCE + bonusCritChance

    if effectiveCritChance > 1 then effectiveCritChance = 1 end
    if math.random() <= effectiveCritChance then
        critMultiplier = 2
        isCrit = true
    end

    -- 2. Calculate damage based on the formula: Power * (Attack / Defense) * Critical
    local targetDefense = math.max(1, target.finalDefenseStat or 1) -- Prevent division by zero
    local damage = power * ((attacker.finalAttackStat or 1) / targetDefense) * critMultiplier
    return damage, isCrit
end

return CombatFormulas