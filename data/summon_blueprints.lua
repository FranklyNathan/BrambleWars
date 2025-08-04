-- data/summon_blueprints.lua
-- Defines the data-driven blueprints for all summonable units.
-- These units can typically be spawned by either players or enemies.

local SummonBlueprints = {
    tadpole = {
        displayName = "Tadpole",
        species = "Tadpole",
        originType = "marshborn",
        class = "warrior",
        sprite = "Tadpole", -- The key for Assets.images and Assets.animations
        maxHp = 4,
        wispStat = 0,
        portrait = "Default_Portrait.png",
        attackStat = 1,
        defenseStat = 1,
        magicStat = 1,
        resistanceStat = 1,
        witStat = 1,
        movement = 10,
        weight = 1, -- Very Light
        equippedWeapons = {},
        canSwim = true,
        dominantColor = {0.2, 0.2, 0.9}, -- Blue
        passives = {"Ephemeral", "Combustive"},
        growths = { maxHp = 5, attackStat = 5, defenseStat = 5, magicStat = 5, resistanceStat = 5, witStat = 5 },
        attacks = {},
        expReward = 5,
        lootValue = 0,
    }
}

return SummonBlueprints