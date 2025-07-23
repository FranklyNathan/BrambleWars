-- enemy_blueprints.lua
-- Defines the data-driven blueprints for all enemy types.

local EnemyBlueprints = {
    brawler = {
        originType = "cavernborn",
        maxHp = 30,
        portrait = "Default_Portrait.png",
        wispStat = 2,
        attackStat = 8,
        defenseStat = 10,
        magicStat = 10,
        resistanceStat = 10,
        witStat = 3,
        movement = 5,
        weight = 7, -- Medium-Heavy
        attacks = {"froggy_rush", "slash"}
    },
    archer = {
        originType = "cavernborn",
        maxHp = 25,
        portrait = "Default_Portrait.png",
        wispStat = 4,
        attackStat = 10,
        defenseStat = 7,
        magicStat = 4,
        resistanceStat = 6,
        witStat = 8,
        movement = 4,
        weight = 4, -- Light
        attacks = {"walnut_toss", "fireball", "longshot"}
    },
    punter = {
        originType = "cavernborn",
        maxHp = 38,
        portrait = "Rapidash_Portrait.png",
        wispStat = 3,
        attackStat = 8,
        defenseStat = 9,
        magicStat = 6,
        resistanceStat = 7,
        witStat = 2,
        movement = 5,
        weight = 8, -- Heavy
        attacks = {"froggy_rush", "uppercut"}
    }
}

return EnemyBlueprints