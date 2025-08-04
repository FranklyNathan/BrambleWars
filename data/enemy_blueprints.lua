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
        weight = 5,
        equippedWeapons = {[1] = "travelers_sword"},
        lootValue = 10,
        dominantColor = {0.7, 0.3, 0.2}, -- Rusty Red
        expReward = 20,
        growths = {
            maxHp = 80,
            attackStat = 40,
            defenseStat = 50,
            magicStat = 10,
            resistanceStat = 20,
            witStat = 20,
        },
        attacks = {"sever"},
        passives = {"Desperate", "Unbound"}
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
        weight = 4,
        equippedWeapons = {[1] = "travelers_bow"},
        lootValue = 15,
        dominantColor = {0.3, 0.5, 0.2}, -- Muted Green
        expReward = 20,
        growths = {
            maxHp = 60,
            attackStat = 55,
            defenseStat = 20,
            magicStat = 20,
            resistanceStat = 25,
            witStat = 45,
        },
        attacks = {"fireball", "longshot"},
        passives = {"Unbound"}
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
        weight = 7,
        equippedWeapons = {[1] = "travelers_lance"},
        lootValue = 20,
        dominantColor = {0.5, 0.5, 0.6}, -- Slate Blue
        expReward = 30,
        growths = {
            maxHp = 75,
            attackStat = 45,
            defenseStat = 35,
            magicStat = 15,
            resistanceStat = 30,
            witStat = 25,
        },
        attacks = {"uppercut"},
        passives = {"Thunderguard"}
    }
}

return EnemyBlueprints