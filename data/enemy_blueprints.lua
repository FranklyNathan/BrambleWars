-- enemy_blueprints.lua
-- Defines the data-driven blueprints for all enemy types.

local EnemyBlueprints = {
    brawler = {
        originType = "cavernborn",
        class = "warrior",
        maxHp = 25,
        portrait = "Default_Portrait.png",
        wispStat = 1,
        attackStat = 4,
        defenseStat = 4,
        magicStat = 0,
        resistanceStat = 1,
        witStat = 2,
        movement = 5,
        weight = 7, -- Medium-Heavy
        equippedWeapon = "travelers_sword",
        expReward = 20,
        growths = {
            maxHp = 80,
            attackStat = 40,
            defenseStat = 50,
            magicStat = 10,
            resistanceStat = 20,
            witStat = 20,
        },
        attacks = {"sever"}
    },
    archer = {
        originType = "cavernborn",
        class = "scout",
        maxHp = 18,
        portrait = "Default_Portrait.png",
        wispStat = 2,
        attackStat = 3,
        defenseStat = 1,
        magicStat = 1,
        resistanceStat = 2,
        witStat = 4,
        movement = 4,
        weight = 4, -- Light
        equippedWeapon = "travelers_bow",
        expReward = 20,
        growths = {
            maxHp = 60,
            attackStat = 55,
            defenseStat = 20,
            magicStat = 20,
            resistanceStat = 25,
            witStat = 45,
        },
        attacks = {"fireball", "longshot"}
    },
    punter = {
        originType = "cavernborn",
        class = "lancer",
        maxHp = 22,
        portrait = "Default_Portrait.png",
        wispStat = 3,
        attackStat = 4,
        defenseStat = 3,
        magicStat = 1,
        resistanceStat = 2,
        witStat = 1,
        movement = 5,
        weight = 8, -- Heavy
        equippedWeapon = "travelers_lance",
        expReward = 30,
        growths = {
            maxHp = 75,
            attackStat = 45,
            defenseStat = 35,
            magicStat = 15,
            resistanceStat = 30,
            witStat = 25,
        },
        attacks = {"uppercut"}
    }
}

return EnemyBlueprints