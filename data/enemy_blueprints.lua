-- enemy_blueprints.lua
-- Defines the data-driven blueprints for all enemy types.

local EnemyBlueprints = {
    brawler = {
        originType = "cavernborn",
        HpStat = 12,
        wispStat = 4,
        attackStat = 10,
        defenseStat = 10,
        magicStat = 10,
        resistanceStat = 10,
        witStat = 8,
        movement = 5,
        weight = 7, -- Medium-Heavy
        attacks = {"froggy_rush", "slash"}
    },
    archer = {
        originType = "cavernborn",
        HpStat = 12,
        wispStat = 4,
        attackStat = 10,
        defenseStat = 10,
        magicStat = 10,
        resistanceStat = 10,
        witStat = 8,
        movement = 4,
        weight = 4, -- Light
        attacks = {"froggy_rush", "fireball", "longshot"}
    },
    punter = {
        originType = "cavernborn",
        HpStat = 12,
        wispStat = 4,
        attackStat = 10,
        defenseStat = 10,
        magicStat = 10,
        resistanceStat = 10,
        witStat = 8,
        movement = 5,
        weight = 8, -- Heavy
        attacks = {"froggy_rush", "uppercut"}
    }
}

return EnemyBlueprints